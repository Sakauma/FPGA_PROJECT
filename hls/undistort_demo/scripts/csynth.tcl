# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : Vitis HLS 综合与 IP 导出入口，生成可接入 Vivado 的 Verilog RTL。
# 数据流位置      : 将 HLS C++ 顶层 `undistort_demo_hls` 综合为 64bit AXIS 流处理核。
# 维护边界      : `hls/undistort_demo/rtl/` 为导出产物，算法应优先改 `src/`。
# 修改约束      : C 综合通过后再更新 RTL 产物，并记录资源、时序和验证结论。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

# 新代码：Egor Izmaylov 支持外部 HLS_BUILD_ROOT，便于在干净工作区重跑综合并隔离派生产物。
if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    set build_root [file join $root_dir build]
}
file mkdir $build_root

open_project [file join $build_root tcl_run undistort_demo_hls]
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

# 新代码：Egor Izmaylov 保留 HLS 综合和 RTL/IP 导出作为正式算法交付入口。

# 旧代码：以下注释保留原有实现，仅作为历史路径参考。
# csim_design
csynth_design
export_design -rtl verilog -format ip_catalog
exit
