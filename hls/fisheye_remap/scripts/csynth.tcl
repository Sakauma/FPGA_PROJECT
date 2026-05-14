# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : 真实鱼眼去畸变 BRAM 读出核综合和 RTL 导出入口。
# 数据流位置    : 生成可接入现有 BRAM->FIFO->SRIO 链路的 Verilog RTL。
# 维护边界      : `hls/fisheye_remap/rtl/` 为导出产物，算法优先改 `src/`。
# ============================================================================

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

if {[info exists ::env(HLS_BUILD_ROOT)]} {
    set build_root [file normalize $::env(HLS_BUILD_ROOT)]
} else {
    set build_root [file join $root_dir build]
}
file mkdir $build_root

open_project [file join $build_root tcl_run fisheye_remap_reader_hls]
set_top fisheye_remap_reader_hls

add_files [file join $root_dir src fisheye_remap_reader_hls.cpp]
add_files [file join $root_dir src fisheye_remap_reader_hls.h]
add_files [file join $root_dir src distortion_lut.h]
add_files -tb [file join $root_dir tb fisheye_remap_reader_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csynth_design
export_design -rtl verilog -format ip_catalog

file mkdir [file join $root_dir rtl]
foreach rtl_file [glob -nocomplain [file join $build_root tcl_run fisheye_remap_reader_hls solution1 syn verilog *.v]] {
    # 新代码：Egor Izmaylov 只同步现有 wrapper include 覆盖的 RTL 文件，避免 HLS 临时 helper 名污染仓库。
    set rtl_tail [file tail $rtl_file]
    set rtl_allowlist {
        fisheye_remap_reader_hls.v
        fisheye_remap_reader_hls_kInfraredScaleQ16_ROM_AUTO_1R.v
        fisheye_remap_reader_hls_kLaserScaleQ16_ROM_AUTO_1R.v
        fisheye_remap_reader_hls_mac_muladd_11ns_7ns_10ns_17_4_1.v
        fisheye_remap_reader_hls_mul_13ns_13ns_25_2_1.v
        fisheye_remap_reader_hls_mul_15s_9ns_24_2_1.v
        fisheye_remap_reader_hls_mul_16ns_12ns_28_2_1.v
        fisheye_remap_reader_hls_mul_17ns_11s_28_2_1.v
        fisheye_remap_reader_hls_mul_17ns_13s_30_2_1.v
        fisheye_remap_reader_hls_partset_65ns_65ns_16ns_6ns_65_1_1.v
        fisheye_remap_reader_hls_sparsemux_7_2_13_1_1.v
        fisheye_remap_reader_hls_sparsemux_9_3_12_1_1.v
        fisheye_remap_reader_hls_sparsemux_9_3_65_1_1.v
    }
    if {[lsearch -exact $rtl_allowlist $rtl_tail] >= 0} {
        file copy -force $rtl_file [file join $root_dir rtl $rtl_tail]
    }
}

# 新代码：Egor Izmaylov HLS 生成的 ROM Verilog 使用 $readmemh 读取 .dat，RTL 仿真必须同步复制。
foreach rom_file [glob -nocomplain [file join $build_root tcl_run fisheye_remap_reader_hls solution1 syn verilog *.dat]] {
    file copy -force $rom_file [file join $root_dir rtl [file tail $rom_file]]
}

# 新代码：Egor Izmaylov HLS 会把 ap_none 输出在中间状态赋为 X；接入真实 FIFO 前必须固定为空闲值。
set top_rtl [file join $root_dir rtl fisheye_remap_reader_hls.v]
if {[file exists $top_rtl]} {
    set fp [open $top_rtl r]
    fconfigure $fp -encoding utf-8
    set rtl_text [read $fp]
    close $fp
    set fifo_din_idle_replacement "// \u65b0\u4ee3\u7801\uff1aEgor Izmaylov \u7a7a\u95f2\u5468\u671f\u56fa\u5b9a\u4e3a 0\uff0c\u907f\u514d X \u6c61\u67d3 FIFO\u3002\n        // \u65e7\u4ee3\u7801\u4fdd\u7559\uff1afifo_din = 'bx;\n        fifo_din = 65'd0;"
    set fifo_wr_idle_replacement "// \u65b0\u4ee3\u7801\uff1aEgor Izmaylov \u975e\u5199\u5468\u671f\u56fa\u5b9a wr_en=0\u3002\n        // \u65e7\u4ee3\u7801\u4fdd\u7559\uff1afifo_wr_en = 'bx;\n        fifo_wr_en = 1'd0;"
    set rtl_text [string map [list \
        "fisheye_remap_reader_hls_mul_17ns_12s_29_2_1" "fisheye_remap_reader_hls_mul_17ns_11s_28_2_1" \
        "fifo_din = 'bx;" $fifo_din_idle_replacement \
        "fifo_wr_en = 'bx;" $fifo_wr_idle_replacement \
    ] $rtl_text]
    set fp [open $top_rtl w]
    fconfigure $fp -encoding utf-8
    puts -nonewline $fp $rtl_text
    close $fp
}

# 新代码：Egor Izmaylov
# Vitis HLS 生成 Verilog 时会保留尾随空白；提交前统一清理，避免 git diff/check 噪声。
foreach clean_file [glob -nocomplain [file join $root_dir rtl *.v]] {
    set fp [open $clean_file r]
    fconfigure $fp -encoding utf-8
    set clean_text [read $fp]
    close $fp
    regsub -all {[ \t]+\n} $clean_text "\n" clean_text
    set fp [open $clean_file w]
    fconfigure $fp -encoding utf-8
    puts -nonewline $fp $clean_text
    close $fp
}
exit
