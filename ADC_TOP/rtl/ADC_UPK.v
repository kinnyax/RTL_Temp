`timescale 1ns / 1ps

module ADC_UPK(
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   chn_en                                         ,
    input               [127:0]             rxd_data                                       ,
    input                                   rxd_data_vld                                   ,
    input                                   rxd_ready                                      ,
    input               [31:0]              adc_ctl                                        ,
    input               [31:0]              frm_cfg                                        ,

    output    reg       [511:0]             rx_fifo_wdat                                   ,
    output    reg                           rx_fifo_winc                                   ,
    output    reg                           data_error                                     ,
    output    wire                          upk_idle
);

parameter                                   UDLY                     = 1                   ;

localparam                                  UPK_IDLE                 = 2'd0                ;
localparam                                  UPK_SYNC                 = 2'd1                ;
localparam                                  UPK_DATA                 = 2'd2                ;

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
wire                                        data_accept                                    ;
wire                                        data_vld                                       ;
wire                                        rx_discontinuity                               ;
wire                                        sync_mismatch                                  ;
wire                                        sync_error                                     ;
wire                                        data_error_set                                 ;
wire                                        upk_end                                        ;
wire                                        upk_start                                      ;
wire                                        upk_fsm_idle                                   ;
wire                                        upk_fsm_sync                                   ;
wire                                        upk_fsm_data                                   ;
wire                                        pack_last                                      ;

reg                     [ 1:0]              upk_fsm                                        ;
reg                     [ 1:0]              upk_fsm_nx                                     ;
reg                     [11:0]              sync_cnt                                       ;
reg                     [ 9:0]              region_cnt                                     ;
reg                     [ 1:0]              pack_cnt                                       ;
reg                     [383:0]             pack_data                                      ;
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
assign upk_start = upk_fsm_idle & chn_en & data_vld & sync_match;
assign upk_end = ~chn_en | rx_discontinuity | sync_error;
assign sync_check = (sync_cnt < 12'd4) | (sync_cnt >= (prefix_beats - 12'd4));
assign sync_last  = (sync_cnt == (prefix_beats - 12'd1));
assign rx_discontinuity = ~upk_fsm_idle & ~data_vld;
assign sync_error = upk_fsm_sync & data_vld & sync_check & ~sync_match;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        upk_fsm <= #UDLY UPK_IDLE;
    else if(upk_end)
        upk_fsm <= #UDLY UPK_IDLE;
    else
        upk_fsm <= #UDLY upk_fsm_nx;
end

always @(*) begin
    case(upk_fsm)
        UPK_IDLE : begin
            if(upk_start)
                upk_fsm_nx = UPK_SYNC;
            else
                upk_fsm_nx = UPK_IDLE;
        end
        UPK_SYNC : begin
            if(sync_last)
                upk_fsm_nx = UPK_DATA;
            else
                upk_fsm_nx = UPK_SYNC;
        end
        UPK_DATA : begin
            upk_fsm_nx = UPK_DATA;
        end
        default : begin
            upk_fsm_nx = UPK_IDLE;
        end
    endcase
end

//////////////////////////////////////////////////
//3. State Decode
//////////////////////////////////////////////////
assign upk_fsm_idle = (upk_fsm == UPK_IDLE);
assign upk_fsm_sync = (upk_fsm == UPK_SYNC);
assign upk_fsm_data = (upk_fsm == UPK_DATA);
assign upk_idle     = upk_fsm_idle & (pack_cnt == 2'd0) & ~rx_fifo_winc;

//////////////////////////////////////////////////
//4. Input Qualification
//////////////////////////////////////////////////
assign sync_match = (rxd_data[15:0]    == 16'h2772) &
                    (rxd_data[31:16]   == 16'h2772) &
                    (rxd_data[47:32]   == 16'h2772) &
                    (rxd_data[63:48]   == 16'h2772) &
                    (rxd_data[79:64]   == 16'h2772) &
                     (rxd_data[95:80]   == 16'h2772) &
                     (rxd_data[111:96]  == 16'h2772) &
                     (rxd_data[127:112] == 16'h2772);
assign data_vld    = rxd_ready & rxd_data_vld;

//////////////////////////////////////////////////
//5. Synchronization And Region Counters
//////////////////////////////////////////////////
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        sync_cnt <= #UDLY 12'd0;
    else if(upk_end)
        sync_cnt <= #UDLY 12'd0;
    else if(upk_fsm_idle)
        sync_cnt <= #UDLY upk_start ? 12'd1 : 12'd0;
    else if(upk_fsm_sync)
        sync_cnt <= #UDLY sync_last ? 12'd0 : sync_cnt + 12'd1;
    else
        sync_cnt <= #UDLY 12'd0;
end

assign data_region = (smp_mode == 2'd0) | (region_cnt < {4'd0,valid_beats});

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        region_cnt <= #UDLY 10'd0;
    else if(upk_end)
        region_cnt <= #UDLY 10'd0;
    else if(upk_fsm_sync & sync_last)
        region_cnt <= #UDLY 10'd0;
    else if(upk_fsm_data & data_vld & (smp_mode != 2'd0))
        region_cnt <= #UDLY (region_cnt == (period_beats - 10'd1)) ? 10'd0 : region_cnt + 10'd1;
end

//////////////////////////////////////////////////
//6. Sample Formatting
//////////////////////////////////////////////////
always @(*) begin
    formatted_data = 128'd0;
    sample_word    = 16'd0;
    for(i=0;i<8;i=i+1) begin
        sample_word = rxd_data[i*16 +: 16];
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
assign data_accept = upk_fsm_data & data_vld & data_region;
assign pack_last = (pack_cnt == 2'd3);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        pack_cnt <= #UDLY 2'd0;
    else if(upk_end)
        pack_cnt <= #UDLY 2'd0;
    else if(data_accept)
        pack_cnt <= #UDLY pack_cnt + 2'd1;
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        pack_data <= #UDLY 384'd0;
    else if(upk_end)
        pack_data <= #UDLY 384'd0;
    else if(data_accept & (pack_cnt == 2'd0))
        pack_data[127:0] <= #UDLY formatted_data;
    else if(data_accept & (pack_cnt == 2'd1))
        pack_data[255:128] <= #UDLY formatted_data;
    else if(data_accept & (pack_cnt == 2'd2))
        pack_data[383:256] <= #UDLY formatted_data;
end

//////////////////////////////////////////////////
//8. FIFO Write
//////////////////////////////////////////////////
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n) begin
        rx_fifo_wdat <= #UDLY 512'd0;
        rx_fifo_winc <= #UDLY 1'd0;
    end
    else if(upk_end) begin
        rx_fifo_wdat <= #UDLY 512'd0;
        rx_fifo_winc <= #UDLY 1'd0;
    end
    else begin
        rx_fifo_winc <= #UDLY 1'd0;
        if(data_accept & pack_last) begin
            rx_fifo_wdat <= #UDLY {formatted_data,pack_data};
            rx_fifo_winc <= #UDLY 1'd1;
        end
    end
end

//////////////////////////////////////////////////
//9. Error Event
//////////////////////////////////////////////////
assign sync_mismatch  = upk_fsm_idle & data_vld & ~sync_match;
assign data_error_set = chn_en & (rx_discontinuity | sync_error | sync_mismatch);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        data_error <= #UDLY 1'd0;
    else if(data_error_set)
        data_error <= #UDLY 1'd1;
    else
        data_error <= #UDLY 1'd0;
end

endmodule
