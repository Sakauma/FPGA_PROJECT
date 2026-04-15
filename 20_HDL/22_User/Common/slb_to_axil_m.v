// ============================================================================
// 维护注释
//   文件职责      : 可复用的 FIFO、复位与总线桥接基础模块。
//   源码属性      : 手工维护源码，不要把修改同步到生成 IP 或网表。
//   更新要求      : 当时钟、复位、接口或数据顺序假设变化时，同步更新注释。
//   维护边界      : 注释用于说明当前实现意图，不替代接口协议文档。
// ============================================================================
module slb_to_axil_m #(
    parameter           P_REQ_SEL_PLUS    = 1  ,  // 鐢宠涓€娆¤Е鍙戜竴娆?

    parameter           C_S_AXI_ADDR_WIDTH    = 32    // AXI瀹樻柟鏍囧噯鍙傛暟鍛藉悕
) (
    // Global Clock & Reset (鏍囧噯鍛藉悕)
    input  wire                                s_axi_aclk          ,
    input  wire                                s_axi_aresetn       ,

    // ==============================================
    // Local Bus (LBE) Slave Interface 銆愬凡鏍囧噯鍖栥€?
    // ==============================================
    input  wire                                lbe_width_sel       ,  // 0=16bit, 1=32bit
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       lbe_addr            ,
    input  wire                                lbe_req             ,
    input  wire                                lbe_wr_en           ,  // 1=Write, 0=Read
    input  wire [31:0]                         lbe_wdata           ,
    output reg                                 lbe_ready           ,
    output reg [31:0]                         lbe_rdata           ,

    // ==============================================
    // AXI4-Lite Master Interface - 瀹樻柟鏍囧噯鍛藉悕
    // ==============================================
    // Write Address Channel
    output reg [C_S_AXI_ADDR_WIDTH-1:0]        m_axi_awaddr        ,
    output reg [2:0]                           m_axi_awprot        ,
    output reg                                 m_axi_awvalid       ,
    input  wire                                m_axi_awready       ,

    // Write Data Channel
    output reg [31:0]                          m_axi_wdata         ,
    output reg [3:0]                           m_axi_wstrb         ,
    output reg                                 m_axi_wvalid        ,
    input  wire                                m_axi_wready        ,

    // Write Response Channel
    input  wire [1:0]                          m_axi_bresp         ,
    input  wire                                m_axi_bvalid        ,
    output reg                                 m_axi_bready        ,

    // Read Address Channel
    output reg [C_S_AXI_ADDR_WIDTH-1:0]        m_axi_araddr        ,
    output reg [2:0]                           m_axi_arprot        ,
    output reg                                 m_axi_arvalid       ,
    input  wire                                m_axi_arready       ,

    // Read Data Channel
    input  wire [31:0]                         m_axi_rdata         ,
    input  wire [1:0]                          m_axi_rresp         ,
    input  wire                                m_axi_rvalid        ,
    output reg                                 m_axi_rready
);

// ---------------------------
// FSM State Definition (鏍囧噯鏍煎紡)
// ---------------------------
localparam [2:0]    S_IDLE          = 3'b000 ;
localparam [2:0]    S_WR_ADDR       = 3'b001 ;
localparam [2:0]    S_WR_DATA       = 3'b010 ;
localparam [2:0]    S_WR_WAIT       = 3'b011 ;
localparam [2:0]    S_RD_ADDR       = 3'b100 ;
localparam [2:0]    S_RD_WAIT       = 3'b101 ;

// ---------------------------
// Internal Registers (瑙勮寖鍛藉悕)
// ---------------------------
reg [2:0]                           curr_state      ;
reg [2:0]                           next_state      ;
reg [C_S_AXI_ADDR_WIDTH-1:0]        req_addr        ;
reg                                 req_wr_en       ;
reg [31:0]                          req_wdata       ;
reg                                 req_pending     ;
reg                                 read_data_vld   ;
reg [1:0]                           byte_offset     ;

// 淇濈暀鍘焞ast_state閫昏緫锛屾爣鍑嗗寲鍛藉悕
reg [2:0]                           last_state      ;

always @(posedge s_axi_aclk   ) begin
    last_state <= curr_state;
end
reg                          lbe_req_d1    = 1'b0   ;
reg                          lbe_req_plus    = 1'b0   ;

always @(posedge s_axi_aclk   ) begin
    lbe_req_d1 <= lbe_req;
    lbe_req_plus<= lbe_req & ~lbe_req_d1;
end
// ---------------------------
// FSM Sequential Logic
// ---------------------------
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        curr_state      <= S_IDLE    ;
        req_addr        <= 'd0       ;
        req_wr_en       <= 1'b0      ;
        req_wdata       <= 'd0       ;
        req_pending     <= 1'b0      ;
        lbe_ready       <= 1'b0      ;
        lbe_rdata       <= 'd0       ;
        read_data_vld   <= 1'b0      ;
        byte_offset     <= 2'b00     ;
    end else begin
        curr_state <= next_state;

        // Capture Local Bus Request
        if (last_state == S_IDLE && (P_REQ_SEL_PLUS==1 ? lbe_req_plus :lbe_req ) && !req_pending) begin
            req_addr        <= lbe_addr      ;
            req_wr_en       <= lbe_wr_en     ;
            req_wdata       <= lbe_wdata     ;
            req_pending     <= 1'b1          ;
            byte_offset     <= lbe_addr[1:0] ;
        end

        // LBE Ready Control
        case (curr_state)
            S_WR_WAIT: lbe_ready <= m_axi_bvalid && m_axi_bready;
            S_RD_WAIT: lbe_ready <= (next_state == S_IDLE) ? 1'b0 : read_data_vld;
            default:    lbe_ready <= 1'b0;
        endcase

        // Read Data Path
        if (m_axi_rvalid && m_axi_rready) begin
            if (lbe_width_sel) begin  // 32-bit mode
                lbe_rdata <= m_axi_rdata;
            end else begin           // 16-bit mode
                case (byte_offset[1])
                    1'b0: lbe_rdata <= {16'b0, m_axi_rdata[15:0]};
                    1'b1: lbe_rdata <= {16'b0, m_axi_rdata[31:16]};
                endcase
            end
            read_data_vld <= 1'b1;
        end else if (lbe_ready && curr_state == S_RD_WAIT) begin
            read_data_vld <= 1'b0;
        end

        // Clear Request Pending Flag
        if ((curr_state == S_WR_WAIT && m_axi_bvalid && m_axi_bready) ||
            (curr_state == S_RD_WAIT && lbe_ready)) begin
            req_pending <= 1'b0;
        end
    end
end

// ---------------------------
// FSM Combinational Logic
// ---------------------------
always @(*) begin
    next_state = curr_state;
    case (curr_state)
        S_IDLE: begin
            if (req_pending)
                next_state = req_wr_en ? S_WR_ADDR : S_RD_ADDR;
            else
                next_state = S_IDLE;
        end

        S_WR_ADDR: begin
            if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready)
                next_state = S_WR_WAIT;
            else if (m_axi_awvalid && m_axi_awready)
                next_state = S_WR_DATA;
            else
                next_state = S_WR_ADDR;
        end

        S_WR_DATA: begin
            next_state = (m_axi_wvalid && m_axi_wready) ? S_WR_WAIT : S_WR_DATA;
        end

        S_WR_WAIT: begin
            next_state = (m_axi_bvalid && m_axi_bready) ? S_IDLE : S_WR_WAIT;
        end

        S_RD_ADDR: begin
            next_state = (m_axi_arvalid && m_axi_arready) ? S_RD_WAIT : S_RD_ADDR;
        end

        S_RD_WAIT: begin
            next_state = (read_data_vld && lbe_ready) ? S_IDLE : S_RD_WAIT;
        end

        default: next_state = S_IDLE;
    endcase
end

// ---------------------------
// AXI4-Lite Master Control Logic
// ---------------------------
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        // Write Address
        m_axi_awaddr    <= 'd0;
        m_axi_awprot    <= 3'b000;
        m_axi_awvalid   <= 1'b0;
        // Write Data
        m_axi_wdata     <= 'd0;
        m_axi_wstrb     <= 4'b0000;
        m_axi_wvalid    <= 1'b0;
        // Write Response
        m_axi_bready    <= 1'b0;
        // Read Address
        m_axi_araddr    <= 'd0;
        m_axi_arprot    <= 3'b000;
        m_axi_arvalid   <= 1'b0;
        // Read Data
        m_axi_rready    <= 1'b0;
    end else begin
        // -------------------
        // Write Address Channel
        // -------------------
        case (curr_state)
            S_IDLE: begin
                if (req_pending && req_wr_en) begin
                    m_axi_awaddr  <= {req_addr[C_S_AXI_ADDR_WIDTH-1:2], 2'b00};
                    m_axi_awprot  <= 3'b000;
                    m_axi_awvalid <= 1'b1;
                end
            end
            S_WR_ADDR: begin
                if (m_axi_awready) m_axi_awvalid <= 1'b0;
            end
            default: m_axi_awvalid <= 1'b0;
        endcase

        // -------------------
        // Write Data Channel
        // -------------------
        case (curr_state)
            S_IDLE: begin
                if (req_pending && req_wr_en) begin
                    if (lbe_width_sel) begin  // 32-bit
                        m_axi_wdata  <= req_wdata;
                        m_axi_wstrb  <= 4'b1111;
                    end else begin           // 16-bit
                        case (byte_offset[1])
                            1'b0: begin
                                m_axi_wdata <= {16'b0, req_wdata[15:0]};
                                m_axi_wstrb <= 4'b0011;
                            end
                            1'b1: begin
                                m_axi_wdata <= {req_wdata[15:0], 16'b0};
                                m_axi_wstrb <= 4'b1100;
                            end
                        endcase
                    end
                    m_axi_wvalid <= 1'b1;
                end
            end
            S_WR_ADDR: begin
                if (m_axi_wready && m_axi_wvalid) m_axi_wvalid <= 1'b0;
            end
            S_WR_DATA: begin
                if (m_axi_wready) m_axi_wvalid <= 1'b0;
            end
            default: m_axi_wvalid <= 1'b0;
        endcase

        // Write Response
        m_axi_bready <= (curr_state == S_WR_WAIT);

        // -------------------
        // Read Address Channel
        // -------------------
        case (curr_state)
            S_IDLE: begin
                if (req_pending && !req_wr_en) begin
                    m_axi_araddr  <= {req_addr[C_S_AXI_ADDR_WIDTH-1:2], 2'b00};
                    m_axi_arprot  <= 3'b000;
                    m_axi_arvalid <= 1'b1;
                end
            end
            S_RD_ADDR: begin
                if (m_axi_arready) m_axi_arvalid <= 1'b0;
            end
            default: m_axi_arvalid <= 1'b0;
        endcase

        // Read Data
        m_axi_rready <= (curr_state == S_RD_WAIT && !read_data_vld);
    end
end

endmodule
