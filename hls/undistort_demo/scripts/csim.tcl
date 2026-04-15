# ============================================================================
# 维护注释
#   文件职责      : HLS C 仿真脚本，用于驱动预处理核的 csim 流程。
#   源码属性      : 手工维护 Tcl 脚本，供当前 HLS 验证使用。
#   更新要求      : 当工程路径、器件或仿真输入变化时，同步更新注释。
#   维护边界      : 注释用于说明当前脚本假设，不替代工程级构建说明。
# ============================================================================
set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

open_project build/csim_run/undistort_demo_hls
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csim_design
exit
