# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : Vitis HLS C/RTL 协同仿真入口，验证综合后 RTL 与 C 模型一致。
# 数据流位置      : 覆盖 64bit AXIS 输入输出和 `algo_ctrl` 模式控制。
# 维护边界      : 只验证 HLS 核内部行为，顶层 RTL 集成由 `80_TB/` 脚本负责。
# 修改约束      : 新增模式位或改变帧相位规则时，必须同步扩展 testbench 覆盖。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

# 新代码：Egor Izmaylov 支持外部 HLS_BUILD_ROOT，避免旧 cosim 目录权限或缓存污染影响验证。
if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    set build_root [file join $root_dir build]
}
file mkdir $build_root

open_project [file join $build_root cosim_run undistort_demo_hls]
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
# 新代码：Egor Izmaylov 为 cosim 增加专用宏，避免 C testbench 等待 RTL 延迟造成误判。
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s -DUNDISTORT_DEMO_COSIM" [file join $root_dir src]]
# 旧代码：以下注释保留原有实现，仅作为历史路径参考。
# add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csynth_design
cosim_design
exit
