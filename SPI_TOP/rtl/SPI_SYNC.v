`timescale 1ns / 1ps

module SPI_SYNC(
    input                                   sys_clk                                        ,
    input                                   spi_clk                                        ,
    input                                   rst_n                                          ,

    input                                   spi_busy                                       ,
    output    wire                          spi_busy_sync                                  ,
    input                                   tx_fifo_empty                                  ,
    output    wire                          tx_fifo_empty_sync                             ,
    input                                   rx_fifo_full                                   ,
    output    wire                          rx_fifo_full_sync                              ,
    input                                   tx_fifo_uf                                     ,
    output    reg                           tx_fifo_uf_sync                                ,
    input                                   rx_fifo_of                                     ,
    output    reg                           rx_fifo_of_sync
);

parameter                                   UDLY                     = 1                   ;

wire                                        tx_fifo_uf_req_sync                            ;
wire                                        tx_fifo_uf_ack_sync                            ;
wire                                        rx_fifo_of_req_sync                            ;
wire                                        rx_fifo_of_ack_sync                            ;

reg                                         tx_fifo_uf_req                                 ;
reg                                         tx_fifo_uf_queued                              ;
reg                                         tx_fifo_uf_req_r                               ;
reg                                         rx_fifo_of_req                                 ;
reg                                         rx_fifo_of_queued                              ;
reg                                         rx_fifo_of_req_r                               ;

//////////////////////////////////////////////////
//1. Status Level CDC
//////////////////////////////////////////////////
level_sync #(.RV(1'd0)) spi_busy_level_sync(.clk(sys_clk), .rst_n(rst_n), .in(spi_busy), .out(spi_busy_sync));
level_sync #(.RV(1'd1)) tx_fifo_empty_level_sync(.clk(sys_clk), .rst_n(rst_n), .in(tx_fifo_empty), .out(tx_fifo_empty_sync));
level_sync #(.RV(1'd0)) rx_fifo_full_level_sync(.clk(sys_clk), .rst_n(rst_n), .in(rx_fifo_full), .out(rx_fifo_full_sync));

//////////////////////////////////////////////////
//2. TX Underflow Event CDC
//////////////////////////////////////////////////
level_sync #(.RV(1'd0)) tx_fifo_uf_req_level_sync(.clk(sys_clk), .rst_n(rst_n), .in(tx_fifo_uf_req), .out(tx_fifo_uf_req_sync));
level_sync #(.RV(1'd0)) tx_fifo_uf_ack_level_sync(.clk(spi_clk), .rst_n(rst_n), .in(tx_fifo_uf_req_sync), .out(tx_fifo_uf_ack_sync));

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n) begin
        tx_fifo_uf_req    <= #UDLY 1'd0;
        tx_fifo_uf_queued <= #UDLY 1'd0;
    end
    else begin
        if(tx_fifo_uf_req & tx_fifo_uf_ack_sync)
            tx_fifo_uf_req <= #UDLY 1'd0;
        else if(~tx_fifo_uf_req & ~tx_fifo_uf_ack_sync & (tx_fifo_uf_queued | tx_fifo_uf))
            tx_fifo_uf_req <= #UDLY 1'd1;

        if(tx_fifo_uf & (tx_fifo_uf_req | tx_fifo_uf_ack_sync))
            tx_fifo_uf_queued <= #UDLY 1'd1;
        else if(~tx_fifo_uf_req & ~tx_fifo_uf_ack_sync & tx_fifo_uf_queued)
            tx_fifo_uf_queued <= #UDLY 1'd0;
    end
end

always @(posedge sys_clk or negedge rst_n) begin
    if(~rst_n) begin
        tx_fifo_uf_req_r <= #UDLY 1'd0;
        tx_fifo_uf_sync  <= #UDLY 1'd0;
    end
    else begin
        tx_fifo_uf_req_r <= #UDLY tx_fifo_uf_req_sync;
        tx_fifo_uf_sync  <= #UDLY tx_fifo_uf_req_sync & ~tx_fifo_uf_req_r;
    end
end

//////////////////////////////////////////////////
//3. RX Overflow Event CDC
//////////////////////////////////////////////////
level_sync #(.RV(1'd0)) rx_fifo_of_req_level_sync(.clk(sys_clk), .rst_n(rst_n), .in(rx_fifo_of_req), .out(rx_fifo_of_req_sync));
level_sync #(.RV(1'd0)) rx_fifo_of_ack_level_sync(.clk(spi_clk), .rst_n(rst_n), .in(rx_fifo_of_req_sync), .out(rx_fifo_of_ack_sync));

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n) begin
        rx_fifo_of_req    <= #UDLY 1'd0;
        rx_fifo_of_queued <= #UDLY 1'd0;
    end
    else begin
        if(rx_fifo_of_req & rx_fifo_of_ack_sync)
            rx_fifo_of_req <= #UDLY 1'd0;
        else if(~rx_fifo_of_req & ~rx_fifo_of_ack_sync & (rx_fifo_of_queued | rx_fifo_of))
            rx_fifo_of_req <= #UDLY 1'd1;

        if(rx_fifo_of & (rx_fifo_of_req | rx_fifo_of_ack_sync))
            rx_fifo_of_queued <= #UDLY 1'd1;
        else if(~rx_fifo_of_req & ~rx_fifo_of_ack_sync & rx_fifo_of_queued)
            rx_fifo_of_queued <= #UDLY 1'd0;
    end
end

always @(posedge sys_clk or negedge rst_n) begin
    if(~rst_n) begin
        rx_fifo_of_req_r <= #UDLY 1'd0;
        rx_fifo_of_sync  <= #UDLY 1'd0;
    end
    else begin
        rx_fifo_of_req_r <= #UDLY rx_fifo_of_req_sync;
        rx_fifo_of_sync  <= #UDLY rx_fifo_of_req_sync & ~rx_fifo_of_req_r;
    end
end

endmodule
