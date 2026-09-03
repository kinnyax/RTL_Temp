`timescale 1ns / 1ps

module ADC_PKT(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,

    input                                   chn_en                                         ,
    input               [511:0]             rx_fifo_rdat                                   ,
    input                                   rx_fifo_empty                                  ,
    input               [ 9:0]              rx_fifo_rlevel                                 ,
    output    wire                          rx_fifo_rinc                                   ,

    output    wire      [511:0]             m_axis_tdata                                   ,
    output    reg       [63:0]              m_axis_tkeep                                   ,
    output    reg                           m_axis_tvalid                                  ,
    output    reg                           m_axis_tlast                                   ,
    input                                   m_axis_tready                                  ,

    output    wire                          pkt_idle
);

parameter                                   UDLY                     = 1                   ;

localparam                                  PKT_IDLE                 = 1'd0                ;
localparam                                  PKT_BUSY                 = 1'd1                ;

wire                                        pkt_run                                        ;
wire                                        pkt_update                                     ;
wire                                        axis_handshake                                 ;
wire                                        pkt_done                                       ;
wire                                        pkt_busy                                       ;

reg                                         pkt_fsm                                        ;
reg                                         pkt_fsm_nx                                     ;
reg                     [ 7:0]              payload_cnt                                    ;
reg                                         pkt_start                                      ;

//////////////////////////////////////////////////
//1. State Machine
//////////////////////////////////////////////////
always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        pkt_fsm <= #UDLY PKT_IDLE;
    else
        pkt_fsm <= #UDLY pkt_fsm_nx;
end

always @(*) begin
    case(pkt_fsm)
        PKT_IDLE : begin
            if(pkt_run)
                pkt_fsm_nx = PKT_BUSY;
            else
                pkt_fsm_nx = PKT_IDLE;
        end
        PKT_BUSY : begin
            if(pkt_done)
                pkt_fsm_nx = PKT_IDLE;
            else
                pkt_fsm_nx = PKT_BUSY;
        end
        default : begin
            pkt_fsm_nx = PKT_IDLE;
        end
    endcase
end

//////////////////////////////////////////////////
//2. State Decode
//////////////////////////////////////////////////
assign pkt_idle       = (pkt_fsm == PKT_IDLE);
assign pkt_busy       = (pkt_fsm == PKT_BUSY);

//////////////////////////////////////////////////
//3. Admission Control
//////////////////////////////////////////////////
assign pkt_update     = pkt_idle | pkt_done;
assign pkt_run        = pkt_idle & pkt_start & chn_en & ~rx_fifo_empty &
                         (rx_fifo_rlevel >= 10'd256);

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        pkt_start <= #UDLY 1'd0;
    else if(pkt_update)
        pkt_start <= #UDLY chn_en;
end

//////////////////////////////////////////////////
//4. AXIS Transfer
//////////////////////////////////////////////////
assign axis_handshake = m_axis_tvalid & m_axis_tready;
assign pkt_done       = axis_handshake & m_axis_tlast;
assign rx_fifo_rinc   = axis_handshake;
assign m_axis_tdata   = m_axis_tvalid ? rx_fifo_rdat : 512'd0;

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        payload_cnt <= #UDLY 8'd0;
    else if(~pkt_busy)
        payload_cnt <= #UDLY 8'd0;
    else if(axis_handshake)
        payload_cnt <= #UDLY payload_cnt + 8'd1;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n) begin
        m_axis_tkeep  <= #UDLY 64'd0;
        m_axis_tvalid <= #UDLY 1'd0;
    end
    else if(pkt_run) begin
        m_axis_tkeep  <= #UDLY 64'hffffffffffffffff;
        m_axis_tvalid <= #UDLY 1'd1;
    end
    else if(~pkt_busy) begin
        m_axis_tkeep  <= #UDLY 64'd0;
        m_axis_tvalid <= #UDLY 1'd0;
    end
    else if(pkt_done) begin
        m_axis_tkeep  <= #UDLY 64'd0;
        m_axis_tvalid <= #UDLY 1'd0;
    end
    else begin
        m_axis_tkeep  <= #UDLY 64'hffffffffffffffff;
        m_axis_tvalid <= #UDLY 1'd1;
    end
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        m_axis_tlast <= #UDLY 1'd0;
    else if(pkt_run)
        m_axis_tlast <= #UDLY 1'd0;
    else if(~pkt_busy)
        m_axis_tlast <= #UDLY 1'd0;
    else if(pkt_done)
        m_axis_tlast <= #UDLY 1'd0;
    else if(axis_handshake)
        m_axis_tlast <= #UDLY (payload_cnt == 8'd254);
end

endmodule
