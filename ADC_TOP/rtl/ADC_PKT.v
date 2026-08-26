`timescale 1ns / 1ps

module ADC_PKT(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,

    input               [ 2:0]              chn_id                                         ,
    input                                   chn_en                                         ,
    input               [ 1:0]              smp_prec                                       ,
    input               [ 1:0]              smp_mode                                       ,
    input               [ 7:0]              dec_m                                          ,
    input                                   link_ready                                     ,
    input                                   fifo_sta                                       ,

    input               [511:0]             rx_fifo_rdat                                   ,
    input                                   rx_fifo_empty                                  ,
    input               [ 9:0]              rx_fifo_rlevel                                 ,
    output    wire                          rx_fifo_rinc                                   ,

    output    wire      [511:0]             m_axis_tdata                                   ,
    output    wire      [63:0]              m_axis_tkeep                                   ,
    output    wire                          m_axis_tvalid                                  ,
    output    wire                          m_axis_tlast                                   ,
    input                                   m_axis_tready                                  ,

    output    wire                          chn_idle
);

parameter                                   UDLY                     = 1                   ;

localparam                                  PACKET_IDLE              = 2'd0                ;
localparam                                  PACKET_CRC               = 2'd1                ;
localparam                                  PACKET_HEADER            = 2'd2                ;
localparam                                  PACKET_PAYLOAD           = 2'd3                ;

wire                                        packet_admit                                   ;
wire                                        axis_handshake                                 ;
wire                                        payload_last                                   ;
wire                                        crc_busy                                       ;
wire                                        crc_done                                       ;
wire                    [15:0]              crc_value                                      ;
wire                    [ 1:0]              smp_mode_eff                                   ;
wire                    [ 1:0]              smp_prec_eff                                   ;
wire                    [ 7:0]              smp_prec_value                                 ;

reg                     [ 1:0]              packet_fsm                                     ;
reg                     [ 1:0]              packet_fsm_nx                                  ;
reg                     [ 7:0]              payload_cnt                                    ;
reg                                         effective_en                                   ;
reg                     [495:0]             header_data                                    ;
reg                     [495:0]             header_data_r                                  ;


assign smp_mode_eff   = (smp_mode==2'd3) ? 2'd0 : smp_mode;
assign smp_prec_eff   = (smp_prec==2'd3) ? 2'd0 : smp_prec;
assign smp_prec_value = (smp_prec_eff==2'd0) ? 8'd10 :
                        (smp_prec_eff==2'd1) ? 8'd12 : 8'd14;

assign packet_admit   = (packet_fsm==PACKET_IDLE) & effective_en & link_ready &
                        !rx_fifo_empty & (rx_fifo_rlevel>=10'd256);
assign axis_handshake = m_axis_tvalid & m_axis_tready;
assign payload_last   = (payload_cnt==8'd255);
assign chn_idle       = (packet_fsm==PACKET_IDLE) && !crc_busy;

always @(*) begin
    header_data          = 496'd0;
    header_data[31:0]    = 32'h31525444;
    header_data[39:32]   = 8'd1;
    header_data[47:40]   = 8'd64;
    header_data[71:64]   = {5'd0,chn_id};
    header_data[79:72]   = {6'd0,smp_mode_eff};
    header_data[87:80]   = smp_prec_value;
    header_data[143:136] = 8'd1;
    header_data[239:232] = 8'h40;
    header_data[263:256] = dec_m;
    header_data[271:264] = (smp_mode_eff==2'd2) ? 8'd1 : 8'd0;
    header_data[279:272] = {7'd0,fifo_sta};
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(adc_rst_n==1'b0)
        packet_fsm <= #UDLY PACKET_IDLE;
    else
        packet_fsm <= #UDLY packet_fsm_nx;
end

always @(*) begin
    case(packet_fsm)
        PACKET_IDLE : begin
            if(packet_admit)
                packet_fsm_nx = PACKET_CRC;
            else
                packet_fsm_nx = PACKET_IDLE;
        end
        PACKET_CRC : begin
            if(crc_done)
                packet_fsm_nx = PACKET_HEADER;
            else
                packet_fsm_nx = PACKET_CRC;
        end
        PACKET_HEADER : begin
            if(axis_handshake)
                packet_fsm_nx = PACKET_PAYLOAD;
            else
                packet_fsm_nx = PACKET_HEADER;
        end
        PACKET_PAYLOAD : begin
            if(axis_handshake && payload_last)
                packet_fsm_nx = PACKET_IDLE;
            else
                packet_fsm_nx = PACKET_PAYLOAD;
        end
        default : begin
            packet_fsm_nx = PACKET_IDLE;
        end
    endcase
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(adc_rst_n==1'b0)
        effective_en <= #UDLY 1'b0;
    else if(packet_fsm==PACKET_IDLE)
        effective_en <= #UDLY chn_en;
    else if((packet_fsm==PACKET_PAYLOAD) && axis_handshake && payload_last)
        effective_en <= #UDLY chn_en;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(adc_rst_n==1'b0)
        header_data_r <= #UDLY 496'd0;
    else if(packet_admit)
        header_data_r <= #UDLY header_data;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(adc_rst_n==1'b0)
        payload_cnt <= #UDLY 8'd0;
    else if(packet_fsm!=PACKET_PAYLOAD)
        payload_cnt <= #UDLY 8'd0;
    else if(axis_handshake)
        payload_cnt <= #UDLY payload_cnt + 8'd1;
end

assign m_axis_tdata  = (packet_fsm==PACKET_HEADER) ?
                       {crc_value[15:8],crc_value[7:0],header_data_r} :
                       (packet_fsm==PACKET_PAYLOAD) ? rx_fifo_rdat : 512'd0;
assign m_axis_tkeep  = ((packet_fsm==PACKET_HEADER) ||
                        (packet_fsm==PACKET_PAYLOAD)) ? 64'hffffffffffffffff : 64'd0;
assign m_axis_tvalid = (packet_fsm==PACKET_HEADER) || (packet_fsm==PACKET_PAYLOAD);
assign m_axis_tlast  = (packet_fsm==PACKET_PAYLOAD) && payload_last;
assign rx_fifo_rinc  = (packet_fsm==PACKET_PAYLOAD) && axis_handshake;

CRC16 crc16(
    .adc_clk                             (adc_clk                                      ),
    .adc_rst_n                           (adc_rst_n                                    ),
    .start                               (packet_admit                                 ),
    .header_data                         (header_data                                  ),
    .busy                                (crc_busy                                     ),
    .done                                (crc_done                                     ),
    .crc                                 (crc_value                                    )
);

endmodule
