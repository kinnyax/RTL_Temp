`timescale 1ns / 1ps

module ADC_RXD(
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   chn_en                                         ,
    input               [127:0]             adi_data                                       ,
    input                                   adi_data_vld                                   ,
    input                                   adi_link_qual                                  ,
    input               [31:0]              adc_ctl                                        ,
    input               [31:0]              frm_cfg                                        ,

    output    reg       [511:0]             rx_fifo_wdat                                   ,
    output    wire                          rx_fifo_winc                                   ,
    output    reg                           data_error                                     ,
    output    wire                          rxd_idle
);

localparam                                  RXD_IDLE                 = 2'd0                ;
localparam                                  RXD_SYNC                 = 2'd1                ;
localparam                                  RXD_DATA                 = 2'd2                ;

wire                    [ 1:0]              smp_mode                                       ;
wire                    [ 1:0]              smp_prec                                       ;
wire                                        frame_fmt                                      ;
wire                    [ 5:0]              dec_n                                          ;
wire                    [ 1:0]              dec_f                                          ;
wire                    [ 1:0]              del_mode                                       ;
wire                    [11:0]              prefix_base                                    ;
wire                    [11:0]              delete_beats                                   ;
wire                    [11:0]              prefix_beats                                   ;
wire                    [ 5:0]              valid_beats                                    ;
wire                    [ 9:0]              zero_beats                                     ;
wire                    [ 9:0]              period_beats                                   ;
wire                                        sync_match                                     ;
wire                                        sync_check                                     ;
wire                                        sync_last                                      ;
wire                                        data_region                                    ;
wire                                        region_advance                                 ;
wire                                        region_last                                    ;
wire                                        data_accept                                    ;
wire                                        beat_qual                                      ;
wire                                        rx_discontinuity                               ;
wire                                        sync_error                                     ;
wire                                        data_error_set                                 ;
wire                                        rxd_abort                                      ;
wire                                        rxd_start                                      ;
wire                                        rxd_fsm_idle                                   ;
wire                                        rxd_fsm_sync                                   ;
wire                                        rxd_fsm_data                                   ;
wire                                        rxd_fsm_invalid                                ;
wire                                        pack_last                                      ;

reg                     [ 1:0]              rxd_fsm                                        ;
reg                     [ 1:0]              rxd_fsm_nx                                     ;
reg                     [11:0]              sync_cnt                                       ;
reg                     [ 9:0]              region_cnt                                     ;
reg                     [ 1:0]              pack_cnt                                       ;
reg                     [383:0]             pack_data                                      ;
reg                                         fifo_write_vld                                 ;
reg                     [127:0]             formatted_data                                 ;
reg                     [15:0]              sample_word                                    ;
integer i;

//////////////////////////////////////////////////
//1. Configuration Decode
//////////////////////////////////////////////////
assign smp_mode = (adc_ctl[27:26] == 2'd3) ? 2'd0 : adc_ctl[27:26];
assign smp_prec = (adc_ctl[31:30] == 2'd3) ? 2'd0 : adc_ctl[31:30];
assign frame_fmt = adc_ctl[25];
assign dec_n     = frm_cfg[7:2];
assign dec_f     = frm_cfg[1:0];
assign del_mode  = (frm_cfg[9:8] == 2'd3) ? 2'd0 : frm_cfg[9:8];

assign prefix_base = (dec_f == 2'd0) ? ({6'd0,dec_n} * 12'd2 + 12'd27) :
                     (dec_f == 2'd1) ? ({6'd0,dec_n} * 12'd8 + 12'd29) :
                     (dec_f == 2'd2) ? ({6'd0,dec_n} * 12'd4 + 12'd29) :
                                      ({6'd0,dec_n} * 12'd8 + 12'd33);
assign delete_beats = (del_mode == 2'd1) ?
                      ({6'd0,dec_n} * 12'd16 + {8'd0,dec_f,2'd0}) :
                      (del_mode == 2'd2) ?
                      ({6'd0,dec_n} * 12'd32 + {7'd0,dec_f,3'd0}) : 12'd0;
assign prefix_beats = (smp_mode == 2'd0) ? 12'd20 : prefix_base + delete_beats;

assign valid_beats = (smp_mode == 2'd1) ?
                     ((dec_f == 2'd0) ? 6'd4  :
                      (dec_f == 2'd2) ? 6'd8  : 6'd16) :
                     ((dec_f == 2'd0) ? 6'd8  : 6'd32);
assign zero_beats = (smp_mode == 2'd1) ?
                    ((dec_f == 2'd0) ? ({4'd0,dec_n} * 10'd4  - 10'd4)  :
                     (dec_f == 2'd1) ? ({4'd0,dec_n} * 10'd16 - 10'd12) :
                     (dec_f == 2'd2) ? ({4'd0,dec_n} * 10'd8  - 10'd4)  :
                                      ({4'd0,dec_n} * 10'd16 - 10'd4)) :
                    ((dec_f == 2'd0) ? ({4'd0,dec_n} * 10'd4  - 10'd8)  :
                     (dec_f == 2'd1) ? ({4'd0,dec_n} * 10'd16 - 10'd28) :
                     (dec_f == 2'd2) ? ({4'd0,dec_n} * 10'd8  - 10'd12) :
                                      ({4'd0,dec_n} * 10'd16 - 10'd20));
assign period_beats = {4'd0,valid_beats} + zero_beats;

//////////////////////////////////////////////////
//2. State Machine
//////////////////////////////////////////////////
assign rxd_start = rxd_fsm_idle & chn_en & beat_qual & sync_match;
assign rxd_abort = ~chn_en | rxd_fsm_invalid | rx_discontinuity | sync_error;
assign sync_check = (sync_cnt < 12'd4) | (sync_cnt >= (prefix_beats - 12'd4));
assign sync_last  = (sync_cnt == (prefix_beats - 12'd1));
assign rx_discontinuity = (rxd_fsm_sync | rxd_fsm_data) & ~beat_qual;
assign sync_error = rxd_fsm_sync & beat_qual & sync_check & ~sync_match;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        rxd_fsm <= RXD_IDLE;
    else if(rxd_abort)
        rxd_fsm <= RXD_IDLE;
    else
        rxd_fsm <= rxd_fsm_nx;
end

always @(*) begin
    case(rxd_fsm)
        RXD_IDLE : begin
            if(rxd_start)
                rxd_fsm_nx = RXD_SYNC;
            else
                rxd_fsm_nx = RXD_IDLE;
        end
        RXD_SYNC : begin
            if(sync_last)
                rxd_fsm_nx = RXD_DATA;
            else
                rxd_fsm_nx = RXD_SYNC;
        end
        RXD_DATA : begin
            rxd_fsm_nx = RXD_DATA;
        end
        default : begin
            rxd_fsm_nx = RXD_IDLE;
        end
    endcase
end

//////////////////////////////////////////////////
//3. State Decode
//////////////////////////////////////////////////
assign rxd_fsm_idle = (rxd_fsm == RXD_IDLE);
assign rxd_fsm_sync = (rxd_fsm == RXD_SYNC);
assign rxd_fsm_data = (rxd_fsm == RXD_DATA);
assign rxd_fsm_invalid = ~(rxd_fsm_idle | rxd_fsm_sync | rxd_fsm_data);
assign rxd_idle     = rxd_fsm_idle;

//////////////////////////////////////////////////
//4. Input Qualification
//////////////////////////////////////////////////
assign sync_match = (adi_data[15:0]    == 16'h2772) &
                    (adi_data[31:16]   == 16'h2772) &
                    (adi_data[47:32]   == 16'h2772) &
                    (adi_data[63:48]   == 16'h2772) &
                    (adi_data[79:64]   == 16'h2772) &
                    (adi_data[95:80]   == 16'h2772) &
                    (adi_data[111:96]  == 16'h2772) &
                    (adi_data[127:112] == 16'h2772);
assign beat_qual  = adi_link_qual & adi_data_vld;

//////////////////////////////////////////////////
//5. Synchronization And Region Counters
//////////////////////////////////////////////////
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        sync_cnt <= 12'd0;
    else if(rxd_abort)
        sync_cnt <= 12'd0;
    else if(rxd_fsm_idle)
        sync_cnt <= rxd_start ? 12'd1 : 12'd0;
    else if(rxd_fsm_sync)
        sync_cnt <= sync_last ? 12'd0 : sync_cnt + 12'd1;
    else
        sync_cnt <= 12'd0;
end

assign data_region = (smp_mode == 2'd0) | (region_cnt < {4'd0,valid_beats});
assign region_advance = rxd_fsm_data & beat_qual & (smp_mode != 2'd0);
assign region_last = (region_cnt == (period_beats - 10'd1));

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        region_cnt <= 10'd0;
    else if(rxd_abort)
        region_cnt <= 10'd0;
    else if(rxd_fsm_sync & sync_last)
        region_cnt <= 10'd0;
    else if(region_advance)
        region_cnt <= region_last ? 10'd0 : region_cnt + 10'd1;
end

//////////////////////////////////////////////////
//6. Sample Formatting
//////////////////////////////////////////////////
always @(*) begin
    formatted_data = 128'd0;
    sample_word    = 16'd0;
    for(i=0;i<8;i=i+1) begin
        sample_word = adi_data[i*16 +: 16];
        if(frame_fmt)
            formatted_data[i*16 +: 16] = sample_word;
        else begin
            case(smp_prec)
                2'd0 : formatted_data[i*16 +: 16] = {{6{sample_word[15]}},sample_word[15:6]};
                2'd1 : formatted_data[i*16 +: 16] = {{4{sample_word[15]}},sample_word[15:4]};
                2'd2 : formatted_data[i*16 +: 16] = {{2{sample_word[15]}},sample_word[15:2]};
                default : formatted_data[i*16 +: 16] = {{6{sample_word[15]}},sample_word[15:6]};
            endcase
        end
    end
end

//////////////////////////////////////////////////
//7. Candidate Packing
//////////////////////////////////////////////////
assign data_accept = rxd_fsm_data & beat_qual & data_region;
assign pack_last   = (pack_cnt == 2'd3);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        pack_cnt <= 2'd0;
    else if(rxd_abort)
        pack_cnt <= 2'd0;
    else if(data_accept)
        pack_cnt <= pack_last ? 2'd0 : pack_cnt + 2'd1;
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        pack_data <= 384'd0;
    else if(rxd_abort)
        pack_data <= 384'd0;
    else if(data_accept & (pack_cnt == 2'd0))
        pack_data[127:0] <= formatted_data;
    else if(data_accept & (pack_cnt == 2'd1))
        pack_data[255:128] <= formatted_data;
    else if(data_accept & (pack_cnt == 2'd2))
        pack_data[383:256] <= formatted_data;
end

//////////////////////////////////////////////////
//8. FIFO Write
//////////////////////////////////////////////////
assign rx_fifo_winc = fifo_write_vld & chn_en;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        rx_fifo_wdat <= 512'd0;
    else if(rxd_abort)
        rx_fifo_wdat <= 512'd0;
    else if(data_accept & pack_last)
        rx_fifo_wdat <= {formatted_data,pack_data};
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        fifo_write_vld <= 1'd0;
    else if(rxd_abort)
        fifo_write_vld <= 1'd0;
    else if(data_accept & pack_last)
        fifo_write_vld <= 1'd1;
    else
        fifo_write_vld <= 1'd0;
end

//////////////////////////////////////////////////
//9. Error Event
//////////////////////////////////////////////////
assign data_error_set = chn_en & (rx_discontinuity | sync_error);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        data_error <= 1'd0;
    else if(data_error_set)
        data_error <= 1'd1;
    else
        data_error <= 1'd0;
end

endmodule
