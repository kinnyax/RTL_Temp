`timescale 1ns / 1ps

module CHN_SYNC(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,
    input                                   jesd_clk                                       ,
    input                                   jesd_rst_n                                     ,

    input                                   phy_rx_reset_done                              ,
    output    wire                          phy_rx_reset_done_sync                         ,
    input                                   phy_pll_lock                                   ,
    output    wire                          phy_pll_lock_sync                              ,
    input               [ 1:0]              phy_byte_aligned                               ,
    output    wire      [ 1:0]              phy_byte_align_sync                            ,

    input                                   sysref_error                                   ,
    input                                   sysref_seen                                    ,
    output    wire                          sysref_seen_sync                               ,
    input                                   link_ready                                     ,
    output    wire                          link_ready_sync                                ,
    input               [ 1:0]              lane_ready                                     ,
    output    wire      [ 1:0]              lane_ready_sync                                ,
    input               [ 1:0]              cgs_ready                                      ,
    output    wire      [ 1:0]              cgs_ready_sync                                 ,
    input               [ 1:0]              phy_disparity                                  ,
    output    wire      [ 1:0]              phy_disparity_sync                             ,
    input               [ 1:0]              phy_notintable                                 ,
    output    wire      [ 1:0]              phy_notintable_sync                            ,
    input                                   link_error                                     ,
    output    wire                          link_error_sync                                ,

    input                                   fifo_sta                                       ,
    output    wire                          fifo_sta_sync                                  ,
    input                                   upk_idle                                       ,
    output    wire                          upk_idle_sync                                  ,
    input                                   tgc_idle                                       ,
    output    wire                          tgc_idle_sync
);

/* verilator lint_off UNUSEDPARAM */
parameter                                   UDLY                     = 1                   ;
/* verilator lint_on UNUSEDPARAM */

wire                                        sysref_error_sync                              ;
wire                                        jesd_link_error_sync                           ;

// JESD and AFE status levels converge in ADC for status and packet admission.
level_sync rx_reset_done_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(phy_rx_reset_done), .out(phy_rx_reset_done_sync));
level_sync pll_lock_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(phy_pll_lock), .out(phy_pll_lock_sync));
levels_sync #(.DS(2)) byte_aligned_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(phy_byte_aligned), .out(phy_byte_align_sync));
level_sync link_ready_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(link_ready), .out(link_ready_sync));
levels_sync #(.DS(2)) lane_ready_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(lane_ready), .out(lane_ready_sync));
levels_sync #(.DS(2)) cgs_ready_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(cgs_ready), .out(cgs_ready_sync));
level_sync fifo_sta_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(fifo_sta), .out(fifo_sta_sync));

// Quiescence is safe on reset, so idle synchronizers reset high.
level_sync #(.RV(1'b1)) upk_idle_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(upk_idle), .out(upk_idle_sync));
level_sync #(.RV(1'b1)) tgc_idle_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(tgc_idle), .out(tgc_idle_sync));

// Occurrence signals retain event semantics across their single CDC hop.
pulse_sync2 sysref_seen_cdc(.clka(afe_clk), .clkb(adc_clk), .rst_n_a(afe_rst_n), .rst_n_b(adc_rst_n), .in(sysref_seen), .out(sysref_seen_sync));
pulse_sync2 sysref_error_cdc(.clka(afe_clk), .clkb(adc_clk), .rst_n_a(afe_rst_n), .rst_n_b(adc_rst_n), .in(sysref_error), .out(sysref_error_sync));
pulse_sync2 disparity0_cdc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(phy_disparity[0]), .out(phy_disparity_sync[0]));
pulse_sync2 disparity1_cdc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(phy_disparity[1]), .out(phy_disparity_sync[1]));
pulse_sync2 notintable0_cdc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(phy_notintable[0]), .out(phy_notintable_sync[0]));
pulse_sync2 notintable1_cdc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(phy_notintable[1]), .out(phy_notintable_sync[1]));
pulse_sync2 link_error_cdc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(link_error), .out(jesd_link_error_sync));

assign link_error_sync = sysref_error_sync | jesd_link_error_sync;

endmodule
