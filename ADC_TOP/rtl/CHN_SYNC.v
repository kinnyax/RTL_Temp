`timescale 1ns / 1ps

// =====
// 1. Channel CDC
// =====
module CHN_SYNC(
    input  wire                             adc_clk                                     ,
    input  wire                             adc_rst_n                                   ,
    input  wire                             afe_clk                                     ,
    input  wire                             afe_rst_n                                   ,
    input  wire                             jesd_clk                                    ,
    input  wire                             jesd_rst_n                                  ,
    input  wire                             en_adc                                      ,
    input  wire [1:0]                       jesd_state                                  ,
    input  wire                             link_ready                                  ,
    input  wire [1:0]                       lane_ready                                  ,
    input  wire [1:0]                       byte_aligned                                ,
    input  wire [1:0]                       comma_detected                              ,
    input  wire                             pll_lock                                    ,
    input  wire                             rx_reset_done                               ,
    input  wire                             link_error_evt                              ,
    input  wire                             sysref_error_evt                            ,
    input  wire                             sysref_seen_evt                             ,
    input  wire [1:0]                       disparity_evt                               ,
    input  wire [1:0]                       notintable_evt                              ,
    input  wire                             fifo_full_afe                               ,
    input  wire                             data_drop_evt_afe                           ,
    input  wire                             ddc_admit_ok_afe                            ,
    output wire                             en_afe                                      ,
    output wire                             en_jesd                                     ,
    output wire                             link_ready_afe                              ,
    output wire [1:0]                       jesd_state_adc                              ,
    output wire                             link_ready_adc                              ,
    output wire [1:0]                       lane_ready_adc                              ,
    output wire [1:0]                       byte_aligned_adc                            ,
    output wire [1:0]                       comma_detected_adc                          ,
    output wire                             pll_lock_adc                                ,
    output wire                             rx_reset_done_adc                           ,
    output wire                             link_error_evt_adc                          ,
    output wire                             sysref_seen_evt_adc                         ,
    output wire [1:0]                       disparity_evt_adc                           ,
    output wire [1:0]                       notintable_evt_adc                          ,
    output wire                             fifo_full_adc                               ,
    output wire                             data_drop_evt_adc                           ,
    output wire                             ddc_admit_ok_adc
);

wire                                        link_error_evt_adc_jesd                      ;
wire                                        sysref_error_evt_adc_afe                     ;

assign link_error_evt_adc = link_error_evt_adc_jesd | sysref_error_evt_adc_afe;

level_sync en_to_afe(.clk(afe_clk), .rst_n(afe_rst_n), .in(en_adc), .out(en_afe));
level_sync en_to_jesd(.clk(jesd_clk), .rst_n(jesd_rst_n), .in(en_adc), .out(en_jesd));
level_sync link_ready_to_afe(.clk(afe_clk), .rst_n(afe_rst_n), .in(link_ready), .out(link_ready_afe));

levels_sync #(.DS(2)) jesd_state_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(jesd_state), .out(jesd_state_adc));
level_sync link_ready_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(link_ready), .out(link_ready_adc));
levels_sync #(.DS(2)) lane_ready_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(lane_ready), .out(lane_ready_adc));
levels_sync #(.DS(2)) byte_aligned_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(byte_aligned), .out(byte_aligned_adc));
levels_sync #(.DS(2)) comma_detected_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(comma_detected), .out(comma_detected_adc));
level_sync pll_lock_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(pll_lock), .out(pll_lock_adc));
level_sync rx_reset_done_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(rx_reset_done), .out(rx_reset_done_adc));
level_sync fifo_full_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(fifo_full_afe), .out(fifo_full_adc));
level_sync ddc_admit_ok_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(ddc_admit_ok_afe), .out(ddc_admit_ok_adc));

pulse_sync2 link_error_to_adc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(link_error_evt), .out(link_error_evt_adc_jesd));
pulse_sync2 sysref_error_to_adc(.clka(afe_clk), .clkb(adc_clk), .rst_n_a(afe_rst_n), .rst_n_b(adc_rst_n), .in(sysref_error_evt), .out(sysref_error_evt_adc_afe));
pulse_sync2 sysref_seen_to_adc(.clka(afe_clk), .clkb(adc_clk), .rst_n_a(afe_rst_n), .rst_n_b(adc_rst_n), .in(sysref_seen_evt), .out(sysref_seen_evt_adc));
pulse_sync2 disparity0_to_adc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(disparity_evt[0]), .out(disparity_evt_adc[0]));
pulse_sync2 disparity1_to_adc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(disparity_evt[1]), .out(disparity_evt_adc[1]));
pulse_sync2 notintable0_to_adc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(notintable_evt[0]), .out(notintable_evt_adc[0]));
pulse_sync2 notintable1_to_adc(.clka(jesd_clk), .clkb(adc_clk), .rst_n_a(jesd_rst_n), .rst_n_b(adc_rst_n), .in(notintable_evt[1]), .out(notintable_evt_adc[1]));
pulse_sync2 data_drop_to_adc(.clka(afe_clk), .clkb(adc_clk), .rst_n_a(afe_rst_n), .rst_n_b(adc_rst_n), .in(data_drop_evt_afe), .out(data_drop_evt_adc));

endmodule

