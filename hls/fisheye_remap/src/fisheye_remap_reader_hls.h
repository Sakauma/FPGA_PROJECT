// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 真实鱼眼去畸变 BRAM 读出 HLS 顶层接口定义。
// 数据流位置    : 位于视频 BRAM 读出阶段，按输出像素坐标计算源像素地址并写入后级 FIFO。
// 维护边界      : 只维护算法读出核接口；SRIO、MIG、BD/IP、XDC 和板级接口不在此处修改。
// 修改约束      : 修改接口或控制位后，必须同步更新 RTL wrapper、testbench 和开发文档。
// ============================================================================
#ifndef FISHEYE_REMAP_READER_HLS_H
#define FISHEYE_REMAP_READER_HLS_H

#include <ap_int.h>

static const int kFisheyeImageWidth = 2048;
static const int kFisheyeImageHeight = 2048;
// HLS 坐标模型说明：
// 输出坐标始终按 2048x2048 全帧计算；垂直方向最终只转换成 256 行环形 BRAM 的相对行槽。
// 这意味着算法可以改变源列和有限源行偏移，但不能跨整帧任意随机访问历史图像。
// 新代码：Egor Izmaylov 使用 raw16 软件拟合得到的真实鱼眼圆参数，替代理想图像中心假设。
// 旧代码保留：static const int kFisheyeCenterX = 1024;
// 旧代码保留：static const int kFisheyeCenterY = 1024;
// 旧代码保留：static const int kFisheyeMaxRadius = 1024;
static const int kFisheyeCenterX = 959;
static const int kFisheyeCenterY = 987;
static const int kFisheyeMaxRadius = 947;
// 新代码：Egor Izmaylov 使用 27/256 近似 100/947，避免 HLS 生成 wrapper 未包含的新乘法 helper。
// 旧代码保留：static const int kFisheyeRadiusRecipQ20 = 1107;
static const int kFisheyeRadiusIndexMul = 27;
// 新代码：Egor Izmaylov 与新工程 RTL 参数 P_LINE_DEPTH=256 对齐，避免 remap 读到错误的 BRAM 行槽。
static const int kFisheyeLineBufferDepth = 256;
static const int kFisheyeHalfLineBufferDepth = 128;
static const int kFisheyePacketPixels = 128;
static const int kFisheyePixelsPerWord = 4;
static const int kFisheyePayloadWordsPerPacket = 32;
static const int kFisheyePacketsPerLine = 16;
static const int kFisheyeAdaptiveGainIdentityQ8 = 256;
static const int kFisheyeAdaptiveGainMaxQ8 = 8192;
static const int kFisheyeAdaptiveMinSpan = 1024;
// 新代码：Egor Izmaylov
// 稳定优先版本将去畸变强度拆成水平/垂直两组：水平有完整 2048 像素可读，允许更强；垂直受 256 行环形缓存限制。
// 旧代码保留：static const int kFisheyeRemapStrengthQ8 = 768;
// 新代码：Egor Izmaylov 参数校准后恢复为畸变表 1x，不再用盲目强度放大替代真实标定。
// 旧代码保留：static const int kFisheyeRemapStrengthXQ8 = 1024;
// 旧代码保留：static const int kFisheyeRemapStrengthYQ8 = 512;
static const int kFisheyeRemapStrengthXQ8 = 256;
static const int kFisheyeRemapStrengthYQ8 = 256;
static const int kFisheyeMaxVerticalShift = 96;
// 新代码：Egor Izmaylov
// 基于 raw16 参考图观察到的可见圆环补偿参数：在不改底层 256 行缓存的前提下，
// 回到第一版“弧线方向拉动明显”的内圈下沿参数，并用局部窄带限制影响范围。
static const int kFisheyeCurveFlattenCenterX = 964;
static const int kFisheyeCurveFlattenCenterY = 981;
static const int kFisheyeCurveFlattenRadius = 760;
static const int kFisheyeCurveFlattenTargetY = 1606;
static const int kFisheyeCurveFlattenArcBase = 135;
static const int kFisheyeCurveFlattenBand = 256;

// 地址类型说明：
// bram_addr_t[18:11] 是 256 行环形缓存的行槽，bram_addr_t[10:0] 是行内 0..2047 像素列。
// fifo_word_t[64] 对应 tlast，fifo_word_t[63:0] 对应 4 个 raw16 像素或 SRIO header。
typedef ap_uint<19> bram_addr_t;
typedef ap_uint<9> line_slot_addr_t;
typedef ap_uint<65> fifo_word_t;

// 新代码：Egor Izmaylov
// 稳定上板版本只让 HLS 计算去畸变源像素地址，SRIO header/payload/tlast 节奏由 RTL 固定生成。
// 该接口是当前默认综合顶层；保持 II=1 对实时输出节奏非常关键。
void fisheye_remap_addr_hls(ap_uint<1> in_valid,
                            ap_uint<11> out_x,
                            ap_uint<12> out_line,
                            line_slot_addr_t out_slot,
                            ap_uint<7> packet_pixel_idx,
                            ap_uint<32> algo_ctrl,
                            ap_uint<1>& out_valid,
                            line_slot_addr_t& src_slot,
                            ap_uint<11>& src_x,
                            ap_uint<7>& packet_pixel_idx_out);

// 新代码：Egor Izmaylov 使用 HLS 直接生成 BRAM 读地址和 SRIO payload FIFO 数据。
// 当前工程不把该 reader 作为默认实时路径，保留它是为了历史对照和离线验证。
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
                              ap_uint<1>& fifo_word_toggle);

#endif
