`timescale 1ns/1ps

// AC9810 + JESD204B + GTH receive-side behavioral model.
//
// Frozen link configuration:
//   M=16, L=2, N'=16, S=1, F=16, K=16
//   Four octets/lane/JESD_CLK, lane0 in rx_data[31:0].
//
// The GTH portion models only the interface visible to ADC_RXD after 8b/10b
// decoding: lock/reset-done, comma/byte alignment, decoded octets, K flags,
// disparity errors and not-in-table errors.  It does not model analog CDR,
// serial jitter, equalization, DRP, vendor reset timing or encrypted GTH RTL.

module AC9810_MASTER #(
    parameter integer CGS_BEATS       = 352,
    parameter integer GTH_LOCK_BEATS  = 16,
    parameter integer GTH_RESET_BEATS = 24
)(
    input  logic                       jesd_clk,
    input  logic                       jesd_rst_n,
    input  logic                       model_enable,
    input  logic                       sysref,
    input  logic                       sync_n,
    input  logic                       rx_encommalign,
    output logic [63:0]                rx_data,
    output logic [7:0]                 rx_charisk,
    output logic [7:0]                 rx_disperr,
    output logic [7:0]                 rx_notintable,
    output logic                       rx_reset_done,
    output logic                       pll_lock,
    output logic [1:0]                 byte_aligned,
    output logic [2:0]                 model_phase
);

localparam logic [2:0] PHASE_IDLE = 3'd0;
localparam logic [2:0] PHASE_CGS  = 3'd1;
localparam logic [2:0] PHASE_ILAS = 3'd2;
localparam logic [2:0] PHASE_DATA = 3'd3;

logic [15:0] pattern_i [0:31];
logic [15:0] pattern_q [0:31];

logic [63:0] tx_data;
logic [7:0]  tx_charisk;
logic [63:0] gth_data_r;
logic [7:0]  gth_charisk_r;
logic [7:0]  inject_disperr_r;
logic [7:0]  inject_notintable_r;
logic        force_link_down_r;
logic        sysref_seen_r;
logic [2:0]  stream_mode_r;
logic        q_select_r;
logic        prefix_active_r;

integer gth_count_r;
integer cgs_count_r;
integer ilas_multiframe_r;
integer ilas_beat_r;
integer prefix_words_r;
integer prefix_word_index_r;
integer data_word_index_r;
integer block_count_r;
integer init_index;

function automatic [31:0] ilas_lane_word(
    input integer multiframe,
    input integer beat
);
    logic [7:0] b0;
    logic [7:0] b1;
    logic [7:0] b2;
    logic [7:0] b3;
    begin
        b0 = (multiframe * 17 + beat * 4 + 0) & 8'hff;
        b1 = (multiframe * 17 + beat * 4 + 1) & 8'hff;
        b2 = (multiframe * 17 + beat * 4 + 2) & 8'hff;
        b3 = (multiframe * 17 + beat * 4 + 3) & 8'hff;
        if (beat == 0)
            b0 = 8'h1c; // K28.0 /R/
        if (beat == 63)
            b3 = 8'h7c; // K28.3 /A/
        ilas_lane_word = {b3,b2,b1,b0};
    end
endfunction

function automatic [15:0] cml_word(
    input logic lane,
    input integer word_index,
    input logic q_select
);
    integer channel_index;
    begin
        if (!lane) begin
            if (word_index < 8)
                channel_index = word_index * 2;
            else
                channel_index = (word_index - 8) * 2 + 1;
        end else begin
            if (word_index < 8)
                channel_index = 16 + word_index * 2;
            else
                channel_index = 16 + (word_index - 8) * 2 + 1;
        end
        cml_word = q_select ? pattern_q[channel_index] : pattern_i[channel_index];
    end
endfunction

function automatic [31:0] data_lane_word(
    input logic lane
);
    logic [15:0] word0;
    logic [15:0] word1;
    begin
        if (prefix_active_r) begin
            if (prefix_word_index_r < 32) begin
                word0 = lane ? 16'h2468 : 16'h1357;
                word1 = lane ? 16'h2468 : 16'h1357;
            end else begin
                word0 = 16'h0000;
                word1 = 16'h0000;
            end
        end else begin
            word0 = cml_word(lane, data_word_index_r,     q_select_r);
            word1 = cml_word(lane, data_word_index_r + 1, q_select_r);
        end
        data_lane_word = {word1,word0};
    end
endfunction

task automatic load_i_pattern(input string pattern_path);
    begin
        $display("AC9810_MODEL: loading I/real pattern %s", pattern_path);
        $readmemh(pattern_path, pattern_i);
    end
endtask

task automatic load_q_pattern(input string pattern_path);
    begin
        $display("AC9810_MODEL: loading Q pattern %s", pattern_path);
        $readmemh(pattern_path, pattern_q);
    end
endtask

task automatic set_i_sample(
    input integer      channel,
    input logic [15:0] sample
);
    begin
        if ((channel < 0) || (channel > 31))
            $fatal(1, "AC9810_MODEL: I channel index out of range: %0d", channel);
        pattern_i[channel] = sample;
    end
endtask

task automatic set_q_sample(
    input integer      channel,
    input logic [15:0] sample
);
    begin
        if ((channel < 0) || (channel > 31))
            $fatal(1, "AC9810_MODEL: Q channel index out of range: %0d", channel);
        pattern_q[channel] = sample;
    end
endtask

task automatic configure_stream(
    input integer stream_mode,
    input integer dec_m,
    input integer dec_del_mode
);
    integer dec_n;
    integer zero_words;
    begin
        stream_mode_r = stream_mode[2:0];
        if (stream_mode == 0) begin
            zero_words = 96;
        end else begin
            dec_n = dec_m >> 2;
            case (dec_m & 3)
                0: zero_words = (dec_n << 4) + 152;
                1: zero_words = (dec_n << 6) + 168;
                2: zero_words = (dec_n << 5) + 168;
                default: zero_words = (dec_n << 6) + 200;
            endcase
            case (dec_del_mode)
                1: zero_words = zero_words + (dec_m << 5);
                2: zero_words = zero_words + (dec_m << 6);
                default: zero_words = zero_words;
            endcase
        end
        prefix_words_r = 32 + zero_words;
        $display("AC9810_MODEL: stream_mode=%0d prefix_words/lane=%0d", stream_mode, prefix_words_r);
    end
endtask

task automatic inject_disparity(input logic [7:0] octet_mask);
    begin
        inject_disperr_r = octet_mask;
    end
endtask

task automatic inject_notintable(input logic [7:0] octet_mask);
    begin
        inject_notintable_r = octet_mask;
    end
endtask

task automatic drop_link(input integer jesd_cycles);
    begin
        force_link_down_r = 1'b1;
        repeat (jesd_cycles) @(posedge jesd_clk);
        force_link_down_r = 1'b0;
    end
endtask

initial begin
    stream_mode_r       = 3'd0;
    prefix_words_r      = 128;
    inject_disperr_r    = 8'd0;
    inject_notintable_r = 8'd0;
    force_link_down_r   = 1'b0;
    for (init_index = 0; init_index < 32; init_index = init_index + 1) begin
        pattern_i[init_index] = init_index + 1;
        pattern_q[init_index] = 16'h0100 + init_index;
    end
end

always_comb begin
    tx_data    = 64'd0;
    tx_charisk = 8'd0;
    case (model_phase)
        PHASE_CGS: begin
            tx_data    = 64'hbcbcbcbc_bcbcbcbc;
            tx_charisk = 8'hff;
        end
        PHASE_ILAS: begin
            tx_data = {ilas_lane_word(ilas_multiframe_r, ilas_beat_r),
                       ilas_lane_word(ilas_multiframe_r, ilas_beat_r)};
            if (ilas_beat_r == 0)
                tx_charisk = 8'h11;
            else if (ilas_beat_r == 63)
                tx_charisk = 8'h88;
        end
        PHASE_DATA: begin
            tx_data = {data_lane_word(1'b1),data_lane_word(1'b0)};
        end
        default: begin
            tx_data    = 64'd0;
            tx_charisk = 8'd0;
        end
    endcase
end

// AC9810/JESD204B transmitter state.  SYSREF is captured during CGS; after
// the fixed CGS dwell the model emits four K=16 ILAS multiframes, then data.
always_ff @(posedge jesd_clk or negedge jesd_rst_n) begin
    if (!jesd_rst_n) begin
        model_phase         <= PHASE_IDLE;
        sysref_seen_r       <= 1'b0;
        cgs_count_r         <= 0;
        ilas_multiframe_r   <= 0;
        ilas_beat_r         <= 0;
        prefix_active_r     <= 1'b1;
        prefix_word_index_r <= 0;
        data_word_index_r   <= 0;
        block_count_r       <= 0;
        q_select_r          <= 1'b0;
    end else if (!model_enable || force_link_down_r || !rx_reset_done || !pll_lock) begin
        model_phase         <= PHASE_IDLE;
        sysref_seen_r       <= 1'b0;
        cgs_count_r         <= 0;
        ilas_multiframe_r   <= 0;
        ilas_beat_r         <= 0;
        prefix_active_r     <= 1'b1;
        prefix_word_index_r <= 0;
        data_word_index_r   <= 0;
        block_count_r       <= 0;
        q_select_r          <= 1'b0;
    end else begin
        if (sysref)
            sysref_seen_r <= 1'b1;
        case (model_phase)
            PHASE_IDLE: begin
                model_phase <= PHASE_CGS;
                cgs_count_r <= 0;
            end
            PHASE_CGS: begin
                if ((cgs_count_r >= CGS_BEATS - 1) && sysref_seen_r) begin
                    model_phase       <= PHASE_ILAS;
                    ilas_multiframe_r <= 0;
                    ilas_beat_r       <= 0;
                end else begin
                    cgs_count_r <= cgs_count_r + 1;
                end
            end
            PHASE_ILAS: begin
                if (ilas_beat_r == 63) begin
                    ilas_beat_r <= 0;
                    if (ilas_multiframe_r == 3) begin
                        model_phase         <= PHASE_DATA;
                        ilas_multiframe_r   <= 0;
                        prefix_active_r     <= 1'b1;
                        prefix_word_index_r <= 0;
                        data_word_index_r   <= 0;
                        block_count_r       <= 0;
                        q_select_r          <= 1'b0;
                    end else begin
                        ilas_multiframe_r <= ilas_multiframe_r + 1;
                    end
                end else begin
                    ilas_beat_r <= ilas_beat_r + 1;
                end
            end
            PHASE_DATA: begin
                if (!sync_n) begin
                    model_phase         <= PHASE_CGS;
                    sysref_seen_r       <= 1'b0;
                    cgs_count_r         <= 0;
                    prefix_active_r     <= 1'b1;
                    prefix_word_index_r <= 0;
                    data_word_index_r   <= 0;
                    q_select_r          <= 1'b0;
                end else if (prefix_active_r) begin
                    if (prefix_word_index_r + 2 >= prefix_words_r) begin
                        prefix_active_r     <= 1'b0;
                        prefix_word_index_r <= 0;
                        data_word_index_r   <= 0;
                    end else begin
                        prefix_word_index_r <= prefix_word_index_r + 2;
                    end
                end else if (data_word_index_r == 14) begin
                    data_word_index_r <= 0;
                    block_count_r     <= block_count_r + 1;
                    if (stream_mode_r == 2)
                        q_select_r <= ~q_select_r;
                end else begin
                    data_word_index_r <= data_word_index_r + 2;
                end
            end
            default: model_phase <= PHASE_IDLE;
        endcase
    end
end

// GTH-visible status and two-cycle decoded parallel-data latency.  This is a
// plain procedural block because error-injection tasks deliberately write the
// pending masks between clocks; always_ff would reject that testbench usage.
always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if (!jesd_rst_n) begin
        gth_count_r     <= 0;
        pll_lock        <= 1'b0;
        rx_reset_done   <= 1'b0;
        byte_aligned    <= 2'b00;
        gth_data_r      <= 64'd0;
        gth_charisk_r   <= 8'd0;
        rx_data         <= 64'd0;
        rx_charisk      <= 8'd0;
        rx_disperr      <= 8'd0;
        rx_notintable   <= 8'd0;
    end else if (!model_enable || force_link_down_r) begin
        gth_count_r     <= 0;
        pll_lock        <= 1'b0;
        rx_reset_done   <= 1'b0;
        byte_aligned    <= 2'b00;
        gth_data_r      <= 64'd0;
        gth_charisk_r   <= 8'd0;
        rx_data         <= 64'd0;
        rx_charisk      <= 8'd0;
        rx_disperr      <= 8'd0;
        rx_notintable   <= 8'd0;
    end else begin
        if (gth_count_r < GTH_RESET_BEATS + 1)
            gth_count_r <= gth_count_r + 1;
        if (gth_count_r >= GTH_LOCK_BEATS - 1)
            pll_lock <= 1'b1;
        if (gth_count_r >= GTH_RESET_BEATS - 1)
            rx_reset_done <= 1'b1;
        if (rx_encommalign && (tx_charisk == 8'hff) && (tx_data == 64'hbcbcbcbc_bcbcbcbc))
            byte_aligned <= 2'b11;

        gth_data_r    <= tx_data;
        gth_charisk_r <= tx_charisk;
        rx_data       <= gth_data_r;
        rx_charisk    <= gth_charisk_r;
        rx_disperr    <= inject_disperr_r;
        rx_notintable <= inject_notintable_r;
        inject_disperr_r    <= 8'd0;
        inject_notintable_r <= 8'd0;
    end
end

endmodule
