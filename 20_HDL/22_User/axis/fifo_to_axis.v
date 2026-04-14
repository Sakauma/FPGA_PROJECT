
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
