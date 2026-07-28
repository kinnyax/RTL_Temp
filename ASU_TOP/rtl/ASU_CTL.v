`timescale 1ns / 1ps
`default_nettype none

// Request decode, local registers, and one-outstanding AXI4-Lite master.
module ASU_CTL
(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             FRT_REQ_VLD                                 ,
    input  wire [127:0]                     FRT_REQ_FRAME                               ,
    output wire                             CTL_REQ_RDY                                 ,
    output reg                              CTL_RSP_VLD                                 ,
    output reg                              CTL_REQ_ERR                                 ,
    output reg  [1:0]                       CTL_AXI_RESP                                ,
    output reg  [31:0]                      CTL_RDATA                                   ,
    input  wire                             FRT_RSP_RDY                                 ,
    input  wire                             FRT_RSP_CONSUMED                            ,
    output wire [31:0]                      M_AXI_AWADDR                                ,
    output wire [2:0]                       M_AXI_AWPROT                                ,
    output wire                             M_AXI_AWVALID                               ,
    input  wire                             M_AXI_AWREADY                               ,
    output wire [31:0]                      M_AXI_WDATA                                 ,
    output wire [3:0]                       M_AXI_WSTRB                                 ,
    output wire                             M_AXI_WVALID                                ,
    input  wire                             M_AXI_WREADY                                ,
    input  wire [1:0]                       M_AXI_BRESP                                 ,
    input  wire                             M_AXI_BVALID                                ,
    output wire                             M_AXI_BREADY                                ,
    output wire [31:0]                      M_AXI_ARADDR                                ,
    output wire [2:0]                       M_AXI_ARPROT                                ,
    output wire                             M_AXI_ARVALID                               ,
    input  wire                             M_AXI_ARREADY                               ,
    input  wire [31:0]                      M_AXI_RDATA                                 ,
    input  wire [1:0]                       M_AXI_RRESP                                 ,
    input  wire                             M_AXI_RVALID                                ,
    output wire                             M_AXI_RREADY
);

parameter integer                           UDLY                        = 1              ;

localparam [1:0]                            ASU_RECV                    = 2'd0           ;
localparam [1:0]                            ASU_DECODE                  = 2'd1           ;
localparam [1:0]                            ASU_TRANS                   = 2'd2           ;
localparam [15:0]                           REQ_WRITE                   = 16'hA501       ;
localparam [15:0]                           REQ_READ                    = 16'hA502       ;
localparam [31:0]                           CHIP_ID_ADDR                = 32'h1000_0000  ;
localparam [31:0]                           CHIP_VER_ADDR               = 32'h1000_0004  ;
localparam [31:0]                           CHIP_ID_VALUE               = 32'h4445_5443  ;
localparam [31:0]                           CHIP_VER_VALUE              = 32'h2026_0720  ;

wire                                        req_hs                                       ;
wire                                        resp_hs                                      ;
wire                                        req_wr                                       ;
wire                                        req_rd                                       ;
wire                                        req_vld                                      ;
wire                                        chip_id                                      ;
wire                                        chip_ver                                     ;
wire                                        local_reg                                    ;
wire                                        local_rd                                     ;
wire                                        req_err                                      ;
wire                                        axi_req                                      ;
wire [31:0]                                 local_rdata                                  ;
wire                                        aw_hs                                        ;
wire                                        w_hs                                         ;
wire                                        b_hs                                         ;
wire                                        ar_hs                                        ;
wire                                        r_hs                                         ;

reg  [1:0]                                  state                                        ;
reg  [1:0]                                  state_nxt                                    ;
reg                                         req_rdy                                      ;
reg  [15:0]                                 req_magic                                    ;
reg  [31:0]                                 req_addr                                     ;
reg  [31:0]                                 req_wdata                                    ;
reg                                         aw_done                                      ;
reg                                         w_done                                       ;
reg                                         ar_done                                      ;
reg                                         axi_resp_seen                                ;

assign req_hs  = FRT_REQ_VLD & CTL_REQ_RDY;
assign resp_hs = CTL_RSP_VLD & FRT_RSP_RDY;

assign req_wr     = (req_magic == REQ_WRITE);
assign req_rd     = (req_magic == REQ_READ);
assign req_vld    = req_wr | req_rd;
assign chip_id    = (req_addr == CHIP_ID_ADDR);
assign chip_ver   = (req_addr == CHIP_VER_ADDR);
assign local_reg  = chip_id | chip_ver;
assign local_rd   = req_rd & local_reg;
assign req_err    = ~req_vld | (req_wr & local_reg);
assign axi_req    = req_vld & ~local_reg;
assign local_rdata = ({32{chip_id}} & CHIP_ID_VALUE) |
                     ({32{chip_ver}} & CHIP_VER_VALUE);

// ASU main FSM, part 1: state register. CTL uses SYS_RST_N only.
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        state <= #UDLY ASU_RECV;
    else
        state <= #UDLY state_nxt;
end

// ASU main FSM, part 2: next-state logic changes only the state.
always @(*) begin
    state_nxt = state;
    case(state)
        ASU_RECV: begin
            if(req_hs)
                state_nxt = ASU_DECODE;
        end
        ASU_DECODE: begin
            state_nxt = ASU_TRANS;
        end
        ASU_TRANS: begin
            if(FRT_RSP_CONSUMED)
                state_nxt = ASU_RECV;
        end
        default: begin
            state_nxt = ASU_RECV;
        end
    endcase
end

// ASU main FSM, part 3: state-derived receive readiness.
always @(*) begin
    req_rdy = 1'b0;
    case(state)
        ASU_RECV: req_rdy = 1'b1;
        default:  req_rdy = 1'b0;
    endcase
end

assign CTL_REQ_RDY = req_rdy;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        req_magic <= #UDLY 16'd0;
        req_addr <= #UDLY 32'd0;
        req_wdata <= #UDLY 32'd0;
    end else if(FRT_RSP_CONSUMED) begin
        req_magic <= #UDLY 16'd0;
        req_addr <= #UDLY 32'd0;
        req_wdata <= #UDLY 32'd0;
    end else if(req_hs) begin
        req_magic <= #UDLY FRT_REQ_FRAME[127:112];
        req_addr <= #UDLY FRT_REQ_FRAME[95:64];
        req_wdata <= #UDLY FRT_REQ_FRAME[63:32];
    end
end

assign aw_hs = M_AXI_AWVALID & M_AXI_AWREADY;
assign w_hs  = M_AXI_WVALID & M_AXI_WREADY;
assign b_hs  = M_AXI_BVALID & M_AXI_BREADY;
assign ar_hs = M_AXI_ARVALID & M_AXI_ARREADY;
assign r_hs  = M_AXI_RVALID & M_AXI_RREADY;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        aw_done <= #UDLY 1'b0;
    else if(req_hs | FRT_RSP_CONSUMED)
        aw_done <= #UDLY 1'b0;
    else if(aw_hs)
        aw_done <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        w_done <= #UDLY 1'b0;
    else if(req_hs | FRT_RSP_CONSUMED)
        w_done <= #UDLY 1'b0;
    else if(w_hs)
        w_done <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        ar_done <= #UDLY 1'b0;
    else if(req_hs | FRT_RSP_CONSUMED)
        ar_done <= #UDLY 1'b0;
    else if(ar_hs)
        ar_done <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        axi_resp_seen <= #UDLY 1'b0;
    else if(req_hs | FRT_RSP_CONSUMED)
        axi_resp_seen <= #UDLY 1'b0;
    else if(b_hs | r_hs)
        axi_resp_seen <= #UDLY 1'b1;
end

assign M_AXI_AWADDR  = req_addr;
assign M_AXI_AWPROT  = 3'b000;
assign M_AXI_AWVALID = (state == ASU_TRANS) & axi_req & req_wr & ~aw_done;
assign M_AXI_WDATA   = req_wdata;
assign M_AXI_WSTRB   = 4'b1111;
assign M_AXI_WVALID  = (state == ASU_TRANS) & axi_req & req_wr & ~w_done;
assign M_AXI_BREADY  = (state == ASU_TRANS) & axi_req & req_wr &
                       aw_done & w_done & ~axi_resp_seen;
assign M_AXI_ARADDR  = req_addr;
assign M_AXI_ARPROT  = 3'b000;
assign M_AXI_ARVALID = (state == ASU_TRANS) & axi_req & req_rd & ~ar_done;
assign M_AXI_RREADY  = (state == ASU_TRANS) & axi_req & req_rd &
                       ar_done & ~axi_resp_seen;

// Four assignment targets hold a ready/valid result payload stable.
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        CTL_RSP_VLD <= #UDLY 1'b0;
        CTL_REQ_ERR <= #UDLY 1'b0;
        CTL_AXI_RESP <= #UDLY 2'd0;
        CTL_RDATA <= #UDLY 32'd0;
    end else if(FRT_RSP_CONSUMED) begin
        CTL_RSP_VLD <= #UDLY 1'b0;
        CTL_REQ_ERR <= #UDLY 1'b0;
        CTL_AXI_RESP <= #UDLY 2'd0;
        CTL_RDATA <= #UDLY 32'd0;
    end else if(resp_hs) begin
        CTL_RSP_VLD <= #UDLY 1'b0;
    end else if(state == ASU_DECODE) begin
        if(local_rd | req_err) begin
            CTL_RSP_VLD <= #UDLY 1'b1;
            CTL_REQ_ERR <= #UDLY req_err;
            CTL_AXI_RESP <= #UDLY 2'd0;
            CTL_RDATA <= #UDLY local_rd ? local_rdata : 32'd0;
        end else begin
            CTL_RSP_VLD <= #UDLY 1'b0;
            CTL_REQ_ERR <= #UDLY 1'b0;
            CTL_AXI_RESP <= #UDLY 2'd0;
            CTL_RDATA <= #UDLY 32'd0;
        end
    end else if(b_hs) begin
        CTL_RSP_VLD <= #UDLY 1'b1;
        CTL_REQ_ERR <= #UDLY 1'b0;
        CTL_AXI_RESP <= #UDLY M_AXI_BRESP;
        CTL_RDATA <= #UDLY 32'd0;
    end else if(r_hs) begin
        CTL_RSP_VLD <= #UDLY 1'b1;
        CTL_REQ_ERR <= #UDLY 1'b0;
        CTL_AXI_RESP <= #UDLY M_AXI_RRESP;
        CTL_RDATA <= #UDLY (M_AXI_RRESP == 2'b00) ?
                             M_AXI_RDATA : 32'd0;
    end
end

endmodule

`default_nettype wire
