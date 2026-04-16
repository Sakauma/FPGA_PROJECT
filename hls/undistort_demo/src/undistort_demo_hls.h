// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
#ifndef UNDISTORT_DEMO_HLS_H
#define UNDISTORT_DEMO_HLS_H

#include <ap_axi_sdata.h>
#include <ap_int.h>
#include <hls_stream.h>

typedef ap_axiu<64, 0, 0, 0> axis64_t;

static const ap_uint<12> kUndistortImageWidth = 2048;
static const ap_uint<12> kUndistortImageHeight = 2048;
static const ap_uint<7> kDemoTileShift = 7;

void undistort_demo_hls(hls::stream<axis64_t>& s_axis,
                        hls::stream<axis64_t>& m_axis,
                        ap_uint<32> algo_ctrl);

#endif
