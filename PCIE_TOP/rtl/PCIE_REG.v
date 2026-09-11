`timescale 1ns / 1ps

module PCIE_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [ 9:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    reg                           s_axi_awready                                  ,

    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    reg                           s_axi_wready                                   ,

    output    reg       [ 1:0]              s_axi_bresp                                    ,
    output    reg                           s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,

    input               [ 9:0]              s_axi_araddr                                   ,
    input                                   s_axi_arvalid                                  ,
    output    reg                           s_axi_arready                                  ,

    output    reg       [31:0]              s_axi_rdata                                    ,
    output    reg       [ 1:0]              s_axi_rresp                                    ,
    output    reg                           s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    input                                   user_lnk_up                                    ,
    input                                   fifo_full                                      ,
    input                                   fifo_empty                                     ,
    input                                   fifo_busy                                      ,
    input                                   fifo_of                                        ,
    input                                   fifo_uf                                        ,
    output    reg       [31:0]              pcie_ctl
);

wire                    [31:0]              io_rdata                                       ;
wire                                        wr_access                                      ;
wire                                        wr_addr                                        ;
wire                                        wr_data                                        ;
wire                                        wr_done                                        ;
wire                                        w_ready                                        ;
wire                                        rd_access                                      ;
wire                                        ar_idle                                        ;
wire                                        reg_0004h_wr                                   ;
wire                                        reg_0008h_wr                                   ;
wire                                        reg_0000h_rd                                   ;
wire                                        reg_0004h_rd                                   ;
wire                                        reg_0008h_rd                                   ;
wire                    [31:0]              reg_0000h                                      ;
wire                    [31:0]              reg_0004h                                      ;
wire                    [31:0]              reg_0008h                                      ;

reg                     [ 9:0]              axi_awaddr_r                                   ;
reg                     [ 9:0]              axi_araddr_r                                   ;
reg                                         aw_busy                                        ;
reg                                         wait_data                                      ;
reg                                         fifo_of_pending                                ;
reg                                         fifo_uf_pending                                ;

//////////////////////////////////////////////////
//1. AXI Protocol
//////////////////////////////////////////////////
assign wr_access = s_axi_wready & s_axi_wvalid;
assign wr_addr   = ~s_axi_awready & s_axi_awvalid & ~aw_busy;
assign wr_data   = wr_access & ~s_axi_bvalid;
assign wr_done   = s_axi_bready & s_axi_bvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_awready <= 1'd0;
        aw_busy       <= 1'd0;
    end
    else if(wr_addr) begin
        s_axi_awready <= 1'd1;
        aw_busy       <= 1'd1;
    end
    else if(wr_done) begin
        s_axi_awready <= 1'd0;
        aw_busy       <= 1'd0;
    end
    else
        s_axi_awready <= 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        axi_awaddr_r <= 10'd0;
    else if(wr_addr)
        axi_awaddr_r <= s_axi_awaddr;
end

assign w_ready = ~s_axi_wready & s_axi_wvalid & (wait_data | wr_addr);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_wready <= 1'd0;
        wait_data    <= 1'd0;
    end
    else if(w_ready) begin
        s_axi_wready <= 1'd1;
        wait_data    <= 1'd0;
    end
    else if(wr_addr) begin
        wait_data <= 1'd1;
    end
    else begin
        s_axi_wready <= 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_bvalid <= 1'd0;
        s_axi_bresp  <= 2'd0;
    end
    else if(wr_data) begin
        s_axi_bvalid <= 1'd1;
        s_axi_bresp  <= 2'd0;
    end
    else if(wr_done)
        s_axi_bvalid <= 1'd0;
end

assign ar_idle   = ~s_axi_rvalid | (s_axi_rvalid & s_axi_rready);
assign rd_access = s_axi_arready & s_axi_arvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_arready <= 1'd0;
        axi_araddr_r  <= 10'd0;
    end
    else if(~s_axi_arready & s_axi_arvalid & ar_idle) begin
        s_axi_arready <= 1'd1;
        axi_araddr_r  <= s_axi_araddr;
    end
    else
        s_axi_arready <= 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_rvalid <= 1'd0;
        s_axi_rdata  <= 32'd0;
        s_axi_rresp  <= 2'd0;
    end
    else if(rd_access) begin
        s_axi_rvalid <= 1'd1;
        s_axi_rdata  <= io_rdata;
        s_axi_rresp  <= 2'd0;
    end
    else if(s_axi_rready & s_axi_rvalid)
        s_axi_rvalid <= 1'd0;
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////
assign reg_0004h_wr = (axi_awaddr_r == 10'h004) & wr_access;
assign reg_0008h_wr = (axi_awaddr_r == 10'h008) & wr_access;

assign reg_0000h_rd = (axi_araddr_r == 10'h000) & rd_access;
assign reg_0004h_rd = (axi_araddr_r == 10'h004) & rd_access;
assign reg_0008h_rd = (axi_araddr_r == 10'h008) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        pcie_ctl <= 32'd0;
    else if(reg_0004h_wr)
        pcie_ctl <= s_axi_wdata;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        fifo_of_pending <= 1'd0;
    else begin
        if(fifo_of) fifo_of_pending <= 1'd1;
        if(reg_0008h_wr & s_axi_wdata[0]) fifo_of_pending <= 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        fifo_uf_pending <= 1'd0;
    else begin
        if(fifo_uf) fifo_uf_pending <= 1'd1;
        if(reg_0008h_wr & s_axi_wdata[1]) fifo_uf_pending <= 1'd0;
    end
end

assign reg_0000h = {28'd0, fifo_busy, fifo_empty, fifo_full, user_lnk_up};
assign reg_0004h = pcie_ctl;
assign reg_0008h = {30'd0, fifo_uf_pending, fifo_of_pending};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h);

endmodule
