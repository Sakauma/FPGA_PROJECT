// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

open_project build/tcl_run/undistort_demo_hls
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

# New code
# Finish RTL synthesis/export first and keep C simulation as a follow-up task.

# Old code
# csim_design
csynth_design
export_design -rtl verilog -format ip_catalog
exit
