`timescale 1ns / 1ps

module ADC_SYNC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   sysref                                         ,
    output    wire                          sysref_sync                                    ,
    input               [ 7:0]              link_ready                                     ,
    output    wire      [ 7:0]              link_ready_sync                                ,
    input               [ 7:0]              fifo_empty                                     ,
    output    wire      [ 7:0]              fifo_empty_sync                                ,
    input               [ 7:0]              fifo_full                                      ,
    output    wire      [ 7:0]              fifo_full_sync                                 ,
    input               [ 7:0]              afe_idle                                       ,
    output    wire      [ 7:0]              afe_idle_sync                                  ,
    input               [ 7:0]              pll_lock                                       ,
    output    wire      [ 7:0]              pll_lock_sync                                  ,
    input               [ 7:0]              rx_reset_done                                  ,
    output    wire      [ 7:0]              rx_reset_done_sync                             ,
    input               [15:0]              lane_ready                                     ,
    output    wire      [15:0]              lane_ready_sync                                ,
    input               [15:0]              byte_aligned                                   ,
    output    wire      [15:0]              byte_aligned_sync                              ,
    input               [15:0]              comma_detected                                 ,
    output    wire      [15:0]              comma_detected_sync                            ,
    input               [ 7:0]              fifo_overflow                                  ,
    output    wire      [ 7:0]              fifo_overflow_sync                             ,
    input               [ 7:0]              data_error                                     ,
    output    wire      [ 7:0]              data_error_sync                                ,
    input               [ 7:0]              link_error                                     ,
    output    wire      [ 7:0]              link_error_sync                                ,
    input               [ 7:0]              sysref_seen                                    ,
    output    wire      [ 7:0]              sysref_seen_sync                               ,
    input               [15:0]              disparity                                      ,
    output    wire      [15:0]              disparity_sync                                 ,
    input               [15:0]              notintable                                     ,
    output    wire      [15:0]              notintable_sync
);

parameter                                   UDLY                     = 1                   ;

//////////////////////////////////////////////////
//1. Level And Event CDC
//////////////////////////////////////////////////
level_sync sysref_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(sysref),.out(sysref_sync));
levels_sync #(.DS(8),.RV(1'd0)) link_ready_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(link_ready),.out(link_ready_sync));
levels_sync #(.DS(8),.RV(1'd1)) fifo_empty_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(fifo_empty),.out(fifo_empty_sync));
levels_sync #(.DS(8),.RV(1'd0)) fifo_full_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(fifo_full),.out(fifo_full_sync));
levels_sync #(.DS(8),.RV(1'd1)) afe_idle_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(afe_idle),.out(afe_idle_sync));
levels_sync #(.DS(8),.RV(1'd0)) pll_lock_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(pll_lock),.out(pll_lock_sync));
levels_sync #(.DS(8),.RV(1'd0)) rx_reset_done_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(rx_reset_done),.out(rx_reset_done_sync));
levels_sync #(.DS(16),.RV(1'd0)) lane_ready_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(lane_ready),.out(lane_ready_sync));
levels_sync #(.DS(16),.RV(1'd0)) byte_aligned_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(byte_aligned),.out(byte_aligned_sync));
levels_sync #(.DS(16),.RV(1'd0)) comma_detected_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(comma_detected),.out(comma_detected_sync));

pulse_sync link_error0_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[0]),.out(link_error_sync[0]));
pulse_sync link_error1_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[1]),.out(link_error_sync[1]));
pulse_sync link_error2_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[2]),.out(link_error_sync[2]));
pulse_sync link_error3_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[3]),.out(link_error_sync[3]));
pulse_sync link_error4_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[4]),.out(link_error_sync[4]));
pulse_sync link_error5_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[5]),.out(link_error_sync[5]));
pulse_sync link_error6_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[6]),.out(link_error_sync[6]));
pulse_sync link_error7_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(link_error[7]),.out(link_error_sync[7]));

pulse_sync sysref_seen0_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[0]),.out(sysref_seen_sync[0]));
pulse_sync sysref_seen1_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[1]),.out(sysref_seen_sync[1]));
pulse_sync sysref_seen2_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[2]),.out(sysref_seen_sync[2]));
pulse_sync sysref_seen3_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[3]),.out(sysref_seen_sync[3]));
pulse_sync sysref_seen4_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[4]),.out(sysref_seen_sync[4]));
pulse_sync sysref_seen5_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[5]),.out(sysref_seen_sync[5]));
pulse_sync sysref_seen6_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[6]),.out(sysref_seen_sync[6]));
pulse_sync sysref_seen7_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(sysref_seen[7]),.out(sysref_seen_sync[7]));

pulse_sync fifo_overflow0_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[0]),.out(fifo_overflow_sync[0]));
pulse_sync fifo_overflow1_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[1]),.out(fifo_overflow_sync[1]));
pulse_sync fifo_overflow2_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[2]),.out(fifo_overflow_sync[2]));
pulse_sync fifo_overflow3_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[3]),.out(fifo_overflow_sync[3]));
pulse_sync fifo_overflow4_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[4]),.out(fifo_overflow_sync[4]));
pulse_sync fifo_overflow5_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[5]),.out(fifo_overflow_sync[5]));
pulse_sync fifo_overflow6_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[6]),.out(fifo_overflow_sync[6]));
pulse_sync fifo_overflow7_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(fifo_overflow[7]),.out(fifo_overflow_sync[7]));

pulse_sync data_error0_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[0]),.out(data_error_sync[0]));
pulse_sync data_error1_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[1]),.out(data_error_sync[1]));
pulse_sync data_error2_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[2]),.out(data_error_sync[2]));
pulse_sync data_error3_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[3]),.out(data_error_sync[3]));
pulse_sync data_error4_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[4]),.out(data_error_sync[4]));
pulse_sync data_error5_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[5]),.out(data_error_sync[5]));
pulse_sync data_error6_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[6]),.out(data_error_sync[6]));
pulse_sync data_error7_pulse_sync(.clka(afe_clk),.clkb(sys_clk),.rst_n_a(afe_rst_n),.rst_n_b(sys_rst_n),.in(data_error[7]),.out(data_error_sync[7]));

pulse_sync disparity0_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[0]),.out(disparity_sync[0]));
pulse_sync disparity1_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[1]),.out(disparity_sync[1]));
pulse_sync disparity2_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[2]),.out(disparity_sync[2]));
pulse_sync disparity3_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[3]),.out(disparity_sync[3]));
pulse_sync disparity4_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[4]),.out(disparity_sync[4]));
pulse_sync disparity5_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[5]),.out(disparity_sync[5]));
pulse_sync disparity6_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[6]),.out(disparity_sync[6]));
pulse_sync disparity7_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[7]),.out(disparity_sync[7]));
pulse_sync disparity8_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[8]),.out(disparity_sync[8]));
pulse_sync disparity9_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[9]),.out(disparity_sync[9]));
pulse_sync disparity10_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[10]),.out(disparity_sync[10]));
pulse_sync disparity11_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[11]),.out(disparity_sync[11]));
pulse_sync disparity12_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[12]),.out(disparity_sync[12]));
pulse_sync disparity13_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[13]),.out(disparity_sync[13]));
pulse_sync disparity14_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[14]),.out(disparity_sync[14]));
pulse_sync disparity15_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(disparity[15]),.out(disparity_sync[15]));

pulse_sync notintable0_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[0]),.out(notintable_sync[0]));
pulse_sync notintable1_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[1]),.out(notintable_sync[1]));
pulse_sync notintable2_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[2]),.out(notintable_sync[2]));
pulse_sync notintable3_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[3]),.out(notintable_sync[3]));
pulse_sync notintable4_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[4]),.out(notintable_sync[4]));
pulse_sync notintable5_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[5]),.out(notintable_sync[5]));
pulse_sync notintable6_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[6]),.out(notintable_sync[6]));
pulse_sync notintable7_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[7]),.out(notintable_sync[7]));
pulse_sync notintable8_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[8]),.out(notintable_sync[8]));
pulse_sync notintable9_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[9]),.out(notintable_sync[9]));
pulse_sync notintable10_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[10]),.out(notintable_sync[10]));
pulse_sync notintable11_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[11]),.out(notintable_sync[11]));
pulse_sync notintable12_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[12]),.out(notintable_sync[12]));
pulse_sync notintable13_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[13]),.out(notintable_sync[13]));
pulse_sync notintable14_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[14]),.out(notintable_sync[14]));
pulse_sync notintable15_pulse_sync(.clka(adc_clk),.clkb(sys_clk),.rst_n_a(adc_rst_n),.rst_n_b(sys_rst_n),.in(notintable[15]),.out(notintable_sync[15]));

endmodule
