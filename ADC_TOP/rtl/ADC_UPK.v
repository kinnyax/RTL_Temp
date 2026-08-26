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

localparam              [1:0]               UPK_IDLE                 = 2'd0                ;
localparam              [1:0]               UPK_PREFIX               = 2'd1                ;
localparam              [1:0]               UPK_VALID                = 2'd2                ;
localparam              [1:0]               UPK_ZERO                 = 2'd3                ;

reg                     [1:0]               upk_fsm                                        ;
reg                     [1:0]               upk_fsm_nx                                     ;
reg                     [11:0]              prefix_cnt                                     ;
reg                     [ 8:0]              region_cnt                                     ;

reg                     [255:0]             candidate_half                                 ;
reg                                         candidate_half_vld                             ;
reg                     [511:0]             mapped_raw                                     ;
reg                     [511:0]             mapped_data                                    ;

reg                     [511:0]             ddc_i_data                                     ;
reg                                         ddc_i_vld                                      ;
reg                     [511:0]             ddc_q_data                                     ;
reg                                         ddc_q_pending                                  ;

wire                    [1:0]               smp_prec                                       ;
wire                    [1:0]               smp_mode                                       ;
wire                                        frame_fmt                                      ;
wire                    [5:0]               dec_int                                        ;
wire                    [1:0]               dec_fra                                        ;
wire                    [1:0]               del_mode                                       ;
wire                    [7:0]               dec_m                                          ;

wire                    [11:0]              prefix_base                                    ;
wire                    [11:0]              prefix_delete                                  ;
wire                    [11:0]              prefix_beats                                   ;
wire                    [ 8:0]              valid_beats                                    ;
wire                    [ 8:0]              zero_beats                                     ;

wire                                        epoch_start                                    ;
wire                                        context_error                                  ;
wire                                        prefix_last                                    ;
wire                                        valid_last                                     ;
wire                                        zero_last                                      ;
wire                                        candidate_first                                ;
wire                                        candidate_done                                 ;
wire                                        ddc_i_candidate                                ;
wire                                        ddc_q_candidate                                ;
wire                                        direct_accept                                  ;
wire                                        ddc_pair_accept                                ;

integer raw_index;
integer format_index;

assign smp_prec  = adc_ctl[31:30];
assign smp_mode  = adc_ctl[27:26];
assign frame_fmt = adc_ctl[25];
assign dec_int   = frm_cfg[7:2];
assign dec_fra   = frm_cfg[1:0];
assign del_mode  = frm_cfg[9:8];
assign dec_m     = frm_cfg[7:0];

// Counts are AFE beats: eight 16-bit words per lane per beat.
assign prefix_base = (dec_fra == 2'd0) ? (({6'd0, dec_int} << 1) + 12'd23) :
                     (dec_fra == 2'd1) ? (({6'd0, dec_int} << 3) + 12'd25) :
                     (dec_fra == 2'd2) ? (({6'd0, dec_int} << 2) + 12'd25) :
                                           (({6'd0, dec_int} << 3) + 12'd29);

assign prefix_delete = (del_mode == 2'd1) ? ({4'd0, dec_m} << 2) :
                       (del_mode == 2'd2) ? ({4'd0, dec_m} << 3) : 12'd0;

assign prefix_beats = (smp_mode == 2'd0) ? 12'd16 : (prefix_base + prefix_delete);

assign valid_beats = (smp_mode == 2'd0) ? 9'd2 :
                     (smp_mode == 2'd1) ? ((dec_fra == 2'd0) ? 9'd2 :
                                           (dec_fra == 2'd1) ? 9'd8 :
                                           (dec_fra == 2'd2) ? 9'd4 : 9'd8) :
                                          ((dec_fra == 2'd0) ? 9'd4 : 9'd16);

assign zero_beats = (smp_mode == 2'd1) ?
                    ((dec_fra == 2'd0) ? (({3'd0, dec_int} << 1) - 9'd2) :
                     (dec_fra == 2'd1) ? (({3'd0, dec_int} << 3) - 9'd6) :
                     (dec_fra == 2'd2) ? (({3'd0, dec_int} << 2) - 9'd2) :
                                         (({3'd0, dec_int} << 3) - 9'd2)) :
                    (smp_mode == 2'd2) ?
                    ((dec_fra == 2'd0) ? (({3'd0, dec_int} << 1) - 9'd4) :
                     (dec_fra == 2'd1) ? (({3'd0, dec_int} << 3) - 9'd14) :
                     (dec_fra == 2'd2) ? (({3'd0, dec_int} << 2) - 9'd6) :
                                         (({3'd0, dec_int} << 3) - 9'd10)) : 9'd0;

assign epoch_start  = rxd_data_vld & rxd_somf[0];
assign context_error = chn_en & !rxd_data_vld & (upk_fsm != UPK_IDLE);
assign prefix_last  = rxd_data_vld & (upk_fsm == UPK_PREFIX) &
                      ((prefix_cnt + 12'd1) == prefix_beats);
assign valid_last   = rxd_data_vld & (upk_fsm == UPK_VALID) &
                      ((region_cnt + 9'd1) == valid_beats);
assign zero_last    = rxd_data_vld & (upk_fsm == UPK_ZERO) &
                      ((region_cnt + 9'd1) == zero_beats);

// PREFIX is fully discarded. VALID indices zero and one form candidate zero.
assign candidate_first = rxd_data_vld & (upk_fsm == UPK_VALID) & !region_cnt[0];
assign candidate_done  = rxd_data_vld & (upk_fsm == UPK_VALID) &
                         region_cnt[0] & candidate_half_vld;
assign ddc_i_candidate = candidate_done & (smp_mode == 2'd2) & !region_cnt[1];
assign ddc_q_candidate = candidate_done & (smp_mode == 2'd2) & region_cnt[1];
assign direct_accept   = candidate_done & (smp_mode != 2'd2) & (rx_fifo_wlevel >= 10'd1);
assign ddc_pair_accept = ddc_q_candidate & ddc_i_vld & (rx_fifo_wlevel >= 10'd2);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n)
        upk_fsm <= #UDLY UPK_IDLE;
    else if(!chn_en)
        upk_fsm <= #UDLY UPK_IDLE;
    else
        upk_fsm <= #UDLY upk_fsm_nx;
end

always @(*) begin
    upk_fsm_nx = upk_fsm;

    case(upk_fsm)
        UPK_IDLE:
            if(epoch_start)
                upk_fsm_nx = UPK_PREFIX;

        UPK_PREFIX:
            if(!rxd_data_vld)
                upk_fsm_nx = UPK_IDLE;
            else if(prefix_last)
                upk_fsm_nx = UPK_VALID;

        UPK_VALID:
            if(!rxd_data_vld)
                upk_fsm_nx = UPK_IDLE;
            else if(valid_last & (zero_beats != 9'd0))
                upk_fsm_nx = UPK_ZERO;

        UPK_ZERO:
            if(!rxd_data_vld)
                upk_fsm_nx = UPK_IDLE;
            else if(zero_last)
                upk_fsm_nx = UPK_VALID;

        default:
            upk_fsm_nx = UPK_IDLE;
    endcase
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n) begin
        prefix_cnt <= #UDLY 12'd0;
        region_cnt <= #UDLY 9'd0;
    end
    else if(!chn_en | context_error) begin
        prefix_cnt <= #UDLY 12'd0;
        region_cnt <= #UDLY 9'd0;
    end
    else begin
        case(upk_fsm)
            UPK_IDLE:
                if(epoch_start)
                    prefix_cnt <= #UDLY 12'd1;

            UPK_PREFIX:
                if(prefix_last) begin
                    prefix_cnt <= #UDLY 12'd0;
                    region_cnt <= #UDLY 9'd0;
                end
                else if(rxd_data_vld)
                    prefix_cnt <= #UDLY prefix_cnt + 12'd1;

            UPK_VALID:
                if(valid_last)
                    region_cnt <= #UDLY 9'd0;
                else if(rxd_data_vld)
                    region_cnt <= #UDLY region_cnt + 9'd1;

            UPK_ZERO:
                if(zero_last)
                    region_cnt <= #UDLY 9'd0;
                else if(rxd_data_vld)
                    region_cnt <= #UDLY region_cnt + 9'd1;

            default: begin
                prefix_cnt <= #UDLY 12'd0;
                region_cnt <= #UDLY 9'd0;
            end
        endcase
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n) begin
        candidate_half     <= #UDLY 256'd0;
        candidate_half_vld <= #UDLY 1'b0;
    end
    else if(!chn_en | context_error) begin
        candidate_half     <= #UDLY 256'd0;
        candidate_half_vld <= #UDLY 1'b0;
    end
    else if(candidate_first) begin
        candidate_half     <= #UDLY rxd_data;
        candidate_half_vld <= #UDLY 1'b1;
    end
    else if(candidate_done) begin
        candidate_half_vld <= #UDLY 1'b0;
    end
end

always @(*) begin
    mapped_raw = 512'd0;

    for(raw_index = 0; raw_index < 16; raw_index = raw_index + 1) begin
        mapped_raw[raw_index*32 +: 16]      = candidate_half[raw_index*16 +: 16];
        mapped_raw[raw_index*32 + 16 +: 16] = rxd_data[raw_index*16 +: 16];
    end
end

always @(*) begin
    mapped_data = mapped_raw;

    if(!frame_fmt) begin
        for(format_index = 0; format_index < 32; format_index = format_index + 1) begin
            case(smp_prec)
                2'd0:
                    mapped_data[format_index*16 +: 16] =
                        {{6{mapped_raw[format_index*16 + 15]}}, mapped_raw[format_index*16 + 6 +: 10]};

                2'd1:
                    mapped_data[format_index*16 +: 16] =
                        {{4{mapped_raw[format_index*16 + 15]}}, mapped_raw[format_index*16 + 4 +: 12]};

                2'd2:
                    mapped_data[format_index*16 +: 16] =
                        {{2{mapped_raw[format_index*16 + 15]}}, mapped_raw[format_index*16 + 2 +: 14]};

                default:
                    mapped_data[format_index*16 +: 16] = 16'd0;
            endcase
        end
    end
end

// Once an I/Q pair is admitted, Q owns the following FIFO write even if disable
// or a new validity loss is observed. Software cannot clear until upk_idle rises.
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n) begin
        ddc_i_data    <= #UDLY 512'd0;
        ddc_i_vld     <= #UDLY 1'b0;
        ddc_q_data    <= #UDLY 512'd0;
        ddc_q_pending <= #UDLY 1'b0;
        rx_fifo_wdat  <= #UDLY 512'd0;
        rx_fifo_winc  <= #UDLY 1'b0;
    end
    else begin
        rx_fifo_winc <= #UDLY 1'b0;

        if(ddc_q_pending) begin
            rx_fifo_wdat  <= #UDLY ddc_q_data;
            rx_fifo_winc  <= #UDLY 1'b1;
            ddc_q_pending <= #UDLY 1'b0;
        end
        else if(!chn_en | context_error) begin
            ddc_i_data    <= #UDLY 512'd0;
            ddc_i_vld     <= #UDLY 1'b0;
            ddc_q_data    <= #UDLY 512'd0;
            ddc_q_pending <= #UDLY 1'b0;
        end
        else if(ddc_i_candidate) begin
            ddc_i_data <= #UDLY mapped_data;
            ddc_i_vld  <= #UDLY 1'b1;
        end
        else if(ddc_q_candidate) begin
            ddc_i_vld <= #UDLY 1'b0;

            if(ddc_pair_accept) begin
                rx_fifo_wdat  <= #UDLY ddc_i_data;
                rx_fifo_winc  <= #UDLY 1'b1;
                ddc_q_data    <= #UDLY mapped_data;
                ddc_q_pending <= #UDLY 1'b1;
            end
        end
        else if(direct_accept) begin
            rx_fifo_wdat <= #UDLY mapped_data;
            rx_fifo_winc <= #UDLY 1'b1;
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n)
        data_error_evt <= #UDLY 1'b0;
    else
        data_error_evt <= #UDLY context_error;
end

assign upk_idle = (upk_fsm == UPK_IDLE) & !candidate_half_vld &
                  !ddc_i_vld & !ddc_q_pending & !rx_fifo_winc;

endmodule
