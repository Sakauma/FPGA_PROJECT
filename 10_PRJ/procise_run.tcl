set_device JFMQL100T900
set script_dir [file dirname [file normalize [info script]]]
set input_bit_path [file normalize [file join $script_dir 00_PRJ.runs impl_1 EB4110_10V10_TOP.bit]]
set output_bit_path [file normalize [file join $script_dir 00_PRJ.runs impl_1 EB4110_10V10_TOP_incr_cfg.bit]]
increment_bit_cfg_v3 $input_bit_path $output_bit_path
