// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
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

// 新代码：Egor Izmaylov 保持顶层接口为 64bit AXIS + ap_none 控制字，便于 RTL wrapper 最小接线。
void undistort_demo_hls(hls::stream<axis64_t>& s_axis,
                        hls::stream<axis64_t>& m_axis,
                        ap_uint<32> algo_ctrl);

#endif
