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

localparam [1:0]                            RXD_IDLE                                     = 2'd0  ;
localparam [1:0]                            RXD_PREF                                     = 2'd1  ;
localparam [1:0]                            RXD_VALID                                    = 2'd2  ;
localparam [1:0]                            RXD_ZERO                                     = 2'd3  ;
localparam [11:0]                           adc_num                                      = 12'd16;

reg [127:0]                                 rxd_buff0                                    ;
reg [127:0]                                 rxd_buff1                                    ;
reg [11:0]                                  prefix_cnt                                   ;
reg [8:0]                                   region_cnt                                   ;
reg                                         rxd_pair_phase                               ;
reg                                         ddc_iq_phase                                 ;
reg [1:0]                                   rxd_fsm                                      ;
reg [1:0]                                   rxd_fsm_nx                                   ;
reg                                         ddc_i_accepted_r                             ;
reg [511:0]                                 mapped_raw                                   ;

wire [511:0]                                mapped_data                                  ;
wire [511:0]                                mapped_data_right                            ;
wire [5:0]                                  dec_int                                      ;
wire [1:0]                                  dec_fra                                      ;
wire                                        upk_trig                                     ;
wire                                        upk_vld                                      ;
wire                                        rxd_clr                                      ;
wire                                        rxd_fsm_idle                                 ;
wire                                        rxd_fsm_pref                                 ;
wire                                        rxd_fsm_valid                                ;
wire                                        rxd_fsm_zero                                 ;
wire [11:0]                                 dec_pref_fra                                 ;
wire [11:0]                                 dec_pref_del                                 ;
wire [11:0]                                 ddc_pref_fra                                 ;
wire [11:0]                                 ddc_pref_del                                 ;
wire [11:0]                                 dec_num                                      ;
wire [11:0]                                 ddc_num                                      ;
wire [11:0]                                 skip_num                                     ;
wire                                        payl_hit                                     ;
wire [8:0]                                  dec_valid_beats                              ;
wire [8:0]                                  dec_zero_beats                               ;
wire [8:0]                                  ddc_valid_beats                              ;
wire [8:0]                                  ddc_zero_beats                               ;
wire [8:0]                                  selected_valid_beats                         ;
wire [8:0]                                  selected_zero_beats                          ;
wire [8:0]                                  selected_region_beats                        ;
wire                                        rxd_valid_beat                               ;
wire                                        rxd_zero_beat                                ;
wire                                        rxd_region_final                             ;
wire                                        rxd_pair_complete                            ;
wire [255:0]                                rxd_concat0                                  ;
wire [255:0]                                rxd_concat1                                  ;
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
// 1. Beat-Aligned Region Reception
// =====
assign dec_int       = dec_m[7:2];
assign dec_fra       = dec_m[1:0];
assign upk_vld       = chn_en_afe && link_ready_afe && adi_rx_valid;
assign upk_trig      = upk_vld && adi_rx_somf[0];
assign rxd_clr       = !upk_vld || fifo_clr;
assign rxd_fsm_idle  = rxd_fsm == RXD_IDLE;
assign rxd_fsm_pref  = rxd_fsm == RXD_PREF;
assign rxd_fsm_valid = rxd_fsm == RXD_VALID;
assign rxd_fsm_zero  = rxd_fsm == RXD_ZERO;

assign dec_pref_fra = (dec_fra == 2'd0) ? (({6'd0,dec_int} << 1) + 12'd23) :
                      (dec_fra == 2'd1) ? (({6'd0,dec_int} << 3) + 12'd25) :
                      (dec_fra == 2'd2) ? (({6'd0,dec_int} << 2) + 12'd25) :
                                           (({6'd0,dec_int} << 3) + 12'd29);
assign dec_pref_del = (dec_del_mode == 2'd1) ? ({4'd0,dec_m} << 2) :
                      (dec_del_mode == 2'd2) ? ({4'd0,dec_m} << 3) : 12'd0;
assign ddc_pref_fra = (dec_fra == 2'd0) ? (({6'd0,dec_int} << 1) + 12'd23) :
                      (dec_fra == 2'd1) ? (({6'd0,dec_int} << 3) + 12'd25) :
                      (dec_fra == 2'd2) ? (({6'd0,dec_int} << 2) + 12'd25) :
                                           (({6'd0,dec_int} << 3) + 12'd29);
assign ddc_pref_del = (dec_del_mode == 2'd1) ? ({4'd0,dec_m} << 2) :
                      (dec_del_mode == 2'd2) ? ({4'd0,dec_m} << 3) : 12'd0;
assign dec_num      = dec_pref_fra + dec_pref_del;
assign ddc_num      = ddc_pref_fra + ddc_pref_del;
assign skip_num     = (smp_mode == 2'd0) ? adc_num :
                      (smp_mode == 2'd1) ? dec_num : ddc_num;
assign payl_hit     = rxd_fsm_pref && ((prefix_cnt + 12'd1) == skip_num);

assign dec_valid_beats = (dec_fra == 2'd0) ? 9'd2 :
                         (dec_fra == 2'd1) ? 9'd8 :
                         (dec_fra == 2'd2) ? 9'd4 : 9'd8;
assign dec_zero_beats  = (dec_fra == 2'd0) ? (({3'd0,dec_int} << 1) - 9'd2) :
                         (dec_fra == 2'd1) ? (({3'd0,dec_int} << 3) - 9'd6) :
                         (dec_fra == 2'd2) ? (({3'd0,dec_int} << 2) - 9'd2) :
                                              (({3'd0,dec_int} << 3) - 9'd2);
assign ddc_valid_beats = (dec_fra == 2'd0) ? 9'd4 : 9'd16;
assign ddc_zero_beats  = (dec_fra == 2'd0) ? (({3'd0,dec_int} << 1) - 9'd4) :
                         (dec_fra == 2'd1) ? (({3'd0,dec_int} << 3) - 9'd14) :
                         (dec_fra == 2'd2) ? (({3'd0,dec_int} << 2) - 9'd6) :
                                              (({3'd0,dec_int} << 3) - 9'd10);
assign selected_valid_beats  = (smp_mode == 2'd0) ? 9'd2 :
                               (smp_mode == 2'd1) ? dec_valid_beats : ddc_valid_beats;
assign selected_zero_beats   = (smp_mode == 2'd0) ? 9'd0 :
                               (smp_mode == 2'd1) ? dec_zero_beats : ddc_zero_beats;
assign selected_region_beats = rxd_fsm_zero ? selected_zero_beats :
                               selected_valid_beats;

// 1. State register
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        rxd_fsm <= #UDLY RXD_IDLE;
    else if (rxd_clr)
        rxd_fsm <= #UDLY RXD_IDLE;
    else
        rxd_fsm <= #UDLY rxd_fsm_nx;
end

// 2. Next-state logic
always @* begin
    case (rxd_fsm)
        RXD_IDLE : if (upk_trig)
                       rxd_fsm_nx = RXD_PREF;
                   else
                       rxd_fsm_nx = RXD_IDLE;
        RXD_PREF : if (payl_hit)
                       rxd_fsm_nx = RXD_VALID;
                   else
                       rxd_fsm_nx = RXD_PREF;
        RXD_VALID: if (rxd_region_final && (selected_zero_beats != 9'd0))
                       rxd_fsm_nx = RXD_ZERO;
                   else
                       rxd_fsm_nx = RXD_VALID;
        RXD_ZERO : if (rxd_region_final)
                       rxd_fsm_nx = RXD_VALID;
                   else
                       rxd_fsm_nx = RXD_ZERO;
        default  : rxd_fsm_nx = RXD_IDLE;
    endcase
end

assign rxd_valid_beat   = (rxd_fsm_pref && payl_hit) || rxd_fsm_valid;
assign rxd_zero_beat    = rxd_fsm_zero;
assign rxd_region_final = (rxd_valid_beat || rxd_zero_beat) &&
                          ((region_cnt + 9'd1) == selected_region_beats);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        prefix_cnt <= 12'd0;
    else if (rxd_clr)
        prefix_cnt <= 12'd0;
    else if (rxd_fsm_pref)
        prefix_cnt <= prefix_cnt + 12'd1;
    else
        prefix_cnt <= 12'd0;
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        region_cnt <= 9'd0;
    else if (rxd_clr || rxd_fsm_idle)
        region_cnt <= 9'd0;
    else if (rxd_valid_beat || rxd_zero_beat) begin
        if (rxd_region_final)
            region_cnt <= 9'd0;
        else
            region_cnt <= region_cnt + 9'd1;
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        rxd_pair_phase <= 1'b0;
    else if (rxd_clr || rxd_fsm_idle || rxd_zero_beat)
        rxd_pair_phase <= 1'b0;
    else if (rxd_valid_beat)
        rxd_pair_phase <= ~rxd_pair_phase;
end

assign rxd_pair_complete = rxd_valid_beat && rxd_pair_phase;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        rxd_buff0 <= 128'd0;
        rxd_buff1 <= 128'd0;
    end else if (rxd_clr) begin
        rxd_buff0 <= 128'd0;
        rxd_buff1 <= 128'd0;
    end else if (rxd_valid_beat && !rxd_pair_phase) begin
        rxd_buff0 <= adi_rx_data[127:0];
        rxd_buff1 <= adi_rx_data[255:128];
    end
end

assign rxd_concat0 = {adi_rx_data[127:0],rxd_buff0};
assign rxd_concat1 = {adi_rx_data[255:128],rxd_buff1};

// =====
// 4. Channel Mapping
// =====
always @* begin
    mapped_raw = 512'd0;
    mapped_raw[15:0]    = rxd_concat0[15:0]     ; mapped_raw[31:16]   = rxd_concat0[143:128];
    mapped_raw[47:32]   = rxd_concat0[31:16]    ; mapped_raw[63:48]   = rxd_concat0[159:144];
    mapped_raw[79:64]   = rxd_concat0[47:32]    ; mapped_raw[95:80]   = rxd_concat0[175:160];
    mapped_raw[111:96]  = rxd_concat0[63:48]    ; mapped_raw[127:112] = rxd_concat0[191:176];
    mapped_raw[143:128] = rxd_concat0[79:64]    ; mapped_raw[159:144] = rxd_concat0[207:192];
    mapped_raw[175:160] = rxd_concat0[95:80]    ; mapped_raw[191:176] = rxd_concat0[223:208];
    mapped_raw[207:192] = rxd_concat0[111:96]   ; mapped_raw[223:208] = rxd_concat0[239:224];
    mapped_raw[239:224] = rxd_concat0[127:112]  ; mapped_raw[255:240] = rxd_concat0[255:240];
    mapped_raw[271:256] = rxd_concat1[15:0]     ; mapped_raw[287:272] = rxd_concat1[143:128];
    mapped_raw[303:288] = rxd_concat1[31:16]    ; mapped_raw[319:304] = rxd_concat1[159:144];
    mapped_raw[335:320] = rxd_concat1[47:32]    ; mapped_raw[351:336] = rxd_concat1[175:160];
    mapped_raw[367:352] = rxd_concat1[63:48]    ; mapped_raw[383:368] = rxd_concat1[191:176];
    mapped_raw[399:384] = rxd_concat1[79:64]    ; mapped_raw[415:400] = rxd_concat1[207:192];
    mapped_raw[431:416] = rxd_concat1[95:80]    ; mapped_raw[447:432] = rxd_concat1[223:208];
    mapped_raw[463:448] = rxd_concat1[111:96]   ; mapped_raw[479:464] = rxd_concat1[239:224];
    mapped_raw[495:480] = rxd_concat1[127:112]  ; mapped_raw[511:496] = rxd_concat1[255:240];
end

// AC9810 provides each signed p-bit sample in the high p bits of its N'=16 container.
// FRAME_FMT=1 keeps that container; FRAME_FMT=0 removes only the documented low-bit padding.
assign mapped_data = frame_fmt ? mapped_raw : mapped_data_right;

assign mapped_data_right[15:0]    =
    (smp_prec == 2'd0) ? {{6{mapped_raw[15]}},mapped_raw[15:6]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[15]}},mapped_raw[15:4]} :
                          {{2{mapped_raw[15]}},mapped_raw[15:2]};
assign mapped_data_right[31:16]   =
    (smp_prec == 2'd0) ? {{6{mapped_raw[31]}},mapped_raw[31:22]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[31]}},mapped_raw[31:20]} :
                          {{2{mapped_raw[31]}},mapped_raw[31:18]};
assign mapped_data_right[47:32]   =
    (smp_prec == 2'd0) ? {{6{mapped_raw[47]}},mapped_raw[47:38]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[47]}},mapped_raw[47:36]} :
                          {{2{mapped_raw[47]}},mapped_raw[47:34]};
assign mapped_data_right[63:48]   =
    (smp_prec == 2'd0) ? {{6{mapped_raw[63]}},mapped_raw[63:54]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[63]}},mapped_raw[63:52]} :
                          {{2{mapped_raw[63]}},mapped_raw[63:50]};
assign mapped_data_right[79:64]   =
    (smp_prec == 2'd0) ? {{6{mapped_raw[79]}},mapped_raw[79:70]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[79]}},mapped_raw[79:68]} :
                          {{2{mapped_raw[79]}},mapped_raw[79:66]};
assign mapped_data_right[95:80]   =
    (smp_prec == 2'd0) ? {{6{mapped_raw[95]}},mapped_raw[95:86]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[95]}},mapped_raw[95:84]} :
                          {{2{mapped_raw[95]}},mapped_raw[95:82]};
assign mapped_data_right[111:96]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[111]}},mapped_raw[111:102]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[111]}},mapped_raw[111:100]} :
                          {{2{mapped_raw[111]}},mapped_raw[111:98]};
assign mapped_data_right[127:112]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[127]}},mapped_raw[127:118]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[127]}},mapped_raw[127:116]} :
                          {{2{mapped_raw[127]}},mapped_raw[127:114]};
assign mapped_data_right[143:128]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[143]}},mapped_raw[143:134]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[143]}},mapped_raw[143:132]} :
                          {{2{mapped_raw[143]}},mapped_raw[143:130]};
assign mapped_data_right[159:144]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[159]}},mapped_raw[159:150]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[159]}},mapped_raw[159:148]} :
                          {{2{mapped_raw[159]}},mapped_raw[159:146]};
assign mapped_data_right[175:160]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[175]}},mapped_raw[175:166]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[175]}},mapped_raw[175:164]} :
                          {{2{mapped_raw[175]}},mapped_raw[175:162]};
assign mapped_data_right[191:176]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[191]}},mapped_raw[191:182]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[191]}},mapped_raw[191:180]} :
                          {{2{mapped_raw[191]}},mapped_raw[191:178]};
assign mapped_data_right[207:192]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[207]}},mapped_raw[207:198]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[207]}},mapped_raw[207:196]} :
                          {{2{mapped_raw[207]}},mapped_raw[207:194]};
assign mapped_data_right[223:208]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[223]}},mapped_raw[223:214]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[223]}},mapped_raw[223:212]} :
                          {{2{mapped_raw[223]}},mapped_raw[223:210]};
assign mapped_data_right[239:224]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[239]}},mapped_raw[239:230]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[239]}},mapped_raw[239:228]} :
                          {{2{mapped_raw[239]}},mapped_raw[239:226]};
assign mapped_data_right[255:240]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[255]}},mapped_raw[255:246]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[255]}},mapped_raw[255:244]} :
                          {{2{mapped_raw[255]}},mapped_raw[255:242]};
assign mapped_data_right[271:256]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[271]}},mapped_raw[271:262]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[271]}},mapped_raw[271:260]} :
                          {{2{mapped_raw[271]}},mapped_raw[271:258]};
assign mapped_data_right[287:272]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[287]}},mapped_raw[287:278]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[287]}},mapped_raw[287:276]} :
                          {{2{mapped_raw[287]}},mapped_raw[287:274]};
assign mapped_data_right[303:288]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[303]}},mapped_raw[303:294]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[303]}},mapped_raw[303:292]} :
                          {{2{mapped_raw[303]}},mapped_raw[303:290]};
assign mapped_data_right[319:304]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[319]}},mapped_raw[319:310]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[319]}},mapped_raw[319:308]} :
                          {{2{mapped_raw[319]}},mapped_raw[319:306]};
assign mapped_data_right[335:320]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[335]}},mapped_raw[335:326]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[335]}},mapped_raw[335:324]} :
                          {{2{mapped_raw[335]}},mapped_raw[335:322]};
assign mapped_data_right[351:336]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[351]}},mapped_raw[351:342]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[351]}},mapped_raw[351:340]} :
                          {{2{mapped_raw[351]}},mapped_raw[351:338]};
assign mapped_data_right[367:352]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[367]}},mapped_raw[367:358]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[367]}},mapped_raw[367:356]} :
                          {{2{mapped_raw[367]}},mapped_raw[367:354]};
assign mapped_data_right[383:368]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[383]}},mapped_raw[383:374]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[383]}},mapped_raw[383:372]} :
                          {{2{mapped_raw[383]}},mapped_raw[383:370]};
assign mapped_data_right[399:384]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[399]}},mapped_raw[399:390]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[399]}},mapped_raw[399:388]} :
                          {{2{mapped_raw[399]}},mapped_raw[399:386]};
assign mapped_data_right[415:400]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[415]}},mapped_raw[415:406]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[415]}},mapped_raw[415:404]} :
                          {{2{mapped_raw[415]}},mapped_raw[415:402]};
assign mapped_data_right[431:416]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[431]}},mapped_raw[431:422]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[431]}},mapped_raw[431:420]} :
                          {{2{mapped_raw[431]}},mapped_raw[431:418]};
assign mapped_data_right[447:432]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[447]}},mapped_raw[447:438]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[447]}},mapped_raw[447:436]} :
                          {{2{mapped_raw[447]}},mapped_raw[447:434]};
assign mapped_data_right[463:448]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[463]}},mapped_raw[463:454]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[463]}},mapped_raw[463:452]} :
                          {{2{mapped_raw[463]}},mapped_raw[463:450]};
assign mapped_data_right[479:464]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[479]}},mapped_raw[479:470]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[479]}},mapped_raw[479:468]} :
                          {{2{mapped_raw[479]}},mapped_raw[479:466]};
assign mapped_data_right[495:480]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[495]}},mapped_raw[495:486]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[495]}},mapped_raw[495:484]} :
                          {{2{mapped_raw[495]}},mapped_raw[495:482]};
assign mapped_data_right[511:496]  =
    (smp_prec == 2'd0) ? {{6{mapped_raw[511]}},mapped_raw[511:502]} :
    (smp_prec == 2'd1) ? {{4{mapped_raw[511]}},mapped_raw[511:500]} :
                          {{2{mapped_raw[511]}},mapped_raw[511:498]};


// =====
// 5. FIFO Write
// =====
assign fifo_has_two_space    = fifo_wlevel >= 10'd2;
assign normal_write_eligible = rxd_pair_complete && (smp_mode != 2'd2);
assign ddc_i_write_eligible  = rxd_pair_complete && (smp_mode == 2'd2) &&
                               !ddc_iq_phase && fifo_has_two_space;
assign ddc_q_write_eligible  = rxd_pair_complete && (smp_mode == 2'd2) &&
                               ddc_iq_phase && ddc_i_accepted_r;
assign fifo_write_eligible   = normal_write_eligible || ddc_i_write_eligible ||
                               ddc_q_write_eligible;
assign ddc_epoch_live        = (smp_mode == 2'd2) && chn_en_afe &&
                               (rxd_fsm_pref || rxd_fsm_valid || rxd_fsm_zero);
assign ddc_abort_set_evt     = !ddc_abort_afe && ddc_epoch_live &&
                               (!link_ready_afe || !adi_rx_valid);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        ddc_i_accepted_r <= 1'b0;
    end else if (rxd_clr ||
                 !(rxd_fsm_pref || rxd_fsm_valid || rxd_fsm_zero)) begin
        ddc_i_accepted_r <= 1'b0;
    end else if (rxd_pair_complete && (smp_mode == 2'd2)) begin
        if (ddc_iq_phase) begin
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
        ddc_iq_phase <= 1'b0;
    else if (rxd_clr || rxd_fsm_idle || rxd_zero_beat)
        ddc_iq_phase <= 1'b0;
    else if (rxd_pair_complete && (smp_mode == 2'd2))
        ddc_iq_phase <= ~ddc_iq_phase;
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
    end else if (rxd_clr) begin
        fifo_wr_valid <= 1'b0;
    end else begin
        fifo_wr_valid <= 1'b0;
        if (upk_vld && !ddc_abort_afe && fifo_write_eligible) begin
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
    end else if (rxd_pair_complete && (smp_mode == 2'd2) && !ddc_iq_phase &&
                 !fifo_has_two_space) begin
        data_drop_evt <= 1'b1;
    end else begin
        data_drop_evt <= 1'b0;
    end
end

endmodule
