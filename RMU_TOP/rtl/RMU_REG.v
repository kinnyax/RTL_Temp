`timescale 1ns / 1ps

module RMU_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [ 7:0]              s_axi_awaddr                                   ,
    input               [ 2:0]              s_axi_awprot                                   ,
    input                                   s_axi_awvalid                                  ,
    output    reg                           s_axi_awready                                  ,

    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    reg                           s_axi_wready                                   ,

    output    reg       [ 1:0]              s_axi_bresp                                    ,
    output    reg                           s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,

    input               [ 7:0]              s_axi_araddr                                   ,
    input               [ 2:0]              s_axi_arprot                                   ,
    input                                   s_axi_arvalid                                  ,
    output    reg                           s_axi_arready                                  ,

    output    reg       [31:0]              s_axi_rdata                                    ,
    output    reg       [ 1:0]              s_axi_rresp                                    ,
    output    reg                           s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    output    reg       [ 4:0]              rst_enable
);

parameter                                   UDLY                     = 1                   ;

wire                    [31:0]              io_rdata                                       ;
wire                                        wr_access                                      ;
wire                                        wr_addr                                        ;
wire                                        wr_data                                        ;
wire                                        wr_done                                        ;
wire                                        w_ready                                        ;
wire                                        rd_access                                      ;
wire                                        ar_idle                                        ;
wire                                        reg_0000h_wr                                   ;
wire                                        reg_0004h_wr                                   ;
wire                                        reg_0008h_wr                                   ;
wire                                        reg_000ch_wr                                   ;
wire                                        reg_0010h_wr                                   ;
wire                                        reg_0000h_rd                                   ;
wire                                        reg_0004h_rd                                   ;
wire                                        reg_0008h_rd                                   ;
wire                                        reg_000ch_rd                                   ;
wire                                        reg_0010h_rd                                   ;
wire                    [31:0]              reg_0000h                                      ;
wire                    [31:0]              reg_0004h                                      ;
wire                    [31:0]              reg_0008h                                      ;
wire                    [31:0]              reg_000ch                                      ;
wire                    [31:0]              reg_0010h                                      ;

reg                     [ 7:0]              axi_awaddr_r                                   ;
reg                     [ 7:0]              axi_araddr_r                                   ;
reg                                         aw_busy                                        ;
reg                                         wait_data                                      ;

//////////////////////////////////////////////////
//1. AXI Protocol
//////////////////////////////////////////////////
assign wr_access = s_axi_wready & s_axi_wvalid;
assign wr_addr   = ~s_axi_awready & s_axi_awvalid & ~aw_busy;
assign wr_data   = wr_access & ~s_axi_bvalid;
assign wr_done   = s_axi_bready & s_axi_bvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_awready <= #UDLY 1'd0;
        aw_busy       <= #UDLY 1'd0;
    end
    else if(wr_addr) begin
        s_axi_awready <= #UDLY 1'd1;
        aw_busy       <= #UDLY 1'd1;
    end
    else if(wr_done) begin
        s_axi_awready <= #UDLY 1'd0;
        aw_busy       <= #UDLY 1'd0;
    end
    else
        s_axi_awready <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        axi_awaddr_r <= #UDLY 8'd0;
    else if(wr_addr)
        axi_awaddr_r <= #UDLY s_axi_awaddr;
end

assign w_ready = ~s_axi_wready & s_axi_wvalid & (wait_data | wr_addr);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_wready <= #UDLY 1'd0;
        wait_data    <= #UDLY 1'd0;
    end
    else if(w_ready) begin
        s_axi_wready <= #UDLY 1'd1;
        wait_data    <= #UDLY 1'd0;
    end
    else if(wr_addr) begin
        wait_data <= #UDLY 1'd1;
    end
    else begin
        s_axi_wready <= #UDLY 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_bvalid <= #UDLY 1'd0;
        s_axi_bresp  <= #UDLY 2'd0;
    end
    else if(wr_data) begin
        s_axi_bvalid <= #UDLY 1'd1;
        s_axi_bresp  <= #UDLY 2'd0;
    end
    else if(wr_done)
        s_axi_bvalid <= #UDLY 1'd0;
end

assign ar_idle   = ~s_axi_rvalid | (s_axi_rvalid & s_axi_rready);
assign rd_access = s_axi_arready & s_axi_arvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_arready <= #UDLY 1'd0;
        axi_araddr_r  <= #UDLY 8'd0;
    end
    else if(~s_axi_arready & s_axi_arvalid & ar_idle) begin
        s_axi_arready <= #UDLY 1'd1;
        axi_araddr_r  <= #UDLY s_axi_araddr;
    end
    else
        s_axi_arready <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_rvalid <= #UDLY 1'd0;
        s_axi_rdata  <= #UDLY 32'd0;
        s_axi_rresp  <= #UDLY 2'd0;
    end
    else if(rd_access) begin
        s_axi_rvalid <= #UDLY 1'd1;
        s_axi_rdata  <= #UDLY io_rdata;
        s_axi_rresp  <= #UDLY 2'd0;
    end
    else if(s_axi_rready & s_axi_rvalid)
        s_axi_rvalid <= #UDLY 1'd0;
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////
assign reg_0000h_wr = (axi_awaddr_r == 8'h00) & wr_access;
assign reg_0004h_wr = (axi_awaddr_r == 8'h04) & wr_access;
assign reg_0008h_wr = (axi_awaddr_r == 8'h08) & wr_access;
assign reg_000ch_wr = (axi_awaddr_r == 8'h0c) & wr_access;
assign reg_0010h_wr = (axi_awaddr_r == 8'h10) & wr_access;

assign reg_0000h_rd = (axi_araddr_r == 8'h00) & rd_access;
assign reg_0004h_rd = (axi_araddr_r == 8'h04) & rd_access;
assign reg_0008h_rd = (axi_araddr_r == 8'h08) & rd_access;
assign reg_000ch_rd = (axi_araddr_r == 8'h0c) & rd_access;
assign reg_0010h_rd = (axi_araddr_r == 8'h10) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        rst_enable <= #UDLY 5'd0;
    else begin
        if(reg_0000h_wr) rst_enable[0] <= #UDLY s_axi_wdata[0];
        if(reg_0004h_wr) rst_enable[1] <= #UDLY s_axi_wdata[0];
        if(reg_0008h_wr) rst_enable[2] <= #UDLY s_axi_wdata[0];
        if(reg_000ch_wr) rst_enable[3] <= #UDLY s_axi_wdata[0];
        if(reg_0010h_wr) rst_enable[4] <= #UDLY s_axi_wdata[0];
    end
end

assign reg_0000h = {31'd0, rst_enable[0]};
assign reg_0004h = {31'd0, rst_enable[1]};
assign reg_0008h = {31'd0, rst_enable[2]};
assign reg_000ch = {31'd0, rst_enable[3]};
assign reg_0010h = {31'd0, rst_enable[4]};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h) |
                  ({32{reg_000ch_rd}} & reg_000ch) |
                  ({32{reg_0010h_rd}} & reg_0010h);

endmodule
