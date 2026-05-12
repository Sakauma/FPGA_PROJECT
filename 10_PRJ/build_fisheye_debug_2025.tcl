# ============================================================================
# 作者          : Egor Izmaylov
# 文件职责      : Vivado 2025.2 一次性可调试鱼眼去畸变构建入口。
# 维护边界      : 只在当前 Vivado 会话中启用调试宏和插入 ILA；不修改 RTL/HLS 源码。
# 使用方式      : vivado -mode batch -source 10_PRJ/build_fisheye_debug_2025.tcl
# 复用综合结果  : vivado -mode batch -source 10_PRJ/build_fisheye_debug_2025.tcl -tclargs reuse_synth
# 产物          : 10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP.bit 和同目录 .ltx。
# ============================================================================

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir "00_PRJ.xpr"]
set report_dir [file join $script_dir "reports_fisheye_debug_2025"]
file mkdir $report_dir

set reuse_synth 0
foreach arg $argv {
    if {$arg eq "reuse_synth"} {
        set reuse_synth 1
    }
}

proc require_one {objects label} {
    if {[llength $objects] == 0} {
        error "ERROR: cannot find $label"
    }
    if {[llength $objects] > 1} {
        puts "WARN: multiple objects found for $label, using first: [lindex $objects 0]"
    }
    return [lindex $objects 0]
}

proc pin_net {cell port} {
    set pin_name [format {%s/%s} $cell $port]
    set pin [require_one [get_pins -quiet $pin_name] $pin_name]
    return [require_one [get_nets -quiet -of_objects $pin] "net of $pin_name"]
}

proc try_pin_net {cell port} {
    set pin_name [format {%s/%s} $cell $port]
    set pin [get_pins -quiet $pin_name]
    if {[llength $pin] == 0} {
        return ""
    }
    set net [get_nets -quiet -of_objects [lindex $pin 0]]
    if {[llength $net] == 0} {
        return ""
    }
    return [lindex $net 0]
}

proc pin_net_any {cell ports label} {
    foreach port $ports {
        set net [try_pin_net $cell $port]
        if {$net ne ""} {
            return $net
        }
    }
    error "ERROR: cannot find any pin/net for $label. Tried ports: $ports"
}

proc optional_pin_net_any {cell ports label} {
    foreach port $ports {
        set net [try_pin_net $cell $port]
        if {$net ne ""} {
            return [list $net]
        }
    }
    puts "WARN: skip $label, cannot find scalar pin/net. Tried ports: $ports"
    return {}
}

proc bus_pin_nets {cell port width} {
    set nets {}
    for {set idx 0} {$idx < $width} {incr idx} {
        set pin_name [format {%s/%s[%d]} $cell $port $idx]
        set pin [require_one [get_pins -quiet $pin_name] $pin_name]
        set net [require_one [get_nets -quiet -of_objects $pin] "net of $pin_name"]
        lappend nets $net
    }
    return $nets
}

proc try_bus_pin_nets {cell port width} {
    set nets {}
    for {set idx 0} {$idx < $width} {incr idx} {
        set net [try_pin_net $cell [format {%s[%d]} $port $idx]]
        if {$net eq ""} {
            return {}
        }
        lappend nets $net
    }
    return $nets
}

proc bus_pin_nets_any {cell ports width label} {
    foreach port $ports {
        set nets [try_bus_pin_nets $cell $port $width]
        if {[llength $nets] == $width} {
            return $nets
        }
    }
    puts "WARN: skip $label, cannot find complete bus. Tried ports: $ports"
    return {}
}

proc add_ila_probe {core label nets} {
    if {[llength $nets] == 0} {
        puts "WARN: skip empty probe $label"
        return
    }
    global ila_probe_count
    if {![info exists ila_probe_count($core)]} {
        set ila_probe_count($core) 0
    }
    set probe_idx $ila_probe_count($core)
    set probe [get_debug_ports -quiet [format {%s/probe%d} $core $probe_idx]]
    if {[llength $probe] == 0} {
        create_debug_port $core probe
        set probe [require_one [get_debug_ports [format {%s/probe%d} $core $probe_idx]] "$core probe$probe_idx"]
    } else {
        set probe [lindex $probe 0]
    }
    set_property PORT_WIDTH [llength $nets] $probe
    connect_debug_port $probe $nets
    incr ila_probe_count($core)
    puts [format "INFO: %s probe%d width=%d label=%s" $core $probe_idx [llength $nets] $label]
}

proc recreate_ila {core_name clk_net depth} {
    set old [get_debug_cores -quiet $core_name]
    if {[llength $old] > 0} {
        delete_debug_core $old
    }
    create_debug_core $core_name ila
    set core [require_one [get_debug_cores $core_name] $core_name]
    set_property C_DATA_DEPTH $depth $core
    set_property C_INPUT_PIPE_STAGES 1 $core
    connect_debug_port $core/clk $clk_net
    global ila_probe_count
    set ila_probe_count($core) 0
    return $core
}

proc insert_fisheye_debug_cores {} {
    set remap [require_one [get_cells -quiet -hier -filter {NAME =~ */u_fisheye_remap_bram_to_axis}] "u_fisheye_remap_bram_to_axis"]
    set hls [require_one [get_cells -quiet -hier -filter {NAME =~ */u_fisheye_remap_reader_hls}] "u_fisheye_remap_reader_hls"]
    set fifo [require_one [get_cells -quiet -hier -filter {NAME =~ */u_fisheye_axis_async_fifo}] "u_fisheye_axis_async_fifo"]

    puts "INFO: Remap wrapper = $remap"
    puts "INFO: HLS reader    = $hls"
    puts "INFO: Async FIFO    = $fifo"

    # 新代码：Egor Izmaylov
    # HLS cell 在综合后可能保留层级名但端口名被优化；BRAM 域 ILA 时钟改从
    # 外层 remap wrapper 的 bram_clk 端口获取，和 RTL 源码连接关系一致。
    set bram_clk_net [pin_net_any $remap {bram_clk} "remap bram_clk"]
    # 新代码：Egor Izmaylov
    # fifo_to_axis 层级可能被综合优化或展平，AXIS 调试点改从 remap wrapper
    # 和 async_fifo 端口取网线，避免脚本依赖可变综合网表实例名。
    set axis_clk_net [pin_net_any $remap {m_axis_aclk} "remap m_axis_aclk"]

    set bram_ila [recreate_ila u_ila_fisheye_bram $bram_clk_net 2048]
    add_ila_probe $bram_ila bram_line_cur_w      [bus_pin_nets_any $remap {bram_line_cur_w} 19 bram_line_cur_w]
    add_ila_probe $bram_ila bram_line_cur_w_en   [optional_pin_net_any $remap {bram_line_cur_w_en} bram_line_cur_w_en]
    add_ila_probe $bram_ila bram_line_num_addr   [bus_pin_nets_any $remap {bram_line_num_addr} 9 bram_line_num_addr]
    add_ila_probe $bram_ila bram_line_num        [bus_pin_nets_any $remap {bram_line_num} 12 bram_line_num]
    add_ila_probe $bram_ila bram_addrb           [bus_pin_nets_any $remap {bram_addrb} 19 bram_addrb]
    add_ila_probe $bram_ila bram_doutb           [bus_pin_nets_any $remap {bram_doutb} 16 bram_doutb]
    add_ila_probe $bram_ila video_algo_ctrl      [bus_pin_nets_any $remap {video_algo_ctrl} 32 video_algo_ctrl]
    add_ila_probe $bram_ila fifo_wr_en           [optional_pin_net_any $fifo {wr_en} fifo_wr_en]
    add_ila_probe $bram_ila fifo_almost_full     [optional_pin_net_any $fifo {prog_full} fifo_almost_full]
    add_ila_probe $bram_ila fifo_din             [bus_pin_nets_any $fifo {din} 65 fifo_din]

    set axis_ila [recreate_ila u_ila_fisheye_axis $axis_clk_net 2048]
    add_ila_probe $axis_ila fifo_empty           [optional_pin_net_any $fifo {empty} fifo_empty]
    add_ila_probe $axis_ila fifo_ren             [optional_pin_net_any $fifo {rd_en} fifo_ren]
    add_ila_probe $axis_ila fifo_rdata           [bus_pin_nets_any $fifo {dout} 65 fifo_rdata]
    add_ila_probe $axis_ila m_axis_tdata         [bus_pin_nets_any $remap {m_axis_tdata} 64 m_axis_tdata]
    add_ila_probe $axis_ila m_axis_tvalid        [optional_pin_net_any $remap {m_axis_tvalid} m_axis_tvalid]
    add_ila_probe $axis_ila m_axis_tready        [optional_pin_net_any $remap {m_axis_tready} m_axis_tready]
    add_ila_probe $axis_ila m_axis_tlast         [optional_pin_net_any $remap {m_axis_tlast} m_axis_tlast]
}

set opened_here 0
if {[llength [get_projects -quiet]] == 0} {
    open_project $project_file
    set opened_here 1
}

set_property target_simulator XSim [current_project]

set fs [get_filesets sources_1]
set defs [get_property verilog_define $fs]
set new_defs {}
foreach d $defs {
    if {$d ne "ENABLE_RETIRED_AXIS_POST_HLS_PATH"} {
        lappend new_defs $d
    }
}
if {[lsearch -exact $new_defs ENABLE_FISHEYE_REMAP_READER] < 0} {
    lappend new_defs ENABLE_FISHEYE_REMAP_READER
}
set_property verilog_define $new_defs $fs
puts "INFO: verilog_define = [get_property verilog_define $fs]"

update_compile_order -fileset sources_1

if {$reuse_synth} {
    puts "INFO: Reusing existing synth_1 result; resetting impl_1 only."
    reset_run impl_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        error "ERROR: reuse_synth requested, but synth_1 is not complete."
    }
} else {
    puts "INFO: Resetting synth_1 and impl_1 for fisheye debug build."
    reset_run synth_1
    reset_run impl_1
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
}

open_run synth_1 -name synth_fisheye_debug

set remap_cells [get_cells -quiet -hier -filter {NAME =~ */u_fisheye_remap_bram_to_axis}]
set hls_cells [get_cells -quiet -hier -filter {NAME =~ */u_fisheye_remap_reader_hls}]
if {[llength $remap_cells] == 0 || [llength $hls_cells] == 0} {
    error "ERROR: ENABLE_FISHEYE_REMAP_READER did not synthesize expected remap/HLS instances."
}

report_utilization -file [file join $report_dir "utilization_synth_fisheye_debug.rpt"]
report_timing_summary -file [file join $report_dir "timing_synth_fisheye_debug.rpt"]

insert_fisheye_debug_cores
save_constraints -force

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
open_run impl_1 -name impl_fisheye_debug

set impl_dir [file normalize [file join $script_dir "00_PRJ.runs" "impl_1"]]
write_debug_probes -force [file join $impl_dir "EB4110_10V10_TOP.ltx"]

report_timing_summary -file [file join $report_dir "timing_routed_fisheye_debug.rpt"]
report_utilization -file [file join $report_dir "utilization_routed_fisheye_debug.rpt"]
report_power -file [file join $report_dir "power_routed_fisheye_debug.rpt"]
report_drc -file [file join $report_dir "drc_routed_fisheye_debug.rpt"]
report_route_status -file [file join $report_dir "route_status_fisheye_debug.rpt"]

puts "INFO: Fisheye debug build completed."
puts "INFO: BIT = [file join $impl_dir EB4110_10V10_TOP.bit]"
puts "INFO: LTX = [file join $impl_dir EB4110_10V10_TOP.ltx]"
puts "INFO: Reports = $report_dir"

if {$opened_here} {
    close_project
}
