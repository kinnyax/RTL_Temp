`timescale 1ns / 1ps

module PCIE_RXD(
    input                                   data_clk                                       ,
    input                                   data_rst_n                                     ,
    input                                   axi_aclk                                       ,
    input                                   axi_aresetn                                    ,
    input                                   pcie_rst_n                                     ,
    input               [31:0]              pcie_ctl                                       ,

    input               [255:0]             s_axis_tdata                                   ,
    input                                   s_axis_tvalid                                  ,
    output    wire                          s_axis_tready                                  ,

    output    wire      [255:0]             m_axis_c2h_tdata                               ,
    output    wire      [31:0]              m_axis_c2h_tkeep                               ,
    output    wire                          m_axis_c2h_tvalid                              ,
    input                                   m_axis_c2h_tready                              ,
    output    wire                          m_axis_c2h_tlast                               ,

    output    wire                          fifo_full                                      ,
    output    wire                          fifo_empty                                     ,
    output    wire                          wr_rst_busy                                    ,
    output    wire                          rd_rst_busy                                    ,
    output    wire                          fifo_of                                        ,
    output    wire                          fifo_uf
);

wire                                        pcie_enable                                    ;
wire                                        pcie_en                                        ;
wire                                        fifo_clr                                       ;
wire                                        fifo_rst                                       ;
wire                                        fifo_winc                                      ;
wire                                        fifo_rinc                                      ;
wire                                        s_axis_handshake                               ;
wire                                        c2h_handshake                                  ;
wire                                        packet_inc                                     ;
wire                                        packet_clr                                     ;

reg                     [ 9:0]              packet_cnt                                     ;

//////////////////////////////////////////////////
//1. Control And Synchronization
//////////////////////////////////////////////////
assign pcie_enable = pcie_ctl[0];
assign fifo_clr    = pcie_ctl[1];

level_sync pcie_enable_sync(.clk(axi_aclk), .rst_n(axi_aresetn), .in(pcie_enable), .out(pcie_en));

//////////////////////////////////////////////////
//2. Asynchronous Data FIFO
//////////////////////////////////////////////////
assign fifo_rst      = ~pcie_rst_n | fifo_clr;
assign s_axis_tready = data_rst_n & pcie_rst_n & ~fifo_clr & ~fifo_full;
assign s_axis_handshake = s_axis_tvalid & s_axis_tready;
assign fifo_winc        = s_axis_handshake;

PCIE_DATA_FIFO pcie_data_fifo(
    .rst                                 (fifo_rst                                     ),
    .wr_clk                              (data_clk                                     ),
    .rd_clk                              (axi_aclk                                     ),
    .din                                 (s_axis_tdata                                 ),
    .wr_en                               (fifo_winc                                    ),
    .rd_en                               (fifo_rinc                                    ),
    .dout                                (m_axis_c2h_tdata                             ),
    .full                                (fifo_full                                    ),
    .empty                               (fifo_empty                                   ),
    .wr_rst_busy                         (wr_rst_busy                                  ),
    .rd_rst_busy                         (rd_rst_busy                                  ),
    .overflow                            (fifo_of                                      ),
    .underflow                           (fifo_uf                                      )
);

//////////////////////////////////////////////////
//3. C2H Packet Framing
//////////////////////////////////////////////////
assign m_axis_c2h_tkeep  = 32'hffff_ffff;
assign m_axis_c2h_tvalid = axi_aresetn & pcie_en & ~fifo_empty;
assign m_axis_c2h_tlast  = m_axis_c2h_tvalid & (packet_cnt == 10'd512);
assign c2h_handshake     = m_axis_c2h_tvalid & m_axis_c2h_tready;
assign fifo_rinc         = c2h_handshake;
assign packet_inc        = c2h_handshake;
assign packet_clr        = (packet_cnt == 10'd512) & packet_inc;

always @(posedge axi_aclk or negedge axi_aresetn) begin
    if(~axi_aresetn)
        packet_cnt <= 10'd0;
    else if(~pcie_en)
        packet_cnt <= 10'd0;
    else if(packet_clr)
        packet_cnt <= 10'd0;
    else if(packet_inc)
        packet_cnt <= packet_cnt + 10'd1;
end

endmodule
