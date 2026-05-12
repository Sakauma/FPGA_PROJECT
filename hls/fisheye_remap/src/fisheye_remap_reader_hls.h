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
static const int kFisheyeCenterX = 1024;
static const int kFisheyeCenterY = 1024;
static const int kFisheyeMaxRadius = 1024;
static const int kFisheyeLineBufferDepth = 256;
static const int kFisheyeHalfLineBufferDepth = 128;
static const int kFisheyePacketPixels = 128;
static const int kFisheyePixelsPerWord = 4;
static const int kFisheyePayloadWordsPerPacket = 32;
static const int kFisheyePacketsPerLine = 16;
static const int kFisheyeAdaptiveGainIdentityQ8 = 256;
static const int kFisheyeAdaptiveGainMaxQ8 = 8192;
static const int kFisheyeAdaptiveMinSpan = 1024;
// 新代码：Egor Izmaylov 上板调试阶段将畸变表径向修正强度放大 3 倍，使去畸变差异更容易观察。
static const int kFisheyeRemapStrengthQ8 = 768;

typedef ap_uint<19> bram_addr_t;
typedef ap_uint<9> line_slot_addr_t;
typedef ap_uint<65> fifo_word_t;

// 新代码：Egor Izmaylov 使用 HLS 直接生成 BRAM 读地址和 SRIO payload FIFO 数据。
void fisheye_remap_reader_hls(bram_addr_t bram_line_cur_w,
                              ap_uint<1> bram_line_cur_w_en,
                              ap_uint<12> bram_line_num,
                              ap_uint<16> bram_doutb,
                              ap_uint<1> fifo_almost_full,
                              ap_uint<32> algo_ctrl,
                              line_slot_addr_t& bram_line_num_addr,
                              bram_addr_t& bram_addrb,
                              ap_uint<1>& fifo_wr_en,
                              fifo_word_t& fifo_din);

#endif
