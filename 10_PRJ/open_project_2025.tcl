# ============================================================================
# 作者          : Egor Izmaylov
# 文件职责      : Vivado 2025.2 工程打开与基础状态检查入口。
# 维护边界      : 只设置工程级仿真器、更新 compile order，并导出 IP 状态报告。
# ============================================================================

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir "00_PRJ.xpr"]
set report_dir [file join $script_dir "reports_2025"]
file mkdir $report_dir

open_project $project_file
set_property target_simulator XSim [current_project]
update_compile_order -fileset sources_1

if {[catch {report_ip_status -file [file join $report_dir "ip_status.rpt"]} msg]} {
    puts "WARN: report_ip_status failed: $msg"
}

puts "INFO: Project opened with XSim target simulator: $project_file"
