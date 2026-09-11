`timescale 1ns / 1ps

module ASU_TXD(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input                                   rxd_req                                        ,
    input                                   rxd_write                                      ,
    input               [31:0]              rxd_addr                                       ,
    input               [31:0]              rxd_wdata                                      ,
    output    reg                           txd_rdy                                        ,
    output    reg                           txd_busy                                       ,
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

parameter integer                           TIMEOUT_MAX              = 4095                ;

wire                                        txd_start                                      ;
wire                                        txd_handshake                                  ;
wire                                        aw_handshake                                   ;
wire                                        w_handshake                                    ;
wire                                        b_handshake                                    ;
wire                                        ar_handshake                                   ;
wire                                        r_handshake                                    ;
wire                                        rsp_done                                       ;
wire                                        timeout_hit                                    ;
wire                                        req_run                                        ;
wire                                        req_exit                                       ;
wire                                        busy_end                                       ;
wire                                        result_set                                     ;

reg                                         txd_write                                      ;
reg                                         aw_done                                        ;
reg                                         w_done                                         ;
reg                                         ar_done                                        ;
reg                                         timeout_seen                                   ;
reg                     [31:0]              timeout_cnt                                    ;

//////////////////////////////////////////////////
//1. Request And Result Handshake
//////////////////////////////////////////////////
assign txd_start     = rxd_req & ~txd_busy & ~txd_rdy;
assign txd_handshake = rxd_req & txd_rdy;

//////////////////////////////////////////////////
//2. AXI Write Path
//////////////////////////////////////////////////
assign m_axi_awprot = 3'b000;
assign m_axi_wstrb  = 4'b1111;
assign m_axi_bready = txd_busy & txd_write & aw_done & w_done;

assign aw_handshake = m_axi_awvalid & m_axi_awready;
assign w_handshake  = m_axi_wvalid & m_axi_wready;
assign b_handshake  = m_axi_bvalid & m_axi_bready;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        m_axi_awaddr <= 32'd0;
        m_axi_awvalid <= 1'd0;
    end
    else if(txd_start) begin
        m_axi_awaddr <= rxd_addr;
        m_axi_awvalid <= rxd_write;
    end
    else if(aw_handshake | req_exit)
        m_axi_awvalid <= 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        m_axi_wdata <= 32'd0;
        m_axi_wvalid <= 1'd0;
    end
    else if(txd_start) begin
        m_axi_wdata <= rxd_wdata;
        m_axi_wvalid <= rxd_write;
    end
    else if(w_handshake | req_exit)
        m_axi_wvalid <= 1'd0;
end

//////////////////////////////////////////////////
//3. AXI Read Path
//////////////////////////////////////////////////
assign m_axi_arprot = 3'b000;
assign m_axi_rready = txd_busy & ~txd_write & ar_done;

assign ar_handshake = m_axi_arvalid & m_axi_arready;
assign r_handshake  = m_axi_rvalid & m_axi_rready;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        m_axi_araddr <= 32'd0;
        m_axi_arvalid <= 1'd0;
    end
    else if(txd_start) begin
        m_axi_araddr <= rxd_addr;
        m_axi_arvalid <= ~rxd_write;
    end
    else if(ar_handshake | req_exit)
        m_axi_arvalid <= 1'd0;
end

//////////////////////////////////////////////////
//4. AXI Lifecycle And Timeout
//////////////////////////////////////////////////
assign rsp_done    = b_handshake | r_handshake;
assign req_run     = txd_write ? (aw_done | w_done |
                                  aw_handshake | w_handshake) :
                                 (ar_done | ar_handshake);
assign timeout_hit = txd_busy & ~timeout_seen &
                     (timeout_cnt == TIMEOUT_MAX) & ~rsp_done;
assign req_exit    = timeout_hit & ~req_run;
assign busy_end    = rsp_done | req_exit;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        txd_busy <= 1'd0;
        txd_write <= 1'd0;
    end
    else if(txd_start) begin
        txd_busy <= 1'd1;
        txd_write <= rxd_write;
    end
    else if(busy_end)
        txd_busy <= 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        aw_done <= 1'd0;
        w_done <= 1'd0;
    end
    else if(txd_start) begin
        aw_done <= 1'd0;
        w_done <= 1'd0;
    end
    else if(busy_end) begin
        aw_done <= 1'd0;
        w_done <= 1'd0;
    end
    else begin
        if(aw_handshake)
            aw_done <= 1'd1;
        if(w_handshake)
            w_done <= 1'd1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        ar_done <= 1'd0;
    else if(txd_start)
        ar_done <= 1'd0;
    else if(busy_end)
        ar_done <= 1'd0;
    else if(ar_handshake)
        ar_done <= 1'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        timeout_seen <= 1'd0;
        timeout_cnt <= 32'd0;
    end
    else if(txd_start) begin
        timeout_seen <= 1'd0;
        timeout_cnt <= 32'd0;
    end
    else if(timeout_hit) begin
        timeout_seen <= 1'd1;
        timeout_cnt <= 32'd0;
    end
    else if(busy_end) begin
        timeout_seen <= 1'd0;
        timeout_cnt <= 32'd0;
    end
    else if(txd_busy & ~timeout_seen)
        timeout_cnt <= timeout_cnt + 32'd1;
end

//////////////////////////////////////////////////
//5. Held Result
//////////////////////////////////////////////////
assign result_set = timeout_hit | (rsp_done & ~timeout_seen);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        txd_rdy <= 1'd0;
        txd_timeout <= 1'd0;
        txd_rdata <= 32'd0;
    end
    else if(result_set) begin
        txd_rdy <= 1'd1;
        txd_timeout <= timeout_hit;
        txd_rdata <= r_handshake ? m_axi_rdata : 32'd0;
    end
    else if(txd_handshake) begin
        txd_rdy <= 1'd0;
        txd_timeout <= 1'd0;
        txd_rdata <= 32'd0;
    end
end

endmodule
