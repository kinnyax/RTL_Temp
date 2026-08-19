`timescale 1ns / 1ps

// =====
// 1. Packet Generation
// =====
module ADC_PKT(
    input  wire                             adc_clk                                     ,
    input  wire                             adc_rst_n                                   ,
    input  wire [2:0]                       afe_id                                      ,
    input  wire                             afe_en                                      ,
    input  wire [1:0]                       smp_prec                                    ,
    input  wire [1:0]                       smp_mode                                    ,
    input  wire [7:0]                       dec_m                                       ,
    input  wire                             link_ready                                  ,
    input  wire [511:0]                     fifo_data                                   ,
    input  wire                             fifo_empty                                  ,
    input  wire [9:0]                       fifo_level                                  ,
    input  wire                             m_axis_tready                               ,
    output reg                              chn_en_eff                                  ,
    output reg                              fifo_rd_inc                                 ,
    output reg [511:0]                      m_axis_tdata                                ,
    output reg [63:0]                       m_axis_tkeep                                ,
    output reg                              m_axis_tvalid                               ,
    output reg                              m_axis_tlast                                ,
    output wire                             afe_idle
);

parameter                                  UDLY          = 1                            ;

localparam [1:0]                           PKT_IDLE      = 2'd0                         ;
localparam [1:0]                           PKT_CRC       = 2'd1                         ;
localparam [1:0]                           PKT_HEADER    = 2'd2                         ;
localparam [1:0]                           PKT_PAYLOAD   = 2'd3                         ;

reg [1:0]                                   pkt_fsm                                     ;
reg [1:0]                                   pkt_fsm_nx                                  ;
reg [15:0]                                  crc_r                                       ;
reg [5:0]                                   crc_byte_r                                  ;
reg [2:0]                                   crc_bit_r                                   ;
reg [31:0]                                  packet_seq_r                                ;
reg [8:0]                                   payload_count_r                             ;
reg [511:0]                                 header_data                                 ;
reg [7:0]                                   crc_byte_data                               ;
reg [7:0]                                   precision_byte                              ;

wire                                        packet_start                                ;
wire                                        crc_done                                    ;
wire                                        crc_feedback                                ;
wire                                        axis_handshake                              ;
wire                                        packet_done                                 ;

assign packet_start   = (pkt_fsm == PKT_IDLE) && chn_en_eff && afe_en &&
                        link_ready && (fifo_level >= 10'd256);
assign crc_done       = (crc_byte_r == 6'd61) && (crc_bit_r == 3'd7);
assign crc_feedback   = crc_r[15] ^ crc_byte_data[7-crc_bit_r];
assign axis_handshake = m_axis_tvalid && m_axis_tready;
assign packet_done    = (pkt_fsm == PKT_PAYLOAD) && axis_handshake && m_axis_tlast;
assign afe_idle       = (pkt_fsm == PKT_IDLE) && !chn_en_eff;

always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        pkt_fsm <= #UDLY PKT_IDLE;
    else
        pkt_fsm <= #UDLY pkt_fsm_nx;
end

always @* begin
    pkt_fsm_nx = pkt_fsm;
    case (pkt_fsm)
        PKT_IDLE   : if (packet_start)   pkt_fsm_nx = PKT_CRC;
        PKT_CRC    : if (crc_done)       pkt_fsm_nx = PKT_HEADER;
        PKT_HEADER : if (axis_handshake) pkt_fsm_nx = PKT_PAYLOAD;
        PKT_PAYLOAD: if (packet_done)    pkt_fsm_nx = PKT_IDLE;
        default    :                     pkt_fsm_nx = PKT_IDLE;
    endcase
end

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
            m_axis_tlast  = (payload_count_r == 9'd255);
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

always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        chn_en_eff <= 1'b0;
    else if (!afe_en && ((pkt_fsm == PKT_IDLE) || packet_done))
        chn_en_eff <= 1'b0;
    else if (afe_en && (pkt_fsm == PKT_IDLE))
        chn_en_eff <= 1'b1;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        payload_count_r <= 9'd0;
    else if ((pkt_fsm == PKT_HEADER) && axis_handshake)
        payload_count_r <= 9'd0;
    else if ((pkt_fsm == PKT_PAYLOAD) && axis_handshake)
        payload_count_r <= payload_count_r + 9'd1;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n)
        packet_seq_r <= 32'd0;
    else if (packet_done)
        packet_seq_r <= packet_seq_r + 32'd1;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if (!adc_rst_n) begin
        crc_r      <= 16'hffff;
        crc_byte_r <= 6'd0;
        crc_bit_r  <= 3'd0;
    end else if ((pkt_fsm == PKT_IDLE) && packet_start) begin
        crc_r      <= 16'hffff;
        crc_byte_r <= 6'd0;
        crc_bit_r  <= 3'd0;
    end else if (pkt_fsm == PKT_CRC) begin
        if (crc_feedback)
            crc_r <= {crc_r[14:0],1'b0} ^ 16'h1021;
        else
            crc_r <= {crc_r[14:0],1'b0};
        if (crc_bit_r == 3'd7) begin
            crc_bit_r  <= 3'd0;
            crc_byte_r <= crc_byte_r + 6'd1;
        end else begin
            crc_bit_r <= crc_bit_r + 3'd1;
        end
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
    case (crc_byte_r)
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
        6'd20: crc_byte_data = packet_seq_r[7:0];
        6'd21: crc_byte_data = packet_seq_r[15:8];
        6'd22: crc_byte_data = packet_seq_r[23:16];
        6'd23: crc_byte_data = packet_seq_r[31:24];
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
    header_data[167:160]   = packet_seq_r[7:0];
    header_data[175:168]   = packet_seq_r[15:8];
    header_data[183:176]   = packet_seq_r[23:16];
    header_data[191:184]   = packet_seq_r[31:24];
    header_data[231:224]   = 8'd0;
    header_data[239:232]   = 8'h40;
    header_data[263:256]   = dec_m;
    header_data[271:264]   = (smp_mode == 2'd2) ? 8'd1 : 8'd0;
    header_data[503:496]   = crc_r[7:0];
    header_data[511:504]   = crc_r[15:8];
end

endmodule

