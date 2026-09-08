`timescale 1ns / 1ps

module DMA_SYNC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   dma_clk                                        ,
    input                                   dma_rst_n                                      ,

    input               [ 7:0]              chn_busy                                       ,
    output    wire      [ 7:0]              chn_busy_sync                                  ,
    input               [ 7:0]              fifo_empty                                     ,
    output    wire      [ 7:0]              fifo_empty_sync                                ,
    input               [ 7:0]              fifo_full                                      ,
    output    wire      [ 7:0]              fifo_full_sync                                 ,
    input               [ 7:0]              half_trans                                     ,
    output    wire      [ 7:0]              half_trans_sync                                ,
    input               [ 7:0]              trans_comp                                     ,
    output    wire      [ 7:0]              trans_comp_sync                                ,
    input               [ 7:0]              axi_error                                      ,
    output    wire      [ 7:0]              axi_error_sync
);

parameter                                   UDLY                     = 1                   ;

//////////////////////////////////////////////////
//1. Level Synchronization
//////////////////////////////////////////////////
levels_sync #(.DS(8), .RV(1'd0)) chn_busy_levels_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(chn_busy), .out(chn_busy_sync));
levels_sync #(.DS(8), .RV(1'd0)) fifo_empty_levels_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_empty), .out(fifo_empty_sync));
levels_sync #(.DS(8), .RV(1'd0)) fifo_full_levels_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_full), .out(fifo_full_sync));

//////////////////////////////////////////////////
//2. Event Synchronization
//////////////////////////////////////////////////
pulse_sync half_trans0_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[0]), .out(half_trans_sync[0]));
pulse_sync half_trans1_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[1]), .out(half_trans_sync[1]));
pulse_sync half_trans2_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[2]), .out(half_trans_sync[2]));
pulse_sync half_trans3_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[3]), .out(half_trans_sync[3]));
pulse_sync half_trans4_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[4]), .out(half_trans_sync[4]));
pulse_sync half_trans5_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[5]), .out(half_trans_sync[5]));
pulse_sync half_trans6_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[6]), .out(half_trans_sync[6]));
pulse_sync half_trans7_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(half_trans[7]), .out(half_trans_sync[7]));
pulse_sync trans_comp0_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[0]), .out(trans_comp_sync[0]));
pulse_sync trans_comp1_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[1]), .out(trans_comp_sync[1]));
pulse_sync trans_comp2_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[2]), .out(trans_comp_sync[2]));
pulse_sync trans_comp3_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[3]), .out(trans_comp_sync[3]));
pulse_sync trans_comp4_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[4]), .out(trans_comp_sync[4]));
pulse_sync trans_comp5_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[5]), .out(trans_comp_sync[5]));
pulse_sync trans_comp6_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[6]), .out(trans_comp_sync[6]));
pulse_sync trans_comp7_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(trans_comp[7]), .out(trans_comp_sync[7]));
pulse_sync axi_error0_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[0]), .out(axi_error_sync[0]));
pulse_sync axi_error1_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[1]), .out(axi_error_sync[1]));
pulse_sync axi_error2_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[2]), .out(axi_error_sync[2]));
pulse_sync axi_error3_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[3]), .out(axi_error_sync[3]));
pulse_sync axi_error4_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[4]), .out(axi_error_sync[4]));
pulse_sync axi_error5_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[5]), .out(axi_error_sync[5]));
pulse_sync axi_error6_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[6]), .out(axi_error_sync[6]));
pulse_sync axi_error7_pulse_sync(.clka(dma_clk), .clkb(sys_clk), .rst_n_a(dma_rst_n), .rst_n_b(sys_rst_n), .in(axi_error[7]), .out(axi_error_sync[7]));

endmodule
