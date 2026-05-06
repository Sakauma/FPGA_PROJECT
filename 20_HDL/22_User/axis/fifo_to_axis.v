// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
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
