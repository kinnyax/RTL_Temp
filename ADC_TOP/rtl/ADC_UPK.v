`timescale 1ns / 1ps

module ADC_UPK(
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   chn_en                                         ,
    input                                   rxd_data_vld                                   ,
    input               [255:0]             rxd_data                                       ,
/* verilator lint_off UNUSEDSIGNAL */
    input               [15:0]              rxd_somf                                       ,
    input               [31:0]              adc_ctl                                        ,
    input               [31:0]              frm_cfg                                        ,
/* verilator lint_on UNUSEDSIGNAL */
    input               [ 9:0]              rx_fifo_wlevel                                 ,

    output    reg       [511:0]             rx_fifo_wdat                                   ,
    output    reg                           rx_fifo_winc                                   ,
    output    reg                           data_error_evt                                 ,
    output    wire                          upk_idle
);

parameter                                   UDLY                     = 1                   ;

localparam                                  UPK_IDLE                 = 2'd0                ;
localparam                                  UPK_PREFIX               = 2'd1                ;
localparam                                  UPK_VALID                = 2'd2                ;
localparam                                  UPK_ZERO                 = 2'd3                ;

wire                                        somf_seen                                      ;
wire                    [ 1:0]              smp_mode                                       ;
wire                    [ 1:0]              smp_prec                                       ;
wire                                        frame_fmt                                      ;
wire                    [ 5:0]              dec_n                                          ;
wire                    [ 1:0]              dec_f                                          ;
wire                    [ 1:0]              del_mode                                       ;
wire                    [10:0]              del_beats                                      ;
wire                    [10:0]              prefix_base                                    ;
wire                    [10:0]              prefix_beats                                   ;
wire                                        prefix_done                                    ;
wire                                        valid_beat                                     ;
wire                    [ 7:0]              valid_beats                                    ;
wire                    [ 9:0]              zero_beats                                     ;
wire                                        valid_last                                     ;
wire                                        zero_last                                      ;
wire                    [255:0]             aligned_data                                   ;
wire                    [511:0]             candidate_data                                 ;

reg                     [ 1:0]              upk_fsm                                        ;
reg                     [ 1:0]              upk_fsm_nx                                     ;
reg                     [10:0]              prefix_cnt                                     ;
reg                     [ 7:0]              valid_cnt                                      ;
reg                     [ 9:0]              zero_cnt                                       ;
reg                     [127:0]             align_tail                                     ;
reg                                         half_vld                                       ;
reg                     [255:0]             half_data                                      ;
reg                                         ddc_i_vld                                      ;
reg                     [511:0]             ddc_i_data                                     ;
reg                                         q_pending                                      ;
reg                     [511:0]             q_data                                         ;
reg                     [255:0]             rxd_data_fmt                                   ;
reg                     [15:0]              sample_word                                    ;

integer i;


assign somf_seen = rxd_somf[0];
assign smp_mode  = ((adc_ctl[27:26]==2'd3) ||
                    ((adc_ctl[27:26]==2'd2) && (frm_cfg[7:2]<6'd2))) ?
                   2'd0 : adc_ctl[27:26];
assign smp_prec  = (adc_ctl[31:30]==2'd3) ? 2'd0 : adc_ctl[31:30];
assign frame_fmt = adc_ctl[25];
assign dec_n     = (frm_cfg[7:2]==6'd0) ? 6'd1 : frm_cfg[7:2];
assign dec_f     = frm_cfg[1:0];
assign del_mode  = (frm_cfg[9:8]==2'd3) ? 2'd0 : frm_cfg[9:8];

assign del_beats = (del_mode==2'd1) ? ({5'd0,dec_n}*11'd8+{7'd0,dec_f,1'b0}) :
                   (del_mode==2'd2) ? ({5'd0,dec_n}*11'd16+{6'd0,dec_f,2'b0}) :
                                      11'd0;

assign prefix_base = (dec_f==2'd0) ? ({5'd0,dec_n}+11'd11) :
                     (dec_f==2'd1) ? ({5'd0,dec_n}*11'd4+11'd12) :
                     (dec_f==2'd2) ? ({5'd0,dec_n}*11'd2+11'd12) :
                                      ({5'd0,dec_n}*11'd4+11'd14);
assign prefix_beats = (smp_mode==2'd0) ? 11'd8 : prefix_base + del_beats;
assign prefix_done  = (prefix_cnt==prefix_beats);
assign valid_beat   = ((upk_fsm==UPK_PREFIX) && prefix_done && (smp_mode==2'd0)) ||
                      (upk_fsm==UPK_VALID);

assign valid_beats = (smp_mode==2'd0) ? 8'd2 :
                     (smp_mode==2'd1) ?
                         ((dec_f==2'd0) ? 8'd2 :
                          (dec_f==2'd2) ? 8'd4 : 8'd8) :
                         ((dec_f==2'd0) ? 8'd4 : 8'd16);

assign zero_beats = (smp_mode==2'd0) ? 10'd0 :
                    (smp_mode==2'd1) ?
                        ((dec_f==2'd0) ? ({4'd0,dec_n}*10'd2-10'd2) :
                         (dec_f==2'd1) ? ({4'd0,dec_n}*10'd8-10'd6) :
                         (dec_f==2'd2) ? ({4'd0,dec_n}*10'd4-10'd2) :
                                        ({4'd0,dec_n}*10'd8-10'd2)) :
                        ((dec_f==2'd0) ? ({4'd0,dec_n}*10'd2-10'd4) :
                         (dec_f==2'd1) ? ({4'd0,dec_n}*10'd8-10'd14) :
                         (dec_f==2'd2) ? ({4'd0,dec_n}*10'd4-10'd6) :
                                        ({4'd0,dec_n}*10'd8-10'd10));

assign valid_last    = (valid_cnt==valid_beats-8'd1);
assign zero_last     = (zero_cnt==zero_beats-10'd1);
assign aligned_data  = (smp_mode==2'd0) ? rxd_data :
                       {rxd_data[191:128],align_tail[127:64],
                        rxd_data[63:0],align_tail[63:0]};
assign candidate_data = {rxd_data_fmt,half_data};
assign upk_idle      = (upk_fsm==UPK_IDLE) && !half_vld && !ddc_i_vld &&
                       !q_pending && !rx_fifo_winc;

always @(*) begin
    rxd_data_fmt = 256'd0;
    sample_word  = 16'd0;
    for(i=0;i<16;i=i+1) begin
        sample_word = aligned_data[i*16 +: 16];
        if(frame_fmt)
            rxd_data_fmt[i*16 +: 16] = sample_word;
        else begin
            case(smp_prec)
                2'd0 : rxd_data_fmt[i*16 +: 16] = {{6{sample_word[15]}},sample_word[15:6]};
                2'd1 : rxd_data_fmt[i*16 +: 16] = {{4{sample_word[15]}},sample_word[15:4]};
                2'd2 : rxd_data_fmt[i*16 +: 16] = {{2{sample_word[15]}},sample_word[15:2]};
                default : rxd_data_fmt[i*16 +: 16] = {{6{sample_word[15]}},sample_word[15:6]};
            endcase
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0)
        upk_fsm <= #UDLY UPK_IDLE;
    else if(!chn_en)
        upk_fsm <= #UDLY UPK_IDLE;
    else if((upk_fsm!=UPK_IDLE) && !rxd_data_vld)
        upk_fsm <= #UDLY UPK_IDLE;
    else
        upk_fsm <= #UDLY upk_fsm_nx;
end

always @(*) begin
    case(upk_fsm)
        UPK_IDLE : begin
            if(rxd_data_vld && somf_seen)
                upk_fsm_nx = UPK_PREFIX;
            else
                upk_fsm_nx = UPK_IDLE;
        end
        UPK_PREFIX : begin
            if(prefix_done)
                upk_fsm_nx = UPK_VALID;
            else
                upk_fsm_nx = UPK_PREFIX;
        end
        UPK_VALID : begin
            if(valid_last && (zero_beats!=10'd0))
                upk_fsm_nx = UPK_ZERO;
            else
                upk_fsm_nx = UPK_VALID;
        end
        UPK_ZERO : begin
            if(zero_last)
                upk_fsm_nx = UPK_VALID;
            else
                upk_fsm_nx = UPK_ZERO;
        end
        default : begin
            upk_fsm_nx = UPK_IDLE;
        end
    endcase
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0)
        prefix_cnt <= #UDLY 11'd0;
    else if(!chn_en || !rxd_data_vld)
        prefix_cnt <= #UDLY 11'd0;
    else if((upk_fsm==UPK_IDLE) && somf_seen)
        prefix_cnt <= #UDLY 11'd1;
    else if(upk_fsm==UPK_PREFIX) begin
        if(prefix_done)
            prefix_cnt <= #UDLY 11'd0;
        else
            prefix_cnt <= #UDLY prefix_cnt + 11'd1;
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0)
        align_tail <= #UDLY 128'd0;
    else if(!chn_en || !rxd_data_vld || (smp_mode==2'd0))
        align_tail <= #UDLY 128'd0;
    else if(((upk_fsm==UPK_PREFIX) && prefix_done) || (upk_fsm==UPK_VALID))
        align_tail <= #UDLY {rxd_data[255:192],rxd_data[127:64]};
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0) begin
        valid_cnt <= #UDLY 8'd0;
        zero_cnt  <= #UDLY 10'd0;
    end
    else if(!chn_en || !rxd_data_vld) begin
        valid_cnt <= #UDLY 8'd0;
        zero_cnt  <= #UDLY 10'd0;
    end
    else begin
        if(valid_beat) begin
            if(valid_last)
                valid_cnt <= #UDLY 8'd0;
            else
                valid_cnt <= #UDLY valid_cnt + 8'd1;
        end
        else if(upk_fsm==UPK_ZERO) begin
            if(zero_last)
                zero_cnt <= #UDLY 10'd0;
            else
                zero_cnt <= #UDLY zero_cnt + 10'd1;
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0) begin
        half_vld  <= #UDLY 1'b0;
        half_data <= #UDLY 256'd0;
    end
    else if(!chn_en || !rxd_data_vld) begin
        half_vld  <= #UDLY 1'b0;
        half_data <= #UDLY 256'd0;
    end
    else if(valid_beat) begin
        if(!half_vld) begin
            half_vld  <= #UDLY 1'b1;
            half_data <= #UDLY rxd_data_fmt;
        end
        else begin
            half_vld <= #UDLY 1'b0;
        end
    end
    else if(upk_fsm==UPK_ZERO) begin
        if(!half_vld) begin
            half_vld  <= #UDLY 1'b1;
            half_data <= #UDLY 256'd0;
        end
        else begin
            half_vld <= #UDLY 1'b0;
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0) begin
        ddc_i_vld <= #UDLY 1'b0;
        ddc_i_data <= #UDLY 512'd0;
    end
    else if(!chn_en || !rxd_data_vld || (smp_mode!=2'd2)) begin
        ddc_i_vld <= #UDLY 1'b0;
        ddc_i_data <= #UDLY 512'd0;
    end
    else if(valid_beat && half_vld) begin
        if(!ddc_i_vld) begin
            ddc_i_vld  <= #UDLY 1'b1;
            ddc_i_data <= #UDLY candidate_data;
        end
        else begin
            ddc_i_vld <= #UDLY 1'b0;
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0) begin
        rx_fifo_wdat <= #UDLY 512'd0;
        rx_fifo_winc <= #UDLY 1'b0;
        q_pending    <= #UDLY 1'b0;
        q_data       <= #UDLY 512'd0;
    end
    else if(!chn_en || !rxd_data_vld) begin
        rx_fifo_wdat <= #UDLY 512'd0;
        rx_fifo_winc <= #UDLY 1'b0;
        q_pending    <= #UDLY 1'b0;
        q_data       <= #UDLY 512'd0;
    end
    else begin
        rx_fifo_winc <= #UDLY 1'b0;
        if(q_pending) begin
            rx_fifo_wdat <= #UDLY q_data;
            rx_fifo_winc <= #UDLY 1'b1;
            q_pending    <= #UDLY 1'b0;
        end
        else if(valid_beat && rxd_data_vld && half_vld) begin
            if(smp_mode!=2'd2) begin
                if(rx_fifo_wlevel>=10'd1) begin
                    rx_fifo_wdat <= #UDLY candidate_data;
                    rx_fifo_winc <= #UDLY 1'b1;
                end
            end
            else if(ddc_i_vld && (rx_fifo_wlevel>=10'd2)) begin
                rx_fifo_wdat <= #UDLY ddc_i_data;
                rx_fifo_winc <= #UDLY 1'b1;
                q_pending    <= #UDLY 1'b1;
                q_data       <= #UDLY candidate_data;
            end
        end
        else if((upk_fsm==UPK_ZERO) && rxd_data_vld && half_vld &&
                (rx_fifo_wlevel>=10'd1)) begin
            rx_fifo_wdat <= #UDLY 512'd0;
            rx_fifo_winc <= #UDLY 1'b1;
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0)
        data_error_evt <= #UDLY 1'b0;
    else begin
        data_error_evt <= #UDLY 1'b0;
        if(chn_en && (upk_fsm!=UPK_IDLE) && !rxd_data_vld)
            data_error_evt <= #UDLY 1'b1;
    end
end

endmodule
