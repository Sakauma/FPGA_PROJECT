// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
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
