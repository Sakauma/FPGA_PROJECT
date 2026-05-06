# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : Vitis HLS C 仿真入口，用于验证去畸变演示核的软件模型。
# 数据流位置      : 输入/输出均为 64bit AXI-Stream，与 RTL 包装层保持同一接口契约。
# 维护边界      : 只维护 HLS 工程脚本，不直接修改 Vivado 生成 RTL。
# 修改约束      : 修改算法控制位或测试样例后，必须同步更新本文档和 testbench。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

# 新代码：Egor Izmaylov 支持外部 HLS_BUILD_ROOT，避免本地旧 build 目录权限或缓存污染影响验证。
if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    set build_root [file join $root_dir build]
}
file mkdir $build_root

open_project [file join $build_root csim_run undistort_demo_hls]
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csim_design
exit
