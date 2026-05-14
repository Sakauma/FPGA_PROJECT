# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : 使用真实 raw16 相机帧运行 fisheye_remap HLS C 仿真并导出图像。
# 维护边界      : 只驱动 HLS C 仿真，不修改 Vivado 工程、IP、约束或板级接口。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    set build_root [file join $root_dir build]
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

set raw_files [lsort [glob -nocomplain [file join $raw_dir *.raw]]]
if {[llength $raw_files] == 0} {
    error "ERROR: no .raw files found in $raw_dir"
}
set selected_raw_files [lrange $raw_files 0 [expr {$max_frames - 1}]]
puts "INFO: raw16 csim files: $selected_raw_files"

open_project [file join $build_root csim_raw_run fisheye_remap_addr_hls]
set_top fisheye_remap_addr_hls

add_files [file join $root_dir src fisheye_remap_reader_hls.cpp]
add_files [file join $root_dir src fisheye_remap_reader_hls.h]
add_files [file join $root_dir src distortion_lut.h]
add_files -tb [file join $root_dir tb fisheye_remap_raw16_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csim_design -argv [join $selected_raw_files " "]
exit
