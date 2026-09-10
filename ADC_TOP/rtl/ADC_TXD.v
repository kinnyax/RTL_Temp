`timescale 1ns / 1ps

module ADC_TXD(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,

    input                                   chn_en                                         ,
    input                                   link_ready_sync                                ,
    input               [511:0]             rx_fifo_rdat                                   ,
    input               [ 9:0]              rx_fifo_rlevel                                 ,
    output    wire                          rx_fifo_rinc                                   ,

    output    wire      [511:0]             m_axis_tdata                                   ,
    output    wire      [63:0]              m_axis_tkeep                                   ,
    output    wire                          m_axis_tvalid                                  ,
    output    wire                          m_axis_tlast                                   ,
    input                                   m_axis_tready                                  ,

    output    wire                          txd_idle
);

parameter               [ 7:0]              AFE_ID                   = 8'd0                ;

localparam                                  TXD_IDLE                 = 2'd0                ;
localparam                                  TXD_HEAD                 = 2'd1                ;
localparam                                  TXD_DATA                 = 2'd2                ;

wire                                        txd_head                                       ;
wire                                        txd_data                                       ;
wire                                        txd_run                                        ;
wire                                        axis_handshake                                 ;
wire                                        header_handshake                               ;
wire                                        data_handshake                                 ;
wire                                        data_last                                      ;
wire                                        txd_done                                       ;
wire                    [511:0]             header_data                                    ;

reg                     [ 1:0]              txd_fsm                                        ;
reg                     [ 1:0]              txd_fsm_nx                                     ;
reg                     [ 7:0]              data_cnt                                       ;
reg                     [31:0]              seq_cnt                                        ;
reg                     [31:0]              header_seq                                     ;
reg                     [ 7:0]              header_sta                                     ;

//////////////////////////////////////////////////
//1. State Machine
//////////////////////////////////////////////////
always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        txd_fsm <= TXD_IDLE;
    else
        txd_fsm <= txd_fsm_nx;
end

always @(*) begin
    case(txd_fsm)
        TXD_IDLE : begin
            if(txd_run)
                txd_fsm_nx = TXD_HEAD;
            else
                txd_fsm_nx = TXD_IDLE;
        end
        TXD_HEAD : begin
            if(header_handshake)
                txd_fsm_nx = TXD_DATA;
            else
                txd_fsm_nx = TXD_HEAD;
        end
        TXD_DATA : begin
            if(txd_done)
                txd_fsm_nx = TXD_IDLE;
            else
                txd_fsm_nx = TXD_DATA;
        end
        default : begin
            txd_fsm_nx = TXD_IDLE;
        end
    endcase
end

//////////////////////////////////////////////////
//2. State Decode And Admission
//////////////////////////////////////////////////
assign txd_idle = (txd_fsm == TXD_IDLE);
assign txd_head = (txd_fsm == TXD_HEAD);
assign txd_data = (txd_fsm == TXD_DATA);
assign txd_run  = txd_idle & chn_en & (rx_fifo_rlevel >= 10'd256);

//////////////////////////////////////////////////
//3. Header Snapshot
//////////////////////////////////////////////////
assign header_data = {416'd0, header_seq, 8'hff, header_sta,
                      AFE_ID, 8'h01, 32'h48434441};

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n) begin
        header_seq <= 32'd0;
        header_sta <= 8'd0;
    end
    else if(txd_run) begin
        header_seq <= seq_cnt;
        header_sta <= {6'd0, (rx_fifo_rlevel >= 10'd384), link_ready_sync};
    end
end

//////////////////////////////////////////////////
//4. Payload Position And Sequence
//////////////////////////////////////////////////
assign axis_handshake   = m_axis_tvalid & m_axis_tready;
assign header_handshake = axis_handshake & txd_head;
assign data_handshake   = axis_handshake & txd_data;
assign data_last        = txd_data & (data_cnt == 8'd255);
assign txd_done         = data_handshake & data_last;

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        data_cnt <= 8'd0;
    else if(txd_run)
        data_cnt <= 8'd0;
    else if(txd_done)
        data_cnt <= 8'd0;
    else if(data_handshake)
        data_cnt <= data_cnt + 8'd1;
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(~adc_rst_n)
        seq_cnt <= 32'd0;
    else if(txd_done)
        seq_cnt <= seq_cnt + 32'd1;
end

//////////////////////////////////////////////////
//5. AXIS Transfer
//////////////////////////////////////////////////
assign rx_fifo_rinc = data_handshake;
assign m_axis_tdata = txd_head ? header_data :
                      txd_data ? rx_fifo_rdat : 512'd0;
assign m_axis_tkeep = m_axis_tvalid ? 64'hffffffffffffffff : 64'd0;
assign m_axis_tvalid = txd_head | txd_data;
assign m_axis_tlast = data_last;

endmodule
