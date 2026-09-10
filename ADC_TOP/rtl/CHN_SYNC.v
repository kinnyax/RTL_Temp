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
    input                                   jesd_link_error                                ,
    output    wire                          link_error_sync                                ,

    input                                   rxd_idle                                       ,
    input                                   tgc_sta_idle                                   ,
    input                                   txd_idle                                       ,
    output    reg                           chn_idle
);

wire                                        sysref_error_sync                              ;
wire                                        jesd_link_error_sync                           ;
wire                                        afe_idle_sync                                  ;

reg                                         afe_idle                                       ;

//////////////////////////////////////////////////
//1. JESD And AFE CDC
//////////////////////////////////////////////////
level_sync phy_rx_reset_done_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(phy_rx_reset_done),.out(phy_rx_reset_done_sync));
level_sync phy_pll_lock_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(phy_pll_lock),.out(phy_pll_lock_sync));
levels_sync #(.DS(2),.RV(1'd0)) phy_byte_aligned_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(phy_byte_aligned),.out(phy_byte_align_sync));
level_sync link_ready_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(link_ready),.out(link_ready_sync));
levels_sync #(.DS(2),.RV(1'd0)) lane_ready_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(lane_ready),.out(lane_ready_sync));
levels_sync #(.DS(2),.RV(1'd0)) cgs_ready_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(cgs_ready),.out(cgs_ready_sync));
pulse_sync sysref_error_pulse_sync(.clka(afe_clk),.clkb(adc_clk),.rst_n_a(afe_rst_n),.rst_n_b(adc_rst_n),.in(sysref_error),.out(sysref_error_sync));
pulse_sync sysref_seen_pulse_sync(.clka(afe_clk),.clkb(adc_clk),.rst_n_a(afe_rst_n),.rst_n_b(adc_rst_n),.in(sysref_seen),.out(sysref_seen_sync));
pulse_sync jesd_link_error_pulse_sync(.clka(jesd_clk),.clkb(adc_clk),.rst_n_a(jesd_rst_n),.rst_n_b(adc_rst_n),.in(jesd_link_error),.out(jesd_link_error_sync));
pulse_sync disparity0_pulse_sync(.clka(jesd_clk),.clkb(adc_clk),.rst_n_a(jesd_rst_n),.rst_n_b(adc_rst_n),.in(phy_disparity[0]),.out(phy_disparity_sync[0]));
pulse_sync disparity1_pulse_sync(.clka(jesd_clk),.clkb(adc_clk),.rst_n_a(jesd_rst_n),.rst_n_b(adc_rst_n),.in(phy_disparity[1]),.out(phy_disparity_sync[1]));
pulse_sync notintable0_pulse_sync(.clka(jesd_clk),.clkb(adc_clk),.rst_n_a(jesd_rst_n),.rst_n_b(adc_rst_n),.in(phy_notintable[0]),.out(phy_notintable_sync[0]));
pulse_sync notintable1_pulse_sync(.clka(jesd_clk),.clkb(adc_clk),.rst_n_a(jesd_rst_n),.rst_n_b(adc_rst_n),.in(phy_notintable[1]),.out(phy_notintable_sync[1]));

assign link_error_sync = sysref_error_sync | jesd_link_error_sync;

//////////////////////////////////////////////////
//2. Idle Aggregation
//////////////////////////////////////////////////
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        afe_idle <= 1'd1;
    else
        afe_idle <= rxd_idle & tgc_sta_idle;
end

level_sync #(.RV(1'd1)) afe_idle_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(afe_idle),.out(afe_idle_sync));

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        chn_idle <= 1'd1;
    else
        chn_idle <= afe_idle_sync & txd_idle;
end

endmodule
