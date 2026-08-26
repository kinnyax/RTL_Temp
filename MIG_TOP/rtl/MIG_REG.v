`timescale 1ns / 1ps

module MIG_REG #(
    parameter integer                       AXI_ADDR_WIDTH              = 15            ,
    parameter integer                       UDLY                        = 1
)(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             INIT_CALIB_COMPLETE_SYNC                    ,
    input  wire                             UI_RST_ACTIVE_SYNC                          ,
    input  wire                             MIG_READY                                   ,
    input  wire [AXI_ADDR_WIDTH-1:0]        S_AXI_CTRL_AWADDR                          ,
    input  wire [2:0]                       S_AXI_CTRL_AWPROT                          ,
    input  wire                             S_AXI_CTRL_AWVALID                         ,
    output wire                             S_AXI_CTRL_AWREADY                         ,
    input  wire [31:0]                      S_AXI_CTRL_WDATA                           ,
    input  wire [3:0]                       S_AXI_CTRL_WSTRB                           ,
    input  wire                             S_AXI_CTRL_WVALID                         ,
    output wire                             S_AXI_CTRL_WREADY                         ,
    output wire [1:0]                       S_AXI_CTRL_BRESP                          ,
    output reg                              S_AXI_CTRL_BVALID                         ,
    input  wire                             S_AXI_CTRL_BREADY                         ,
    input  wire [AXI_ADDR_WIDTH-1:0]        S_AXI_CTRL_ARADDR                          ,
    input  wire [2:0]                       S_AXI_CTRL_ARPROT                          ,
    input  wire                             S_AXI_CTRL_ARVALID                         ,
    output wire                             S_AXI_CTRL_ARREADY                         ,
    output reg  [31:0]                      S_AXI_CTRL_RDATA                           ,
    output wire [1:0]                       S_AXI_CTRL_RRESP                          ,
    output reg                              S_AXI_CTRL_RVALID                         ,
    input  wire                             S_AXI_CTRL_RREADY
);

localparam [1:0]                         AXI_OKAY                    = 2'b00             ;
localparam [AXI_ADDR_WIDTH-1:0]          MIG_STA_OFFSET             = 0                 ;

reg                                      aw_pending                                     ;
reg                                      w_pending                                      ;

wire                                     aw_accept                                      ;
wire                                     w_accept                                       ;
wire                                     wr_access                                      ;
wire                                     rd_access                                      ;
wire                                     reg_0000h_rd                                   ;
wire [31:0]                              reg_0000h                                      ;
wire [31:0]                              io_rdata                                       ;

//////////////////////////////////////////////////
//1. AXI4-Lite Protocol
//////////////////////////////////////////////////

assign S_AXI_CTRL_AWREADY = ~aw_pending & ~S_AXI_CTRL_BVALID;
assign S_AXI_CTRL_WREADY  = ~w_pending  & ~S_AXI_CTRL_BVALID;
assign S_AXI_CTRL_BRESP   = AXI_OKAY;
assign S_AXI_CTRL_ARREADY = ~S_AXI_CTRL_RVALID;
assign S_AXI_CTRL_RRESP   = AXI_OKAY;

assign aw_accept = S_AXI_CTRL_AWVALID & S_AXI_CTRL_AWREADY;
assign w_accept  = S_AXI_CTRL_WVALID  & S_AXI_CTRL_WREADY;
assign wr_access = ~S_AXI_CTRL_BVALID
                 & (aw_pending | aw_accept)
                 & (w_pending  | w_accept);
assign rd_access = S_AXI_CTRL_ARVALID & S_AXI_CTRL_ARREADY;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        aw_pending <= #UDLY 1'b0;
    else if(wr_access)
        aw_pending <= #UDLY 1'b0;
    else if(aw_accept)
        aw_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        w_pending <= #UDLY 1'b0;
    else if(wr_access)
        w_pending <= #UDLY 1'b0;
    else if(w_accept)
        w_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_CTRL_BVALID <= #UDLY 1'b0;
    else if(wr_access)
        S_AXI_CTRL_BVALID <= #UDLY 1'b1;
    else if(S_AXI_CTRL_BVALID & S_AXI_CTRL_BREADY)
        S_AXI_CTRL_BVALID <= #UDLY 1'b0;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        S_AXI_CTRL_RDATA  <= #UDLY 32'd0;
        S_AXI_CTRL_RVALID <= #UDLY 1'b0;
    end
    else if(rd_access) begin
        S_AXI_CTRL_RDATA  <= #UDLY io_rdata;
        S_AXI_CTRL_RVALID <= #UDLY 1'b1;
    end
    else if(S_AXI_CTRL_RVALID & S_AXI_CTRL_RREADY) begin
        S_AXI_CTRL_RVALID <= #UDLY 1'b0;
    end
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////

assign reg_0000h_rd = rd_access
                    & (S_AXI_CTRL_ARADDR[1:0] == 2'b00)
                    & (S_AXI_CTRL_ARADDR == MIG_STA_OFFSET);

//////////////////////////////////////////////////
//3. Register Encode
//////////////////////////////////////////////////

assign reg_0000h = {
    29'd0                      ,
    MIG_READY                  ,
    UI_RST_ACTIVE_SYNC         ,
    INIT_CALIB_COMPLETE_SYNC
};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h);

endmodule
