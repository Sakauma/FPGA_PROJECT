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

proc apply_required_ip_patch_hooks {} {
    # 新代码：Egor Izmaylov
    # 用户要求：综合前必须加载 JFM_Kits 的 ip_patch，并把 hook Tcl 写回工程。
    # 这里放在 open_project 之后、reset/launch synth 之前执行。
    set jfm_bootstrap "D:/Staff/JFM_Kits/ip_patch/run.tcl"
    if {![file exists $jfm_bootstrap]} {
        error "ERROR: required ip_patch bootstrap not found: $jfm_bootstrap"
    }

    source $jfm_bootstrap
    set run_tcl_path [file join $::env(JFM_PATH) "ip_patch" "run.tcl"]
    if {![file exists $run_tcl_path]} {
        error "ERROR: required ip_patch run.tcl not found: $run_tcl_path"
    }

    if {[catch {source $run_tcl_path -notrace} msg]} {
        puts "WARN: source \$run_tcl_path -notrace failed: $msg"
        puts "WARN: retrying with Vivado option order: source -notrace \$run_tcl_path"
        source -notrace $run_tcl_path
    }
    show_ip_patch_version
    add_hook_tcl_to_prj
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

proc pin_tail_name {pin} {
    set pin_name [get_property NAME $pin]
    set parts [split $pin_name "/"]
    return [lindex $parts end]
}

proc find_pin_by_tail {cell port} {
    set pin_name [format {%s/%s} $cell $port]
    set exact [get_pins -quiet $pin_name]
    if {[llength $exact] > 0} {
        return [lindex $exact 0]
    }

    # 新代码：Egor Izmaylov
    # 综合后有些层级 cell 仍可见，但 pin 的完整路径不再能用 cell/port 精确命中。
    # 因此遍历该 cell 实际 pins，按最后一级 pin 名匹配，兼容 bus bit 名称如 dout[0]。
    foreach pin [get_pins -quiet -of_objects $cell] {
        if {[pin_tail_name $pin] eq $port} {
            return $pin
        }
    }

    return ""
}

proc dump_cell_pins {cell label} {
    puts "WARN: available pins for $label:"
    set count 0
    foreach pin [get_pins -quiet -of_objects $cell] {
        puts "WARN:   $pin"
        incr count
        if {$count >= 80} {
            puts "WARN:   ... truncated after 80 pins"
            break
        }
    }
    if {$count == 0} {
        puts "WARN:   no pins returned by get_pins -of_objects"
    }
}

proc try_pin_net {cell port} {
    set pin [find_pin_by_tail $cell $port]
    if {[llength $pin] == 0} {
        return ""
    }
    set net [get_nets -quiet -of_objects $pin]
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
    dump_cell_pins $cell $label
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

proc debug_nets_by_prefix {prefix} {
    return [lsort -dictionary [get_nets -quiet -hier [format {*%s*} $prefix]]]
}

proc debug_scalar_net {prefix} {
    set nets [debug_nets_by_prefix $prefix]
    if {[llength $nets] == 0} {
        error "ERROR: cannot find debug tap net '$prefix'. Re-run synthesis with ENABLE_FISHEYE_DEBUG_TAPS."
    }
    if {[llength $nets] > 1} {
        puts "WARN: multiple nets found for $prefix, using first: [lindex $nets 0]"
    }
    return [lindex $nets 0]
}

proc debug_bus_nets {prefix width} {
    set nets [debug_nets_by_prefix $prefix]
    if {[llength $nets] < $width} {
        error "ERROR: debug tap bus '$prefix' has [llength $nets] nets, expected $width. Re-run synthesis with ENABLE_FISHEYE_DEBUG_TAPS."
    }
    if {[llength $nets] > $width} {
        puts "WARN: debug tap bus $prefix has [llength $nets] nets, using first $width."
    }
    return [lrange $nets 0 [expr {$width - 1}]]
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
    # 新代码：Egor Izmaylov
    # 不再依赖综合后的层级端口名。RTL 在 ENABLE_FISHEYE_DEBUG_TAPS 下
    # 生成 dbg_fisheye_* 稳定探针网线，脚本只按这些固定前缀连 ILA。
    set remap_cells [get_cells -quiet -hier -filter {NAME =~ */u_fisheye_remap_bram_to_axis}]
    puts "INFO: Remap wrapper count = [llength $remap_cells]"

    set bram_clk_net [debug_scalar_net dbg_fisheye_bram_clk]
    set axis_clk_net [debug_scalar_net dbg_fisheye_axis_clk]

    set bram_ila [recreate_ila u_ila_fisheye_bram $bram_clk_net 2048]
    add_ila_probe $bram_ila bram_line_cur_w      [debug_bus_nets dbg_fisheye_bram_line_cur_w 19]
    add_ila_probe $bram_ila bram_line_cur_w_en   [list [debug_scalar_net dbg_fisheye_bram_line_cur_w_en]]
    add_ila_probe $bram_ila bram_line_num_addr   [debug_bus_nets dbg_fisheye_bram_line_num_addr 9]
    add_ila_probe $bram_ila bram_line_num        [debug_bus_nets dbg_fisheye_bram_line_num 12]
    add_ila_probe $bram_ila bram_addrb           [debug_bus_nets dbg_fisheye_bram_addrb 19]
    add_ila_probe $bram_ila bram_doutb           [debug_bus_nets dbg_fisheye_bram_doutb 16]
    add_ila_probe $bram_ila video_algo_ctrl      [debug_bus_nets dbg_fisheye_video_algo_ctrl 32]
    add_ila_probe $bram_ila fifo_wr_en           [list [debug_scalar_net dbg_fisheye_fifo_wr_en]]
    add_ila_probe $bram_ila fifo_almost_full     [list [debug_scalar_net dbg_fisheye_fifo_almost_full]]
    add_ila_probe $bram_ila fifo_din             [debug_bus_nets dbg_fisheye_fifo_din 65]

    set axis_ila [recreate_ila u_ila_fisheye_axis $axis_clk_net 2048]
    add_ila_probe $axis_ila fifo_empty           [list [debug_scalar_net dbg_fisheye_fifo_empty]]
    add_ila_probe $axis_ila fifo_ren             [list [debug_scalar_net dbg_fisheye_fifo_ren]]
    add_ila_probe $axis_ila fifo_rdata           [debug_bus_nets dbg_fisheye_fifo_rdata 65]
    add_ila_probe $axis_ila m_axis_tdata         [debug_bus_nets dbg_fisheye_m_axis_tdata 64]
    add_ila_probe $axis_ila m_axis_tvalid        [list [debug_scalar_net dbg_fisheye_m_axis_tvalid]]
    add_ila_probe $axis_ila m_axis_tready        [list [debug_scalar_net dbg_fisheye_m_axis_tready]]
    add_ila_probe $axis_ila m_axis_tlast         [list [debug_scalar_net dbg_fisheye_m_axis_tlast]]
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
if {[lsearch -exact $new_defs ENABLE_FISHEYE_DEBUG_TAPS] < 0} {
    lappend new_defs ENABLE_FISHEYE_DEBUG_TAPS
}
set_property verilog_define $new_defs $fs
puts "INFO: verilog_define = [get_property verilog_define $fs]"

update_compile_order -fileset sources_1
apply_required_ip_patch_hooks

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
