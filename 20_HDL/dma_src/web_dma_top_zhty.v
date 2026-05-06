// ============================================================================
// 新增维护说明
// 作者          : Egor Izmaylov
// 文件职责      : 当前文件为手工维护源码，具体职责见模块名、端口和上层实例化。
// 维护边界      : 只追加说明性注释；Vivado/IP 生成物和第三方支撑代码不在此处手改。
// 修改约束      : 功能改动需同步更新仿真、综合结果和相关文档。
// ============================================================================
// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
// Date        : Mon Apr 13 14:16:03 2026
// Host        : WIN-20241207VME running 64-bit major release  (build 9200)
// Command     : write_verilog -mode synth_stub /web_dma_top_zhty.v
// Design      : web_dma_top
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z100ffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module web_dma_top(clk, rst_n, package_int, axi_slite_clk, 
  axi_slite_awaddr, axi_slite_awvalid, axi_slite_awready, axi_slite_awprot, 
  axi_slite_wdata, axi_slite_wstrb, axi_slite_wvalid, axi_slite_wready, axi_slite_bresp, 
  axi_slite_bvalid, axi_slite_bready, axi_slite_araddr, axi_slite_arvalid, 
  axi_slite_arready, axi_slite_arprot, axi_slite_rdata, axi_slite_rresp, axi_slite_rvalid, 
  axi_slite_rready, axi_clk, axi_mhp_wready, axi_mhp_wid, axi_mhp_waddr, axi_mhp_wlen, 
  axi_mhp_wsize, axi_mhp_wburst, axi_mhp_wlock, axi_mhp_wcache, axi_mhp_wprot, 
  axi_mhp_wvalid, axi_mhp_wqos, axi_mhp_wd_wready, axi_mhp_wd_wid, axi_mhp_wd_data, 
  axi_mhp_wd_strb, axi_mhp_wd_last, axi_mhp_wd_valid, axi_mhp_wd_bid, axi_mhp_wd_bresp, 
  axi_mhp_wd_bvalid, axi_mhp_wd_bready, axi_mhp_rready, axi_mhp_rid, axi_mhp_raddr, 
  axi_mhp_rlen, axi_mhp_rsize, axi_mhp_rburst, axi_mhp_rlock, axi_mhp_rcache, axi_mhp_rprot, 
  axi_mhp_rvalid, axi_mhp_rqos, axi_mhp_rd_bid, axi_mhp_rd_rresp, axi_mhp_rd_rvalid, 
  axi_mhp_rd_data, axi_mhp_rd_last, axi_mhp_rd_rready, axis_dn_clk, axis_dn_tready, 
  axis_dn_tdata, axis_dn_tid, axis_dn_tvalid, axis_dn_tstrb, axis_dn_tkeep, axis_dn_tlast, 
  axis_dn_tuser, axis_dn_tdest, axis_up_clk, axis_up_tready, axis_up_tdata, axis_up_tid, 
  axis_up_tvalid, axis_up_tstrb, axis_up_tkeep, axis_up_tlast, axis_up_tuser, axis_up_tdest)
/* synthesis syn_black_box black_box_pad_pin="clk,rst_n,package_int,axi_slite_clk,axi_slite_awaddr[31:0],axi_slite_awvalid,axi_slite_awready,axi_slite_awprot[2:0],axi_slite_wdata[31:0],axi_slite_wstrb[3:0],axi_slite_wvalid,axi_slite_wready,axi_slite_bresp[1:0],axi_slite_bvalid,axi_slite_bready,axi_slite_araddr[31:0],axi_slite_arvalid,axi_slite_arready,axi_slite_arprot[2:0],axi_slite_rdata[31:0],axi_slite_rresp[1:0],axi_slite_rvalid,axi_slite_rready,axi_clk,axi_mhp_wready,axi_mhp_wid[3:0],axi_mhp_waddr[31:0],axi_mhp_wlen[7:0],axi_mhp_wsize[2:0],axi_mhp_wburst[1:0],axi_mhp_wlock[1:0],axi_mhp_wcache[3:0],axi_mhp_wprot[2:0],axi_mhp_wvalid,axi_mhp_wqos[3:0],axi_mhp_wd_wready,axi_mhp_wd_wid[3:0],axi_mhp_wd_data[63:0],axi_mhp_wd_strb[7:0],axi_mhp_wd_last,axi_mhp_wd_valid,axi_mhp_wd_bid[3:0],axi_mhp_wd_bresp[1:0],axi_mhp_wd_bvalid,axi_mhp_wd_bready,axi_mhp_rready,axi_mhp_rid[3:0],axi_mhp_raddr[31:0],axi_mhp_rlen[7:0],axi_mhp_rsize[2:0],axi_mhp_rburst[1:0],axi_mhp_rlock[1:0],axi_mhp_rcache[3:0],axi_mhp_rprot[2:0],axi_mhp_rvalid,axi_mhp_rqos[3:0],axi_mhp_rd_bid[3:0],axi_mhp_rd_rresp[1:0],axi_mhp_rd_rvalid,axi_mhp_rd_data[63:0],axi_mhp_rd_last,axi_mhp_rd_rready,axis_dn_clk[2:0],axis_dn_tready[2:0],axis_dn_tdata[191:0],axis_dn_tid[11:0],axis_dn_tvalid[2:0],axis_dn_tstrb[23:0],axis_dn_tkeep[23:0],axis_dn_tlast[2:0],axis_dn_tuser[191:0],axis_dn_tdest[11:0],axis_up_clk[3:0],axis_up_tready[3:0],axis_up_tdata[255:0],axis_up_tid[15:0],axis_up_tvalid[3:0],axis_up_tstrb[31:0],axis_up_tkeep[31:0],axis_up_tlast[3:0],axis_up_tuser[255:0],axis_up_tdest[15:0]" */;
  input clk;
  input rst_n;
  output package_int;
  input axi_slite_clk;
  input [31:0]axi_slite_awaddr;
  input axi_slite_awvalid;
  output axi_slite_awready;
  input [2:0]axi_slite_awprot;
  input [31:0]axi_slite_wdata;
  input [3:0]axi_slite_wstrb;
  input axi_slite_wvalid;
  output axi_slite_wready;
  output [1:0]axi_slite_bresp;
  output axi_slite_bvalid;
  input axi_slite_bready;
  input [31:0]axi_slite_araddr;
  input axi_slite_arvalid;
  output axi_slite_arready;
  input [2:0]axi_slite_arprot;
  output [31:0]axi_slite_rdata;
  output [1:0]axi_slite_rresp;
  output axi_slite_rvalid;
  input axi_slite_rready;
  input axi_clk;
  input axi_mhp_wready;
  output [3:0]axi_mhp_wid;
  output [31:0]axi_mhp_waddr;
  output [7:0]axi_mhp_wlen;
  output [2:0]axi_mhp_wsize;
  output [1:0]axi_mhp_wburst;
  output [1:0]axi_mhp_wlock;
  output [3:0]axi_mhp_wcache;
  output [2:0]axi_mhp_wprot;
  output axi_mhp_wvalid;
  output [3:0]axi_mhp_wqos;
  input axi_mhp_wd_wready;
  output [3:0]axi_mhp_wd_wid;
  output [63:0]axi_mhp_wd_data;
  output [7:0]axi_mhp_wd_strb;
  output axi_mhp_wd_last;
  output axi_mhp_wd_valid;
  input [3:0]axi_mhp_wd_bid;
  input [1:0]axi_mhp_wd_bresp;
  input axi_mhp_wd_bvalid;
  output axi_mhp_wd_bready;
  input axi_mhp_rready;
  output [3:0]axi_mhp_rid;
  output [31:0]axi_mhp_raddr;
  output [7:0]axi_mhp_rlen;
  output [2:0]axi_mhp_rsize;
  output [1:0]axi_mhp_rburst;
  output [1:0]axi_mhp_rlock;
  output [3:0]axi_mhp_rcache;
  output [2:0]axi_mhp_rprot;
  output axi_mhp_rvalid;
  output [3:0]axi_mhp_rqos;
  input [3:0]axi_mhp_rd_bid;
  input [1:0]axi_mhp_rd_rresp;
  input axi_mhp_rd_rvalid;
  input [63:0]axi_mhp_rd_data;
  input axi_mhp_rd_last;
  output axi_mhp_rd_rready;
  input [2:0]axis_dn_clk;
  input [2:0]axis_dn_tready;
  output [191:0]axis_dn_tdata;
  output [11:0]axis_dn_tid;
  output [2:0]axis_dn_tvalid;
  output [23:0]axis_dn_tstrb;
  output [23:0]axis_dn_tkeep;
  output [2:0]axis_dn_tlast;
  output [191:0]axis_dn_tuser;
  output [11:0]axis_dn_tdest;
  input [3:0]axis_up_clk;
  output [3:0]axis_up_tready;
  input [255:0]axis_up_tdata;
  input [15:0]axis_up_tid;
  input [3:0]axis_up_tvalid;
  input [31:0]axis_up_tstrb;
  input [31:0]axis_up_tkeep;
  input [3:0]axis_up_tlast;
  input [255:0]axis_up_tuser;
  input [15:0]axis_up_tdest;
endmodule
