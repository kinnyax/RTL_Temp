`timescale 1ns / 1ps

module SPI_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [31:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    reg                           s_axi_awready                                  ,

    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    reg                           s_axi_wready                                   ,

    output    reg       [ 1:0]              s_axi_bresp                                    ,
    output    reg                           s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,

    input               [31:0]              s_axi_araddr                                   ,
    input                                   s_axi_arvalid                                  ,
    output    reg                           s_axi_arready                                  ,

    output    reg       [31:0]              s_axi_rdata                                    ,
    output    reg       [ 1:0]              s_axi_rresp                                    ,
    output    reg                           s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    output    reg       [31:0]              spi_ctl                                        ,
    output    reg       [31:0]              sck_div                                        ,
    output    reg       [31:0]              cs_cfg                                         ,

    input                                   spi_busy                                       ,
    input                                   tx_fifo_empty                                  ,
    input                                   tx_fifo_full                                   ,
    input                                   tx_fifo_of                                     ,
    input                                   tx_fifo_uf                                     ,
    input                                   rx_fifo_empty                                  ,
    input                                   rx_fifo_full                                   ,
    input                                   rx_fifo_of                                     ,
    input                                   rx_fifo_uf                                     ,

    output    reg       [31:0]              tx_fifo_wdata                                  ,
    output    reg                           tx_fifo_winc                                   ,
    input               [31:0]              rx_fifo_rdata                                  ,
    output    wire                          rx_fifo_rinc
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
wire                                        reg_0010h_wr                                   ;
wire                                        reg_001ch_wr                                   ;
wire                                        reg_0000h_rd                                   ;
wire                                        reg_0004h_rd                                   ;
wire                                        reg_0008h_rd                                   ;
wire                                        reg_0014h_rd                                   ;
wire                                        reg_0018h_rd                                   ;
wire                                        reg_001ch_rd                                   ;
wire                    [31:0]              reg_0000h                                      ;
wire                    [31:0]              reg_0004h                                      ;
wire                    [31:0]              reg_0008h                                      ;
wire                    [31:0]              reg_0014h                                      ;
wire                    [31:0]              reg_0018h                                      ;
wire                    [31:0]              reg_001ch                                      ;

reg                     [31:0]              axi_awaddr_r                                   ;
reg                     [31:0]              axi_araddr_r                                   ;
reg                                         aw_busy                                        ;
reg                                         wait_data                                      ;
reg                                         rdata_pop_pending                              ;
reg                     [ 3:0]              spi_pd                                         ;

integer i;

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
        axi_awaddr_r <= #UDLY 32'd0;
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
        axi_araddr_r  <= #UDLY 32'd0;
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
assign reg_0000h_wr = (axi_awaddr_r == 32'h0000) & wr_access;
assign reg_0004h_wr = (axi_awaddr_r == 32'h0004) & wr_access;
assign reg_0008h_wr = (axi_awaddr_r == 32'h0008) & wr_access;
assign reg_0010h_wr = (axi_awaddr_r == 32'h0010) & wr_access;
assign reg_001ch_wr = (axi_awaddr_r == 32'h001c) & wr_access;

assign reg_0000h_rd = (axi_araddr_r == 32'h0000) & rd_access;
assign reg_0004h_rd = (axi_araddr_r == 32'h0004) & rd_access;
assign reg_0008h_rd = (axi_araddr_r == 32'h0008) & rd_access;
assign reg_0014h_rd = (axi_araddr_r == 32'h0014) & rd_access;
assign reg_0018h_rd = (axi_araddr_r == 32'h0018) & rd_access;
assign reg_001ch_rd = (axi_araddr_r == 32'h001c) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        spi_ctl <= #UDLY 32'h0000_0180;
        sck_div <= #UDLY 32'd0;
        cs_cfg  <= #UDLY 32'd0;
    end
    else begin
        if(reg_0000h_wr) spi_ctl <= #UDLY s_axi_wdata;
        if(reg_0004h_wr) sck_div <= #UDLY s_axi_wdata;
        if(reg_0008h_wr) cs_cfg  <= #UDLY s_axi_wdata;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        tx_fifo_wdata <= #UDLY 32'd0;
        tx_fifo_winc  <= #UDLY 1'd0;
    end
    else if(reg_0010h_wr) begin
        tx_fifo_wdata <= #UDLY s_axi_wdata;
        tx_fifo_winc  <= #UDLY 1'd1;
    end
    else
        tx_fifo_winc <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        spi_pd <= #UDLY 4'd0;
    else begin
        for(i=0;i<4;i=i+1) begin
            if(reg_001ch_wr & s_axi_wdata[i]) spi_pd[i] <= #UDLY 1'd0;
        end
        if(tx_fifo_of) spi_pd[0] <= #UDLY 1'd1;
        if(tx_fifo_uf) spi_pd[1] <= #UDLY 1'd1;
        if(rx_fifo_of) spi_pd[2] <= #UDLY 1'd1;
        if(rx_fifo_uf) spi_pd[3] <= #UDLY 1'd1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        rdata_pop_pending <= #UDLY 1'd0;
    else begin
        if(s_axi_rvalid & s_axi_rready)
            rdata_pop_pending <= #UDLY 1'd0;
        if(reg_0014h_rd)
            rdata_pop_pending <= #UDLY 1'd1;
    end
end

assign rx_fifo_rinc = s_axi_rvalid & s_axi_rready & rdata_pop_pending;

assign reg_0000h = spi_ctl & 32'h0000_07ff;
assign reg_0004h = sck_div & 32'h0000_ffff;
assign reg_0008h = cs_cfg  & 32'h0000_0007;
assign reg_0014h = rx_fifo_rdata;
assign reg_0018h = {27'd0, rx_fifo_full, rx_fifo_empty, tx_fifo_full, tx_fifo_empty, spi_busy};
assign reg_001ch = {28'd0, spi_pd};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h) |
                  ({32{reg_0014h_rd}} & reg_0014h) |
                  ({32{reg_0018h_rd}} & reg_0018h) |
                  ({32{reg_001ch_rd}} & reg_001ch);

endmodule
