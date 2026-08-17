`timescale 1ns / 1ps

module ADC_RXD(
    input  wire                             jesd_clk                                     ,
    input  wire                             jesd_rst_n                                   ,
    input  wire                             afe_clk                                      ,
    input  wire                             afe_rst_n                                    ,
    input  wire                             sysref                                       ,
    input  wire                             chn_en_jesd                                  ,
    input  wire                             chn_en_afe                                   ,
    input  wire [1:0]                       smp_prec                                     ,
    input  wire [1:0]                       smp_mode                                     ,
    input  wire                             frame_fmt                                    ,
    input  wire [7:0]                       dec_m                                        ,
    input  wire [1:0]                       dec_del_mode                                 ,
    input  wire [63:0]                      phy_rx_data                                  ,
    input  wire [7:0]                       phy_rx_charisk                               ,
    input  wire [7:0]                       phy_rx_disperr                               ,
    input  wire [7:0]                       phy_rx_notintable                            ,
    input  wire                             phy_rx_reset_done                            ,
    input  wire                             phy_pll_lock                                 ,
    input  wire                             fifo_clr                                     ,
    input  wire [9:0]                       fifo_wlevel                                  ,
    output wire                             phy_rx_encommalign                           ,
    output wire                             phy_sync_n                                   ,
    output reg [511:0]                      fifo_wr_data                                 ,
    output reg                              fifo_wr_valid                                ,
    output wire                             link_ready                                   ,
    output wire [1:0]                       lane_ready                                   ,
    output wire [1:0]                       comma_detected                               ,
    output wire                             link_error_evt                               ,
    output wire                             sysref_error_evt                             ,
    output wire                             sysref_seen_evt                              ,
    output wire [1:0]                       disparity_evt                                ,
    output wire [1:0]                       notintable_evt                               ,
    output reg                              data_drop_evt                                ,
    output reg                              ddc_abort_afe
);
parameter                                   UDLY                                         = 1;

localparam [1:0]                            RXD_WAIT_SOMF                                = 2'd0;
localparam [1:0]                            RXD_SKIP_PREFIX                              = 2'd1;
localparam [1:0]                            RXD_PAYLOAD                                  = 2'd2;

reg [255:0]                                 lane0_history_r                              ;
reg [255:0]                                 lane1_history_r                              ;
reg [11:0]                                  prefix_beat_r                                ;
reg [63:0]                                  word_pos_r                                   ;
reg [63:0]                                  next_term_r                                  ;
reg [2:0]                                   term_phase_r                                 ;
reg [1:0]                                   rxd_fsm                                      ;
reg [1:0]                                   rxd_fsm_nx                                   ;
reg                                         ddc_i_accepted_r                             ;
reg [511:0]                                 mapped_raw                                   ;
reg [255:0]                                 lane0_block_raw                              ;
reg [255:0]                                 lane1_block_raw                              ;

wire [511:0]                                mapped_data                                  ;
wire [5:0]                                  dec_int                                      ;
wire [1:0]                                  dec_frac                                     ;
wire [11:0]                                 gap_base16                                   ;
wire [11:0]                                 gap_base32                                   ;
wire [11:0]                                 gap_base64                                   ;
wire [11:0]                                 gap_dec1                                     ;
wire [11:0]                                 gap_ddc0                                     ;
wire [11:0]                                 gap_ddc1                                     ;
wire [11:0]                                 gap_ddc2                                     ;
wire [11:0]                                 gap_ddc3                                     ;
wire [11:0]                                 term_gap                                     ;
wire [2:0]                                  phase4_nx                                    ;
wire [2:0]                                  phase8_nx                                    ;
wire [2:0]                                  term_phase_next                              ;
wire                                        marker_present                               ;
wire                                        prec_vld                                     ;
wire                                        dec_vld                                      ;
wire                                        map_vld                                      ;
wire                                        upk_vld                                      ;
wire [11:0]                                 payload_start_beat                           ;
wire                                        payload_hit                                  ;
wire                                        block_complete                               ;
wire                                        block_is_q                                   ;
wire                                        block_is_i                                   ;
wire [2:0]                                  block_end_offset                             ;
wire [383:0]                                lane0_window                                 ;
wire [383:0]                                lane1_window                                 ;
wire                                        fifo_has_two_space                           ;
wire                                        normal_write_eligible                        ;
wire                                        ddc_i_write_eligible                         ;
wire                                        ddc_q_write_eligible                         ;
wire                                        fifo_write_eligible                          ;
wire                                        ddc_epoch_live                               ;
wire                                        ddc_abort_set_evt                            ;
wire                                        link_ready_afe                               ;

wire                                        jesd_core_reset                              ;
wire                                        device_core_reset                            ;
wire [255:0]                                adi_rx_data                                  ;
wire                                        adi_rx_valid                                 ;
wire [15:0]                                 adi_rx_somf                                  ;
wire                                        adi_sync_n                                   ;
wire                                        adi_encommalign                              ;
wire [1:0]                                  adi_lane_ifs_ready                           ;
wire [3:0]                                  adi_lane_cgs_state                           ;
wire [1:0]                                  adi_status_state                             ;
wire                                        adi_frame_error                              ;
wire                                        adi_unexpected_lane_error                    ;
wire                                        adi_sysref_error                             ;
wire                                        adi_sysref_seen                              ;
wire [1:0]                                  phy_disparity_level                          ;
wire [1:0]                                  phy_notintable_level                         ;
wire                                        link_error_level                             ;
reg [1:0]                                   phy_disparity_r                              ;
reg [1:0]                                   phy_notintable_r                             ;
reg                                         link_error_r                                 ;

// =====
// 1. ADI JESD204 RX
// =====
assign jesd_core_reset    = ~jesd_rst_n | ~chn_en_jesd | ~phy_rx_reset_done | ~phy_pll_lock;
assign device_core_reset  = ~afe_rst_n | ~chn_en_afe;

jesd204_rx #(
    .NUM_LANES                          (2                                             ),
    .NUM_LINKS                          (1                                             ),
    .LINK_MODE                          (1                                             ),
    .DATA_PATH_WIDTH                    (4                                             ),
    .TPL_DATA_PATH_WIDTH                (16                                            ),
    .ASYNC_CLK                          (1                                             ),
    .ENABLE_FRAME_ALIGN_CHECK           (1                                             ),
    .ENABLE_FRAME_ALIGN_ERR_RESET       (1                                             ),
    .ENABLE_CHAR_REPLACE                (1                                             )
) adi_jesd204_rx(
    .clk                                (jesd_clk                                      ),
    .reset                              (jesd_core_reset                               ),
    .device_clk                         (afe_clk                                       ),
    .device_reset                       (device_core_reset                             ),
    .phy_data                           (phy_rx_data                                   ),
    .phy_header                         (4'd0                                          ),
    .phy_charisk                        (phy_rx_charisk                                ),
    .phy_notintable                     (phy_rx_notintable                             ),
    .phy_disperr                        (phy_rx_disperr                                ),
    .phy_block_sync                     (2'b00                                         ),
    .sysref                             (sysref                                        ),
    .lmfc_edge                          (                                              ),
    .lmfc_clk                           (                                              ),
    .device_event_sysref_alignment_error(adi_sysref_error                              ),
    .device_event_sysref_edge           (adi_sysref_seen                               ),
    .event_frame_alignment_error        (adi_frame_error                               ),
    .event_unexpected_lane_state_error  (adi_unexpected_lane_error                     ),
    .sync                               (adi_sync_n                                    ),
    .phy_en_char_align                  (adi_encommalign                               ),
    .rx_data                            (adi_rx_data                                   ),
    .rx_valid                           (adi_rx_valid                                  ),
    .rx_eof                             (                                              ),
    .rx_sof                             (                                              ),
    .rx_eomf                            (                                              ),
    .rx_somf                            (adi_rx_somf                                   ),
    .cfg_lanes_disable                  (2'b00                                         ),
    .cfg_links_disable                  (1'b0                                          ),
    .cfg_octets_per_multiframe          (10'd255                                       ),
    .cfg_octets_per_frame               (8'd15                                         ),
    .cfg_disable_scrambler              (1'b1                                          ),
    .cfg_disable_char_replacement       (1'b0                                          ),
    .cfg_frame_align_err_threshold      (8'd1                                          ),
    .device_cfg_octets_per_multiframe   (10'd255                                       ),
    .device_cfg_octets_per_frame        (8'd15                                         ),
    .device_cfg_beats_per_multiframe    (8'd15                                         ),
    .device_cfg_lmfc_offset             (8'd0                                          ),
    .device_cfg_sysref_oneshot          (1'b1                                          ),
    .device_cfg_sysref_disable          (1'b0                                          ),
    .device_cfg_buffer_early_release    (1'b0                                          ),
    .device_cfg_buffer_delay            (8'd0                                          ),
    .ctrl_err_statistics_reset          (1'b0                                          ),
    .ctrl_err_statistics_mask           (7'd0                                          ),
    .status_err_statistics_cnt          (                                              ),
    .ilas_config_valid                  (                                              ),
    .ilas_config_addr                   (                                              ),
    .ilas_config_data                   (                                              ),
    .status_ctrl_state                  (adi_status_state                              ),
    .status_lane_cgs_state              (adi_lane_cgs_state                            ),
    .status_lane_ifs_ready              (adi_lane_ifs_ready                            ),
    .status_lane_latency                (                                              ),
    .status_lane_emb_state              (                                              ),
    .status_lane_frame_align_err_cnt    (                                              ),
    .status_synth_params0               (                                              ),
    .status_synth_params1               (                                              ),
    .status_synth_params2               (                                              )
);

// =====
// 2. Relink / Link Status
// =====
assign link_ready           = chn_en_jesd && phy_rx_reset_done && phy_pll_lock &&
                              (adi_status_state == 2'd3) && (&adi_lane_ifs_ready);
assign lane_ready           = adi_lane_ifs_ready;
assign comma_detected       = {adi_lane_cgs_state[2],adi_lane_cgs_state[0]};
assign phy_disparity_level  = {|phy_rx_disperr[7:4],|phy_rx_disperr[3:0]};
assign phy_notintable_level = {|phy_rx_notintable[7:4],|phy_rx_notintable[3:0]};
assign link_error_level     = adi_frame_error || adi_unexpected_lane_error ||
                              (|phy_disparity_level) || (|phy_notintable_level);
assign link_error_evt       = chn_en_jesd && link_error_level && !link_error_r;
assign sysref_error_evt     = adi_sysref_error;
assign sysref_seen_evt      = adi_sysref_seen;
assign disparity_evt        = {2{chn_en_jesd}} & phy_disparity_level &
                              ~phy_disparity_r;
assign notintable_evt       = {2{chn_en_jesd}} & phy_notintable_level &
                              ~phy_notintable_r;
assign phy_rx_encommalign   = adi_encommalign;
assign phy_sync_n           = adi_sync_n;

level_sync link_ready_to_afe(.clk(afe_clk), .rst_n(afe_rst_n), .in(link_ready), .out(link_ready_afe));

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if (!jesd_rst_n) begin
        phy_disparity_r  <= 2'd0;
        phy_notintable_r <= 2'd0;
        link_error_r     <= 1'b0;
    end else if (!chn_en_jesd) begin
        phy_disparity_r  <= 2'd0;
        phy_notintable_r <= 2'd0;
        link_error_r     <= 1'b0;
    end else begin
        phy_disparity_r  <= phy_disparity_level;
        phy_notintable_r <= phy_notintable_level;
        link_error_r     <= link_error_level;
    end
end

// =====
// 3. Payload Position / Block Decode
// =====
assign marker_present     = adi_rx_somf[0];
assign dec_int            = dec_m[7:2];
assign dec_frac           = dec_m[1:0];
assign prec_vld           = smp_prec != 2'd3;
assign dec_vld            = (dec_del_mode != 2'd3) &&
                            (((smp_mode == 2'd1) && (dec_int != 6'd0)) ||
                             ((smp_mode == 2'd2) && (dec_int >= 6'd2)));
assign map_vld            = (smp_mode == 2'd0) ? prec_vld :
                            ((smp_mode == 2'd1) || (smp_mode == 2'd2)) ? (prec_vld && dec_vld) : 1'b0;
assign upk_vld            = chn_en_afe && link_ready_afe && adi_rx_valid;
assign payload_start_beat =
                            (smp_mode == 2'd0) ? 12'd16 :
                            (((dec_frac == 2'd0) ? (({6'd0,dec_int} << 1) + 12'd23) :
                              (dec_frac == 2'd1) ? (({6'd0,dec_int} << 3) + 12'd25) :
                              (dec_frac == 2'd2) ? (({6'd0,dec_int} << 2) + 12'd25) :
                                                  (({6'd0,dec_int} << 3) + 12'd29)) +
                             ((dec_del_mode == 2'd1) ? ({4'd0,dec_m} << 2) :
                              (dec_del_mode == 2'd2) ? ({4'd0,dec_m} << 3) : 12'd0));
assign payload_hit        = (rxd_fsm == RXD_SKIP_PREFIX) &&
                            ((prefix_beat_r + 12'd1) == payload_start_beat);

assign gap_base16 = ({6'd0,dec_int} << 4);
assign gap_base32 = ({6'd0,dec_int} << 5);
assign gap_base64 = ({6'd0,dec_int} << 6);
assign gap_dec1   = gap_base64 - 12'd32;
assign gap_ddc0   = gap_base16 - 12'd16;
assign gap_ddc1   = gap_base64 - 12'd96;
assign gap_ddc2   = gap_base32 - 12'd32;
assign gap_ddc3   = gap_base64 - 12'd64;
assign phase4_nx = (term_phase_r == 3'd3) ? 3'd0 : (term_phase_r + 3'd1);
assign phase8_nx = (term_phase_r == 3'd7) ? 3'd0 : (term_phase_r + 3'd1);

assign term_gap =
    (smp_mode == 2'd1) ?
        ((dec_frac == 2'd0) ? gap_base16 :
         (dec_frac == 2'd1) ? ((term_phase_r == 3'd3) ? gap_dec1 : 12'd16) :
         (dec_frac == 2'd2) ? (term_phase_r[0] ? (gap_base32 + 12'd1) : 12'd16) :
                              ((term_phase_r == 3'd3) ? gap_base64 : 12'd16)) :
    (smp_mode == 2'd2) ?
        ((dec_frac == 2'd0) ? (term_phase_r[0] ? gap_ddc0 : 12'd16) :
         (dec_frac == 2'd1) ? ((term_phase_r == 3'd7) ? gap_ddc1 : 12'd16) :
         (dec_frac == 2'd2) ? ((term_phase_r == 3'd7) ? gap_ddc2 : 12'd16) :
                              ((term_phase_r == 3'd7) ? gap_ddc3 : 12'd16)) :
    12'd16;

assign term_phase_next =
    (smp_mode == 2'd1) ? ((dec_frac == 2'd0) ? 3'd0 : phase4_nx) :
    (smp_mode == 2'd2) ? ((dec_frac == 2'd0) ? (term_phase_r[0] ? 3'd0 : 3'd1) : phase8_nx) :
    3'd0;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        rxd_fsm <= #UDLY RXD_WAIT_SOMF;
    else
        rxd_fsm <= #UDLY rxd_fsm_nx;
end

always @* begin
    rxd_fsm_nx = rxd_fsm;
    if (!upk_vld || !map_vld || fifo_clr) begin
        rxd_fsm_nx = RXD_WAIT_SOMF;
    end else begin
        case (rxd_fsm)
            RXD_WAIT_SOMF  : if (marker_present) rxd_fsm_nx = RXD_SKIP_PREFIX;
            RXD_SKIP_PREFIX: if (payload_hit)     rxd_fsm_nx = RXD_PAYLOAD;
            RXD_PAYLOAD    :                      rxd_fsm_nx = RXD_PAYLOAD;
            default        :                      rxd_fsm_nx = RXD_WAIT_SOMF;
        endcase
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        prefix_beat_r <= 12'd0;
        word_pos_r    <= 64'd0;
        next_term_r   <= 64'd0;
        term_phase_r  <= 3'd0;
    end else if (!upk_vld || !map_vld || fifo_clr) begin
        prefix_beat_r <= 12'd0;
        word_pos_r    <= 64'd0;
        next_term_r   <= 64'd0;
        term_phase_r  <= 3'd0;
    end else begin
        case (rxd_fsm)
            RXD_WAIT_SOMF: begin
                prefix_beat_r <= 12'd0;
                word_pos_r    <= 64'd0;
                next_term_r   <= 64'd0;
                term_phase_r  <= 3'd0;
            end
            RXD_SKIP_PREFIX: begin
                prefix_beat_r <= prefix_beat_r + 12'd1;
                if (payload_hit) begin
                    word_pos_r   <= 64'd8;
                    next_term_r  <= 64'd15;
                    term_phase_r <= 3'd0;
                end
            end
            RXD_PAYLOAD: begin
                word_pos_r <= word_pos_r + 64'd8;
                if (block_complete) begin
                    next_term_r  <= next_term_r + term_gap;
                    term_phase_r <= term_phase_next;
                end
            end
            default: begin
                prefix_beat_r <= 12'd0;
                word_pos_r    <= 64'd0;
                next_term_r   <= 64'd0;
                term_phase_r  <= 3'd0;
            end
        endcase
    end
end

assign block_complete = map_vld && (rxd_fsm == RXD_PAYLOAD) &&
                         (word_pos_r[63:3] == next_term_r[63:3]);
assign block_is_q = block_complete && (smp_mode == 2'd2) && term_phase_r[0];
assign block_is_i = block_complete && (smp_mode == 2'd2) && !term_phase_r[0];
assign block_end_offset = next_term_r[2:0];

// =====
// 4. ADC_UPK
// =====
assign lane0_window = {adi_rx_data[127:0],lane0_history_r};
assign lane1_window = {adi_rx_data[255:128],lane1_history_r};

always @* begin
    lane0_block_raw = 256'd0;
    lane1_block_raw = 256'd0;
    case (block_end_offset)
        3'd0: begin
            lane0_block_raw = lane0_window[271:16];
            lane1_block_raw = lane1_window[271:16];
        end
        3'd1: begin
            lane0_block_raw = lane0_window[287:32];
            lane1_block_raw = lane1_window[287:32];
        end
        3'd2: begin
            lane0_block_raw = lane0_window[303:48];
            lane1_block_raw = lane1_window[303:48];
        end
        3'd3: begin
            lane0_block_raw = lane0_window[319:64];
            lane1_block_raw = lane1_window[319:64];
        end
        3'd4: begin
            lane0_block_raw = lane0_window[335:80];
            lane1_block_raw = lane1_window[335:80];
        end
        3'd5: begin
            lane0_block_raw = lane0_window[351:96];
            lane1_block_raw = lane1_window[351:96];
        end
        3'd6: begin
            lane0_block_raw = lane0_window[367:112];
            lane1_block_raw = lane1_window[367:112];
        end
        default: begin
            lane0_block_raw = lane0_window[383:128];
            lane1_block_raw = lane1_window[383:128];
        end
    endcase
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        lane0_history_r <= 256'd0;
        lane1_history_r <= 256'd0;
    end else if (!upk_vld || !map_vld || fifo_clr) begin
        lane0_history_r <= 256'd0;
        lane1_history_r <= 256'd0;
    end else if ((rxd_fsm == RXD_SKIP_PREFIX) || (rxd_fsm == RXD_PAYLOAD)) begin
        lane0_history_r <= {adi_rx_data[127:0],lane0_history_r[255:128]};
        lane1_history_r <= {adi_rx_data[255:128],lane1_history_r[255:128]};
    end else begin
        lane0_history_r <= 256'd0;
        lane1_history_r <= 256'd0;
    end
end

always @* begin
    mapped_raw = 512'd0;
    mapped_raw[15:0]    = lane0_block_raw[15:0]     ; mapped_raw[31:16]   = lane0_block_raw[143:128];
    mapped_raw[47:32]   = lane0_block_raw[31:16]    ; mapped_raw[63:48]   = lane0_block_raw[159:144];
    mapped_raw[79:64]   = lane0_block_raw[47:32]    ; mapped_raw[95:80]   = lane0_block_raw[175:160];
    mapped_raw[111:96]  = lane0_block_raw[63:48]    ; mapped_raw[127:112] = lane0_block_raw[191:176];
    mapped_raw[143:128] = lane0_block_raw[79:64]    ; mapped_raw[159:144] = lane0_block_raw[207:192];
    mapped_raw[175:160] = lane0_block_raw[95:80]    ; mapped_raw[191:176] = lane0_block_raw[223:208];
    mapped_raw[207:192] = lane0_block_raw[111:96]   ; mapped_raw[223:208] = lane0_block_raw[239:224];
    mapped_raw[239:224] = lane0_block_raw[127:112]  ; mapped_raw[255:240] = lane0_block_raw[255:240];
    mapped_raw[271:256] = lane1_block_raw[15:0]     ; mapped_raw[287:272] = lane1_block_raw[143:128];
    mapped_raw[303:288] = lane1_block_raw[31:16]    ; mapped_raw[319:304] = lane1_block_raw[159:144];
    mapped_raw[335:320] = lane1_block_raw[47:32]    ; mapped_raw[351:336] = lane1_block_raw[175:160];
    mapped_raw[367:352] = lane1_block_raw[63:48]    ; mapped_raw[383:368] = lane1_block_raw[191:176];
    mapped_raw[399:384] = lane1_block_raw[79:64]    ; mapped_raw[415:400] = lane1_block_raw[207:192];
    mapped_raw[431:416] = lane1_block_raw[95:80]    ; mapped_raw[447:432] = lane1_block_raw[223:208];
    mapped_raw[463:448] = lane1_block_raw[111:96]   ; mapped_raw[479:464] = lane1_block_raw[239:224];
    mapped_raw[495:480] = lane1_block_raw[127:112]  ; mapped_raw[511:496] = lane1_block_raw[255:240];
end

wire [2:0]                                  sample_fmt                                  ;
assign sample_fmt = {frame_fmt,smp_prec};

assign mapped_data[15:0]    =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[9]}},mapped_raw[9:0]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[11]}},mapped_raw[11:0]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[13]}},mapped_raw[13:0]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[15]}},mapped_raw[15:6]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[15]}},mapped_raw[15:4]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[15]}},mapped_raw[15:2]} : 16'd0;

assign mapped_data[31:16]   =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[25]}},mapped_raw[25:16]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[27]}},mapped_raw[27:16]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[29]}},mapped_raw[29:16]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[31]}},mapped_raw[31:22]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[31]}},mapped_raw[31:20]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[31]}},mapped_raw[31:18]} : 16'd0;

assign mapped_data[47:32]   =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[41]}},mapped_raw[41:32]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[43]}},mapped_raw[43:32]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[45]}},mapped_raw[45:32]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[47]}},mapped_raw[47:38]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[47]}},mapped_raw[47:36]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[47]}},mapped_raw[47:34]} : 16'd0;

assign mapped_data[63:48]   =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[57]}},mapped_raw[57:48]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[59]}},mapped_raw[59:48]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[61]}},mapped_raw[61:48]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[63]}},mapped_raw[63:54]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[63]}},mapped_raw[63:52]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[63]}},mapped_raw[63:50]} : 16'd0;

assign mapped_data[79:64]   =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[73]}},mapped_raw[73:64]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[75]}},mapped_raw[75:64]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[77]}},mapped_raw[77:64]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[79]}},mapped_raw[79:70]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[79]}},mapped_raw[79:68]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[79]}},mapped_raw[79:66]} : 16'd0;

assign mapped_data[95:80]   =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[89]}},mapped_raw[89:80]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[91]}},mapped_raw[91:80]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[93]}},mapped_raw[93:80]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[95]}},mapped_raw[95:86]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[95]}},mapped_raw[95:84]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[95]}},mapped_raw[95:82]} : 16'd0;

assign mapped_data[111:96]  =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[105]}},mapped_raw[105:96]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[107]}},mapped_raw[107:96]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[109]}},mapped_raw[109:96]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[111]}},mapped_raw[111:102]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[111]}},mapped_raw[111:100]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[111]}},mapped_raw[111:98]} : 16'd0;

assign mapped_data[127:112] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[121]}},mapped_raw[121:112]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[123]}},mapped_raw[123:112]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[125]}},mapped_raw[125:112]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[127]}},mapped_raw[127:118]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[127]}},mapped_raw[127:116]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[127]}},mapped_raw[127:114]} : 16'd0;

assign mapped_data[143:128] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[137]}},mapped_raw[137:128]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[139]}},mapped_raw[139:128]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[141]}},mapped_raw[141:128]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[143]}},mapped_raw[143:134]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[143]}},mapped_raw[143:132]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[143]}},mapped_raw[143:130]} : 16'd0;

assign mapped_data[159:144] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[153]}},mapped_raw[153:144]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[155]}},mapped_raw[155:144]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[157]}},mapped_raw[157:144]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[159]}},mapped_raw[159:150]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[159]}},mapped_raw[159:148]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[159]}},mapped_raw[159:146]} : 16'd0;

assign mapped_data[175:160] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[169]}},mapped_raw[169:160]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[171]}},mapped_raw[171:160]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[173]}},mapped_raw[173:160]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[175]}},mapped_raw[175:166]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[175]}},mapped_raw[175:164]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[175]}},mapped_raw[175:162]} : 16'd0;

assign mapped_data[191:176] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[185]}},mapped_raw[185:176]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[187]}},mapped_raw[187:176]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[189]}},mapped_raw[189:176]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[191]}},mapped_raw[191:182]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[191]}},mapped_raw[191:180]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[191]}},mapped_raw[191:178]} : 16'd0;

assign mapped_data[207:192] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[201]}},mapped_raw[201:192]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[203]}},mapped_raw[203:192]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[205]}},mapped_raw[205:192]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[207]}},mapped_raw[207:198]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[207]}},mapped_raw[207:196]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[207]}},mapped_raw[207:194]} : 16'd0;

assign mapped_data[223:208] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[217]}},mapped_raw[217:208]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[219]}},mapped_raw[219:208]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[221]}},mapped_raw[221:208]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[223]}},mapped_raw[223:214]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[223]}},mapped_raw[223:212]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[223]}},mapped_raw[223:210]} : 16'd0;

assign mapped_data[239:224] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[233]}},mapped_raw[233:224]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[235]}},mapped_raw[235:224]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[237]}},mapped_raw[237:224]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[239]}},mapped_raw[239:230]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[239]}},mapped_raw[239:228]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[239]}},mapped_raw[239:226]} : 16'd0;

assign mapped_data[255:240] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[249]}},mapped_raw[249:240]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[251]}},mapped_raw[251:240]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[253]}},mapped_raw[253:240]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[255]}},mapped_raw[255:246]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[255]}},mapped_raw[255:244]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[255]}},mapped_raw[255:242]} : 16'd0;

assign mapped_data[271:256] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[265]}},mapped_raw[265:256]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[267]}},mapped_raw[267:256]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[269]}},mapped_raw[269:256]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[271]}},mapped_raw[271:262]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[271]}},mapped_raw[271:260]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[271]}},mapped_raw[271:258]} : 16'd0;

assign mapped_data[287:272] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[281]}},mapped_raw[281:272]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[283]}},mapped_raw[283:272]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[285]}},mapped_raw[285:272]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[287]}},mapped_raw[287:278]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[287]}},mapped_raw[287:276]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[287]}},mapped_raw[287:274]} : 16'd0;

assign mapped_data[303:288] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[297]}},mapped_raw[297:288]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[299]}},mapped_raw[299:288]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[301]}},mapped_raw[301:288]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[303]}},mapped_raw[303:294]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[303]}},mapped_raw[303:292]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[303]}},mapped_raw[303:290]} : 16'd0;

assign mapped_data[319:304] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[313]}},mapped_raw[313:304]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[315]}},mapped_raw[315:304]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[317]}},mapped_raw[317:304]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[319]}},mapped_raw[319:310]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[319]}},mapped_raw[319:308]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[319]}},mapped_raw[319:306]} : 16'd0;

assign mapped_data[335:320] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[329]}},mapped_raw[329:320]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[331]}},mapped_raw[331:320]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[333]}},mapped_raw[333:320]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[335]}},mapped_raw[335:326]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[335]}},mapped_raw[335:324]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[335]}},mapped_raw[335:322]} : 16'd0;

assign mapped_data[351:336] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[345]}},mapped_raw[345:336]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[347]}},mapped_raw[347:336]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[349]}},mapped_raw[349:336]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[351]}},mapped_raw[351:342]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[351]}},mapped_raw[351:340]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[351]}},mapped_raw[351:338]} : 16'd0;

assign mapped_data[367:352] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[361]}},mapped_raw[361:352]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[363]}},mapped_raw[363:352]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[365]}},mapped_raw[365:352]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[367]}},mapped_raw[367:358]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[367]}},mapped_raw[367:356]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[367]}},mapped_raw[367:354]} : 16'd0;

assign mapped_data[383:368] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[377]}},mapped_raw[377:368]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[379]}},mapped_raw[379:368]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[381]}},mapped_raw[381:368]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[383]}},mapped_raw[383:374]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[383]}},mapped_raw[383:372]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[383]}},mapped_raw[383:370]} : 16'd0;

assign mapped_data[399:384] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[393]}},mapped_raw[393:384]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[395]}},mapped_raw[395:384]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[397]}},mapped_raw[397:384]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[399]}},mapped_raw[399:390]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[399]}},mapped_raw[399:388]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[399]}},mapped_raw[399:386]} : 16'd0;

assign mapped_data[415:400] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[409]}},mapped_raw[409:400]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[411]}},mapped_raw[411:400]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[413]}},mapped_raw[413:400]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[415]}},mapped_raw[415:406]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[415]}},mapped_raw[415:404]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[415]}},mapped_raw[415:402]} : 16'd0;

assign mapped_data[431:416] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[425]}},mapped_raw[425:416]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[427]}},mapped_raw[427:416]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[429]}},mapped_raw[429:416]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[431]}},mapped_raw[431:422]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[431]}},mapped_raw[431:420]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[431]}},mapped_raw[431:418]} : 16'd0;

assign mapped_data[447:432] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[441]}},mapped_raw[441:432]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[443]}},mapped_raw[443:432]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[445]}},mapped_raw[445:432]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[447]}},mapped_raw[447:438]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[447]}},mapped_raw[447:436]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[447]}},mapped_raw[447:434]} : 16'd0;

assign mapped_data[463:448] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[457]}},mapped_raw[457:448]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[459]}},mapped_raw[459:448]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[461]}},mapped_raw[461:448]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[463]}},mapped_raw[463:454]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[463]}},mapped_raw[463:452]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[463]}},mapped_raw[463:450]} : 16'd0;

assign mapped_data[479:464] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[473]}},mapped_raw[473:464]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[475]}},mapped_raw[475:464]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[477]}},mapped_raw[477:464]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[479]}},mapped_raw[479:470]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[479]}},mapped_raw[479:468]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[479]}},mapped_raw[479:466]} : 16'd0;

assign mapped_data[495:480] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[489]}},mapped_raw[489:480]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[491]}},mapped_raw[491:480]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[493]}},mapped_raw[493:480]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[495]}},mapped_raw[495:486]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[495]}},mapped_raw[495:484]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[495]}},mapped_raw[495:482]} : 16'd0;

assign mapped_data[511:496] =
    (sample_fmt == 3'b000) ? {{6{mapped_raw[505]}},mapped_raw[505:496]} :
    (sample_fmt == 3'b001) ? {{4{mapped_raw[507]}},mapped_raw[507:496]} :
    (sample_fmt == 3'b010) ? {{2{mapped_raw[509]}},mapped_raw[509:496]} :
    (sample_fmt == 3'b100) ? {{6{mapped_raw[511]}},mapped_raw[511:502]} :
    (sample_fmt == 3'b101) ? {{4{mapped_raw[511]}},mapped_raw[511:500]} :
    (sample_fmt == 3'b110) ? {{2{mapped_raw[511]}},mapped_raw[511:498]} : 16'd0;


// =====
// 5. FIFO Write Output
// =====
assign fifo_has_two_space    = fifo_wlevel >= 10'd2;
assign normal_write_eligible = block_complete && (smp_mode != 2'd2);
assign ddc_i_write_eligible  = block_is_i && fifo_has_two_space;
assign ddc_q_write_eligible  = block_is_q && ddc_i_accepted_r;
assign fifo_write_eligible   = normal_write_eligible || ddc_i_write_eligible ||
                               ddc_q_write_eligible;
assign ddc_epoch_live        = (smp_mode == 2'd2) && chn_en_afe &&
                               ((rxd_fsm == RXD_SKIP_PREFIX) || (rxd_fsm == RXD_PAYLOAD));
assign ddc_abort_set_evt     = !ddc_abort_afe && ddc_epoch_live &&
                               (!link_ready_afe || !adi_rx_valid);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        ddc_i_accepted_r <= 1'b0;
    end else if (fifo_clr || !upk_vld || !map_vld ||
                 ((rxd_fsm != RXD_SKIP_PREFIX) && (rxd_fsm != RXD_PAYLOAD))) begin
        ddc_i_accepted_r <= 1'b0;
    end else if (block_complete && (smp_mode == 2'd2)) begin
        if (block_is_q) begin
            ddc_i_accepted_r <= 1'b0;
        end else if (fifo_has_two_space) begin
            ddc_i_accepted_r <= 1'b1;
        end else begin
            ddc_i_accepted_r <= 1'b0;
        end
    end else if (smp_mode != 2'd2) begin
        ddc_i_accepted_r <= 1'b0;
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        ddc_abort_afe <= 1'b0;
    else if (fifo_clr)
        ddc_abort_afe <= 1'b0;
    else if (ddc_abort_set_evt)
        ddc_abort_afe <= 1'b1;
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        fifo_wr_data  <= 512'd0;
        fifo_wr_valid <= 1'b0;
    end else begin
        fifo_wr_valid <= 1'b0;
        if (upk_vld && fifo_write_eligible) begin
            fifo_wr_data  <= mapped_data;
            fifo_wr_valid <= 1'b1;
        end
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        data_drop_evt <= 1'b0;
    end else if (fifo_clr) begin
        data_drop_evt <= 1'b0;
    end else if (ddc_abort_set_evt) begin
        data_drop_evt <= 1'b1;
    end else if (upk_vld && block_is_i && !fifo_has_two_space) begin
        data_drop_evt <= 1'b1;
    end else begin
        data_drop_evt <= 1'b0;
    end
end

endmodule

