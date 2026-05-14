# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : 真实鱼眼去畸变 BRAM 读出核 C 仿真入口。
# 数据流位置    : 验证 HLS 核生成 BRAM 地址和 FIFO 输出数据的软件行为。
# 维护边界      : 只维护 HLS 脚本，不修改 Vivado 工程底层配置。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    set build_root [file join $root_dir build]
}
file mkdir $build_root

open_project [file join $build_root csim_run fisheye_remap_addr_hls]
set_top fisheye_remap_addr_hls

add_files [file join $root_dir src fisheye_remap_reader_hls.cpp]
add_files [file join $root_dir src fisheye_remap_reader_hls.h]
add_files [file join $root_dir src distortion_lut.h]
add_files -tb [file join $root_dir tb fisheye_remap_reader_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csim_design
exit
