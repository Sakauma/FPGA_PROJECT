// ============================================================================
// ĞÂÔöÎ¬»¤ËµÃ÷
// ÎÄ¼şÖ°Ôğ      : µ±Ç°ÎÄ¼şÎªÊÖ¹¤Î¬»¤Ô´Âë£¬³Ğµ£±¾Ä£¿é/½Å±¾µÄÕæÊµÊµÏÖ¡£
// Î¬»¤±ß½ç      : ±¾×¢ÊÍ¿é½ö²¹³äÎ¬»¤ËµÃ÷£¬²»¸ÄĞ´ÈÎºÎÔ­ÓĞËµÃ÷¡¢ÀúÊ·×¢ÊÍ»òÏÖÓĞÂß¼­¡£
// ĞŞ¸ÄÔ¼Êø      : ºóĞøÈçĞè¼ÌĞø²¹³äËµÃ÷£¬Ö»ÔÊĞí×·¼ÓÖĞÎÄ×¢ÊÍ£¬²»µÃÌæ»»¾É×¢ÊÍ»ò¸Ä¶¯¾É´úÂë¡£
// Éú³É¹ØÏµ      : Èô´æÔÚ¶ÔÓ¦Éú³ÉÎï£¬Ó¦ÒÔµ±Ç°ÊÖ¹¤Ô´ÂëÎª×¼£¬½ûÖ¹·´Ïò¸²¸Ç±¾ÎÄ¼ş¡£
// ============================================================================
set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]

open_project build/cosim_run/undistort_demo_hls
set_top undistort_demo_hls

add_files [file join $root_dir src undistort_demo_hls.cpp]
add_files [file join $root_dir src undistort_demo_hls.h]
# æ–°ä»£ç 
add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s -DUNDISTORT_DEMO_COSIM" [file join $root_dir src]]
# æ—§ä»£ç 
# add_files -tb [file join $root_dir tb undistort_demo_hls_tb.cpp] -cflags [format "-I%s" [file join $root_dir src]]

open_solution "solution1" -flow_target vivado
set_part xc7z100ffg900-2
create_clock -period 4.000 -name default

csynth_design
cosim_design
exit
