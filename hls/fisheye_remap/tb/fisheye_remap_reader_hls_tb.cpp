// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 真实鱼眼去畸变 BRAM 读出 HLS C 仿真测试。
// 数据流位置    : 用软件 BRAM 模型验证旁路、红外去畸变和激光表选择。
// 维护边界      : 测试 HLS 核功能，不修改硬件底层接口。
// 修改约束      : 畸变表或状态机节拍变化后必须同步更新期望值。
// ============================================================================
#include "fisheye_remap_reader_hls.h"
#include "distortion_lut.h"

#include <cassert>
#include <cstdint>
#include <iostream>
#include <vector>

enum image_model_t {
    kImageModelByteRamp = 0,
    kImageModelAdaptiveRamp = 1
};

static uint16_t image_model(uint16_t line, uint16_t x, image_model_t model) {
    if (model == kImageModelAdaptiveRamp) {
        return static_cast<uint16_t>(1000U + ((x & 0x07FFU) << 2) + (line & 0x000FU));
    }
    return static_cast<uint16_t>(((line & 0x00FFU) << 8) | (x & 0x00FFU));
}

static uint16_t memory_read(bram_addr_t addr, image_model_t model) {
    uint16_t slot = static_cast<uint16_t>((addr >> 11) & 0x00FFU);
    uint16_t x = static_cast<uint16_t>(addr & 0x07FFU);
    return image_model(slot, x, model);
}

#if 0
// 旧代码保留：Egor Izmaylov
// 早期 testbench 只统计 header/payload 数量并检查第一拍数据，无法发现 tlast 时序和整行 packet 结构错误。
static void run_reader(uint32_t ctrl,
                       std::vector<uint64_t>& headers,
                       std::vector<uint64_t>& payloads,
                       uint16_t forced_line = 0,
                       image_model_t model = kImageModelByteRamp) {
    // 新代码：Egor Izmaylov 与工程实际 200 行环形缓存对齐，当前写槽位于半深度位置时应读到 0 号延迟槽。
    bram_addr_t bram_line_cur_w = kFisheyeHalfLineBufferDepth;
    ap_uint<1> bram_line_cur_w_en = 0;
    ap_uint<12> bram_line_num = 0;
    ap_uint<16> bram_doutb = 0;
    ap_uint<1> fifo_almost_full = 0;
    ap_uint<32> algo_ctrl = ctrl;
    line_slot_addr_t bram_line_num_addr = 0;
    bram_addr_t bram_addrb = 0;
    ap_uint<1> fifo_wr_en = 0;
    fifo_word_t fifo_din = 0;

    bram_addr_t delayed_addr = 0;
    headers.clear();
    payloads.clear();

    const int expected_line_payload_words = kFisheyePacketsPerLine * kFisheyePayloadWordsPerPacket;
    for (int cycle = 0; cycle < 24000 && payloads.size() < expected_line_payload_words; ++cycle) {
        bram_line_cur_w_en = (cycle == 2) ? 1 : 0;
        bram_line_num = forced_line;
        bram_doutb = memory_read(delayed_addr, model);

        fisheye_remap_reader_hls(bram_line_cur_w,
                                 bram_line_cur_w_en,
                                 bram_line_num,
                                 bram_doutb,
                                 fifo_almost_full,
                                 algo_ctrl,
                                 bram_line_num_addr,
                                 bram_addrb,
                                 fifo_wr_en,
                                 fifo_din);

        delayed_addr = bram_addrb;

        if (fifo_wr_en) {
            uint64_t data = static_cast<uint64_t>(fifo_din.range(63, 0));
            bool is_header = ((data >> 32) == 0x00602000ULL);
            if (is_header) {
                headers.push_back(data);
            } else {
                payloads.push_back(data);
            }
        }
    }

    assert(!headers.empty());
    assert(payloads.size() == expected_line_payload_words);
}

int main() {
    std::vector<uint64_t> headers;
    std::vector<uint64_t> payloads;
    std::vector<uint64_t> disabled_preprocess_payloads;
    std::vector<uint64_t> adaptive_payloads;

    run_reader(0x00000000, headers, payloads);
    assert(headers[0] == 0x0060200000000000ULL);
    assert(payloads[0] == 0x0003000200010000ULL);

    run_reader(0x00000001, headers, payloads);
    assert(headers[0] == 0x0060200000000000ULL);
    assert(payloads[0] != 0x0003000200010000ULL);

    run_reader(0x00000009, headers, payloads);
    assert(headers[0] == 0x0060200000000000ULL);
    assert(payloads[0] != 0x0003000200010000ULL);

    // 新代码：Egor Izmaylov 先用末行训练一帧统计参数，再验证下一行自适应预处理会改变真实像素。
    run_reader(0x00000001, headers, payloads, kFisheyeImageHeight - 1, kImageModelAdaptiveRamp);
    run_reader(0x00000011, headers, disabled_preprocess_payloads, 0, kImageModelAdaptiveRamp);
    run_reader(0x00000001, headers, adaptive_payloads, 0, kImageModelAdaptiveRamp);
    assert(headers[0] == 0x0060200000000000ULL);
    assert(!disabled_preprocess_payloads.empty());
    assert(!adaptive_payloads.empty());
    assert(disabled_preprocess_payloads[0] != adaptive_payloads[0]);

    std::cout << "fisheye_remap_reader_hls TB passed for bypass/remap/table/adaptive-preprocess modes" << std::endl;
    return 0;
}
#endif

struct captured_word_t {
    uint64_t data;
    bool last;
};

static void run_reader(uint32_t ctrl,
                       std::vector<captured_word_t>& words,
                       uint16_t forced_line = 0,
                       image_model_t model = kImageModelByteRamp) {
    // 新代码：Egor Izmaylov
    // 与工程实际 200 行环形缓存对齐，当前写槽位于半深度位置时应读到 0 号延迟槽。
    bram_addr_t bram_line_cur_w = kFisheyeHalfLineBufferDepth;
    ap_uint<1> bram_line_cur_w_en = 0;
    ap_uint<12> bram_line_num = 0;
    ap_uint<16> bram_doutb = 0;
    ap_uint<1> fifo_almost_full = 0;
    ap_uint<32> algo_ctrl = ctrl;
    line_slot_addr_t bram_line_num_addr = 0;
    bram_addr_t bram_addrb = 0;
    ap_uint<1> fifo_wr_en = 0;
    fifo_word_t fifo_din = 0;

    bram_addr_t delayed_addr = 0;
    words.clear();

    const int expected_line_words = kFisheyePacketsPerLine * (1 + kFisheyePayloadWordsPerPacket);
    for (int cycle = 0; cycle < 32000 && words.size() < expected_line_words; ++cycle) {
        bram_line_cur_w_en = (cycle == 2) ? 1 : 0;
        bram_line_num = forced_line;
        bram_doutb = memory_read(delayed_addr, model);

        fisheye_remap_reader_hls(bram_line_cur_w,
                                 bram_line_cur_w_en,
                                 bram_line_num,
                                 bram_doutb,
                                 fifo_almost_full,
                                 algo_ctrl,
                                 bram_line_num_addr,
                                 bram_addrb,
                                 fifo_wr_en,
                                 fifo_din);

        delayed_addr = bram_addrb;

        if (fifo_wr_en) {
            captured_word_t word;
            word.data = static_cast<uint64_t>(fifo_din.range(63, 0));
            word.last = fifo_din[64].to_bool();
            words.push_back(word);
        }
    }

    assert(words.size() == expected_line_words);
}

static uint64_t payload_at(const std::vector<captured_word_t>& words, int packet, int payload) {
    return words[packet * (1 + kFisheyePayloadWordsPerPacket) + 1 + payload].data;
}

static void check_line_protocol(const std::vector<captured_word_t>& words, uint16_t forced_line) {
    // 新代码：Egor Izmaylov
    // 对齐旧 readbram_to_axis64_top：每 128 像素一个包，1 个 header + 32 个 payload。
    const int words_per_packet = 1 + kFisheyePayloadWordsPerPacket;
    assert(words.size() == kFisheyePacketsPerLine * words_per_packet);
    for (int packet = 0; packet < kFisheyePacketsPerLine; ++packet) {
        const int base = packet * words_per_packet;
        const uint64_t expected_header =
            (0x00602000ULL << 32) |
            (static_cast<uint64_t>(forced_line) << 12) |
            (static_cast<uint64_t>(packet) << 8);
        assert(words[base].data == expected_header);
        assert(!words[base].last);
        for (int payload = 0; payload < kFisheyePayloadWordsPerPacket; ++payload) {
            const captured_word_t& word = words[base + 1 + payload];
            assert(word.last == (payload == (kFisheyePayloadWordsPerPacket - 1)));
        }
    }
}

int main() {
    std::vector<captured_word_t> words;
    std::vector<captured_word_t> disabled_preprocess_words;
    std::vector<captured_word_t> adaptive_words;

    run_reader(0x00000000, words);
    check_line_protocol(words, 0);
    assert(payload_at(words, 0, 0) == 0x0003000200010000ULL);

    run_reader(0x00000001, words);
    check_line_protocol(words, 0);
    assert(payload_at(words, 0, 0) != 0x0003000200010000ULL);

    run_reader(0x00000009, words);
    check_line_protocol(words, 0);
    assert(payload_at(words, 0, 0) != 0x0003000200010000ULL);

    run_reader(0x00000001, words, kFisheyeImageHeight - 1, kImageModelAdaptiveRamp);
    check_line_protocol(words, kFisheyeImageHeight - 1);
    run_reader(0x00000011, disabled_preprocess_words, 0, kImageModelAdaptiveRamp);
    check_line_protocol(disabled_preprocess_words, 0);
    run_reader(0x00000001, adaptive_words, 0, kImageModelAdaptiveRamp);
    check_line_protocol(adaptive_words, 0);
    assert(payload_at(disabled_preprocess_words, 0, 0) != payload_at(adaptive_words, 0, 0));

    std::cout << "fisheye_remap_reader_hls TB passed for full packet/header/payload/tlast protocol" << std::endl;
    return 0;
}
