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
