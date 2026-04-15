// ============================================================================
// 维护注释
//   文件职责      : HLS 预处理核的共享类型、常量与顶层接口声明。
//   源码属性      : 手工维护头文件，供 HLS 源码与测试共用。
//   更新要求      : 当导出常量、类型或控制语义变化时，同步更新注释。
//   维护边界      : 注释用于说明当前接口约定，不替代系统级寄存器说明。
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
