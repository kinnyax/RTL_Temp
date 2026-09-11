`timescale 1ns / 1ps

module PCIE_SYNC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   data_clk                                       ,
    input                                   data_rst_n                                     ,
    input                                   axi_aclk                                       ,
    input                                   axi_aresetn                                    ,

    input                                   user_lnk_up                                    ,
    output    wire                          user_lnk_up_sync                               ,
    input                                   fifo_full                                      ,
    output    wire                          fifo_full_sync                                 ,
    input                                   fifo_empty                                     ,
    output    wire                          fifo_empty_sync                                ,
    input                                   wr_rst_busy                                    ,
    output    wire                          wr_rst_busy_sync                               ,
    input                                   rd_rst_busy                                    ,
    output    wire                          rd_rst_busy_sync                               ,
    input                                   fifo_of                                        ,
    output    wire                          fifo_of_sync                                   ,
    input                                   fifo_uf                                        ,
    output    wire                          fifo_uf_sync                                   ,
    output    wire                          fifo_busy
);

//////////////////////////////////////////////////
//1. Status Levels
//////////////////////////////////////////////////
level_sync user_lnk_up_level_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(user_lnk_up), .out(user_lnk_up_sync));
level_sync fifo_full_level_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_full), .out(fifo_full_sync));
level_sync fifo_empty_level_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_empty), .out(fifo_empty_sync));
level_sync wr_rst_busy_level_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(wr_rst_busy), .out(wr_rst_busy_sync));
level_sync rd_rst_busy_level_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(rd_rst_busy), .out(rd_rst_busy_sync));

assign fifo_busy = wr_rst_busy_sync | rd_rst_busy_sync;

//////////////////////////////////////////////////
//2. Status Events
//////////////////////////////////////////////////
pulse_sync fifo_of_pulse_sync(.clka(data_clk), .clkb(sys_clk), .rst_n_a(data_rst_n), .rst_n_b(sys_rst_n), .in(fifo_of), .out(fifo_of_sync));
pulse_sync fifo_uf_pulse_sync(.clka(axi_aclk), .clkb(sys_clk), .rst_n_a(axi_aresetn), .rst_n_b(sys_rst_n), .in(fifo_uf), .out(fifo_uf_sync));

endmodule
