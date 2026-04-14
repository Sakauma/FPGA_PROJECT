#include "undistort_demo_hls.h"

static ap_uint<13> abs_diff(ap_uint<12> lhs, ap_uint<12> rhs) {
#pragma HLS INLINE
    return (lhs >= rhs) ? (ap_uint<13>)(lhs - rhs) : (ap_uint<13>)(rhs - lhs);
}

static ap_uint<16> apply_undistort_foundation(ap_uint<16> pixel,
                                              ap_uint<12> x,
                                              ap_uint<12> y,
                                              ap_uint<1> algo_enable) {
#pragma HLS INLINE
    if (!algo_enable) {
        return pixel;
    }

    const ap_uint<12> center_x = kUndistortImageWidth >> 1;
    const ap_uint<12> center_y = kUndistortImageHeight >> 1;
    ap_uint<13> dx = abs_diff(x, center_x);
    ap_uint<13> dy = abs_diff(y, center_y);

    // 去畸变基础坐标模型：先保留径向补偿框架，后续可替换为 LUT 重映射。
    ap_uint<6> radial_gain = (dx + dy) >> 7;
    ap_uint<17> compensated = (ap_uint<17>)pixel + radial_gain;
    return compensated[16] ? (ap_uint<16>)0xFFFF : compensated.range(15, 0);
}

static ap_uint<16> apply_demo_overlay(ap_uint<16> pixel,
                                      ap_uint<12> x,
                                      ap_uint<12> y,
                                      ap_uint<1> frame_phase,
                                      ap_uint<1> demo_enable,
                                      ap_uint<1> demo_frame_toggle_enable) {
#pragma HLS INLINE
    if (!demo_enable) {
        return pixel;
    }

    ap_uint<1> phase = demo_frame_toggle_enable ? frame_phase : (ap_uint<1>)0;
    ap_uint<1> overlay_cell = (((x >> kDemoTileShift) + (y >> kDemoTileShift) + phase) & 0x1) == 0;

    if (!overlay_cell) {
        return pixel;
    }

    return phase ? (ap_uint<16>)0xFFFF : (ap_uint<16>)0x0000;
}

void undistort_demo_hls(hls::stream<axis64_t>& s_axis,
                        hls::stream<axis64_t>& m_axis,
                        ap_uint<32> algo_ctrl) {
#pragma HLS INTERFACE axis port=s_axis
#pragma HLS INTERFACE axis port=m_axis
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE ap_none port=algo_ctrl
#pragma HLS PIPELINE II=1

    static ap_uint<1> in_payload = 0;
    static ap_uint<6> payload_word_idx = 0;
    static ap_uint<12> current_line = 0;
    static ap_uint<12> last_line = 0;
    static ap_uint<4> current_packet = 0;
    static ap_uint<1> frame_phase = 0;
    static ap_uint<1> seen_line = 0;

    if (s_axis.empty()) {
        return;
    }

    axis64_t in_word = s_axis.read();
    axis64_t out_word = in_word;

    ap_uint<1> algo_enable = algo_ctrl[0];
    ap_uint<1> demo_enable = algo_ctrl[1];
    ap_uint<1> demo_frame_toggle_enable = algo_ctrl[2];

    if (!in_payload) {
        ap_uint<32> srio_addr = in_word.data.range(31, 0);
        ap_uint<12> line_idx = srio_addr.range(23, 12);
        ap_uint<4> packet_idx = srio_addr.range(11, 8);

        if (packet_idx == 0) {
            if (seen_line && (line_idx < last_line) && demo_frame_toggle_enable) {
                frame_phase = ~frame_phase;
            }
            last_line = line_idx;
            seen_line = 1;
        }

        current_line = line_idx;
        current_packet = packet_idx;
        payload_word_idx = 0;
        in_payload = in_word.last ? (ap_uint<1>)0 : (ap_uint<1>)1;
    } else {
        if (algo_enable || demo_enable) {
            ap_uint<12> base_x = ((ap_uint<12>)current_packet << 7) + ((ap_uint<12>)payload_word_idx << 2);
            for (int pix = 0; pix < 4; ++pix) {
#pragma HLS UNROLL
                ap_uint<12> pixel_x = base_x + pix;
                ap_uint<16> pixel = in_word.data.range(pix * 16 + 15, pix * 16);
                ap_uint<16> corrected = apply_undistort_foundation(pixel, pixel_x, current_line, algo_enable);
                ap_uint<16> demo_pixel = apply_demo_overlay(corrected,
                                                            pixel_x,
                                                            current_line,
                                                            frame_phase,
                                                            demo_enable,
                                                            demo_frame_toggle_enable);
                out_word.data.range(pix * 16 + 15, pix * 16) = demo_pixel;
            }
        }

        payload_word_idx = payload_word_idx + 1;
        if (in_word.last) {
            in_payload = 0;
            payload_word_idx = 0;
        }
    }

    m_axis.write(out_word);
}
