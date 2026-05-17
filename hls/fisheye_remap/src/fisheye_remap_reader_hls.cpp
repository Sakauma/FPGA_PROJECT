// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 表驱动鱼眼去畸变 BRAM 读出核。
// 数据流位置    : 根据输出像素位置计算源像素 BRAM 地址，再打包为原 SRIO 64bit payload。
// 维护边界      : 不改变 SRIO、MIG、BD/IP、XDC；只替换原顺序 BRAM 读出逻辑。
// 修改约束      : 畸变表、图像尺寸或控制位变化后必须重新跑 csim/csynth/cosim 和 RTL 集成仿真。
// ============================================================================
#include "fisheye_remap_reader_hls.h"
#include "distortion_lut.h"

enum reader_state_t {
    S_IDLE = 0,
    S_WAIT_LINE_NUM = 1,
    S_WRITE_HEADER = 2,
    S_ISSUE_ADDR = 3,
    S_WAIT_DATA = 4,
    S_CAPTURE_PIXEL = 5,
    S_PREPROCESS_PIXEL = 6,
    S_WRITE_PAYLOAD = 7
};

static ap_uint<8> calc_delayed_line_slot(bram_addr_t bram_line_cur_w) {
#pragma HLS INLINE
    ap_uint<8> cur_slot = bram_line_cur_w.range(7, 0);
    // 新代码：Egor Izmaylov 新工程实际为 256 行环形缓存，半深度为 128 行。
    return (cur_slot >= kFisheyeHalfLineBufferDepth)
               ? (ap_uint<8>)(cur_slot - kFisheyeHalfLineBufferDepth)
               : (ap_uint<8>)(cur_slot + kFisheyeHalfLineBufferDepth);
}

static ap_uint<13> abs_s13(ap_int<13> value) {
#pragma HLS INLINE
    return (value < 0) ? (ap_uint<13>)(-value) : (ap_uint<13>)value;
}

static ap_uint<11> clamp_coord(ap_int<16> value) {
#pragma HLS INLINE
    if (value < 0) {
        return 0;
    }
    if (value > (kFisheyeImageWidth - 1)) {
        return kFisheyeImageWidth - 1;
    }
    return (ap_uint<11>)value;
}

static ap_uint<12> clamp_line(ap_int<16> value) {
#pragma HLS INLINE
    if (value < 0) {
        return 0;
    }
    if (value > (kFisheyeImageHeight - 1)) {
        return kFisheyeImageHeight - 1;
    }
    return (ap_uint<12>)value;
}

static ap_uint<13> approx_radius(ap_uint<13> abs_x, ap_uint<13> abs_y) {
#pragma HLS INLINE
    ap_uint<13> max_v = (abs_x > abs_y) ? abs_x : abs_y;
    ap_uint<13> min_v = (abs_x > abs_y) ? abs_y : abs_x;
    ap_uint<15> radius = (ap_uint<15>)max_v + (((ap_uint<15>)min_v * 3) >> 3);
    return (radius > kFisheyeMaxRadius) ? (ap_uint<13>)kFisheyeMaxRadius : (ap_uint<13>)radius;
}

static ap_uint<7> radius_to_lut_index(ap_uint<13> radius) {
#pragma HLS INLINE
    // 新代码：Egor Izmaylov 拟合半径不再是 1024，使用 27/256 的移位加减近似映射到 0..100。
    // 旧代码保留：ap_uint<20> scaled = (ap_uint<20>)radius * 100 + (kFisheyeMaxRadius >> 1);
    // 旧代码保留：ap_uint<10> idx = scaled >> 10;
    // 旧代码保留：ap_uint<27> scaled = ((ap_uint<27>)radius * 100 * kFisheyeRadiusRecipQ20) + (1 << 19);
    // 旧代码保留：ap_uint<10> idx = scaled >> 20;
    ap_uint<18> scaled = (((ap_uint<18>)radius << 5) - ((ap_uint<18>)radius << 2) - (ap_uint<18>)radius) + 128;
    ap_uint<10> idx = scaled >> 8;
    return (idx > 100) ? (ap_uint<7>)100 : (ap_uint<7>)idx;
}

static ap_int<16> scale_delta(ap_int<13> delta, ap_uint<18> scale_q16) {
#pragma HLS INLINE
    ap_int<32> product = (ap_int<32>)delta * (ap_int<32>)scale_q16;
    return (ap_int<16>)(product >> 16);
}

static ap_uint<18> amplify_scale_x_q16(ap_uint<18> scale_q16) {
#pragma HLS INLINE
    // 新代码：Egor Izmaylov
    // 水平方向按拟合后的畸变表 1x 执行，不再用强度放大掩盖中心/半径误差。
    // 旧代码保留：static ap_uint<18> amplify_scale_q16(ap_uint<18> scale_q16)
    ap_int<20> delta_from_identity = (ap_int<20>)scale_q16 - (ap_int<20>)65536;
    ap_int<30> amplified = (ap_int<30>)65536 + (((ap_int<30>)delta_from_identity * kFisheyeRemapStrengthXQ8) >> 8);
    if (amplified < 0) {
        return 0;
    }
    if (amplified > 262143) {
        return 262143;
    }
    return (ap_uint<18>)amplified;
}

static ap_uint<18> amplify_scale_y_q16(ap_uint<18> scale_q16) {
#pragma HLS INLINE
    // 新代码：Egor Izmaylov
    // 垂直方向按拟合后的畸变表 1x 执行；参考拟合显示自然位移小于 96 行安全窗。
    ap_int<20> delta_from_identity = (ap_int<20>)scale_q16 - (ap_int<20>)65536;
    ap_int<30> amplified = (ap_int<30>)65536 + (((ap_int<30>)delta_from_identity * kFisheyeRemapStrengthYQ8) >> 8);
    if (amplified < 0) {
        return 0;
    }
    if (amplified > 262143) {
        return 262143;
    }
    return (ap_uint<18>)amplified;
}

static ap_int<13> clamp_vertical_shift(ap_int<16> shift) {
#pragma HLS INLINE
    // 新代码：Egor Izmaylov
    // 当前新工程使用 256 行环形缓存，最大安全半窗为 128 行；这里仍限制到 96 行，避免 wrap 到错误行。
    if (shift > kFisheyeMaxVerticalShift) {
        return (ap_int<13>)kFisheyeMaxVerticalShift;
    }
    if (shift < -kFisheyeMaxVerticalShift) {
        return (ap_int<13>)(-kFisheyeMaxVerticalShift);
    }
    return (ap_int<13>)shift;
}

static ap_int<13> calc_curve_flatten_delta_y(ap_uint<11> out_x,
                                             ap_uint<12> out_y) {
#pragma HLS INLINE
    // 新代码：Egor Izmaylov
    // 局部圆环拉平补偿：只在下半图像、目标水平线附近生效，且最终仍受 ±96 行安全窗口限制。
    // 旧代码保留：此前仅依赖畸变表径向比例，raw16 参考图证明其位移不足以拉直可见圆环。
    if (out_y < kFisheyeCurveFlattenCenterY) {
        return 0;
    }

    ap_int<13> dx = (ap_int<13>)out_x - (ap_int<13>)kFisheyeCurveFlattenCenterX;
    ap_uint<13> abs_dx = abs_s13(dx);
    if (abs_dx > kFisheyeCurveFlattenRadius) {
        return 0;
    }

    ap_int<13> line_delta = (ap_int<13>)out_y - (ap_int<13>)kFisheyeCurveFlattenTargetY;
    ap_uint<13> dist_to_line = abs_s13(line_delta);
    if (dist_to_line >= kFisheyeCurveFlattenBand) {
        return 0;
    }

    // 新代码：Egor Izmaylov
    // 下半圆弧 y ~= cy + r - dx^2/(2r)，第一版检测目标线低于切线约 135 行。
    // 使用 dx^2>>11 做保守近似，保留弧线方向拉动，同时换取 250MHz 目标下更短组合路径。
    ap_uint<26> dx_square = (ap_uint<26>)abs_dx * (ap_uint<26>)abs_dx;
    ap_uint<14> sagitta = (ap_uint<14>)(dx_square >> 11);
    // 旧代码保留：ap_int<16> raw_delta = -(ap_int<16>)sagitta;
    ap_int<16> raw_delta = (ap_int<16>)kFisheyeCurveFlattenArcBase - (ap_int<16>)sagitta;
    ap_uint<9> weight = (ap_uint<9>)(kFisheyeCurveFlattenBand - dist_to_line);
    // 带宽固定为 256 行，权重归一化可直接用 >>8，避免额外常数乘法拖慢 HLS 时序。
    ap_int<27> weighted = (ap_int<27>)raw_delta * (ap_int<27>)weight;
    ap_int<16> delta = (ap_int<16>)(weighted >> 8);
    return clamp_vertical_shift(delta);
}

static ap_uint<8> wrap_source_slot(ap_uint<8> out_slot, ap_int<13> delta_line) {
#pragma HLS INLINE
    ap_int<14> slot = (ap_int<14>)out_slot + (ap_int<14>)delta_line;
    if (slot < 0) {
        slot += kFisheyeLineBufferDepth;
    }
    if (slot < 0) {
        slot += kFisheyeLineBufferDepth;
    }
    if (slot >= kFisheyeLineBufferDepth) {
        slot -= kFisheyeLineBufferDepth;
    }
    if (slot >= kFisheyeLineBufferDepth) {
        slot -= kFisheyeLineBufferDepth;
    }
    return (ap_uint<8>)slot;
}

static void map_source_pixel(ap_uint<11> out_x,
                             ap_uint<12> out_y,
                             ap_uint<8> out_slot,
                             ap_uint<32> algo_ctrl,
                             ap_uint<8>& src_slot,
                             ap_uint<11>& src_x) {
#pragma HLS INLINE
    if (algo_ctrl[0] == 0) {
        src_slot = out_slot;
        src_x = out_x;
        return;
    }

    ap_int<13> dx = (ap_int<13>)out_x - kFisheyeCenterX;
    ap_int<13> dy = (ap_int<13>)out_y - kFisheyeCenterY;
    ap_uint<13> radius = approx_radius(abs_s13(dx), abs_s13(dy));
    ap_uint<7> lut_idx = radius_to_lut_index(radius);
    ap_uint<18> scale_q16 = algo_ctrl[3] ? kLaserScaleQ16[lut_idx] : kInfraredScaleQ16[lut_idx];
    ap_uint<18> amplified_scale_x_q16 = amplify_scale_x_q16(scale_q16);
    ap_uint<18> amplified_scale_y_q16 = amplify_scale_y_q16(scale_q16);

    // 新代码：Egor Izmaylov 按 F-THETA 畸变定义使用 source_radius = ideal_radius * (1 + distortion)。
    // 旧代码保留：ap_int<16> src_x_s = (ap_int<16>)kFisheyeCenterX + scale_delta(dx, scale_q16);
    // 旧代码保留：ap_int<16> src_y_s = (ap_int<16>)kFisheyeCenterY + scale_delta(dy, scale_q16);
    // 新代码：Egor Izmaylov 使用 X/Y 分离强度：水平强化效果，垂直限制到 256 行缓存安全窗口内。
    ap_int<16> src_x_s = (ap_int<16>)kFisheyeCenterX + scale_delta(dx, amplified_scale_x_q16);
    ap_int<16> src_y_s_unclamped = (ap_int<16>)kFisheyeCenterY + scale_delta(dy, amplified_scale_y_q16);
    ap_uint<12> src_y = clamp_line(src_y_s_unclamped);
    ap_int<16> base_delta_line = (ap_int<16>)src_y - (ap_int<16>)out_y;
    // 新代码：Egor Izmaylov
    // 在畸变表基础上叠加局部圆环拉平补偿，增强“内圈下半部分应接近水平线”的可见效果。
    // 旧代码保留：ap_int<13> safe_delta_line = clamp_vertical_shift((ap_int<16>)src_y - (ap_int<16>)out_y);
    ap_int<13> curve_delta_line = calc_curve_flatten_delta_y(out_x, out_y);
    ap_int<13> safe_delta_line = clamp_vertical_shift(base_delta_line + (ap_int<16>)curve_delta_line);
    // 旧代码保留：src_slot = wrap_source_slot(out_slot, (ap_int<13>)src_y - (ap_int<13>)out_y);
    src_x = clamp_coord(src_x_s);
    src_slot = wrap_source_slot(out_slot, safe_delta_line);
}

void fisheye_remap_addr_hls(ap_uint<1> in_valid,
                            ap_uint<11> out_x,
                            ap_uint<12> out_line,
                            line_slot_addr_t out_slot,
                            ap_uint<7> packet_pixel_idx,
                            ap_uint<32> algo_ctrl,
                            ap_uint<1>& out_valid,
                            line_slot_addr_t& src_slot,
                            ap_uint<11>& src_x,
                            ap_uint<7>& packet_pixel_idx_out) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE ap_none port=in_valid
#pragma HLS INTERFACE ap_none port=out_x
#pragma HLS INTERFACE ap_none port=out_line
#pragma HLS INTERFACE ap_none port=out_slot
#pragma HLS INTERFACE ap_none port=packet_pixel_idx
#pragma HLS INTERFACE ap_none port=algo_ctrl
#pragma HLS INTERFACE ap_none port=out_valid
#pragma HLS INTERFACE ap_none port=src_slot
#pragma HLS INTERFACE ap_none port=src_x
#pragma HLS INTERFACE ap_none port=packet_pixel_idx_out
#pragma HLS PIPELINE II=1
    // 新代码：Egor Izmaylov
    // HLS 只承担去畸变地址计算，并回传对齐后的 packet 内像素序号；发包节奏由 RTL packetizer 固定。
    ap_uint<8> mapped_slot = 0;
    ap_uint<11> mapped_x = 0;
    if (in_valid) {
        map_source_pixel(out_x, out_line, out_slot.range(7, 0), algo_ctrl, mapped_slot, mapped_x);
    }

    out_valid = in_valid;
    src_slot = mapped_slot;
    src_x = mapped_x;
    packet_pixel_idx_out = packet_pixel_idx;
}

static ap_uint<16> clamp_pixel_u16(ap_uint<32> value) {
#pragma HLS INLINE
    return (value > 65535) ? (ap_uint<16>)65535 : (ap_uint<16>)value;
}

static ap_uint<16> calc_adaptive_gain_q8(ap_uint<16> span) {
#pragma HLS INLINE
    if (span < kFisheyeAdaptiveMinSpan) {
        return kFisheyeAdaptiveGainIdentityQ8;
    }
    if (span >= 32768) {
        // 新代码：Egor Izmaylov
        // 真实 raw16 帧动态范围已经足够大时保持 1x，避免默认算法模式把高亮区域整体打到饱和。
        // 旧代码保留：return 512;
        return kFisheyeAdaptiveGainIdentityQ8;
    }
    if (span >= 16384) {
        // 新代码：Egor Izmaylov
        // 中高动态范围只做温和增强，避免上板画面亮部细节被预处理吞掉。
        // 旧代码保留：return 1024;
        return 384;
    }
    if (span >= 8192) {
        // 新代码：Egor Izmaylov
        // 中动态范围按 2x 增益处理，主要服务偏暗场景。
        // 旧代码保留：return 2048;
        return 512;
    }
    if (span >= 4096) {
        // 新代码：Egor Izmaylov
        // 低动态范围才进入较强拉伸。
        // 旧代码保留：return 4096;
        return 1024;
    }
    // 新代码：Egor Izmaylov
    // 极低动态范围限制在 8x，保留暗场可见性，同时避免噪声被过度放大。
    // 旧代码保留：return kFisheyeAdaptiveGainMaxQ8;
    return 2048;
}

static ap_uint<16> smooth_u16(ap_uint<16> old_value, ap_uint<16> new_value) {
#pragma HLS INLINE
    ap_uint<18> mixed = ((ap_uint<18>)old_value * 3) + new_value + 2;
    return (ap_uint<16>)(mixed >> 2);
}

static ap_uint<16> preprocess_pixel(ap_uint<16> pixel,
                                    ap_uint<32> algo_ctrl,
                                    ap_uint<16> adaptive_black,
                                    ap_uint<16> adaptive_gain_q8) {
#pragma HLS INLINE
    // 新代码：Egor Izmaylov bit4 用于关闭自适应预处理，便于上板和旁路画面对比。
    if (algo_ctrl[0] == 0 || algo_ctrl[4]) {
        return pixel;
    }

    ap_uint<16> shifted = (pixel > adaptive_black) ? (ap_uint<16>)(pixel - adaptive_black) : (ap_uint<16>)0;
    ap_uint<32> scaled = (ap_uint<32>)shifted * adaptive_gain_q8;
    return clamp_pixel_u16(scaled >> 8);
}

#if 0
// 旧代码保留：Egor Izmaylov
// 该版本每个像素需要“发地址/等待/采集/预处理”多状态推进，板上容易因为吞吐不足导致算法链路断流。
void fisheye_remap_reader_hls(bram_addr_t bram_line_cur_w,
                              ap_uint<1> bram_line_cur_w_en,
                              ap_uint<12> bram_line_num,
                              ap_uint<16> bram_doutb,
                              ap_uint<1> fifo_almost_full,
                              ap_uint<32> algo_ctrl,
                              line_slot_addr_t& bram_line_num_addr,
                              bram_addr_t& bram_addrb,
                              ap_uint<1>& fifo_wr_en,
                              fifo_word_t& fifo_din,
                              ap_uint<1>& fifo_word_toggle) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE ap_none port=bram_line_cur_w
#pragma HLS INTERFACE ap_none port=bram_line_cur_w_en
#pragma HLS INTERFACE ap_none port=bram_line_num
#pragma HLS INTERFACE ap_none port=bram_doutb
#pragma HLS INTERFACE ap_none port=fifo_almost_full
#pragma HLS INTERFACE ap_none port=algo_ctrl
#pragma HLS INTERFACE ap_none port=bram_line_num_addr
#pragma HLS INTERFACE ap_none port=bram_addrb
#pragma HLS INTERFACE ap_none port=fifo_wr_en
#pragma HLS INTERFACE ap_none port=fifo_din
#pragma HLS INTERFACE ap_none port=fifo_word_toggle
    // 新代码：Egor Izmaylov
    // 顶层为逐拍推进的协议状态机，必须保持 II=1；否则 HLS 会把乘法/查表调度成长延迟事务，
    // 板上表现为 fifo_wr_en 稀疏脉冲，无法复刻旧 readbram_to_axis64_top 的连续 packet 节奏。
// 旧代码保留：#pragma HLS PIPELINE II=1
// 新代码：Egor Izmaylov
// 顶层强制 pipeline 会把完整 remap 计算压进单拍组合路径，HLS 估算 Fmax 降到约 60MHz；
// 这里改回逐拍寄存器状态机，让地址/像素/打包状态按时钟推进。
    // 新代码：Egor Izmaylov 本函数是逐拍推进的状态机，不强制顶层 PIPELINE，避免 HLS 报出误导性 II 警告。
    // 旧代码保留：#pragma HLS PIPELINE II=1

// 新代码：Egor Izmaylov
// 板上 ILA 证明未 pipeline 时 HLS 内部调度约 118 拍才输出 1 个 FIFO word，导致画面压缩并重复。
// 因此顶层必须保持 II=1；若时序不足，应拆分 remap 计算流水线，而不是牺牲输出协议节奏。
#pragma HLS PIPELINE II=1

    static ap_uint<3> state = S_IDLE;
    static ap_uint<1> video_started = 0;
    static ap_uint<8> out_slot = 0;
    static ap_uint<12> out_line = 0;
    static ap_uint<4> packet_idx = 0;
    static ap_uint<7> packet_pixel_idx = 0;
    static ap_uint<12> line_pixel_idx = 0;
    static ap_uint<2> pack_idx = 0;
    static fifo_word_t payload_word = 0;
    static ap_uint<1> payload_last = 0;
    static bram_addr_t bram_addr_reg = 0;
    static line_slot_addr_t line_num_addr_reg = 0;
    static ap_uint<16> source_pixel_reg = 0;
    // 新代码：Egor Izmaylov 自适应预处理参数。当前帧统计 min/max，下一帧应用黑电平和 Q8 增益。
    static ap_uint<16> frame_min = 65535;
    static ap_uint<16> frame_max = 0;
    static ap_uint<16> adaptive_black = 0;
    static ap_uint<16> adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
    static ap_uint<1> adaptive_valid = 0;
    // 新代码：Egor Izmaylov ap_ctrl_none 状态机需要显式复位内部静态寄存器，保证板上复位和 RTL 仿真一致。
#pragma HLS RESET variable=state
#pragma HLS RESET variable=video_started
#pragma HLS RESET variable=out_slot
#pragma HLS RESET variable=out_line
#pragma HLS RESET variable=packet_idx
#pragma HLS RESET variable=packet_pixel_idx
#pragma HLS RESET variable=line_pixel_idx
#pragma HLS RESET variable=pack_idx
#pragma HLS RESET variable=payload_word
#pragma HLS RESET variable=payload_last
#pragma HLS RESET variable=bram_addr_reg
#pragma HLS RESET variable=line_num_addr_reg
#pragma HLS RESET variable=source_pixel_reg
#pragma HLS RESET variable=frame_min
#pragma HLS RESET variable=frame_max
#pragma HLS RESET variable=adaptive_black
#pragma HLS RESET variable=adaptive_gain_q8
#pragma HLS RESET variable=adaptive_valid

    // 新代码：Egor Izmaylov
    // 所有 ap_none 输出端口统一在函数末尾赋值一次，避免 HLS 因多分支写端口而把顶层 pipeline 退化到大 II。
    ap_uint<1> fifo_wr_en_out = 0;
    fifo_word_t fifo_din_out = 0;
    bram_addr_t bram_addrb_out = bram_addr_reg;
    line_slot_addr_t bram_line_num_addr_out = line_num_addr_reg;
    ap_uint<3> state_next = state;
    ap_uint<1> fifo_word_toggle_out = word_toggle;

    if (algo_ctrl[31]) {
        // 新代码：Egor Izmaylov
        // 调试/仿真复位位。正常上板控制值不会置位 bit31；raw16 多模式 C 仿真用它隔离各模式状态。
        state_next = S_IDLE;
        video_started = 0;
        out_slot = 0;
        out_line = 0;
        packet_idx = 0;
        packet_pixel_idx = 0;
        line_pixel_idx = 0;
        pack_idx = 0;
        payload_word = 0;
        payload_last = 0;
        bram_addr_reg = 0;
        line_num_addr_reg = 0;
        source_pixel_reg = 0;
        frame_min = 65535;
        frame_max = 0;
        adaptive_black = 0;
        adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
        adaptive_valid = 0;
        word_toggle = 0;
        bram_addrb_out = 0;
        bram_line_num_addr_out = 0;
    } else {

    if (bram_line_cur_w_en && bram_line_cur_w.range(7, 0) >= kFisheyeHalfLineBufferDepth) {
        video_started = 1;
    }

    switch (state) {
    case S_IDLE:
        if (bram_line_cur_w_en && (video_started || bram_line_cur_w.range(7, 0) >= kFisheyeHalfLineBufferDepth)) {
            out_slot = calc_delayed_line_slot(bram_line_cur_w);
            line_num_addr_reg = calc_delayed_line_slot(bram_line_cur_w);
            state_next = S_WAIT_LINE_NUM;
        }
        break;

    case S_WAIT_LINE_NUM:
        out_line = bram_line_num;
        packet_idx = 0;
        packet_pixel_idx = 0;
        line_pixel_idx = 0;
        pack_idx = 0;
        payload_word = 0;
        payload_last = 0;
        state_next = S_WRITE_HEADER;
        break;

    case S_WRITE_HEADER:
        if (!fifo_almost_full) {
            ap_uint<32> srio_addr = ((ap_uint<32>)out_line << 12) | ((ap_uint<32>)packet_idx << 8);
            fifo_din_out = ((fifo_word_t)0 << 64) | ((fifo_word_t)0x00602000 << 32) | srio_addr;
            fifo_wr_en_out = 1;
            pack_idx = 0;
            payload_word = 0;
            state_next = S_ISSUE_ADDR;
        }
        break;

    case S_ISSUE_ADDR: {
        ap_uint<8> src_slot;
        ap_uint<11> src_x;
        ap_uint<11> out_x = line_pixel_idx.range(10, 0);
        map_source_pixel(out_x, out_line, out_slot, algo_ctrl, src_slot, src_x);
        bram_addr_reg = ((bram_addr_t)src_slot << 11) | src_x;
        state_next = S_WAIT_DATA;
        break;
    }

    case S_WAIT_DATA:
        state_next = S_CAPTURE_PIXEL;
        break;

    case S_CAPTURE_PIXEL:
        // 新代码：Egor Izmaylov 先寄存 BRAM 读数据，避免 BRAM 输出同拍进入自适应预处理乘法器导致 250MHz 时序过长。
        source_pixel_reg = bram_doutb;
        state_next = S_PREPROCESS_PIXEL;
        break;

    case S_PREPROCESS_PIXEL: {
        // 新代码：Egor Izmaylov 用固定分支替代可变 range，降低 HLS 生成动态选择器的风险。
        // 旧代码保留：payload_word.range(pack_idx * 16 + 15, pack_idx * 16) = bram_doutb;
        // 新代码：Egor Izmaylov 对真实源像素执行自适应预处理；第一帧默认单位增益，后续帧使用上一帧统计参数。
        ap_uint<16> source_pixel = source_pixel_reg;
        if (algo_ctrl[0] && !algo_ctrl[4]) {
            if (source_pixel < frame_min) {
                frame_min = source_pixel;
            }
            if (source_pixel > frame_max) {
                frame_max = source_pixel;
            }
        }
        ap_uint<16> output_pixel = preprocess_pixel(source_pixel, algo_ctrl, adaptive_black, adaptive_gain_q8);
        switch (pack_idx) {
        case 0:
            payload_word.range(15, 0) = output_pixel;
            break;
        case 1:
            payload_word.range(31, 16) = output_pixel;
            break;
        case 2:
            payload_word.range(47, 32) = output_pixel;
            break;
        default:
            payload_word.range(63, 48) = output_pixel;
            break;
        }
        payload_last = (packet_pixel_idx == (kFisheyePacketPixels - 1));

        line_pixel_idx = line_pixel_idx + 1;
        packet_pixel_idx = packet_pixel_idx + 1;

        if (pack_idx == (kFisheyePixelsPerWord - 1)) {
            pack_idx = 0;
            state_next = S_WRITE_PAYLOAD;
        } else {
            pack_idx = pack_idx + 1;
            state_next = S_ISSUE_ADDR;
        }
        break;
    }

    case S_WRITE_PAYLOAD:
        if (!fifo_almost_full) {
            fifo_din_out = ((fifo_word_t)payload_last << 64) | payload_word.range(63, 0);
            fifo_wr_en_out = 1;
            payload_word = 0;

            if (payload_last) {
                packet_pixel_idx = 0;
                if (line_pixel_idx == kFisheyeImageWidth) {
                    // 新代码：Egor Izmaylov 每帧末尾更新下一帧使用的自适应预处理参数；bit5 可冻结当前参数。
                    if (out_line == (kFisheyeImageHeight - 1) && !algo_ctrl[5]) {
                        ap_uint<16> frame_span = frame_max - frame_min;
                        if (algo_ctrl[0] && !algo_ctrl[4] && frame_span >= kFisheyeAdaptiveMinSpan) {
                            ap_uint<16> target_gain_q8 = calc_adaptive_gain_q8(frame_span);
                            if (adaptive_valid) {
                                // 新代码：Egor Izmaylov
                                // 帧末路径不再做平滑加权，避免 old*3+new 的组合链路拖低 250MHz HLS 时序。
                                // 旧代码保留：adaptive_black = smooth_u16(adaptive_black, frame_min);
                                // 旧代码保留：adaptive_gain_q8 = smooth_u16(adaptive_gain_q8, target_gain_q8);
                                adaptive_black = frame_min;
                                adaptive_gain_q8 = target_gain_q8;
                            } else {
                                adaptive_black = frame_min;
                                adaptive_gain_q8 = target_gain_q8;
                                adaptive_valid = 1;
                            }
                        } else if (!adaptive_valid) {
                            adaptive_black = 0;
                            adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
                        }
                        frame_min = 65535;
                        frame_max = 0;
                    }
                    state_next = S_IDLE;
                } else {
                    packet_idx = packet_idx + 1;
                    state_next = S_WRITE_HEADER;
                }
            } else {
                state_next = S_ISSUE_ADDR;
            }
        }
        break;

    default:
        state_next = S_IDLE;
        break;
    }
    }

    if (fifo_wr_en_out) {
        ap_uint<1> next_word_toggle = ~word_toggle;
        word_toggle = next_word_toggle;
        fifo_word_toggle_out = next_word_toggle;
    }

    state = state_next;
    fifo_wr_en = fifo_wr_en_out;
    fifo_din = fifo_din_out;
    fifo_word_toggle = fifo_word_toggle_out;
    bram_addrb = bram_addrb_out;
    bram_line_num_addr = bram_line_num_addr_out;
}
#endif

// 新代码：Egor Izmaylov
// 连续 BRAM reader：保持最新 remap/预处理参数不变，只把传输节奏改为接近旧 readbram_to_axis64_top。
void fisheye_remap_reader_hls(bram_addr_t bram_line_cur_w,
                              ap_uint<1> bram_line_cur_w_en,
                              ap_uint<12> bram_line_num,
                              ap_uint<16> bram_doutb,
                              ap_uint<1> fifo_almost_full,
                              ap_uint<32> algo_ctrl,
                              line_slot_addr_t& bram_line_num_addr,
                              bram_addr_t& bram_addrb,
                              ap_uint<1>& fifo_wr_en,
                              fifo_word_t& fifo_din,
                              ap_uint<1>& fifo_word_toggle) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE ap_none port=bram_line_cur_w
#pragma HLS INTERFACE ap_none port=bram_line_cur_w_en
#pragma HLS INTERFACE ap_none port=bram_line_num
#pragma HLS INTERFACE ap_none port=bram_doutb
#pragma HLS INTERFACE ap_none port=fifo_almost_full
#pragma HLS INTERFACE ap_none port=algo_ctrl
#pragma HLS INTERFACE ap_none port=bram_line_num_addr
#pragma HLS INTERFACE ap_none port=bram_addrb
#pragma HLS INTERFACE ap_none port=fifo_wr_en
#pragma HLS INTERFACE ap_none port=fifo_din
#pragma HLS INTERFACE ap_none port=fifo_word_toggle
// 旧代码保留：#pragma HLS PIPELINE II=1
// 新代码：Egor Izmaylov
// 顶层强制 pipeline 会把完整 remap 计算压进单拍组合路径；本实现依靠寄存器状态机逐拍推进。
// 旧代码保留：#pragma HLS PIPELINE II=1

    static ap_uint<3> state = S_IDLE;
    static ap_uint<1> video_started = 0;
    static ap_uint<8> out_slot = 0;
    static ap_uint<12> out_line = 0;
    static ap_uint<4> packet_idx = 0;
    static ap_uint<12> issue_pixel_idx = 0;
    static ap_uint<7> read_packet_pixel_idx = 0;
    static ap_uint<1> read_valid = 0;
    static ap_uint<2> pack_idx = 0;
    static fifo_word_t payload_word = 0;
    static ap_uint<1> pending_payload_valid = 0;
    static fifo_word_t pending_payload_word = 0;
    static ap_uint<1> word_toggle = 0;
    static bram_addr_t bram_addr_reg = 0;
    static line_slot_addr_t line_num_addr_reg = 0;
    static ap_uint<16> frame_min = 65535;
    static ap_uint<16> frame_max = 0;
    static ap_uint<16> adaptive_black = 0;
    static ap_uint<16> adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
    static ap_uint<1> adaptive_valid = 0;

#pragma HLS RESET variable=state
#pragma HLS RESET variable=video_started
#pragma HLS RESET variable=out_slot
#pragma HLS RESET variable=out_line
#pragma HLS RESET variable=packet_idx
#pragma HLS RESET variable=issue_pixel_idx
#pragma HLS RESET variable=read_packet_pixel_idx
#pragma HLS RESET variable=read_valid
#pragma HLS RESET variable=pack_idx
#pragma HLS RESET variable=payload_word
#pragma HLS RESET variable=pending_payload_valid
#pragma HLS RESET variable=pending_payload_word
#pragma HLS RESET variable=word_toggle
#pragma HLS RESET variable=bram_addr_reg
#pragma HLS RESET variable=line_num_addr_reg
#pragma HLS RESET variable=frame_min
#pragma HLS RESET variable=frame_max
#pragma HLS RESET variable=adaptive_black
#pragma HLS RESET variable=adaptive_gain_q8
#pragma HLS RESET variable=adaptive_valid

    ap_uint<1> fifo_wr_en_out = 0;
    fifo_word_t fifo_din_out = 0;
    bram_addr_t bram_addrb_out = bram_addr_reg;
    line_slot_addr_t bram_line_num_addr_out = line_num_addr_reg;
    ap_uint<3> state_next = state;
    // 新代码：Egor Izmaylov
    // HLS RTL 对 ap_none 输出会保持上一拍值；该翻转位只在有效写字产生时改变，
    // wrapper 据此过滤保持态重复写入，不改变 payload 内容和现有 SRIO 协议。
    ap_uint<1> fifo_word_toggle_out = word_toggle;

    if (algo_ctrl[31]) {
        state_next = S_IDLE;
        video_started = 0;
        out_slot = 0;
        out_line = 0;
        packet_idx = 0;
        issue_pixel_idx = 0;
        read_packet_pixel_idx = 0;
        read_valid = 0;
        pack_idx = 0;
        payload_word = 0;
        pending_payload_valid = 0;
        pending_payload_word = 0;
        word_toggle = 0;
        bram_addr_reg = 0;
        line_num_addr_reg = 0;
        frame_min = 65535;
        frame_max = 0;
        adaptive_black = 0;
        adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
        adaptive_valid = 0;
        bram_addrb_out = 0;
        bram_line_num_addr_out = 0;
        fifo_word_toggle_out = 0;
    } else {
        if (bram_line_cur_w_en && bram_line_cur_w.range(7, 0) >= kFisheyeHalfLineBufferDepth) {
            video_started = 1;
        }

        switch (state) {
        case S_IDLE:
            read_valid = 0;
            pending_payload_valid = 0;
            if (bram_line_cur_w_en && (video_started || bram_line_cur_w.range(7, 0) >= kFisheyeHalfLineBufferDepth)) {
                ap_uint<8> delayed_slot = calc_delayed_line_slot(bram_line_cur_w);
                out_slot = delayed_slot;
                line_num_addr_reg = delayed_slot;
                bram_line_num_addr_out = delayed_slot;
                state_next = S_WAIT_LINE_NUM;
            }
            break;

        case S_WAIT_LINE_NUM:
            out_line = bram_line_num;
            packet_idx = 0;
            issue_pixel_idx = 0;
            read_packet_pixel_idx = 0;
            read_valid = 0;
            pack_idx = 0;
            payload_word = 0;
            pending_payload_valid = 0;
            pending_payload_word = 0;
            state_next = S_WRITE_HEADER;
            break;

        case S_WRITE_HEADER:
            if (!fifo_almost_full) {
                ap_uint<32> srio_addr = ((ap_uint<32>)out_line << 12) | ((ap_uint<32>)packet_idx << 8);
                fifo_din_out = ((fifo_word_t)0 << 64) | ((fifo_word_t)0x00602000 << 32) | srio_addr;
                fifo_wr_en_out = 1;
                pack_idx = 0;
                payload_word = 0;
                read_valid = 0;
                state_next = S_ISSUE_ADDR;
            }
            break;

        case S_ISSUE_ADDR: {
            ap_uint<1> block_issue = 0;

            if (pending_payload_valid) {
                if (!fifo_almost_full) {
                    fifo_din_out = pending_payload_word;
                    fifo_wr_en_out = 1;
                    pending_payload_valid = 0;
                    if (pending_payload_word[64]) {
                        if (packet_idx == (kFisheyePacketsPerLine - 1)) {
                            if (out_line == (kFisheyeImageHeight - 1) && !algo_ctrl[5]) {
                                ap_uint<16> frame_span = frame_max - frame_min;
                                if (algo_ctrl[0] && !algo_ctrl[4] && frame_span >= kFisheyeAdaptiveMinSpan) {
                                    ap_uint<16> target_gain_q8 = calc_adaptive_gain_q8(frame_span);
                                    adaptive_black = frame_min;
                                    adaptive_gain_q8 = target_gain_q8;
                                    adaptive_valid = 1;
                                } else if (!adaptive_valid) {
                                    adaptive_black = 0;
                                    adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
                                }
                                frame_min = 65535;
                                frame_max = 0;
                            }
                            state_next = S_IDLE;
                        } else {
                            packet_idx = packet_idx + 1;
                            state_next = S_WRITE_HEADER;
                        }
                    }
                }
                block_issue = 1;
            } else if (read_valid) {
                ap_uint<16> source_pixel = bram_doutb;
                if (algo_ctrl[0] && !algo_ctrl[4]) {
                    if (source_pixel < frame_min) {
                        frame_min = source_pixel;
                    }
                    if (source_pixel > frame_max) {
                        frame_max = source_pixel;
                    }
                }

                ap_uint<16> output_pixel = preprocess_pixel(source_pixel, algo_ctrl, adaptive_black, adaptive_gain_q8);
                fifo_word_t new_payload_word = payload_word;
                switch (pack_idx) {
                case 0:
                    new_payload_word.range(15, 0) = output_pixel;
                    break;
                case 1:
                    new_payload_word.range(31, 16) = output_pixel;
                    break;
                case 2:
                    new_payload_word.range(47, 32) = output_pixel;
                    break;
                default:
                    new_payload_word.range(63, 48) = output_pixel;
                    break;
                }

                read_valid = 0;
                if (pack_idx == (kFisheyePixelsPerWord - 1)) {
                    fifo_word_t completed_word =
                        ((fifo_word_t)(read_packet_pixel_idx == (kFisheyePacketPixels - 1)) << 64) |
                        new_payload_word.range(63, 0);
                    payload_word = 0;
                    pack_idx = 0;
                    if (!fifo_almost_full) {
                        fifo_din_out = completed_word;
                        fifo_wr_en_out = 1;
                        // 新代码：Egor Izmaylov
                        // 复刻旧 readbram_to_fifo 的 4 像素采集 + 1 拍 payload 写入节奏。
                        // 旧实现不会在写 payload 的同一拍推进下一个 BRAM 地址；保持该节奏可降低
                        // BRAM 读出到 SRIO 异步 FIFO 的瞬时写入压力，避免板上出现压缩/重复包现象。
                        block_issue = 1;
                        if (completed_word[64]) {
                            if (packet_idx == (kFisheyePacketsPerLine - 1)) {
                                if (out_line == (kFisheyeImageHeight - 1) && !algo_ctrl[5]) {
                                    ap_uint<16> frame_span = frame_max - frame_min;
                                    if (algo_ctrl[0] && !algo_ctrl[4] && frame_span >= kFisheyeAdaptiveMinSpan) {
                                        ap_uint<16> target_gain_q8 = calc_adaptive_gain_q8(frame_span);
                                        adaptive_black = frame_min;
                                        adaptive_gain_q8 = target_gain_q8;
                                        adaptive_valid = 1;
                                    } else if (!adaptive_valid) {
                                        adaptive_black = 0;
                                        adaptive_gain_q8 = kFisheyeAdaptiveGainIdentityQ8;
                                    }
                                    frame_min = 65535;
                                    frame_max = 0;
                                }
                                state_next = S_IDLE;
                            } else {
                                packet_idx = packet_idx + 1;
                                state_next = S_WRITE_HEADER;
                            }
                        }
                    } else {
                        pending_payload_valid = 1;
                        pending_payload_word = completed_word;
                        block_issue = 1;
                    }
                } else {
                    payload_word = new_payload_word;
                    pack_idx = pack_idx + 1;
                }
            }

            ap_uint<12> packet_pixel_limit = (((ap_uint<12>)packet_idx + 1) << 7);
            if (!block_issue && state_next == S_ISSUE_ADDR && issue_pixel_idx < packet_pixel_limit) {
                ap_uint<8> src_slot;
                ap_uint<11> src_x;
                ap_uint<11> out_x = issue_pixel_idx.range(10, 0);
                map_source_pixel(out_x, out_line, out_slot, algo_ctrl, src_slot, src_x);
                bram_addr_t next_addr = ((bram_addr_t)src_slot << 11) | src_x;
                bram_addr_reg = next_addr;
                bram_addrb_out = next_addr;
                read_packet_pixel_idx = issue_pixel_idx.range(6, 0);
                read_valid = 1;
                issue_pixel_idx = issue_pixel_idx + 1;
            }
            break;
        }

        default:
            state_next = S_IDLE;
            break;
        }
    }

    if (fifo_wr_en_out) {
        ap_uint<1> next_word_toggle = ~word_toggle;
        word_toggle = next_word_toggle;
        fifo_word_toggle_out = next_word_toggle;
    }

    state = state_next;
    fifo_wr_en = fifo_wr_en_out;
    fifo_din = fifo_din_out;
    fifo_word_toggle = fifo_word_toggle_out;
    bram_addrb = bram_addrb_out;
    bram_line_num_addr = bram_line_num_addr_out;
}
