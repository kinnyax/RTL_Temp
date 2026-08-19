`timescale 1ns / 1ps

// AFE-domain region unpacker. FIFO clear is deliberately outside this context.
module ADC_UPK(
    input wire afe_clk, input wire afe_rst_n, input wire chn_en_afe,
    input wire [255:0] rxd_data, input wire [15:0] rxd_somf, input wire link_ready_afe,
    input wire [31:0] adc_ctl, input wire [31:0] frame_cfg, input wire [9:0] fifo_wlevel,
    output reg [511:0] fifo_wr_data, output reg fifo_wr_valid, output reg data_drop_evt
);
localparam [1:0] RXD_IDLE=2'd0, RXD_PREF=2'd1, RXD_VALID=2'd2, RXD_ZERO=2'd3;
reg [1:0] rxd_fsm, rxd_fsm_nx;
reg [11:0] prefix_cnt;
reg [8:0] region_cnt;
reg [127:0] rxd_buff0, rxd_buff1;
reg [511:0] ddc_i_buff, ddc_q_buff;
reg ddc_wr_sel;
reg [511:0] mapped_raw;
wire [1:0] smp_prec=adc_ctl[31:30], smp_mode=adc_ctl[27:26];
wire frame_fmt=adc_ctl[25];
wire [5:0] dec_n=frame_cfg[7:2];
wire [1:0] dec_f=frame_cfg[1:0], dec_del_mode=frame_cfg[9:8];
wire [7:0] dec_e=frame_cfg[7:0];
wire upk_vld, upk_trig, payl_hit, p0;
wire rxd_fsm_idle, rxd_fsm_pref, rxd_fsm_valid, rxd_fsm_zero;
wire [11:0] pref_fra, pref_del, dec_num, ddc_num, skip_num;
wire [8:0] dec_valid_beats, ddc_valid_beats, valid_beats, dec_zero_beats, ddc_zero_beats, zero_beats;
wire valid_region_final, zero_region_final, rxd_buff_upd, rxd_data_upd, ddc_i_sta, ddc_q_sta, fifo_has_two_space;
wire [255:0] rxd_raw0={rxd_data[127:0],rxd_buff0};
wire [255:0] rxd_raw1={rxd_data[255:128],rxd_buff1};
wire [511:0] rxd_data_right;
wire [511:0] mapped_data=frame_fmt ? mapped_raw : rxd_data_right;

assign upk_vld=chn_en_afe & link_ready_afe;
assign upk_trig=upk_vld & rxd_somf[0];
assign rxd_fsm_idle=(rxd_fsm==RXD_IDLE);
assign rxd_fsm_pref=(rxd_fsm==RXD_PREF);
assign rxd_fsm_valid=(rxd_fsm==RXD_VALID);
assign rxd_fsm_zero=(rxd_fsm==RXD_ZERO);
assign pref_fra=(dec_f==2'd0)?(({6'd0,dec_n}<<1)+12'd23):
                (dec_f==2'd1)?(({6'd0,dec_n}<<3)+12'd25):
                (dec_f==2'd2)?(({6'd0,dec_n}<<2)+12'd25):(({6'd0,dec_n}<<3)+12'd29);
assign pref_del=(dec_del_mode==2'd1)?({4'd0,dec_e}<<2):
                (dec_del_mode==2'd2)?({4'd0,dec_e}<<3):12'd0;
assign dec_num=pref_fra+pref_del;
assign ddc_num=pref_fra+pref_del;
assign skip_num=(smp_mode==2'd0)?12'd16:(smp_mode==2'd1)?dec_num:ddc_num;
assign payl_hit=rxd_fsm_pref && ((prefix_cnt+12'd1)==skip_num);
assign p0=rxd_fsm_pref && payl_hit;
assign dec_valid_beats=(dec_f==2'd0)?9'd2:(dec_f==2'd1)?9'd8:(dec_f==2'd2)?9'd4:9'd8;
assign ddc_valid_beats=(dec_f==2'd0)?9'd4:9'd16;
assign valid_beats=(smp_mode==2'd0)?9'd2:(smp_mode==2'd1)?dec_valid_beats:ddc_valid_beats;
assign dec_zero_beats=(dec_f==2'd0)?(({3'd0,dec_n}<<1)-9'd2):
                      (dec_f==2'd1)?(({3'd0,dec_n}<<3)-9'd6):
                      (dec_f==2'd2)?(({3'd0,dec_n}<<2)-9'd2):(({3'd0,dec_n}<<3)-9'd2);
assign ddc_zero_beats=(dec_f==2'd0)?(({3'd0,dec_n}<<1)-9'd4):
                      (dec_f==2'd1)?(({3'd0,dec_n}<<3)-9'd14):
                      (dec_f==2'd2)?(({3'd0,dec_n}<<2)-9'd6):(({3'd0,dec_n}<<3)-9'd10);
assign zero_beats=(smp_mode==2'd1)?dec_zero_beats:(smp_mode==2'd2)?ddc_zero_beats:9'd0;
assign valid_region_final=rxd_fsm_valid && ((region_cnt+9'd1)==valid_beats);
assign zero_region_final=rxd_fsm_zero && ((region_cnt+9'd1)==zero_beats);
assign rxd_buff_upd=p0 || (rxd_fsm_valid && ((region_cnt==9'd0)||(region_cnt==9'd2)||(region_cnt==9'd4)||(region_cnt==9'd6)||(region_cnt==9'd8)||(region_cnt==9'd10)||(region_cnt==9'd12)||(region_cnt==9'd14)));
assign rxd_data_upd=rxd_fsm_valid && ((region_cnt==9'd1)||(region_cnt==9'd3)||(region_cnt==9'd5)||(region_cnt==9'd7)||(region_cnt==9'd9)||(region_cnt==9'd11)||(region_cnt==9'd13)||(region_cnt==9'd15));
assign ddc_i_sta=p0 || (rxd_fsm_valid && ((region_cnt==9'd0)||(region_cnt==9'd1)||(region_cnt==9'd4)||(region_cnt==9'd5)||(region_cnt==9'd8)||(region_cnt==9'd9)||(region_cnt==9'd12)||(region_cnt==9'd13)));
assign ddc_q_sta=rxd_fsm_valid && ((region_cnt==9'd2)||(region_cnt==9'd3)||(region_cnt==9'd6)||(region_cnt==9'd7)||(region_cnt==9'd10)||(region_cnt==9'd11)||(region_cnt==9'd14)||(region_cnt==9'd15));
assign fifo_has_two_space=fifo_wlevel>=10'd2;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) rxd_fsm<=RXD_IDLE;
    else if (!upk_vld) rxd_fsm<=RXD_IDLE;
    else rxd_fsm<=rxd_fsm_nx;
end
always @* begin
    case (rxd_fsm)
        RXD_IDLE:  if (upk_trig) rxd_fsm_nx=RXD_PREF; else rxd_fsm_nx=RXD_IDLE;
        RXD_PREF:  if (payl_hit) rxd_fsm_nx=RXD_VALID; else rxd_fsm_nx=RXD_PREF;
        RXD_VALID: if (valid_region_final && (zero_beats!=9'd0)) rxd_fsm_nx=RXD_ZERO; else rxd_fsm_nx=RXD_VALID;
        RXD_ZERO:  if (zero_region_final) rxd_fsm_nx=RXD_VALID; else rxd_fsm_nx=RXD_ZERO;
        default: rxd_fsm_nx=RXD_IDLE;
    endcase
end
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) prefix_cnt<=12'd0;
    else if (!upk_vld) prefix_cnt<=12'd0;
    else if (rxd_fsm_pref && payl_hit) prefix_cnt<=12'd0;
    else if (rxd_fsm_pref) prefix_cnt<=prefix_cnt+12'd1;
end
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) region_cnt<=9'd0;
    else if (!upk_vld) region_cnt<=9'd0;
    else if (p0) region_cnt<=9'd1;
    else if (valid_region_final || zero_region_final) region_cnt<=9'd0;
    else if (rxd_fsm_valid || rxd_fsm_zero) region_cnt<=region_cnt+9'd1;
end
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin rxd_buff0<=128'd0; rxd_buff1<=128'd0; end
    else if (!upk_vld) begin rxd_buff0<=128'd0; rxd_buff1<=128'd0; end
    else if (rxd_buff_upd) begin rxd_buff0<=rxd_data[127:0]; rxd_buff1<=rxd_data[255:128]; end
end
always @* begin
    mapped_raw=512'd0;
    mapped_raw[15:0] = rxd_raw0[15:0];
    mapped_raw[31:16] = rxd_raw0[143:128];
    mapped_raw[47:32] = rxd_raw0[31:16];
    mapped_raw[63:48] = rxd_raw0[159:144];
    mapped_raw[79:64] = rxd_raw0[47:32];
    mapped_raw[95:80] = rxd_raw0[175:160];
    mapped_raw[111:96] = rxd_raw0[63:48];
    mapped_raw[127:112] = rxd_raw0[191:176];
    mapped_raw[143:128] = rxd_raw0[79:64];
    mapped_raw[159:144] = rxd_raw0[207:192];
    mapped_raw[175:160] = rxd_raw0[95:80];
    mapped_raw[191:176] = rxd_raw0[223:208];
    mapped_raw[207:192] = rxd_raw0[111:96];
    mapped_raw[223:208] = rxd_raw0[239:224];
    mapped_raw[239:224] = rxd_raw0[127:112];
    mapped_raw[255:240] = rxd_raw0[255:240];
    mapped_raw[271:256] = rxd_raw1[15:0];
    mapped_raw[287:272] = rxd_raw1[143:128];
    mapped_raw[303:288] = rxd_raw1[31:16];
    mapped_raw[319:304] = rxd_raw1[159:144];
    mapped_raw[335:320] = rxd_raw1[47:32];
    mapped_raw[351:336] = rxd_raw1[175:160];
    mapped_raw[367:352] = rxd_raw1[63:48];
    mapped_raw[383:368] = rxd_raw1[191:176];
    mapped_raw[399:384] = rxd_raw1[79:64];
    mapped_raw[415:400] = rxd_raw1[207:192];
    mapped_raw[431:416] = rxd_raw1[95:80];
    mapped_raw[447:432] = rxd_raw1[223:208];
    mapped_raw[463:448] = rxd_raw1[111:96];
    mapped_raw[479:464] = rxd_raw1[239:224];
    mapped_raw[495:480] = rxd_raw1[127:112];
    mapped_raw[511:496] = rxd_raw1[255:240];
end

assign rxd_data_right[15:0] = (smp_prec == 2'd0) ? {{6{mapped_raw[15]}},mapped_raw[15:6]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[15]}},mapped_raw[15:4]} :
                                                             {{2{mapped_raw[15]}},mapped_raw[15:2]};
assign rxd_data_right[31:16] = (smp_prec == 2'd0) ? {{6{mapped_raw[31]}},mapped_raw[31:22]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[31]}},mapped_raw[31:20]} :
                                                             {{2{mapped_raw[31]}},mapped_raw[31:18]};
assign rxd_data_right[47:32] = (smp_prec == 2'd0) ? {{6{mapped_raw[47]}},mapped_raw[47:38]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[47]}},mapped_raw[47:36]} :
                                                             {{2{mapped_raw[47]}},mapped_raw[47:34]};
assign rxd_data_right[63:48] = (smp_prec == 2'd0) ? {{6{mapped_raw[63]}},mapped_raw[63:54]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[63]}},mapped_raw[63:52]} :
                                                             {{2{mapped_raw[63]}},mapped_raw[63:50]};
assign rxd_data_right[79:64] = (smp_prec == 2'd0) ? {{6{mapped_raw[79]}},mapped_raw[79:70]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[79]}},mapped_raw[79:68]} :
                                                             {{2{mapped_raw[79]}},mapped_raw[79:66]};
assign rxd_data_right[95:80] = (smp_prec == 2'd0) ? {{6{mapped_raw[95]}},mapped_raw[95:86]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[95]}},mapped_raw[95:84]} :
                                                             {{2{mapped_raw[95]}},mapped_raw[95:82]};
assign rxd_data_right[111:96] = (smp_prec == 2'd0) ? {{6{mapped_raw[111]}},mapped_raw[111:102]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[111]}},mapped_raw[111:100]} :
                                                             {{2{mapped_raw[111]}},mapped_raw[111:98]};
assign rxd_data_right[127:112] = (smp_prec == 2'd0) ? {{6{mapped_raw[127]}},mapped_raw[127:118]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[127]}},mapped_raw[127:116]} :
                                                             {{2{mapped_raw[127]}},mapped_raw[127:114]};
assign rxd_data_right[143:128] = (smp_prec == 2'd0) ? {{6{mapped_raw[143]}},mapped_raw[143:134]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[143]}},mapped_raw[143:132]} :
                                                             {{2{mapped_raw[143]}},mapped_raw[143:130]};
assign rxd_data_right[159:144] = (smp_prec == 2'd0) ? {{6{mapped_raw[159]}},mapped_raw[159:150]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[159]}},mapped_raw[159:148]} :
                                                             {{2{mapped_raw[159]}},mapped_raw[159:146]};
assign rxd_data_right[175:160] = (smp_prec == 2'd0) ? {{6{mapped_raw[175]}},mapped_raw[175:166]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[175]}},mapped_raw[175:164]} :
                                                             {{2{mapped_raw[175]}},mapped_raw[175:162]};
assign rxd_data_right[191:176] = (smp_prec == 2'd0) ? {{6{mapped_raw[191]}},mapped_raw[191:182]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[191]}},mapped_raw[191:180]} :
                                                             {{2{mapped_raw[191]}},mapped_raw[191:178]};
assign rxd_data_right[207:192] = (smp_prec == 2'd0) ? {{6{mapped_raw[207]}},mapped_raw[207:198]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[207]}},mapped_raw[207:196]} :
                                                             {{2{mapped_raw[207]}},mapped_raw[207:194]};
assign rxd_data_right[223:208] = (smp_prec == 2'd0) ? {{6{mapped_raw[223]}},mapped_raw[223:214]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[223]}},mapped_raw[223:212]} :
                                                             {{2{mapped_raw[223]}},mapped_raw[223:210]};
assign rxd_data_right[239:224] = (smp_prec == 2'd0) ? {{6{mapped_raw[239]}},mapped_raw[239:230]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[239]}},mapped_raw[239:228]} :
                                                             {{2{mapped_raw[239]}},mapped_raw[239:226]};
assign rxd_data_right[255:240] = (smp_prec == 2'd0) ? {{6{mapped_raw[255]}},mapped_raw[255:246]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[255]}},mapped_raw[255:244]} :
                                                             {{2{mapped_raw[255]}},mapped_raw[255:242]};
assign rxd_data_right[271:256] = (smp_prec == 2'd0) ? {{6{mapped_raw[271]}},mapped_raw[271:262]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[271]}},mapped_raw[271:260]} :
                                                             {{2{mapped_raw[271]}},mapped_raw[271:258]};
assign rxd_data_right[287:272] = (smp_prec == 2'd0) ? {{6{mapped_raw[287]}},mapped_raw[287:278]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[287]}},mapped_raw[287:276]} :
                                                             {{2{mapped_raw[287]}},mapped_raw[287:274]};
assign rxd_data_right[303:288] = (smp_prec == 2'd0) ? {{6{mapped_raw[303]}},mapped_raw[303:294]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[303]}},mapped_raw[303:292]} :
                                                             {{2{mapped_raw[303]}},mapped_raw[303:290]};
assign rxd_data_right[319:304] = (smp_prec == 2'd0) ? {{6{mapped_raw[319]}},mapped_raw[319:310]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[319]}},mapped_raw[319:308]} :
                                                             {{2{mapped_raw[319]}},mapped_raw[319:306]};
assign rxd_data_right[335:320] = (smp_prec == 2'd0) ? {{6{mapped_raw[335]}},mapped_raw[335:326]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[335]}},mapped_raw[335:324]} :
                                                             {{2{mapped_raw[335]}},mapped_raw[335:322]};
assign rxd_data_right[351:336] = (smp_prec == 2'd0) ? {{6{mapped_raw[351]}},mapped_raw[351:342]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[351]}},mapped_raw[351:340]} :
                                                             {{2{mapped_raw[351]}},mapped_raw[351:338]};
assign rxd_data_right[367:352] = (smp_prec == 2'd0) ? {{6{mapped_raw[367]}},mapped_raw[367:358]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[367]}},mapped_raw[367:356]} :
                                                             {{2{mapped_raw[367]}},mapped_raw[367:354]};
assign rxd_data_right[383:368] = (smp_prec == 2'd0) ? {{6{mapped_raw[383]}},mapped_raw[383:374]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[383]}},mapped_raw[383:372]} :
                                                             {{2{mapped_raw[383]}},mapped_raw[383:370]};
assign rxd_data_right[399:384] = (smp_prec == 2'd0) ? {{6{mapped_raw[399]}},mapped_raw[399:390]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[399]}},mapped_raw[399:388]} :
                                                             {{2{mapped_raw[399]}},mapped_raw[399:386]};
assign rxd_data_right[415:400] = (smp_prec == 2'd0) ? {{6{mapped_raw[415]}},mapped_raw[415:406]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[415]}},mapped_raw[415:404]} :
                                                             {{2{mapped_raw[415]}},mapped_raw[415:402]};
assign rxd_data_right[431:416] = (smp_prec == 2'd0) ? {{6{mapped_raw[431]}},mapped_raw[431:422]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[431]}},mapped_raw[431:420]} :
                                                             {{2{mapped_raw[431]}},mapped_raw[431:418]};
assign rxd_data_right[447:432] = (smp_prec == 2'd0) ? {{6{mapped_raw[447]}},mapped_raw[447:438]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[447]}},mapped_raw[447:436]} :
                                                             {{2{mapped_raw[447]}},mapped_raw[447:434]};
assign rxd_data_right[463:448] = (smp_prec == 2'd0) ? {{6{mapped_raw[463]}},mapped_raw[463:454]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[463]}},mapped_raw[463:452]} :
                                                             {{2{mapped_raw[463]}},mapped_raw[463:450]};
assign rxd_data_right[479:464] = (smp_prec == 2'd0) ? {{6{mapped_raw[479]}},mapped_raw[479:470]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[479]}},mapped_raw[479:468]} :
                                                             {{2{mapped_raw[479]}},mapped_raw[479:466]};
assign rxd_data_right[495:480] = (smp_prec == 2'd0) ? {{6{mapped_raw[495]}},mapped_raw[495:486]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[495]}},mapped_raw[495:484]} :
                                                             {{2{mapped_raw[495]}},mapped_raw[495:482]};
assign rxd_data_right[511:496] = (smp_prec == 2'd0) ? {{6{mapped_raw[511]}},mapped_raw[511:502]} :
                                      (smp_prec == 2'd1) ? {{4{mapped_raw[511]}},mapped_raw[511:500]} :
                                                             {{2{mapped_raw[511]}},mapped_raw[511:498]};
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin fifo_wr_data<=512'd0; fifo_wr_valid<=1'b0; ddc_i_buff<=512'd0; ddc_q_buff<=512'd0; ddc_wr_sel<=1'b0; end
    else if (!upk_vld) begin fifo_wr_valid<=1'b0; ddc_i_buff<=512'd0; ddc_q_buff<=512'd0; ddc_wr_sel<=1'b0; end
    else begin
        fifo_wr_valid<=1'b0;
        if (ddc_wr_sel) begin fifo_wr_data<=ddc_q_buff; fifo_wr_valid<=1'b1; ddc_wr_sel<=1'b0; end
        else if (rxd_data_upd && (smp_mode!=2'd2)) begin fifo_wr_data<=mapped_data; fifo_wr_valid<=1'b1; end
        else if (rxd_data_upd && ddc_i_sta) ddc_i_buff<=mapped_data;
        else if (rxd_data_upd && ddc_q_sta && fifo_has_two_space) begin fifo_wr_data<=ddc_i_buff; fifo_wr_valid<=1'b1; ddc_q_buff<=mapped_data; ddc_wr_sel<=1'b1; end
    end
end
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) data_drop_evt<=1'b0;
    else if (!upk_vld) data_drop_evt<=1'b0;
    else if ((smp_mode==2'd2) && rxd_data_upd && ddc_q_sta && !fifo_has_two_space) data_drop_evt<=1'b1;
    else data_drop_evt<=1'b0;
end
endmodule
