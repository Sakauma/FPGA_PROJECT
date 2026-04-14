set_device JFMQL100T900
# New code: resolve bitstream paths relative to this TCL file so the script works after cloning.
set script_dir [file dirname [file normalize [info script]]]
set input_bit_path [file normalize [file join $script_dir 00_PRJ.runs impl_1 EB4110_10V10_TOP.bit]]
set output_bit_path [file normalize [file join $script_dir 00_PRJ.runs impl_1 EB4110_10V10_TOP_incr_cfg.bit]]
increment_bit_cfg_v3 $input_bit_path $output_bit_path
# Old code preserved below:
# set input_bit_path D:/Staff/test/EB4110_FPGA_20260410_2/10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP.bit
# set output_bit_path D:/Staff/test/EB4110_FPGA_20260410_2/10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_incr_cfg.bit
# increment_bit_cfg_v3 $input_bit_path $output_bit_path
