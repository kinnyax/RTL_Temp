`timescale 1ns / 1ps

module ADC_RXD(
    input  wire                             jesd_clk                                     ,
    input  wire                             jesd_rst_n                                   ,
    input  wire                             afe_clk                                      ,
    input  wire                             afe_rst_n                                    ,
    input  wire                             sysref                                       ,
    input  wire                             chn_en_jesd                                  ,
    input  wire                             chn_en_afe                                   ,
    input  wire                             link_ready_afe                               ,
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
    output wire [1:0]                       jesd_state                                   ,
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
reg [255:0]                                 lane0_history_r                               ;
reg [255:0]                                 lane1_history_r                               ;
reg [15:0]                                  word_epoch_r                                  ;
reg                                         epoch_valid_r                                 ;
reg                                         payload_active_r                              ;
reg [15:0]                                  payload_pos_r                                 ;
reg                                         ddc_i_accepted_r                              ;
reg [511:0]                                 mapped_raw                                    ;
wire [511:0]                                mapped_data                                   ;
wire [7:0]                                  dec_n                                         ;
reg [15:0]                                  zero_words                                    ;
reg [15:0]                                  payload_start_word                            ;
reg [15:0]                                  period_words                                  ;
reg [255:0]                                 lane0_block_raw                               ;
reg [255:0]                                 lane1_block_raw                               ;
reg [127:0]                                 terminal_words                                ;
reg [127:0]                                 q_terminal_words                              ;

wire                                        marker_present                               ;
wire                                        epoch_active                                 ;
wire                                        map_config_valid                             ;
wire                                        initial_payload_hit                          ;
wire [15:0]                                 payload_pos_advance                          ;
wire [15:0]                                 pos_w0                                       ;
wire [15:0]                                 pos_w1                                       ;
wire [15:0]                                 pos_w2                                       ;
wire [15:0]                                 pos_w3                                       ;
wire [15:0]                                 pos_w4                                       ;
wire [15:0]                                 pos_w5                                       ;
wire [15:0]                                 pos_w6                                       ;
wire [15:0]                                 pos_w7                                       ;
wire [15:0]                                 terminal_w0                                  ;
wire [15:0]                                 terminal_w1                                  ;
wire [15:0]                                 terminal_w2                                  ;
wire [15:0]                                 terminal_w3                                  ;
wire [15:0]                                 terminal_w4                                  ;
wire [15:0]                                 terminal_w5                                  ;
wire [15:0]                                 terminal_w6                                  ;
wire [15:0]                                 terminal_w7                                  ;
wire [15:0]                                 q_terminal_w0                                ;
wire [15:0]                                 q_terminal_w1                                ;
wire [15:0]                                 q_terminal_w2                                ;
wire [15:0]                                 q_terminal_w3                                ;
wire                                        end_match_w0                                 ;
wire                                        end_match_w1                                 ;
wire                                        end_match_w2                                 ;
wire                                        end_match_w3                                 ;
wire                                        end_match_w4                                 ;
wire                                        end_match_w5                                 ;
wire                                        end_match_w6                                 ;
wire                                        end_match_w7                                 ;
wire                                        q_match_w0                                   ;
wire                                        q_match_w1                                   ;
wire                                        q_match_w2                                   ;
wire                                        q_match_w3                                   ;
wire                                        q_match_w4                                   ;
wire                                        q_match_w5                                   ;
wire                                        q_match_w6                                   ;
wire                                        q_match_w7                                   ;
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

wire                                        jesd_core_reset                              ;
wire                                        device_core_reset                            ;
wire [255:0]                                adi_rx_data                                  ;
wire                                        adi_rx_valid                                 ;
wire [15:0]                                 adi_rx_sof                                   ;
wire [15:0]                                 adi_rx_eof                                   ;
wire [15:0]                                 adi_rx_somf                                  ;
wire [15:0]                                 adi_rx_eomf                                  ;
wire                                        adi_sync_n                                   ;
wire                                        adi_encommalign                              ;
wire [1:0]                                  adi_lane_ifs_ready                           ;
wire [3:0]                                  adi_lane_cgs_state                           ;
wire [1:0]                                  adi_ilas_valid                               ;
wire [3:0]                                  adi_ilas_addr                                ;
wire [63:0]                                 adi_ilas_data                                ;
wire [1:0]                                  adi_status_state                             ;
wire                                        adi_frame_error                              ;
wire                                        adi_unexpected_lane_error                    ;
wire                                        adi_sysref_error                             ;
wire                                        adi_sysref_seen                              ;
wire [63:0]                                 adi_err_statistics                           ;
wire [1:0]                                  phy_disparity_level                          ;
wire [1:0]                                  phy_notintable_level                         ;
wire                                        link_error_level                             ;
reg [1:0]                                   phy_disparity_r                              ;
reg [1:0]                                   phy_notintable_r                             ;
reg                                         link_error_r                                 ;

// =====
// 1. ADI JESD204 RX
// =====
assign jesd_core_reset      = ~jesd_rst_n | ~chn_en_jesd |
                               ~phy_rx_reset_done | ~phy_pll_lock;
assign device_core_reset    = ~afe_rst_n | ~chn_en_afe;

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
    .rx_eof                             (adi_rx_eof                                    ),
    .rx_sof                             (adi_rx_sof                                    ),
    .rx_eomf                            (adi_rx_eomf                                   ),
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
    .status_err_statistics_cnt          (adi_err_statistics                            ),
    .ilas_config_valid                  (adi_ilas_valid                                ),
    .ilas_config_addr                   (adi_ilas_addr                                 ),
    .ilas_config_data                   (adi_ilas_data                                 ),
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
assign jesd_state           = chn_en_jesd ? adi_status_state : 2'd0;
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
assign marker_present        = adi_rx_somf[0];
assign epoch_active          = epoch_valid_r | marker_present;
assign dec_n                 = {2'b00,dec_m[7:2]};
assign map_config_valid      = (smp_prec != 2'd3) &&
                               ((smp_mode == 2'd0) ||
                                (((smp_mode == 2'd1) || (smp_mode == 2'd2)) &&
                                 (dec_m >= 8'd32) && (dec_m <= 8'd96) &&
                                 (dec_del_mode != 2'd3)));

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        word_epoch_r  <= 16'd0;
        epoch_valid_r <= 1'b0;
    end else if (!chn_en_afe || !link_ready_afe || !adi_rx_valid) begin
        word_epoch_r  <= 16'd0;
        epoch_valid_r <= 1'b0;
    end else if (adi_rx_valid && !epoch_valid_r && marker_present) begin
        word_epoch_r  <= 16'd8;
        epoch_valid_r <= 1'b1;
    end else if (adi_rx_valid && epoch_valid_r) begin
        word_epoch_r <= word_epoch_r + 16'd8;
    end
end

always @* begin
    zero_words = 16'd0;
    if (smp_mode == 2'd0) begin
        zero_words = 16'd96;
    end else begin
        case (dec_m[1:0])
            2'd0: zero_words = ({8'd0,dec_n} << 4) + 16'd152;
            2'd1: zero_words = ({8'd0,dec_n} << 6) + 16'd168;
            2'd2: zero_words = ({8'd0,dec_n} << 5) + 16'd168;
            default: zero_words = ({8'd0,dec_n} << 6) + 16'd200;
        endcase
        case (dec_del_mode)
            2'd1: zero_words = zero_words + ({8'd0,dec_m} << 5);
            2'd2: zero_words = zero_words + ({8'd0,dec_m} << 6);
            default: zero_words = zero_words;
        endcase
    end
end

always @* begin
    payload_start_word = 16'd32 + zero_words;
    period_words       = 16'd16;
    case (smp_mode)
        2'd1: begin
            case (dec_m[1:0])
                2'd0   : period_words = {8'd0,dec_n} << 5;
                2'd1   : period_words = ({8'd0,dec_n} << 6) + 16'd16;
                2'd2   : period_words = ({8'd0,dec_n} << 6) + 16'd34;
                default: period_words = ({8'd0,dec_n} << 6) + 16'd48;
            endcase
        end
        2'd2: begin
            case (dec_m[1:0])
                2'd0   : period_words = {8'd0,dec_n} << 4;
                2'd1   : period_words = ({8'd0,dec_n} << 6) + 16'd16;
                2'd2   : period_words = ({8'd0,dec_n} << 5) + 16'd80;
                default: period_words = ({8'd0,dec_n} << 6) + 16'd48;
            endcase
        end
        default: period_words = 16'd16;
    endcase
end

assign initial_payload_hit    = adi_rx_valid && epoch_valid_r && !payload_active_r &&
                                (word_epoch_r == payload_start_word);
assign payload_pos_advance    = ((payload_pos_r + 16'd8) >= period_words) ?
                                ((payload_pos_r + 16'd8) - period_words) :
                                (payload_pos_r + 16'd8);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        payload_active_r <= 1'b0;
        payload_pos_r    <= 16'd0;
    end else if (!chn_en_afe || !link_ready_afe || !adi_rx_valid) begin
        payload_active_r <= 1'b0;
        payload_pos_r    <= 16'd0;
    end else if (adi_rx_valid && epoch_active && !payload_active_r &&
                 initial_payload_hit && map_config_valid) begin
        payload_active_r <= 1'b1;
        payload_pos_r    <= 16'd8;
    end else if (adi_rx_valid && epoch_active && payload_active_r) begin
        payload_pos_r <= payload_pos_advance;
    end
end

assign pos_w0 = payload_pos_r;
assign pos_w1 = (pos_w0 == (period_words - 16'd1)) ? 16'd0 : (pos_w0 + 16'd1);
assign pos_w2 = (pos_w1 == (period_words - 16'd1)) ? 16'd0 : (pos_w1 + 16'd1);
assign pos_w3 = (pos_w2 == (period_words - 16'd1)) ? 16'd0 : (pos_w2 + 16'd1);
assign pos_w4 = (pos_w3 == (period_words - 16'd1)) ? 16'd0 : (pos_w3 + 16'd1);
assign pos_w5 = (pos_w4 == (period_words - 16'd1)) ? 16'd0 : (pos_w4 + 16'd1);
assign pos_w6 = (pos_w5 == (period_words - 16'd1)) ? 16'd0 : (pos_w5 + 16'd1);
assign pos_w7 = (pos_w6 == (period_words - 16'd1)) ? 16'd0 : (pos_w6 + 16'd1);

always @* begin
    terminal_words   = {8{16'hffff}};
    q_terminal_words = {8{16'hffff}};
    case (smp_mode)
        2'd0: begin
            terminal_words[15:0] = 16'd15;
        end
        2'd1: begin
            case (dec_m[1:0])
                2'd0: begin
                    terminal_words[15:0]  = 16'd15;
                    terminal_words[31:16] = ({8'd0,dec_n} << 4) + 16'd15;
                end
                2'd1: begin
                    terminal_words[15:0]   = 16'd15;
                    terminal_words[31:16]  = 16'd31;
                    terminal_words[47:32]  = 16'd47;
                    terminal_words[63:48]  = 16'd63;
                end
                2'd2: begin
                    terminal_words[15:0]   = 16'd15;
                    terminal_words[31:16]  = 16'd31;
                    terminal_words[47:32]  = ({8'd0,dec_n} << 5) + 16'd32;
                    terminal_words[63:48]  = ({8'd0,dec_n} << 5) + 16'd48;
                end
                default: begin
                    terminal_words[15:0]   = 16'd15;
                    terminal_words[31:16]  = 16'd31;
                    terminal_words[47:32]  = 16'd47;
                    terminal_words[63:48]  = 16'd63;
                end
            endcase
        end
        2'd2: begin
            terminal_words[15:0]  = 16'd15;
            terminal_words[31:16] = 16'd31;
            q_terminal_words[15:0] = 16'd31;
            if (dec_m[1:0] != 2'd0) begin
                terminal_words[47:32]   = 16'd47;
                terminal_words[63:48]   = 16'd63;
                terminal_words[79:64]   = 16'd79;
                terminal_words[95:80]   = 16'd95;
                terminal_words[111:96]  = 16'd111;
                terminal_words[127:112] = 16'd127;
                q_terminal_words[31:16] = 16'd63;
                q_terminal_words[47:32] = 16'd95;
                q_terminal_words[63:48] = 16'd127;
            end
        end
        default: begin
            terminal_words   = {8{16'hffff}};
            q_terminal_words = {8{16'hffff}};
        end
    endcase
end

assign terminal_w0   = terminal_words[15:0];
assign terminal_w1   = terminal_words[31:16];
assign terminal_w2   = terminal_words[47:32];
assign terminal_w3   = terminal_words[63:48];
assign terminal_w4   = terminal_words[79:64];
assign terminal_w5   = terminal_words[95:80];
assign terminal_w6   = terminal_words[111:96];
assign terminal_w7   = terminal_words[127:112];
assign q_terminal_w0 = q_terminal_words[15:0];
assign q_terminal_w1 = q_terminal_words[31:16];
assign q_terminal_w2 = q_terminal_words[47:32];
assign q_terminal_w3 = q_terminal_words[63:48];

assign end_match_w0 = map_config_valid && payload_active_r &&
                      ((pos_w0 == terminal_w0) || (pos_w0 == terminal_w1) ||
                       (pos_w0 == terminal_w2) || (pos_w0 == terminal_w3) ||
                       (pos_w0 == terminal_w4) || (pos_w0 == terminal_w5) ||
                       (pos_w0 == terminal_w6) || (pos_w0 == terminal_w7));
assign end_match_w1 = map_config_valid && payload_active_r &&
                      ((pos_w1 == terminal_w0) || (pos_w1 == terminal_w1) ||
                       (pos_w1 == terminal_w2) || (pos_w1 == terminal_w3) ||
                       (pos_w1 == terminal_w4) || (pos_w1 == terminal_w5) ||
                       (pos_w1 == terminal_w6) || (pos_w1 == terminal_w7));
assign end_match_w2 = map_config_valid && payload_active_r &&
                      ((pos_w2 == terminal_w0) || (pos_w2 == terminal_w1) ||
                       (pos_w2 == terminal_w2) || (pos_w2 == terminal_w3) ||
                       (pos_w2 == terminal_w4) || (pos_w2 == terminal_w5) ||
                       (pos_w2 == terminal_w6) || (pos_w2 == terminal_w7));
assign end_match_w3 = map_config_valid && payload_active_r &&
                      ((pos_w3 == terminal_w0) || (pos_w3 == terminal_w1) ||
                       (pos_w3 == terminal_w2) || (pos_w3 == terminal_w3) ||
                       (pos_w3 == terminal_w4) || (pos_w3 == terminal_w5) ||
                       (pos_w3 == terminal_w6) || (pos_w3 == terminal_w7));
assign end_match_w4 = map_config_valid && payload_active_r &&
                      ((pos_w4 == terminal_w0) || (pos_w4 == terminal_w1) ||
                       (pos_w4 == terminal_w2) || (pos_w4 == terminal_w3) ||
                       (pos_w4 == terminal_w4) || (pos_w4 == terminal_w5) ||
                       (pos_w4 == terminal_w6) || (pos_w4 == terminal_w7));
assign end_match_w5 = map_config_valid && payload_active_r &&
                      ((pos_w5 == terminal_w0) || (pos_w5 == terminal_w1) ||
                       (pos_w5 == terminal_w2) || (pos_w5 == terminal_w3) ||
                       (pos_w5 == terminal_w4) || (pos_w5 == terminal_w5) ||
                       (pos_w5 == terminal_w6) || (pos_w5 == terminal_w7));
assign end_match_w6 = map_config_valid && payload_active_r &&
                      ((pos_w6 == terminal_w0) || (pos_w6 == terminal_w1) ||
                       (pos_w6 == terminal_w2) || (pos_w6 == terminal_w3) ||
                       (pos_w6 == terminal_w4) || (pos_w6 == terminal_w5) ||
                       (pos_w6 == terminal_w6) || (pos_w6 == terminal_w7));
assign end_match_w7 = map_config_valid && payload_active_r &&
                      ((pos_w7 == terminal_w0) || (pos_w7 == terminal_w1) ||
                       (pos_w7 == terminal_w2) || (pos_w7 == terminal_w3) ||
                       (pos_w7 == terminal_w4) || (pos_w7 == terminal_w5) ||
                       (pos_w7 == terminal_w6) || (pos_w7 == terminal_w7));

assign q_match_w0 = (pos_w0 == q_terminal_w0) || (pos_w0 == q_terminal_w1) ||
                    (pos_w0 == q_terminal_w2) || (pos_w0 == q_terminal_w3);
assign q_match_w1 = (pos_w1 == q_terminal_w0) || (pos_w1 == q_terminal_w1) ||
                    (pos_w1 == q_terminal_w2) || (pos_w1 == q_terminal_w3);
assign q_match_w2 = (pos_w2 == q_terminal_w0) || (pos_w2 == q_terminal_w1) ||
                    (pos_w2 == q_terminal_w2) || (pos_w2 == q_terminal_w3);
assign q_match_w3 = (pos_w3 == q_terminal_w0) || (pos_w3 == q_terminal_w1) ||
                    (pos_w3 == q_terminal_w2) || (pos_w3 == q_terminal_w3);
assign q_match_w4 = (pos_w4 == q_terminal_w0) || (pos_w4 == q_terminal_w1) ||
                    (pos_w4 == q_terminal_w2) || (pos_w4 == q_terminal_w3);
assign q_match_w5 = (pos_w5 == q_terminal_w0) || (pos_w5 == q_terminal_w1) ||
                    (pos_w5 == q_terminal_w2) || (pos_w5 == q_terminal_w3);
assign q_match_w6 = (pos_w6 == q_terminal_w0) || (pos_w6 == q_terminal_w1) ||
                    (pos_w6 == q_terminal_w2) || (pos_w6 == q_terminal_w3);
assign q_match_w7 = (pos_w7 == q_terminal_w0) || (pos_w7 == q_terminal_w1) ||
                    (pos_w7 == q_terminal_w2) || (pos_w7 == q_terminal_w3);

assign block_complete   = end_match_w0 || end_match_w1 || end_match_w2 || end_match_w3 ||
                         end_match_w4 || end_match_w5 || end_match_w6 || end_match_w7;
assign block_is_q       = block_complete &&
                         (q_match_w0 || q_match_w1 || q_match_w2 || q_match_w3 ||
                          q_match_w4 || q_match_w5 || q_match_w6 || q_match_w7);
assign block_is_i       = block_complete && (smp_mode == 2'd2) && !block_is_q;
assign block_end_offset = end_match_w0 ? 3'd0 : end_match_w1 ? 3'd1 :
                          end_match_w2 ? 3'd2 : end_match_w3 ? 3'd3 :
                          end_match_w4 ? 3'd4 : end_match_w5 ? 3'd5 :
                          end_match_w6 ? 3'd6 : 3'd7;

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
    end else if (!chn_en_afe || !link_ready_afe || !adi_rx_valid) begin
        lane0_history_r <= 256'd0;
        lane1_history_r <= 256'd0;
    end else if (adi_rx_valid && epoch_active) begin
        lane0_history_r <= {adi_rx_data[127:0],lane0_history_r[255:128]};
        lane1_history_r <= {adi_rx_data[255:128],lane1_history_r[255:128]};
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
assign ddc_epoch_live        = (smp_mode == 2'd2) && chn_en_afe && epoch_valid_r;
assign ddc_abort_set_evt     = !ddc_abort_afe && ddc_epoch_live &&
                               (!link_ready_afe || !adi_rx_valid);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        ddc_i_accepted_r <= 1'b0;
    end else if (fifo_clr || !chn_en_afe || !link_ready_afe || !adi_rx_valid ||
                 !epoch_valid_r) begin
        ddc_i_accepted_r <= 1'b0;
    end else if (adi_rx_valid && block_complete && (smp_mode == 2'd2)) begin
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
        if (chn_en_afe && link_ready_afe && adi_rx_valid && fifo_write_eligible) begin
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
    end else if (adi_rx_valid && block_is_i && !fifo_has_two_space) begin
        data_drop_evt <= 1'b1;
    end else begin
        data_drop_evt <= 1'b0;
    end
end

endmodule

