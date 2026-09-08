`timescale 1ns / 1ps

module ASU_TXD(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input                                   rxd_req                                        ,
    input                                   rxd_write                                      ,
    input               [31:0]              rxd_addr                                       ,
    input               [31:0]              rxd_wdata                                      ,
    output    reg                           txd_rdy                                        ,
    output    reg                           txd_timeout                                    ,
    output    reg       [31:0]              txd_rdata                                      ,

    output    reg       [31:0]              m_axi_awaddr                                   ,
    output    wire      [ 2:0]              m_axi_awprot                                   ,
    output    reg                           m_axi_awvalid                                  ,
    input                                   m_axi_awready                                  ,
    output    reg       [31:0]              m_axi_wdata                                    ,
    output    wire      [ 3:0]              m_axi_wstrb                                    ,
    output    reg                           m_axi_wvalid                                   ,
    input                                   m_axi_wready                                   ,
    input               [ 1:0]              m_axi_bresp                                    ,
    input                                   m_axi_bvalid                                   ,
    output    wire                          m_axi_bready                                   ,

    output    reg       [31:0]              m_axi_araddr                                   ,
    output    wire      [ 2:0]              m_axi_arprot                                   ,
    output    reg                           m_axi_arvalid                                  ,
    input                                   m_axi_arready                                  ,
    input               [31:0]              m_axi_rdata                                    ,
    input               [ 1:0]              m_axi_rresp                                    ,
    input                                   m_axi_rvalid                                   ,
    output    wire                          m_axi_rready
);

parameter                                   UDLY                     = 1                   ;
parameter integer                           TIMEOUT_MAX              = 4095                ;

wire                                        txd_start                                      ;
wire                                        txd_handshake                                  ;
wire                                        aw_handshake                                   ;
wire                                        w_handshake                                    ;
wire                                        b_handshake                                    ;
wire                                        ar_handshake                                   ;
wire                                        r_handshake                                    ;
wire                                        transaction_end                                ;
wire                                        timeout_end                                    ;
wire                                        txd_end                                        ;

reg                                         txd_run                                        ;
reg                     [31:0]              timeout_cnt                                    ;

//////////////////////////////////////////////////
//1. Request And Completion Handshake
//////////////////////////////////////////////////
assign txd_start     = rxd_req & ~txd_run & ~txd_rdy;
assign txd_handshake = rxd_req & txd_rdy;

//////////////////////////////////////////////////
//2. AXI Write Path
//////////////////////////////////////////////////
assign m_axi_awprot = 3'b000;
assign m_axi_wstrb  = 4'b1111;
assign m_axi_bready = txd_run & rxd_write & ~m_axi_awvalid & ~m_axi_wvalid;

assign aw_handshake = m_axi_awvalid & m_axi_awready;
assign w_handshake  = m_axi_wvalid & m_axi_wready;
assign b_handshake  = m_axi_bvalid & m_axi_bready;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        m_axi_awaddr <= #UDLY 32'd0;
        m_axi_awvalid <= #UDLY 1'd0;
    end
    else if(txd_start) begin
        m_axi_awaddr <= #UDLY rxd_addr;
        m_axi_awvalid <= #UDLY rxd_write;
    end
    else if(aw_handshake | txd_end)
        m_axi_awvalid <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        m_axi_wdata <= #UDLY 32'd0;
        m_axi_wvalid <= #UDLY 1'd0;
    end
    else if(txd_start) begin
        m_axi_wdata <= #UDLY rxd_wdata;
        m_axi_wvalid <= #UDLY rxd_write;
    end
    else if(w_handshake | txd_end)
        m_axi_wvalid <= #UDLY 1'd0;
end

//////////////////////////////////////////////////
//3. AXI Read Path
//////////////////////////////////////////////////
assign m_axi_arprot = 3'b000;
assign m_axi_rready = txd_run & ~rxd_write & ~m_axi_arvalid;

assign ar_handshake = m_axi_arvalid & m_axi_arready;
assign r_handshake  = m_axi_rvalid & m_axi_rready;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        m_axi_araddr <= #UDLY 32'd0;
        m_axi_arvalid <= #UDLY 1'd0;
    end
    else if(txd_start) begin
        m_axi_araddr <= #UDLY rxd_addr;
        m_axi_arvalid <= #UDLY ~rxd_write;
    end
    else if(ar_handshake | txd_end)
        m_axi_arvalid <= #UDLY 1'd0;
end

//////////////////////////////////////////////////
//4. Timeout And Result Control
//////////////////////////////////////////////////
assign transaction_end = b_handshake | r_handshake;
assign timeout_end     = txd_run & (timeout_cnt == TIMEOUT_MAX) &
                         ~transaction_end;
assign txd_end         = transaction_end | timeout_end;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        txd_run <= #UDLY 1'd0;
    else if(txd_start)
        txd_run <= #UDLY 1'd1;
    else if(txd_end)
        txd_run <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        timeout_cnt <= #UDLY 32'd0;
    else if(txd_start | txd_end)
        timeout_cnt <= #UDLY 32'd0;
    else if(txd_run)
        timeout_cnt <= #UDLY timeout_cnt + 32'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        txd_rdy <= #UDLY 1'd0;
        txd_timeout <= #UDLY 1'd0;
        txd_rdata <= #UDLY 32'd0;
    end
    else if(txd_end) begin
        txd_rdy <= #UDLY 1'd1;
        txd_timeout <= #UDLY timeout_end;
        txd_rdata <= #UDLY r_handshake ? m_axi_rdata : 32'd0;
    end
    else if(txd_handshake) begin
        txd_rdy <= #UDLY 1'd0;
        txd_timeout <= #UDLY 1'd0;
        txd_rdata <= #UDLY 32'd0;
    end
end

endmodule
