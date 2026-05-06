# ============================================================================
# 新增维护说明
# 作者          : Egor Izmaylov
# 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
# 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
# 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
# ============================================================================
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]

#set_property PACKAGE_PIN AH10 [get_ports {fc_gt_rxp[0]}]
#set_property PACKAGE_PIN AK10 [get_ports {fc_gt_txp[0]}]
#set_property PACKAGE_PIN AJ8 [get_ports {fc_gt_rxp[1]}]
#set_property PACKAGE_PIN AK6 [get_ports {fc_gt_txp[1]}]
#set_property PACKAGE_PIN AF10 [get_ports gtxrefclk109_p]

# 历史说明：原注释编码已损坏，已替换为中文维护说明。
#set_property PACKAGE_PIN AE22 [get_ports sys_clk_p]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	sys_clk_p	]

set_property PACKAGE_PIN D9 [get_ports sys_clk_p]
set_property PACKAGE_PIN D8 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL18_I [get_ports sys_clk_p]


#set_property PACKAGE_PIN AE8 [get_ports {video_srio_rxp0[0]}]
#set_property PACKAGE_PIN AK2 [get_ports {video_srio_txp0[0]}]
#set_property PACKAGE_PIN AG8 [get_ports {video_srio_rxp0[1]}]
#set_property PACKAGE_PIN AJ4 [get_ports {video_srio_txp0[1]}]

#set_property PACKAGE_PIN AJ8 [get_ports {video_srio_rxp0[2]}]
#set_property PACKAGE_PIN AK6 [get_ports {video_srio_txp0[2]}]
#set_property PACKAGE_PIN AH10 [get_ports {video_srio_rxp0[3]}]
#set_property PACKAGE_PIN AK10 [get_ports {video_srio_txp0[3]}]

set_property PACKAGE_PIN AE8 [get_ports {video_srio_rxp0[1]}]
set_property PACKAGE_PIN AK2 [get_ports {video_srio_txp0[1]}]
set_property PACKAGE_PIN AG8 [get_ports {video_srio_rxp0[0]}]
set_property PACKAGE_PIN AJ4 [get_ports {video_srio_txp0[0]}]

set_property PACKAGE_PIN AJ8 [get_ports {video_srio_rxp0[2]}]
set_property PACKAGE_PIN AK6 [get_ports {video_srio_txp0[2]}]
set_property PACKAGE_PIN AH10 [get_ports {video_srio_rxp0[3]}]
set_property PACKAGE_PIN AK10 [get_ports {video_srio_txp0[3]}]


#set_property PACKAGE_PIN AG8 [get_ports {video_srio_rxp0[0]}]
#set_property PACKAGE_PIN AJ4 [get_ports {video_srio_txp0[0]}]


#set_property PACKAGE_PIN AH10 [get_ports {video_srio_rxp0[1]}]
#set_property PACKAGE_PIN AK10 [get_ports {video_srio_txp0[1]}]


set_property PACKAGE_PIN AF10 [get_ports gtxrefclk109_p]
create_clock -period 8 -name v_srio_clk -waveform {0 4} [get_ports gtxrefclk109_p]


set_property PACKAGE_PIN AH6 [get_ports {fc_gt_rxp[0]}]
set_property PACKAGE_PIN AH2 [get_ports {fc_gt_txp[0]}]
set_property PACKAGE_PIN AG4 [get_ports {fc_gt_rxp[1]}]
set_property PACKAGE_PIN AF2 [get_ports {fc_gt_txp[1]}]

set_property PACKAGE_PIN AC8 [get_ports gtxrefclk110_p]
create_clock -period 8 -name d_srio_clk -waveform {0 4} [get_ports gtxrefclk110_p]

#set_property	PACKAGE_PIN	AJ13	[get_ports	Z7_UART_DE	]
#set_property	PACKAGE_PIN	Y27	[get_ports	Z7_UART_DE1	]
#set_property	PACKAGE_PIN	AG27	[get_ports	Z7_UART_DE2	]
#set_property	PACKAGE_PIN	AB26	[get_ports	Z7_UART_DE3	]
#set_property	PACKAGE_PIN	AA30	[get_ports	Z7_UART_DE4	]
#set_property	PACKAGE_PIN	AH14	[get_ports	Z7_UART_REN	]
#set_property	PACKAGE_PIN	Y28	[get_ports	Z7_UART_REN1	]
#set_property	PACKAGE_PIN	AE26	[get_ports	Z7_UART_REN2	]
#set_property	PACKAGE_PIN	AC29	[get_ports	Z7_UART_REN3	]
#set_property	PACKAGE_PIN	AA29	[get_ports	Z7_UART_REN4	]
set_property	PACKAGE_PIN	Y26		[get_ports	rs422_rx_in_1	]
set_property	PACKAGE_PIN	AG26	[get_ports	rs422_rx_in_2	]
set_property	PACKAGE_PIN	AC28	[get_ports	rs422_rx_in_3	]
set_property	PACKAGE_PIN	AA28	[get_ports	rs422_rx_in_4	]
set_property	PACKAGE_PIN	Y30		[get_ports	rs422_tx_out_1	]
set_property	PACKAGE_PIN	AF27	[get_ports	rs422_tx_out_2	]
set_property	PACKAGE_PIN	AB27	[get_ports	rs422_tx_out_3	]
set_property	PACKAGE_PIN	AA27	[get_ports	rs422_tx_out_4	]
					
													
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_DE	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_DE1	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_DE2	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_DE3	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_DE4	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_REN	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_REN1	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_REN2	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_REN3	]
#set_property	IOSTANDARD	LVCMOS33	[get_ports	Z7_UART_REN4	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_rx_in_1	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_rx_in_2	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_rx_in_3	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_rx_in_4	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_tx_out_1	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_tx_out_2	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_tx_out_3	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_tx_out_4	]

#
#NET	"PPS_REN1"	LOC	=	"AG30";
#NET	"PPS_REN2"	LOC	=	"AE28";



set_property	PACKAGE_PIN	AG29		[get_ports	rs422_rx_in_5	]
set_property	PACKAGE_PIN	AF29		[get_ports	rs422_rx_in_6	]
set_property	PACKAGE_PIN	AF30		[get_ports	rs422_tx_out_5	]
set_property	PACKAGE_PIN	AD29		[get_ports	rs422_tx_out_6	]

set_property	PACKAGE_PIN	AF28		[get_ports	rs422_ten_5	]
set_property	PACKAGE_PIN	AD28		[get_ports	rs422_ten_6	]

set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_rx_in_5	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_rx_in_6	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_tx_out_5	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_tx_out_6	]
      
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_ten_5	]
set_property	IOSTANDARD	LVCMOS33	[get_ports	rs422_ten_6	]


set_property PACKAGE_PIN AD18 [get_ports eMMC_RSTN]
set_property PACKAGE_PIN AD19 [get_ports eMMC_DS]
set_property IOSTANDARD LVCMOS18 [get_ports eMMC_RSTN]
set_property IOSTANDARD LVCMOS18 [get_ports eMMC_DS]



set_property PACKAGE_PIN AF13 [get_ports ds18_dq0]
set_property PACKAGE_PIN AF12 [get_ports ds18_dq1]

set_property IOSTANDARD	LVCMOS33 [get_ports ds18_dq0]
set_property IOSTANDARD	LVCMOS33 [get_ports ds18_dq1]

set_property PACKAGE_PIN AA14 [get_ports {XP1_GPIO[0]}]
set_property PACKAGE_PIN AE12 [get_ports {XP1_GPIO[1]}]

set_property IOSTANDARD	LVCMOS33 [get_ports {XP1_GPIO[*]}]


set_clock_groups -asynchronous -group [get_clocks clk_fpga_0] -group [get_clocks -of_objects [get_pins srio_video_loop/u_dcm/inst/mmcm_adv_inst/CLKOUT1]]

# set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets srio_video_loop/u_dcm/inst/clk_in1_clk_dcm] 
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks clk_fpga_1]

#set_clock_groups -asynchronous -group [get_clocks clk_fpga_0] -group [get_clocks -of_objects [get_pins u_xr2000_top_AT01_TOP/i_srio_support/u_SRIO_5g_1x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT1]]
#set_clock_groups -asynchronous -group [get_clocks clk_fpga_0] -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT2]]

set_false_path -from [get_pins {zynq_i/proc_sys_reset_0/U0/PR_OUT_DFF[0].FDRE_PER/C}]
# 历史说明：原注释编码已损坏，已替换为中文维护说明。
#set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_D.ddr_byte_lane_D/phaser_in_gen.phaser_in/ICLK]]
#set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_2.u_ddr_phy_4lanes/ddr_byte_lane_A.ddr_byte_lane_A/phaser_in_gen.phaser_in/ICLK]]
#set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_memc_ui_top_axi/mem_intfc0/ddr_phy_top0/u_ddr_mc_phy_wrapper/u_ddr_mc_phy/ddr_phy_4lanes_2.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/phaser_in_gen.phaser_in/ICLK]]

set_false_path -from [get_pins srio_video_loop/rst_n_reg/C]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT2]] -group [get_clocks -of_objects [get_pins srio_video_loop/u_dcm/inst/mmcm_adv_inst/CLKOUT1]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT2]] -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT3]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_dcm/inst/mmcm_adv_inst/CLKOUT1]] -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT2]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_dcm/inst/mmcm_adv_inst/CLKOUT1]] -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT3]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins srio_video_loop/u_mem/mig_7series_0/u_MY_MEM_mig_7series_0_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -group [get_clocks -of_objects [get_pins srio_video_loop/u_dcm/inst/mmcm_adv_inst/CLKOUT1]]


set_clock_groups -asynchronous -group [get_clocks clk_fpga_0] -group [get_clocks -of_objects [get_pins srio_video_loop/srio_top/i_srio_support/u_SRIO_5g_2x_8b.u_srio_support/srio_clk_inst/srio_mmcm_inst/CLKOUT2]] 
