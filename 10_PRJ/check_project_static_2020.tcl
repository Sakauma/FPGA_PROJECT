# ============================================================================
# 作者          : Egor Izmaylov
# 文件职责      : Vivado 2020.2 静态兼容检查脚本。
# 维护边界      : 只扫描工程文本，不打开或升级工程，不声明已完成 2020.2 实机验证。
# 使用方式      : vivado -mode batch -source 10_PRJ/check_project_static_2020.tcl
# ============================================================================

set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ".."]]
set report_file [file join $script_dir "reports_static_2020.txt"]

set checks {
    {10_PRJ/00_PRJ.xpr {Vivado v2025.2|SimulatorVersionXsim|D:/|C:/|ModelSim|modelsim}}
    {10_PRJ/00_PRJ.srcs/sources_1/bd/MY_MEM/MY_MEM.bd {2025\.2|D:/|C:/|ModelSim|modelsim}}
    {10_PRJ/00_PRJ.srcs/sources_1/bd/zynq/zynq.bd {2025\.2|D:/|C:/|ModelSim|modelsim}}
}

set fd [open $report_file w]
puts $fd "Vivado 2020.2 static compatibility scan"
puts $fd "Author: Egor Izmaylov"
puts $fd "Root: $root_dir"
puts $fd "Note: this is a static scan only; Vivado 2020.2 machine validation is still required."
puts $fd ""

foreach item $checks {
    lassign $item rel pattern
    set path [file join $root_dir $rel]
    if {![file exists $path]} {
        puts $fd "MISSING: $rel"
        continue
    }
    set in [open $path r]
    set line_no 0
    set hit 0
    while {[gets $in line] >= 0} {
        incr line_no
        if {[regexp -nocase $pattern $line]} {
            puts $fd "WARN: $rel:$line_no: $line"
            set hit 1
        }
    }
    close $in
    if {!$hit} {
        puts $fd "OK: $rel"
    }
}

close $fd
puts "INFO: Static compatibility report written to $report_file"
