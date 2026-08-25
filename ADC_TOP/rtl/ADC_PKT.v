`timescale 1ns / 1ps

module ADC_PKT(
    input  wire         adc_clk       ,
    input  wire         adc_rst_n     ,
    input  wire [2:0]   chn_id        ,
    input  wire         chn_en        ,
    input  wire [1:0]   smp_prec      ,
    input  wire [1:0]   smp_mode      ,
    input  wire [7:0]   dec_m         ,
    input  wire         link_ready    ,
    input  wire [511:0] rx_fifo_rdat  ,
    input  wire         rx_fifo_empty ,
    input  wire [9:0]   rx_fifo_rlevel,
    output reg          rx_fifo_rinc  ,
    output reg  [511:0] m_axis_tdata  ,
    output reg  [63:0]  m_axis_tkeep  ,
    output reg          m_axis_tvalid ,
    output reg          m_axis_tlast  ,
    input  wire         m_axis_tready ,
    output wire         chn_idle      ,
    input  wire         fifo_sta
);

parameter                                   UDLY                        = 1             ;

localparam [1:0]   PKT_IDLE       = 2'd0;
localparam [1:0]   PKT_CRC        = 2'd1;
localparam [1:0]   PKT_HEADER     = 2'd2;
localparam [1:0]   PKT_PAYLOAD    = 2'd3;

reg        [1:0]   pkt_fsm       ;
reg        [1:0]   pkt_fsm_nx    ;
reg                chn_en_eff    ;
reg        [2:0]   crc_wait_cnt  ;
reg        [8:0]   payload_cnt   ;
reg        [495:0] header_buff   ;
reg        [495:0] header_image  ;

wire       [7:0]   precision_byte;
wire               packet_admit  ;
wire               axis_handshake;
wire               crc_wait_last ;
wire               payload_done  ;
wire               chn_en_eff_upd;
wire               payload_clr   ;
wire               payload_inc   ;
wire       [15:0]  crc           ;
wire               crc_done      ;
assign packet_admit   = (pkt_fsm == PKT_IDLE) & chn_en_eff & link_ready & (rx_fifo_rlevel >= 10'd256);
assign axis_handshake = m_axis_tvalid & m_axis_tready;
assign crc_wait_last  = (crc_wait_cnt == 3'd7);
assign payload_done   = (pkt_fsm == PKT_PAYLOAD) & axis_handshake & (payload_cnt == 9'd255);

CRC16 #(
    .UDLY                               (UDLY                                         )
) crc16(
    .adc_clk                             (adc_clk),
    .adc_rst_n                           (adc_rst_n),
    .start                               (packet_admit),
    .header_data                         (header_buff),
    .busy                                (),
    .done                                (crc_done),
    .crc                                 (crc)
);

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(!adc_rst_n)
        pkt_fsm <= #UDLY PKT_IDLE;
    else
        pkt_fsm <= #UDLY pkt_fsm_nx;
end

always @(*) begin
    pkt_fsm_nx = pkt_fsm;

    case(pkt_fsm)
        PKT_IDLE: begin
            if(packet_admit)
                pkt_fsm_nx = PKT_CRC;
            else
                pkt_fsm_nx = PKT_IDLE;
        end
        PKT_CRC: begin
            if(crc_wait_last)
                pkt_fsm_nx = PKT_HEADER;
            else
                pkt_fsm_nx = PKT_CRC;
        end
        PKT_HEADER: begin
            if(axis_handshake)
                pkt_fsm_nx = PKT_PAYLOAD;
            else
                pkt_fsm_nx = PKT_HEADER;
        end
        PKT_PAYLOAD: begin
            if(payload_done)
                pkt_fsm_nx = PKT_IDLE;
            else
                pkt_fsm_nx = PKT_PAYLOAD;
        end
        default: begin
            pkt_fsm_nx = PKT_IDLE;
        end
    endcase
end

// Admission edge N is cycle zero; the N+8 edge completes the CRC phase.
always @(posedge adc_clk or negedge adc_rst_n) begin
    if(!adc_rst_n)
        crc_wait_cnt <= #UDLY 3'd0;
    else if(packet_admit)
        crc_wait_cnt <= #UDLY 3'd0;
    else if(pkt_fsm == PKT_CRC) begin
        if(crc_wait_last)
            crc_wait_cnt <= #UDLY 3'd0;
        else
            crc_wait_cnt <= #UDLY crc_wait_cnt + 3'd1;
    end
end

assign chn_en_eff_upd = (pkt_fsm == PKT_IDLE) | payload_done;

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(!adc_rst_n)
        chn_en_eff <= #UDLY 1'b0;
    else if(chn_en_eff_upd)
        chn_en_eff <= #UDLY chn_en;
end

assign chn_idle = (pkt_fsm == PKT_IDLE) & !chn_en_eff;

assign payload_clr = (pkt_fsm == PKT_HEADER) & axis_handshake;
assign payload_inc = (pkt_fsm == PKT_PAYLOAD) & axis_handshake & !payload_done;

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(!adc_rst_n)
        payload_cnt <= #UDLY 9'd0;
    else if(payload_clr)
        payload_cnt <= #UDLY 9'd0;
    else if(payload_inc)
        payload_cnt <= #UDLY payload_cnt + 9'd1;
end

assign precision_byte = (smp_prec == 2'd0) ? 8'd10 :
                        (smp_prec == 2'd1) ? 8'd12 :
                        (smp_prec == 2'd2) ? 8'd14 : 8'd0;

always @(*) begin
    header_image          = 496'd0;
    header_image[31:0]    = 32'h3152_5444;
    header_image[39:32]   = 8'd1;
    header_image[47:40]   = 8'd64;
    header_image[71:64]   = {5'd0, chn_id};
    header_image[79:72]   = {6'd0, smp_mode};
    header_image[87:80]   = precision_byte;
    header_image[143:136] = 8'd1;
    header_image[239:232] = 8'h40;
    header_image[263:256] = dec_m;
    header_image[271:264] = {7'd0, (smp_mode == 2'd2)};
    header_image[279:272] = {7'd0, fifo_sta};
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(!adc_rst_n)
        header_buff <= #UDLY 496'd0;
    else if(packet_admit)
        header_buff <= #UDLY header_image;
end

always @(*) begin
    m_axis_tdata = 512'd0;
    m_axis_tkeep = 64'd0;
    m_axis_tvalid = 1'b0;
    m_axis_tlast = 1'b0;
    rx_fifo_rinc = 1'b0;
    if(pkt_fsm == PKT_HEADER) begin
        m_axis_tdata = {crc,header_buff};
        m_axis_tkeep = 64'hffff_ffff_ffff_ffff;
        m_axis_tvalid = 1'b1;
    end
    else if(pkt_fsm == PKT_PAYLOAD) begin
        m_axis_tdata = rx_fifo_rdat;
        m_axis_tkeep = 64'hffff_ffff_ffff_ffff;
        m_axis_tvalid = !rx_fifo_empty;
        m_axis_tlast = (payload_cnt == 9'd255);
        rx_fifo_rinc = m_axis_tvalid & m_axis_tready;
    end
end

endmodule
