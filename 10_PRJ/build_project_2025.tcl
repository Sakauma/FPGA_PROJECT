# ============================================================================
# 作者          : Egor Izmaylov
# 文件职责      : Vivado 2025.2 Project Mode 一键综合、实现与 bitstream 构建入口。
# 维护边界      : 不改源码，不手改 IP 生成文件；报告输出到 `10_PRJ/reports_2025/`。
# 使用方式      : vivado -mode batch -source 10_PRJ/build_project_2025.tcl
# 可选参数      : 追加 `-tclargs reset` 可在构建前 reset synth_1/impl_1。
# ============================================================================

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir "00_PRJ.xpr"]
set report_dir [file join $script_dir "reports_2025"]
file mkdir $report_dir

set do_reset 0
foreach arg $argv {
    if {$arg eq "reset"} {
        set do_reset 1
    }
}

open_project $project_file
set_property target_simulator XSim [current_project]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[catch {report_ip_status -file [file join $report_dir "ip_status_pre_build.rpt"]} msg]} {
    puts "WARN: report_ip_status failed: $msg"
}

if {$do_reset} {
    puts "INFO: Resetting synth_1 and impl_1 before build."
    reset_run synth_1
    reset_run impl_1
}

launch_runs synth_1 -jobs 8
wait_on_run synth_1
open_run synth_1 -name synth_1
report_utilization -file [file join $report_dir "utilization_synth.rpt"]
report_timing_summary -file [file join $report_dir "timing_synth.rpt"]

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
open_run impl_1
report_timing_summary -file [file join $report_dir "timing_routed.rpt"]
report_utilization -file [file join $report_dir "utilization_routed.rpt"]
report_power -file [file join $report_dir "power_routed.rpt"]
report_drc -file [file join $report_dir "drc_routed.rpt"]
report_methodology -file [file join $report_dir "methodology_routed.rpt"]
report_route_status -file [file join $report_dir "route_status.rpt"]

puts "INFO: Vivado 2025.2 build flow completed. Reports: $report_dir"
close_project
