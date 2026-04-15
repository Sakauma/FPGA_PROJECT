// ============================================================================
// 维护注释
//   文件职责      : 可复用的 AXIS 辅助逻辑。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================

module fifo_to_axis #(
    parameter 		P_D_WIDTH 					= 32										 
) (
	output 										fifo_ren									,
	input			[P_D_WIDTH-1:0]				fifo_rdata									,
	input 										fifo_empty									,

	/*******************axi_stream************/
	input 										m_axis_aclk									,
	input 										m_axis_aresetn									,
	
	input										m_axis_tready								,
	output			[P_D_WIDTH-1:0]				m_axis_tdata								,
	output										m_axis_tvalid								
);

	assign m_axis_tvalid 						= !fifo_empty								;
	assign m_axis_tdata 						= fifo_rdata[P_D_WIDTH-1:0]							;
                                                                                        	
	assign fifo_ren 							= m_axis_tvalid & m_axis_tready				;

endmodule
