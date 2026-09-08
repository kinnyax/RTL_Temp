`timescale 1ns / 1ps

module DMA_CHN(
    input                                   dma_clk                                        ,
    input                                   dma_rst_n                                      ,

    input               [31:0]              s_axis_tdata                                   ,
    input                                   s_axis_tlast                                   ,
    input                                   s_axis_tvalid                                  ,
    output    wire                          s_axis_tready                                  ,

    input               [31:0]              chn_addr                                       ,
    input               [31:0]              chn_num                                        ,
    input               [31:0]              chn_ctl                                        ,

    output    wire                          m_axi_awid                                     ,
    output    wire      [31:0]              m_axi_awaddr                                   ,
    output    wire      [ 7:0]              m_axi_awlen                                    ,
    output    wire      [ 2:0]              m_axi_awsize                                   ,
    output    wire      [ 1:0]              m_axi_awburst                                  ,
    output    wire                          m_axi_awlock                                   ,
    output    wire      [ 3:0]              m_axi_awcache                                  ,
    output    wire      [ 2:0]              m_axi_awprot                                   ,
    output    wire      [ 3:0]              m_axi_awqos                                    ,
    output    wire                          m_axi_awvalid                                  ,
    input                                   m_axi_awready                                  ,

    output    wire      [255:0]             m_axi_wdata                                    ,
    output    wire      [31:0]              m_axi_wstrb                                    ,
    output    wire                          m_axi_wlast                                    ,
    output    wire                          m_axi_wvalid                                   ,
    input                                   m_axi_wready                                   ,

    input                                   m_axi_bid                                      ,
    input               [ 1:0]              m_axi_bresp                                    ,
    input                                   m_axi_bvalid                                   ,
    output    wire                          m_axi_bready                                   ,

    output    wire                          chn_busy                                       ,
    output    wire                          fifo_empty                                     ,
    output    wire                          fifo_full                                      ,
    output    wire                          half_trans                                     ,
    output    wire                          trans_comp                                     ,
    output    wire                          axi_error
);

parameter                                   UDLY                     = 1                   ;

wire                                        chn_en                                         ;
wire                                        fifo_rst_n                                     ;
wire                    [255:0]             fifo_wdat                                      ;
wire                                        fifo_winc                                      ;
wire                    [255:0]             fifo_rdat                                      ;
wire                    [ 8:0]              fifo_rlevel                                    ;
wire                                        fifo_rinc                                      ;

//////////////////////////////////////////////////
//1. Channel Enable Synchronization
//////////////////////////////////////////////////
level_sync chn_enable_sync(.clk(dma_clk), .rst_n(dma_rst_n), .in(chn_ctl[0]), .out(chn_en));

//////////////////////////////////////////////////
//2. Stream Receiver
//////////////////////////////////////////////////
DMA_RXD dma_rxd(
    .dma_clk                             (dma_clk                                      ) ,
    .dma_rst_n                           (dma_rst_n                                    ) ,
    .s_axis_tdata                        (s_axis_tdata                                 ) ,
    .s_axis_tlast                        (s_axis_tlast                                 ) ,
    .s_axis_tvalid                       (s_axis_tvalid                                ) ,
    .s_axis_tready                       (s_axis_tready                                ) ,
    .chn_ctl                             (chn_ctl                                      ) ,
    .chn_en                              (chn_en                                       ) ,
    .fifo_full                           (fifo_full                                    ) ,
    .fifo_wdat                           (fifo_wdat                                    ) ,
    .fifo_winc                           (fifo_winc                                    )
);

//////////////////////////////////////////////////
//3. FIFO
//////////////////////////////////////////////////
assign fifo_rst_n = dma_rst_n & ~chn_ctl[8];

async_fifo #(
    .AS                                  (8                                            ) ,
    .DS                                  (256                                          )
) async_fifo(
    .wclk                                (dma_clk                                      ) ,
    .rclk                                (dma_clk                                      ) ,
    .wclr                                (1'd0                                         ) ,
    .rclr                                (1'd0                                         ) ,
    .rst_n                               (fifo_rst_n                                   ) ,
    .winc                                (fifo_winc                                    ) ,
    .rinc                                (fifo_rinc                                    ) ,
    .wdata                               (fifo_wdat                                    ) ,
    .rdata                               (fifo_rdat                                    ) ,
    .full                                (fifo_full                                    ) ,
    .empty                               (fifo_empty                                   ) ,
    .overflow                            (                                             ) ,
    .underflow                           (                                             ) ,
    .wlevel                              (                                             ) ,
    .rlevel                              (fifo_rlevel                                  )
);

//////////////////////////////////////////////////
//4. AXI Write Transmitter
//////////////////////////////////////////////////
DMA_TXD dma_txd(
    .dma_clk                             (dma_clk                                      ) ,
    .dma_rst_n                           (dma_rst_n                                    ) ,
    .chn_addr                            (chn_addr                                     ) ,
    .chn_num                             (chn_num[12:0]                                ) ,
    .chn_ctl                             (chn_ctl                                      ) ,
    .chn_en                              (chn_en                                       ) ,
    .fifo_rdat                           (fifo_rdat                                    ) ,
    .fifo_empty                          (fifo_empty                                   ) ,
    .fifo_rlevel                         (fifo_rlevel                                  ) ,
    .fifo_rinc                           (fifo_rinc                                    ) ,
    .m_axi_awid                          (m_axi_awid                                   ) ,
    .m_axi_awaddr                        (m_axi_awaddr                                 ) ,
    .m_axi_awlen                         (m_axi_awlen                                  ) ,
    .m_axi_awsize                        (m_axi_awsize                                 ) ,
    .m_axi_awburst                       (m_axi_awburst                                ) ,
    .m_axi_awlock                        (m_axi_awlock                                 ) ,
    .m_axi_awcache                       (m_axi_awcache                                ) ,
    .m_axi_awprot                        (m_axi_awprot                                 ) ,
    .m_axi_awqos                         (m_axi_awqos                                  ) ,
    .m_axi_awvalid                       (m_axi_awvalid                                ) ,
    .m_axi_awready                       (m_axi_awready                                ) ,
    .m_axi_wdata                         (m_axi_wdata                                  ) ,
    .m_axi_wstrb                         (m_axi_wstrb                                  ) ,
    .m_axi_wlast                         (m_axi_wlast                                  ) ,
    .m_axi_wvalid                        (m_axi_wvalid                                 ) ,
    .m_axi_wready                        (m_axi_wready                                 ) ,
    .m_axi_bid                           (m_axi_bid                                    ) ,
    .m_axi_bresp                         (m_axi_bresp                                  ) ,
    .m_axi_bvalid                        (m_axi_bvalid                                 ) ,
    .m_axi_bready                        (m_axi_bready                                 ) ,
    .chn_busy                            (chn_busy                                     ) ,
    .half_trans                          (half_trans                                   ) ,
    .trans_comp                          (trans_comp                                   ) ,
    .axi_error                           (axi_error                                    )
);

endmodule
