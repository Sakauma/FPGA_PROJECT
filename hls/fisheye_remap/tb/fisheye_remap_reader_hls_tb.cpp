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

static void run_reader(uint32_t ctrl,
                       std::vector<uint64_t>& headers,
                       std::vector<uint64_t>& payloads,
                       uint16_t forced_line = 0,
                       image_model_t model = kImageModelByteRamp) {
    bram_addr_t bram_line_cur_w = 128;
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
