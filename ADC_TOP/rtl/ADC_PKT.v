`timescale 1ns / 1ps

// Fixed-length ADC packet and AXI-Stream producer.
module ADC_PKT(
    // ADC clock domain
    input  wire                             adc_clk                                      ,
    input  wire                             adc_rst_n                                    ,

    // Channel and packet configuration
    input  wire [2:0]                       afe_id                                       ,
    input  wire                             afe_en                                       ,
    input  wire [1:0]                       smp_prec                                     ,
    input  wire [1:0]                       smp_mode                                     ,
    input  wire [7:0]                       dec_m                                        ,
    input  wire                             link_ready                                   ,

    // FIFO read interface
    input  wire [511:0]                     fifo_data                                    ,
    input  wire                             fifo_empty                                   ,
    input  wire [9:0]                       fifo_level                                   ,
    output reg                              fifo_rd_inc                                  ,

    // AXIS output interface
    output reg  [511:0]                     m_axis_tdata                                 ,
    output reg  [63:0]                      m_axis_tkeep                                 ,
    output reg                              m_axis_tvalid                                ,
    output reg                              m_axis_tlast                                 ,
    input  wire                             m_axis_tready                                ,

    // Channel status
    output reg                              chn_en_eff                                   ,
    output wire                             afe_idle
);

parameter                                   UDLY                                         = 1        ;

localparam [1:0]                            PKT_IDLE                                     = 2'd0     ;
localparam [1:0]                            PKT_CRC                                      = 2'd1     ;
localparam [1:0]                            PKT_HEADER                                   = 2'd2     ;
localparam [1:0]                            PKT_PAYLOAD                                  = 2'd3     ;

reg      [1:0]                              pkt_fsm                                      ;
reg      [1:0]                              pkt_fsm_nx                                   ;
reg      [15:0]                             crc_r                                        ;
reg      [5:0]                              crc_byte_cnt                                 ;
reg      [2:0]                              crc_bit_cnt                                  ;
reg      [31:0]                             packet_seq_cnt                               ;
reg      [8:0]                              payload_cnt                                  ;
reg      [511:0]                            header_data                                  ;
reg      [7:0]                              crc_byte_data                                ;
reg      [7:0]                              precision_byte                               ;

wire                                        packet_start                                 ;
wire                                        crc_done                                     ;
wire                                        crc_feedback                                 ;
wire                                        axis_handshake                               ;
wire                                        packet_done                                  ;
wire                                        pkt_fsm_idle                                 ;
wire                                        pkt_fsm_crc                                  ;
wire                                        pkt_fsm_header                               ;
wire                                        pkt_fsm_payload                              ;
wire                                        payload_cnt_clr                              ;
wire                                        payload_cnt_inc                              ;
wire                                        packet_seq_inc                               ;
wire                                        crc_init                                     ;
wire                                        crc_upd                                      ;
wire                                        crc_bit_clr                                  ;
wire                                        crc_bit_inc                                  ;
wire                                        crc_byte_inc                                 ;

assign pkt_fsm_idle    = (pkt_fsm == PKT_IDLE);
assign pkt_fsm_crc     = (pkt_fsm == PKT_CRC);
assign pkt_fsm_header  = (pkt_fsm == PKT_HEADER);
assign pkt_fsm_payload = (pkt_fsm == PKT_PAYLOAD);
assign packet_start    = pkt_fsm_idle && chn_en_eff && afe_en &&
                         link_ready && (fifo_level >= 10'd256);
assign crc_done        = (crc_byte_cnt == 6'd61) && (crc_bit_cnt == 3'd7);
assign crc_feedback    = crc_r[15] ^ crc_byte_data[7-crc_bit_cnt];
assign axis_handshake  = m_axis_tvalid && m_axis_tready;
assign packet_done     = pkt_fsm_payload && axis_handshake && m_axis_tlast;
assign afe_idle        = pkt_fsm_idle && !chn_en_eff;
assign payload_cnt_clr = pkt_fsm_header && axis_handshake;
assign payload_cnt_inc = pkt_fsm_payload && axis_handshake;
assign packet_seq_inc  = packet_done;
assign crc_init        = packet_start;
assign crc_upd         = pkt_fsm_crc;
assign crc_bit_clr     = crc_upd && (crc_bit_cnt == 3'd7);
assign crc_bit_inc     = crc_upd && !crc_bit_clr;
assign crc_byte_inc    = crc_bit_clr;

// 1. Packet phase state.
always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n) begin
        pkt_fsm <= #UDLY PKT_IDLE;
    end else begin
        pkt_fsm <= #UDLY pkt_fsm_nx;
    end
end

// 2. Packet phase transition.
always @* begin
    case (pkt_fsm)
        PKT_IDLE: begin
            if (packet_start) begin
                pkt_fsm_nx = PKT_CRC;
            end else begin
                pkt_fsm_nx = PKT_IDLE;
            end
        end
        PKT_CRC: begin
            if (crc_done) begin
                pkt_fsm_nx = PKT_HEADER;
            end else begin
                pkt_fsm_nx = PKT_CRC;
            end
        end
        PKT_HEADER: begin
            if (axis_handshake) begin
                pkt_fsm_nx = PKT_PAYLOAD;
            end else begin
                pkt_fsm_nx = PKT_HEADER;
            end
        end
        PKT_PAYLOAD: begin
            if (packet_done) begin
                pkt_fsm_nx = PKT_IDLE;
            end else begin
                pkt_fsm_nx = PKT_PAYLOAD;
            end
        end
        default: begin
            pkt_fsm_nx = PKT_IDLE;
        end
    endcase
end

// 3. AXI-Stream output and FIFO read acceptance.
always @* begin
    m_axis_tvalid = 1'b0;
    m_axis_tdata  = 512'd0;
    m_axis_tkeep  = 64'd0;
    m_axis_tlast  = 1'b0;
    fifo_rd_inc   = 1'b0;
    case (pkt_fsm)
        PKT_HEADER: begin
            m_axis_tvalid = 1'b1;
            m_axis_tdata  = header_data;
            m_axis_tkeep  = 64'hffff_ffff_ffff_ffff;
        end
        PKT_PAYLOAD: begin
            m_axis_tvalid = ~fifo_empty;
            m_axis_tdata  = fifo_data;
            m_axis_tkeep  = 64'hffff_ffff_ffff_ffff;
            m_axis_tlast  = (payload_cnt == 9'd255);
            fifo_rd_inc   = m_axis_tvalid && m_axis_tready;
        end
        default: begin
            m_axis_tvalid = 1'b0;
            m_axis_tdata  = 512'd0;
            m_axis_tkeep  = 64'd0;
            m_axis_tlast  = 1'b0;
            fifo_rd_inc   = 1'b0;
        end
    endcase
end

// 4. Effective channel-enable lifetime.
always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        chn_en_eff <= #UDLY 1'b0;
    else if (!afe_en && (pkt_fsm_idle || packet_done))
        chn_en_eff <= #UDLY 1'b0;
    else if (afe_en && pkt_fsm_idle)
        chn_en_eff <= #UDLY 1'b1;
end

// 5. Accepted payload-beat and completed-packet counters.
always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        payload_cnt <= #UDLY 9'd0;
    else if (payload_cnt_clr)
        payload_cnt <= #UDLY 9'd0;
    else if (payload_cnt_inc)
        payload_cnt <= #UDLY payload_cnt + 9'd1;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        packet_seq_cnt <= #UDLY 32'd0;
    else if (packet_seq_inc)
        packet_seq_cnt <= #UDLY packet_seq_cnt + 32'd1;
end

// 6. Header CRC, one bit per ADC clock while in PKT_CRC.
always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n) begin
        crc_r        <= #UDLY 16'hffff;
        crc_byte_cnt <= #UDLY 6'd0;
        crc_bit_cnt  <= #UDLY 3'd0;
    end else if (crc_init) begin
        crc_r        <= #UDLY 16'hffff;
        crc_byte_cnt <= #UDLY 6'd0;
        crc_bit_cnt  <= #UDLY 3'd0;
    end else if (crc_upd) begin
        if (crc_feedback)
            crc_r <= #UDLY {crc_r[14:0],1'b0} ^ 16'h1021;
        else
            crc_r <= #UDLY {crc_r[14:0],1'b0};
        if (crc_bit_clr) begin
            crc_bit_cnt  <= #UDLY 3'd0;
        end else if (crc_bit_inc) begin
            crc_bit_cnt <= #UDLY crc_bit_cnt + 3'd1;
        end
        if (crc_byte_inc)
            crc_byte_cnt <= #UDLY crc_byte_cnt + 6'd1;
    end
end

always @* begin
    case (smp_prec)
        2'd0   : precision_byte = 8'd10;
        2'd1   : precision_byte = 8'd12;
        2'd2   : precision_byte = 8'd14;
        default: precision_byte = 8'd0;
    endcase
end

always @* begin
    crc_byte_data = 8'd0;
    case (crc_byte_cnt)
        6'd0 : crc_byte_data = 8'h44;
        6'd1 : crc_byte_data = 8'h54;
        6'd2 : crc_byte_data = 8'h52;
        6'd3 : crc_byte_data = 8'h31;
        6'd4 : crc_byte_data = 8'd1;
        6'd5 : crc_byte_data = 8'd64;
        6'd8 : crc_byte_data = {5'd0,afe_id};
        6'd9 : crc_byte_data = {6'd0,smp_mode};
        6'd10: crc_byte_data = precision_byte;
        6'd16: crc_byte_data = 8'd0;
        6'd17: crc_byte_data = 8'd1;
        6'd20: crc_byte_data = packet_seq_cnt[7:0];
        6'd21: crc_byte_data = packet_seq_cnt[15:8];
        6'd22: crc_byte_data = packet_seq_cnt[23:16];
        6'd23: crc_byte_data = packet_seq_cnt[31:24];
        6'd28: crc_byte_data = 8'd0;
        6'd29: crc_byte_data = 8'h40;
        6'd32: crc_byte_data = dec_m;
        6'd33: crc_byte_data = (smp_mode == 2'd2) ? 8'd1 : 8'd0;
        default: crc_byte_data = 8'd0;
    endcase
end

always @* begin
    header_data = 512'd0;
    header_data[7:0]       = 8'h44;
    header_data[15:8]      = 8'h54;
    header_data[23:16]     = 8'h52;
    header_data[31:24]     = 8'h31;
    header_data[39:32]     = 8'd1;
    header_data[47:40]     = 8'd64;
    header_data[71:64]     = {5'd0,afe_id};
    header_data[79:72]     = {6'd0,smp_mode};
    header_data[87:80]     = precision_byte;
    header_data[135:128]   = 8'd0;
    header_data[143:136]   = 8'd1;
    header_data[167:160]   = packet_seq_cnt[7:0];
    header_data[175:168]   = packet_seq_cnt[15:8];
    header_data[183:176]   = packet_seq_cnt[23:16];
    header_data[191:184]   = packet_seq_cnt[31:24];
    header_data[231:224]   = 8'd0;
    header_data[239:232]   = 8'h40;
    header_data[263:256]   = dec_m;
    header_data[271:264]   = (smp_mode == 2'd2) ? 8'd1 : 8'd0;
    header_data[503:496]   = crc_r[7:0];
    header_data[511:504]   = crc_r[15:8];
end

endmodule

