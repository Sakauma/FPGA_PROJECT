# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : 使用真实 raw16 帧拟合鱼眼圆心/半径，并生成软件参考去畸变图。
# 数据流位置    : HLS C 仿真侧分析工具，不进入综合核心，不修改底层硬件链路。
# 维护边界      : 只用于参数校准和图像对比；确认参数后再单独同步到 HLS 算法源码。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    # 新代码：Egor Izmaylov 默认把分析输出放到仓库根目录的 hls_work，避免污染 HLS 子工程目录。
    set build_root [file normalize [file join $root_dir .. .. hls_work]]
}
file mkdir $build_root

if {[info exists ::env(FISHEYE_RAW_DIR)]} {
    set raw_dir [file normalize $::env(FISHEYE_RAW_DIR)]
} else {
    set raw_dir "D:/Staff/data"
}

if {[info exists ::env(FISHEYE_RAW_MAX_FRAMES)]} {
    set max_frames $::env(FISHEYE_RAW_MAX_FRAMES)
} else {
    set max_frames 3
}

if {![info exists ::env(FISHEYE_REF_OUT_DIR)]} {
    set ::env(FISHEYE_REF_OUT_DIR) [file join $build_root fisheye_reference_fit]
}

set raw_files [lsort [glob -nocomplain [file join $raw_dir *.raw]]]
if {[llength $raw_files] == 0} {
    error "ERROR: no .raw files found in $raw_dir"
}
set selected_raw_files [lrange $raw_files 0 [expr {$max_frames - 1}]]
puts "INFO: reference fit raw16 files: $selected_raw_files"
puts "INFO: reference fit output dir: $::env(FISHEYE_REF_OUT_DIR)"

open_project [file join $build_root csim_reference_fit_run fisheye_remap_reader_hls]
set_top fisheye_remap_reader_hls

add_files [file join $root_dir src fisheye_remap_reader_hls.cpp]
add_files [file join $root_dir src fisheye_remap_reader_hls.h]
add_files [file join $root_dir src distortion_lut.h]
add_files -tb [file join $root_dir tb fisheye_reference_fit_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csim_design -argv [join $selected_raw_files " "]
exit
