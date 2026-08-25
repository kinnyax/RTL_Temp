`timescale 1ns / 1ps

module ADC_SYNC(
    input  wire        sys_clk              ,
    input  wire        sys_rst_n            ,
    input  wire        adc_clk              ,
    input  wire        adc_rst_n            ,
    input  wire        afe_clk              ,
    input  wire        afe_rst_n            ,
    input  wire        sysref               ,
    input  wire [7:0]  link_ready_adc       ,
    input  wire [7:0]  fifo_empty_adc       ,
    input  wire [7:0]  afe_idle_adc         ,
    input  wire [7:0]  pll_lock_adc         ,
    input  wire [7:0]  rx_reset_done_adc    ,
    input  wire [15:0] lane_ready_adc       ,
    input  wire [15:0] byte_aligned_adc     ,
    input  wire [15:0] comma_detected_adc   ,
    input  wire [7:0]  link_error_evt_adc   ,
    input  wire [7:0]  sysref_seen_evt_adc  ,
    input  wire [15:0] disparity_evt_adc    ,
    input  wire [15:0] notintable_evt_adc   ,
    input  wire [7:0]  fifo_overflow_evt_afe,
    output wire [7:0]  link_ready_sys       ,
    output wire [7:0]  fifo_empty_sys       ,
    output wire [7:0]  fifo_full_sys        ,
    output wire [7:0]  afe_idle_sys         ,
    output wire [7:0]  pll_lock_sys         ,
    output wire [7:0]  rx_reset_done_sys    ,
    output wire [15:0] lane_ready_sys       ,
    output wire [15:0] byte_aligned_sys     ,
    output wire [15:0] comma_detected_sys   ,
    output wire        sysref_level_sys     ,
    output wire [7:0]  fifo_overflow_evt_sys,
    output wire [7:0]  data_error_evt_sys   ,
    output wire [7:0]  link_error_evt_sys   ,
    output wire [7:0]  sysref_seen_evt_sys  ,
    output wire [15:0] disparity_evt_sys    ,
    output wire [15:0] notintable_evt_sys   ,
    input  wire [7:0]  tgc_cmd_evt_sys      ,
    input  wire [15:0] tgc_profile_sys      ,
    input  wire [7:0]  tgc_up_dn_sys        ,
    input  wire [7:0]  tgc_done_evt_afe     ,
    output wire [7:0]  tgc_cmd_evt_afe      ,
    output wire [15:0] tgc_profile_afe      ,
    output wire [7:0]  tgc_up_dn_afe        ,
    output wire [7:0]  tgc_done_evt_sys     ,
    input  wire [7:0]  fifo_full_afe        ,
    input  wire [7:0]  data_error_evt_afe
);

parameter                                   UDLY                        = 1             ;

// Bundled TGC configuration is software-held from command launch until RUN clears.
assign tgc_profile_afe = tgc_profile_sys;
assign tgc_up_dn_afe   = tgc_up_dn_sys;

// Sampled status levels converge independently in SYS; they are not event counters.
levels_sync #(.DS(8)) link_ready_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(link_ready_adc), .out(link_ready_sys));
levels_sync #(.DS(8)) fifo_empty_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_empty_adc), .out(fifo_empty_sys));
levels_sync #(.DS(8)) afe_idle_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(afe_idle_adc), .out(afe_idle_sys));
levels_sync #(.DS(8)) pll_lock_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(pll_lock_adc), .out(pll_lock_sys));
levels_sync #(.DS(8)) rx_reset_done_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(rx_reset_done_adc), .out(rx_reset_done_sys));
levels_sync #(.DS(16)) lane_ready_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(lane_ready_adc), .out(lane_ready_sys));
levels_sync #(.DS(16)) byte_aligned_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(byte_aligned_adc), .out(byte_aligned_sys));
levels_sync #(.DS(16)) comma_detected_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(comma_detected_adc), .out(comma_detected_sys));
levels_sync #(.DS(8)) fifo_full_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(fifo_full_afe), .out(fifo_full_sys));
level_sync sysref_level_cdc(.clk(sys_clk), .rst_n(sys_rst_n), .in(sysref), .out(sysref_level_sys));

// TGC command and completion events each cross exactly once in their owning direction.
pulse_sync2 tgc_cmd0_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[0]), .out(tgc_cmd_evt_afe[0]));
pulse_sync2 tgc_cmd1_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[1]), .out(tgc_cmd_evt_afe[1]));
pulse_sync2 tgc_cmd2_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[2]), .out(tgc_cmd_evt_afe[2]));
pulse_sync2 tgc_cmd3_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[3]), .out(tgc_cmd_evt_afe[3]));
pulse_sync2 tgc_cmd4_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[4]), .out(tgc_cmd_evt_afe[4]));
pulse_sync2 tgc_cmd5_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[5]), .out(tgc_cmd_evt_afe[5]));
pulse_sync2 tgc_cmd6_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[6]), .out(tgc_cmd_evt_afe[6]));
pulse_sync2 tgc_cmd7_cdc(.clka(sys_clk), .clkb(afe_clk), .rst_n_a(sys_rst_n), .rst_n_b(afe_rst_n), .in(tgc_cmd_evt_sys[7]), .out(tgc_cmd_evt_afe[7]));
pulse_sync2 tgc_done0_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[0]), .out(tgc_done_evt_sys[0]));
pulse_sync2 tgc_done1_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[1]), .out(tgc_done_evt_sys[1]));
pulse_sync2 tgc_done2_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[2]), .out(tgc_done_evt_sys[2]));
pulse_sync2 tgc_done3_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[3]), .out(tgc_done_evt_sys[3]));
pulse_sync2 tgc_done4_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[4]), .out(tgc_done_evt_sys[4]));
pulse_sync2 tgc_done5_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[5]), .out(tgc_done_evt_sys[5]));
pulse_sync2 tgc_done6_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[6]), .out(tgc_done_evt_sys[6]));
pulse_sync2 tgc_done7_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(tgc_done_evt_afe[7]), .out(tgc_done_evt_sys[7]));

pulse_sync2 fifo_of0_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[0]), .out(fifo_overflow_evt_sys[0]));
pulse_sync2 fifo_of1_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[1]), .out(fifo_overflow_evt_sys[1]));
pulse_sync2 fifo_of2_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[2]), .out(fifo_overflow_evt_sys[2]));
pulse_sync2 fifo_of3_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[3]), .out(fifo_overflow_evt_sys[3]));
pulse_sync2 fifo_of4_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[4]), .out(fifo_overflow_evt_sys[4]));
pulse_sync2 fifo_of5_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[5]), .out(fifo_overflow_evt_sys[5]));
pulse_sync2 fifo_of6_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[6]), .out(fifo_overflow_evt_sys[6]));
pulse_sync2 fifo_of7_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(fifo_overflow_evt_afe[7]), .out(fifo_overflow_evt_sys[7]));
pulse_sync2 data_error0_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[0]), .out(data_error_evt_sys[0]));
pulse_sync2 data_error1_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[1]), .out(data_error_evt_sys[1]));
pulse_sync2 data_error2_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[2]), .out(data_error_evt_sys[2]));
pulse_sync2 data_error3_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[3]), .out(data_error_evt_sys[3]));
pulse_sync2 data_error4_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[4]), .out(data_error_evt_sys[4]));
pulse_sync2 data_error5_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[5]), .out(data_error_evt_sys[5]));
pulse_sync2 data_error6_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[6]), .out(data_error_evt_sys[6]));
pulse_sync2 data_error7_cdc(.clka(afe_clk), .clkb(sys_clk), .rst_n_a(afe_rst_n), .rst_n_b(sys_rst_n), .in(data_error_evt_afe[7]), .out(data_error_evt_sys[7]));

pulse_sync2 link_error0_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[0]), .out(link_error_evt_sys[0]));
pulse_sync2 link_error1_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[1]), .out(link_error_evt_sys[1]));
pulse_sync2 link_error2_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[2]), .out(link_error_evt_sys[2]));
pulse_sync2 link_error3_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[3]), .out(link_error_evt_sys[3]));
pulse_sync2 link_error4_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[4]), .out(link_error_evt_sys[4]));
pulse_sync2 link_error5_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[5]), .out(link_error_evt_sys[5]));
pulse_sync2 link_error6_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[6]), .out(link_error_evt_sys[6]));
pulse_sync2 link_error7_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(link_error_evt_adc[7]), .out(link_error_evt_sys[7]));

pulse_sync2 sysref_seen0_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[0]), .out(sysref_seen_evt_sys[0]));
pulse_sync2 sysref_seen1_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[1]), .out(sysref_seen_evt_sys[1]));
pulse_sync2 sysref_seen2_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[2]), .out(sysref_seen_evt_sys[2]));
pulse_sync2 sysref_seen3_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[3]), .out(sysref_seen_evt_sys[3]));
pulse_sync2 sysref_seen4_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[4]), .out(sysref_seen_evt_sys[4]));
pulse_sync2 sysref_seen5_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[5]), .out(sysref_seen_evt_sys[5]));
pulse_sync2 sysref_seen6_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[6]), .out(sysref_seen_evt_sys[6]));
pulse_sync2 sysref_seen7_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(sysref_seen_evt_adc[7]), .out(sysref_seen_evt_sys[7]));

pulse_sync2 disparity0_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[0]), .out(disparity_evt_sys[0]));
pulse_sync2 disparity1_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[1]), .out(disparity_evt_sys[1]));
pulse_sync2 disparity2_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[2]), .out(disparity_evt_sys[2]));
pulse_sync2 disparity3_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[3]), .out(disparity_evt_sys[3]));
pulse_sync2 disparity4_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[4]), .out(disparity_evt_sys[4]));
pulse_sync2 disparity5_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[5]), .out(disparity_evt_sys[5]));
pulse_sync2 disparity6_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[6]), .out(disparity_evt_sys[6]));
pulse_sync2 disparity7_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[7]), .out(disparity_evt_sys[7]));
pulse_sync2 disparity8_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[8]), .out(disparity_evt_sys[8]));
pulse_sync2 disparity9_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[9]), .out(disparity_evt_sys[9]));
pulse_sync2 disparity10_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[10]), .out(disparity_evt_sys[10]));
pulse_sync2 disparity11_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[11]), .out(disparity_evt_sys[11]));
pulse_sync2 disparity12_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[12]), .out(disparity_evt_sys[12]));
pulse_sync2 disparity13_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[13]), .out(disparity_evt_sys[13]));
pulse_sync2 disparity14_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[14]), .out(disparity_evt_sys[14]));
pulse_sync2 disparity15_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(disparity_evt_adc[15]), .out(disparity_evt_sys[15]));
pulse_sync2 notintable0_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[0]), .out(notintable_evt_sys[0]));
pulse_sync2 notintable1_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[1]), .out(notintable_evt_sys[1]));
pulse_sync2 notintable2_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[2]), .out(notintable_evt_sys[2]));
pulse_sync2 notintable3_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[3]), .out(notintable_evt_sys[3]));
pulse_sync2 notintable4_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[4]), .out(notintable_evt_sys[4]));
pulse_sync2 notintable5_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[5]), .out(notintable_evt_sys[5]));
pulse_sync2 notintable6_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[6]), .out(notintable_evt_sys[6]));
pulse_sync2 notintable7_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[7]), .out(notintable_evt_sys[7]));
pulse_sync2 notintable8_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[8]), .out(notintable_evt_sys[8]));
pulse_sync2 notintable9_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[9]), .out(notintable_evt_sys[9]));
pulse_sync2 notintable10_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[10]), .out(notintable_evt_sys[10]));
pulse_sync2 notintable11_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[11]), .out(notintable_evt_sys[11]));
pulse_sync2 notintable12_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[12]), .out(notintable_evt_sys[12]));
pulse_sync2 notintable13_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[13]), .out(notintable_evt_sys[13]));
pulse_sync2 notintable14_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[14]), .out(notintable_evt_sys[14]));
pulse_sync2 notintable15_cdc(.clka(adc_clk), .clkb(sys_clk), .rst_n_a(adc_rst_n), .rst_n_b(sys_rst_n), .in(notintable_evt_adc[15]), .out(notintable_evt_sys[15]));

endmodule
