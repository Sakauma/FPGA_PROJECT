set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

open_project build/csim_run/undistort_demo_hls
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csim_design
exit
