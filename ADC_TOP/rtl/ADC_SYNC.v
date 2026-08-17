`timescale 1ns / 1ps

// =====
// 1. System CDC
// =====
module ADC_SYNC(
    input  wire                             sys_clk                                     ,
    input  wire                             sys_rst_n                                   ,
    input  wire                             adc_clk                                     ,
    input  wire                             adc_rst_n                                   ,
    input  wire                             afe_clk                                     ,
    input  wire                             afe_rst_n                                   ,
    input  wire                             sysref                                      ,
    input  wire [7:0]                       afe_en_sys                                  ,
    input  wire                             tgc_req_sys                                 ,
    input  wire [7:0]                       tgc_mask_sys                                ,
    input  wire [1:0]                       tgc_profile_sys                             ,
    input  wire                             tgc_up_dn_sys                               ,
    input  wire                             tgc_slope_sys                               ,
    input  wire [7:0]                       link_ready_adc                              ,
    input  wire [7:0]                       fifo_empty_adc                              ,
    input  wire [7:0]                       fifo_full_adc                               ,
    input  wire [7:0]                       afe_idle_adc                                ,
    input  wire [7:0]                       pll_lock_adc                                ,
    input  wire [7:0]                       rx_reset_done_adc                           ,
    input  wire [15:0]                      lane_ready_adc                              ,
    input  wire [15:0]                      byte_aligned_adc                            ,
    input  wire [15:0]                      comma_detected_adc                          ,
    input  wire [7:0]                       data_drop_evt_adc                           ,
    input  wire [7:0]                       link_error_evt_adc                          ,
    input  wire [7:0]                       sysref_seen_evt_adc                         ,
    input  wire [15:0]                      disparity_evt_adc                           ,
    input  wire [15:0]                      notintable_evt_adc                          ,
    input  wire [7:0]                       fifo_overflow_evt_afe                       ,
    input  wire                             tgc_busy_afe                                ,
    input  wire                             tgc_done_afe                                ,
    output wire [7:0]                       afe_en_adc                                  ,
    output wire                             tgc_req_afe                                 ,
    output wire [7:0]                       tgc_mask_afe                                ,
    output wire [1:0]                       tgc_profile_afe                             ,
    output wire                             tgc_up_dn_afe                               ,
    output wire                             tgc_slope_afe                               ,
    output wire [7:0]                       link_ready_sys                              ,
    output wire [7:0]                       fifo_empty_sys                              ,
    output wire [7:0]                       fifo_full_sys                               ,
    output wire [7:0]                       afe_idle_sys                                ,
    output wire [7:0]                       pll_lock_sys                                ,
    output wire [7:0]                       rx_reset_done_sys                           ,
    output wire [15:0]                      lane_ready_sys                              ,
    output wire [15:0]                      byte_aligned_sys                            ,
    output wire [15:0]                      comma_detected_sys                          ,
    output wire                             sysref_level_sys                            ,
    output wire [7:0]                       fifo_overflow_evt_sys                       ,
    output wire [7:0]                       data_drop_evt_sys                           ,
    output wire [7:0]                       link_error_evt_sys                          ,
    output wire [7:0]                       sysref_seen_evt_sys                         ,
    output wire [15:0]                      disparity_evt_sys                           ,
    output wire [15:0]                      notintable_evt_sys                          ,
    output wire                             tgc_busy_sys                                ,
    output wire                             tgc_done_sys
);

assign tgc_mask_afe    = tgc_mask_sys;
assign tgc_profile_afe = tgc_profile_sys;
assign tgc_up_dn_afe   = tgc_up_dn_sys;
assign tgc_slope_afe   = tgc_slope_sys;

levels_sync #(.DS(8)) afe_enable_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(afe_en_sys), .out(afe_en_adc));
pulse_sync2 tgc_request_to_afe(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_req_sys), .out(tgc_req_afe));
level_sync tgc_busy_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(tgc_busy_afe), .out(tgc_busy_sys));
pulse_sync2 tgc_done_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_afe), .out(tgc_done_sys));
level_sync sysref_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(sysref), .out(sysref_level_sys));

levels_sync #(.DS(8)) link_ready_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(link_ready_adc), .out(link_ready_sys));
levels_sync #(.DS(8)) fifo_empty_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_empty_adc), .out(fifo_empty_sys));
levels_sync #(.DS(8)) fifo_full_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_full_adc), .out(fifo_full_sys));
levels_sync #(.DS(8)) afe_idle_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(afe_idle_adc), .out(afe_idle_sys));
levels_sync #(.DS(8)) pll_lock_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(pll_lock_adc), .out(pll_lock_sys));
levels_sync #(.DS(8)) rx_reset_done_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(rx_reset_done_adc), .out(rx_reset_done_sys));
levels_sync #(.DS(16)) lane_ready_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(lane_ready_adc), .out(lane_ready_sys));
levels_sync #(.DS(16)) byte_aligned_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(byte_aligned_adc), .out(byte_aligned_sys));
levels_sync #(.DS(16)) comma_detected_to_sys(.clk(sys_clk), .rst_n(sys_rst_n), .in(comma_detected_adc), .out(comma_detected_sys));

pulse_sync2 fifo_overflow0_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[0]), .out(fifo_overflow_evt_sys[0]));
pulse_sync2 fifo_overflow1_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[1]), .out(fifo_overflow_evt_sys[1]));
pulse_sync2 fifo_overflow2_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[2]), .out(fifo_overflow_evt_sys[2]));
pulse_sync2 fifo_overflow3_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[3]), .out(fifo_overflow_evt_sys[3]));
pulse_sync2 fifo_overflow4_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[4]), .out(fifo_overflow_evt_sys[4]));
pulse_sync2 fifo_overflow5_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[5]), .out(fifo_overflow_evt_sys[5]));
pulse_sync2 fifo_overflow6_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[6]), .out(fifo_overflow_evt_sys[6]));
pulse_sync2 fifo_overflow7_to_sys(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[7]), .out(fifo_overflow_evt_sys[7]));

pulse_sync2 data_drop0_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[0]), .out(data_drop_evt_sys[0]));
pulse_sync2 data_drop1_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[1]), .out(data_drop_evt_sys[1]));
pulse_sync2 data_drop2_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[2]), .out(data_drop_evt_sys[2]));
pulse_sync2 data_drop3_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[3]), .out(data_drop_evt_sys[3]));
pulse_sync2 data_drop4_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[4]), .out(data_drop_evt_sys[4]));
pulse_sync2 data_drop5_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[5]), .out(data_drop_evt_sys[5]));
pulse_sync2 data_drop6_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[6]), .out(data_drop_evt_sys[6]));
pulse_sync2 data_drop7_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(data_drop_evt_adc[7]), .out(data_drop_evt_sys[7]));
pulse_sync2 link_error0_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[0]), .out(link_error_evt_sys[0]));
pulse_sync2 link_error1_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[1]), .out(link_error_evt_sys[1]));
pulse_sync2 link_error2_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[2]), .out(link_error_evt_sys[2]));
pulse_sync2 link_error3_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[3]), .out(link_error_evt_sys[3]));
pulse_sync2 link_error4_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[4]), .out(link_error_evt_sys[4]));
pulse_sync2 link_error5_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[5]), .out(link_error_evt_sys[5]));
pulse_sync2 link_error6_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[6]), .out(link_error_evt_sys[6]));
pulse_sync2 link_error7_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[7]), .out(link_error_evt_sys[7]));
pulse_sync2 sysref_seen0_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[0]), .out(sysref_seen_evt_sys[0]));
pulse_sync2 sysref_seen1_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[1]), .out(sysref_seen_evt_sys[1]));
pulse_sync2 sysref_seen2_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[2]), .out(sysref_seen_evt_sys[2]));
pulse_sync2 sysref_seen3_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[3]), .out(sysref_seen_evt_sys[3]));
pulse_sync2 sysref_seen4_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[4]), .out(sysref_seen_evt_sys[4]));
pulse_sync2 sysref_seen5_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[5]), .out(sysref_seen_evt_sys[5]));
pulse_sync2 sysref_seen6_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[6]), .out(sysref_seen_evt_sys[6]));
pulse_sync2 sysref_seen7_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[7]), .out(sysref_seen_evt_sys[7]));

pulse_sync2 disparity00_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[0]), .out(disparity_evt_sys[0]));
pulse_sync2 disparity01_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[1]), .out(disparity_evt_sys[1]));
pulse_sync2 disparity02_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[2]), .out(disparity_evt_sys[2]));
pulse_sync2 disparity03_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[3]), .out(disparity_evt_sys[3]));
pulse_sync2 disparity04_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[4]), .out(disparity_evt_sys[4]));
pulse_sync2 disparity05_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[5]), .out(disparity_evt_sys[5]));
pulse_sync2 disparity06_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[6]), .out(disparity_evt_sys[6]));
pulse_sync2 disparity07_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[7]), .out(disparity_evt_sys[7]));
pulse_sync2 disparity08_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[8]), .out(disparity_evt_sys[8]));
pulse_sync2 disparity09_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[9]), .out(disparity_evt_sys[9]));
pulse_sync2 disparity10_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[10]), .out(disparity_evt_sys[10]));
pulse_sync2 disparity11_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[11]), .out(disparity_evt_sys[11]));
pulse_sync2 disparity12_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[12]), .out(disparity_evt_sys[12]));
pulse_sync2 disparity13_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[13]), .out(disparity_evt_sys[13]));
pulse_sync2 disparity14_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[14]), .out(disparity_evt_sys[14]));
pulse_sync2 disparity15_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[15]), .out(disparity_evt_sys[15]));
pulse_sync2 notintable00_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[0]), .out(notintable_evt_sys[0]));
pulse_sync2 notintable01_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[1]), .out(notintable_evt_sys[1]));
pulse_sync2 notintable02_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[2]), .out(notintable_evt_sys[2]));
pulse_sync2 notintable03_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[3]), .out(notintable_evt_sys[3]));
pulse_sync2 notintable04_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[4]), .out(notintable_evt_sys[4]));
pulse_sync2 notintable05_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[5]), .out(notintable_evt_sys[5]));
pulse_sync2 notintable06_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[6]), .out(notintable_evt_sys[6]));
pulse_sync2 notintable07_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[7]), .out(notintable_evt_sys[7]));
pulse_sync2 notintable08_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[8]), .out(notintable_evt_sys[8]));
pulse_sync2 notintable09_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[9]), .out(notintable_evt_sys[9]));
pulse_sync2 notintable10_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[10]), .out(notintable_evt_sys[10]));
pulse_sync2 notintable11_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[11]), .out(notintable_evt_sys[11]));
pulse_sync2 notintable12_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[12]), .out(notintable_evt_sys[12]));
pulse_sync2 notintable13_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[13]), .out(notintable_evt_sys[13]));
pulse_sync2 notintable14_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[14]), .out(notintable_evt_sys[14]));
pulse_sync2 notintable15_to_sys(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[15]), .out(notintable_evt_sys[15]));

endmodule

