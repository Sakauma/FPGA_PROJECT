// ============================================================================
// ĞÂÔöÎ¬»¤ËµÃ÷
// ÎÄ¼şÖ°Ôğ      : µ±Ç°ÎÄ¼şÎªÊÖ¹¤Î¬»¤Ô´Âë£¬³Ğµ£±¾Ä£¿é/½Å±¾µÄÕæÊµÊµÏÖ¡£
// Î¬»¤±ß½ç      : ±¾×¢ÊÍ¿é½ö²¹³äÎ¬»¤ËµÃ÷£¬²»¸ÄĞ´ÈÎºÎÔ­ÓĞËµÃ÷¡¢ÀúÊ·×¢ÊÍ»òÏÖÓĞÂß¼­¡£
// ĞŞ¸ÄÔ¼Êø      : ºóĞøÈçĞè¼ÌĞø²¹³äËµÃ÷£¬Ö»ÔÊĞí×·¼ÓÖĞÎÄ×¢ÊÍ£¬²»µÃÌæ»»¾É×¢ÊÍ»ò¸Ä¶¯¾É´úÂë¡£
// Éú³É¹ØÏµ      : Èô´æÔÚ¶ÔÓ¦Éú³ÉÎï£¬Ó¦ÒÔµ±Ç°ÊÖ¹¤Ô´ÂëÎª×¼£¬½ûÖ¹·´Ïò¸²¸Ç±¾ÎÄ¼ş¡£
// ============================================================================
#include "undistort_demo_hls.h"

#include <cassert>
#include <array>
#include <cstdint>
#include <iostream>
#include <vector>

static axis64_t make_word(uint64_t data, bool last) {
    axis64_t word;
    word.data = data;
    word.last = last ? 1 : 0;
    word.keep = 0xFF;
    word.strb = 0xFF;
    return word;
}

static uint64_t pack_pixels(uint16_t p0, uint16_t p1, uint16_t p2, uint16_t p3) {
    return (uint64_t)p0 |
           ((uint64_t)p1 << 16) |
           ((uint64_t)p2 << 32) |
           ((uint64_t)p3 << 48);
}

static void push_packet(hls::stream<axis64_t>& in_stream,
                        uint16_t line_idx,
                        uint8_t packet_idx,
                        uint64_t payload_word) {
    uint32_t header_addr = ((uint32_t)line_idx << 12) | ((uint32_t)packet_idx << 8);
    uint64_t header_word = ((uint64_t)0x00602000 << 32) | header_addr;
    in_stream.write(make_word(header_word, false));
    in_stream.write(make_word(payload_word, true));
}

static uint16_t ref_abs_diff(uint16_t lhs, uint16_t rhs) {
    return (lhs >= rhs) ? static_cast<uint16_t>(lhs - rhs) : static_cast<uint16_t>(rhs - lhs);
}

static uint16_t ref_apply_undistort(uint16_t pixel, uint16_t x, uint16_t y, bool algo_enable) {
    if (!algo_enable) {
        return pixel;
    }

    const uint16_t center_x = static_cast<uint16_t>(kUndistortImageWidth >> 1);
    const uint16_t center_y = static_cast<uint16_t>(kUndistortImageHeight >> 1);
    const uint16_t dx = ref_abs_diff(x, center_x);
    const uint16_t dy = ref_abs_diff(y, center_y);
    const uint16_t radial_gain = static_cast<uint16_t>((dx + dy) >> 7);
    const uint32_t compensated = static_cast<uint32_t>(pixel) + radial_gain;
    return (compensated > 0xFFFFU) ? 0xFFFFU : static_cast<uint16_t>(compensated);
}

static uint16_t ref_apply_demo(uint16_t pixel,
                               uint16_t x,
                               uint16_t y,
                               bool frame_phase,
                               bool demo_enable,
                               bool demo_frame_toggle_enable) {
    if (!demo_enable) {
        return pixel;
    }

    const bool phase = demo_frame_toggle_enable ? frame_phase : false;
    const bool overlay_cell = ((((x >> kDemoTileShift) + (y >> kDemoTileShift) + (phase ? 1 : 0)) & 0x1) == 0);
    if (!overlay_cell) {
        return pixel;
    }

    return phase ? 0xFFFFU : 0x0000U;
}

static uint64_t ref_process_payload(uint64_t payload_word,
                                    uint16_t line_idx,
                                    uint8_t packet_idx,
                                    bool frame_phase,
                                    ap_uint<32> algo_ctrl) {
    const bool algo_enable = algo_ctrl[0] != 0;
    const bool demo_enable = algo_ctrl[1] != 0;
    const bool demo_toggle_enable = algo_ctrl[2] != 0;
    const uint16_t base_x = static_cast<uint16_t>((packet_idx << 7) + 0);

    uint64_t out_word = 0;
    for (int pix = 0; pix < 4; ++pix) {
        const uint16_t pixel = static_cast<uint16_t>((payload_word >> (pix * 16)) & 0xFFFFU);
        const uint16_t pixel_x = static_cast<uint16_t>(base_x + pix);
        const uint16_t corrected = ref_apply_undistort(pixel, pixel_x, line_idx, algo_enable);
        const uint16_t demo_pixel = ref_apply_demo(corrected, pixel_x, line_idx, frame_phase, demo_enable, demo_toggle_enable);
        out_word |= (static_cast<uint64_t>(demo_pixel) << (pix * 16));
    }
    return out_word;
}

static std::vector<axis64_t> run_case(ap_uint<32> algo_ctrl) {
    hls::stream<axis64_t> in_stream;
    hls::stream<axis64_t> out_stream;
    const int expected_words = 6;
    std::vector<axis64_t> outputs;
    outputs.reserve(expected_words);

    push_packet(in_stream, 0, 0, pack_pixels(1, 2, 3, 4));
    push_packet(in_stream, 1, 0, pack_pixels(5, 6, 7, 8));
    push_packet(in_stream, 0, 0, pack_pixels(9, 10, 11, 12));

    // æ–°ä»£ç 
    for (int cycle = 0; cycle < expected_words; ++cycle) {
        undistort_demo_hls(in_stream, out_stream, algo_ctrl);
        outputs.push_back(out_stream.read());
    }

    assert(outputs.size() == expected_words);

    // æ—§ä»£ç 
    // for (int cycle = 0; cycle < 24; ++cycle) {
    //     undistort_demo_hls(in_stream, out_stream, algo_ctrl);
    //     if (!out_stream.empty()) {
    //         outputs.push_back(out_stream.read());
    //     }
    // }
    return outputs;
}

static void check_case(ap_uint<32> algo_ctrl) {
#ifdef UNDISTORT_DEMO_COSIM
    (void)run_case(algo_ctrl);
    return;
#else
    const std::array<uint16_t, 3> line_idx = {0, 1, 0};
    const std::array<uint8_t, 3> packet_idx = {0, 0, 0};
    const std::array<uint64_t, 3> payloads = {
        pack_pixels(1, 2, 3, 4),
        pack_pixels(5, 6, 7, 8),
        pack_pixels(9, 10, 11, 12)
    };

    std::vector<axis64_t> outputs = run_case(algo_ctrl);

    bool seen_line = false;
    uint16_t last_line = 0;
    bool frame_phase = false;

    for (int pkt = 0; pkt < 3; ++pkt) {
        const axis64_t& header = outputs[pkt * 2 + 0];
        const axis64_t& payload = outputs[pkt * 2 + 1];
        const uint64_t expected_header = ((uint64_t)0x00602000 << 32) |
                                         (((uint64_t)line_idx[pkt] << 12) | ((uint64_t)packet_idx[pkt] << 8));

        if (packet_idx[pkt] == 0) {
            if (seen_line && (line_idx[pkt] < last_line) && (algo_ctrl[2] != 0)) {
                frame_phase = !frame_phase;
            }
            last_line = line_idx[pkt];
            seen_line = true;
        }

        const uint64_t expected_payload = ref_process_payload(payloads[pkt],
                                                              line_idx[pkt],
                                                              packet_idx[pkt],
                                                              frame_phase,
                                                              algo_ctrl);

        assert((uint64_t)header.data == expected_header);
        assert(header.last == 0);
        assert((uint64_t)payload.data == expected_payload);
        assert(payload.last == 1);
    }
#endif
}

// æ—§ä»£ç 
// int main() {
//     hls::stream<axis64_t> in_stream;
//     hls::stream<axis64_t> out_stream;
//
//     const ap_uint<32> algo_ctrl = 0x00000007;
//
//     push_packet(in_stream, 0, 0, pack_pixels(1, 2, 3, 4));
//     push_packet(in_stream, 1, 0, pack_pixels(5, 6, 7, 8));
//     push_packet(in_stream, 0, 0, pack_pixels(9, 10, 11, 12));
//
//     for (int cycle = 0; cycle < 16; ++cycle) {
//         undistort_demo_hls(in_stream, out_stream, algo_ctrl);
//     }
//
//     assert(out_stream.size() == 6);
//
//     axis64_t header0 = out_stream.read();
//     axis64_t payload0 = out_stream.read();
//     axis64_t header1 = out_stream.read();
//     axis64_t payload1 = out_stream.read();
//     axis64_t header2 = out_stream.read();
//     axis64_t payload2 = out_stream.read();
//
//     assert((uint64_t)header0.data == (((uint64_t)0x00602000 << 32) | ((uint64_t)0 << 12)));
//     assert((uint64_t)header1.data == ((((uint64_t)0x00602000 << 32) | ((uint64_t)1 << 12))));
//     assert((uint64_t)header2.data == (((uint64_t)0x00602000 << 32) | ((uint64_t)0 << 12)));
//
//     assert((uint64_t)payload0.data == 0x0000000000000000ULL);
//     assert((uint64_t)payload1.data == 0x0000000000000000ULL);
//     assert((uint64_t)payload2.data == 0xFFFFFFFFFFFFFFFFULL);
//     assert(payload0.last == 1);
//     assert(payload1.last == 1);
//     assert(payload2.last == 1);
//
//     std::cout << "undistort_demo_hls TB passed" << std::endl;
//     return 0;
// }

// æ–°ä»£ç 
int main() {
    check_case(0x00000000);
    check_case(0x00000001);
    check_case(0x00000003);
    check_case(0x00000007);

    std::cout << "undistort_demo_hls TB passed for ctrl=0x0/0x1/0x3/0x7" << std::endl;
    return 0;
}
