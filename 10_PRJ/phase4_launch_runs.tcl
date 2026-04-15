set script_dir [file normalize [file dirname [info script]]]
set project_path [file join $script_dir 00_PRJ.xpr]

proc check_run_complete {run_name} {
    set status [get_property STATUS [get_runs $run_name]]
    puts "PHASE4: $run_name status = $status"
    if {![string match "*Complete*" $status]} {
        error "Run $run_name did not complete successfully"
    }
}

open_project $project_path

if {[llength [get_runs synth_1 -quiet]] == 0} {
    error "Run synth_1 not found in project"
}

if {[llength [get_runs impl_1 -quiet]] == 0} {
    error "Run impl_1 not found in project"
}

catch {reset_run impl_1}
catch {reset_run synth_1}

launch_runs synth_1 -jobs 4
wait_on_run synth_1
check_run_complete synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
check_run_complete impl_1

close_project
