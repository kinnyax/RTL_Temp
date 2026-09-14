`timescale 1ns / 1ps

module DMA_CHN(
    input                                   src_clk                                        ,
    input                                   src_rst_n                                      ,
    input                                   dev_clk                                        ,
    input                                   dev_rst_n                                      ,

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

    output    wire                          txd_busy                                       ,
    output    wire                          fifo_empty                                     ,
    output    wire                          fifo_full                                      ,
    output    wire                          half_trans                                     ,
    output    wire                          trans_comp                                     ,
    output    wire                          axi_error                                      ,
    output    wire                          run_clear
);

wire                                        rxd_en                                         ;
wire                                        chn_en                                         ;
wire                                        chn_run                                        ;
wire                                        src_chn_rst_n                                  ;
wire                                        dev_chn_rst_n                                  ;
wire                                        fifo_rst                                       ;
wire                                        fifo_wr_ready                                  ;
wire                                        fifo_rd_ready                                  ;
wire                                        fifo_wr_rst_busy                               ;
wire                                        fifo_rd_rst_busy                               ;
wire                    [255:0]             fifo_wdat                                      ;
wire                                        fifo_winc                                      ;
wire                    [255:0]             fifo_rdat                                      ;
wire                    [ 8:0]              fifo_rlevel                                    ;
wire                                        fifo_rinc                                      ;

reg                                         src_rst_meta                                   ;
reg                                         src_rst_release                                ;
reg                                         dev_rst_meta                                   ;
reg                                         dev_rst_release                                ;

//////////////////////////////////////////////////
//1. Reset Synchronization
//////////////////////////////////////////////////
assign src_chn_rst_n = src_rst_release;
assign dev_chn_rst_n = dev_rst_release;

always @(posedge src_clk or negedge src_rst_n) begin
    if(~src_rst_n) begin
        src_rst_meta    <= 1'd0;
        src_rst_release <= 1'd0;
    end
    else begin
        src_rst_meta    <= 1'd1;
        src_rst_release <= src_rst_meta;
    end
end

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n) begin
        dev_rst_meta    <= 1'd0;
        dev_rst_release <= 1'd0;
    end
    else begin
        dev_rst_meta    <= 1'd1;
        dev_rst_release <= dev_rst_meta;
    end
end

//////////////////////////////////////////////////
//2. Channel Control Synchronization
//////////////////////////////////////////////////
level_sync src_chn_enable_sync(.clk(src_clk), .rst_n(src_chn_rst_n), .in(chn_ctl[0]), .out(rxd_en));
level_sync dev_chn_enable_sync(.clk(dev_clk), .rst_n(dev_chn_rst_n), .in(chn_ctl[0]), .out(chn_en));
level_sync dev_chn_run_sync(.clk(dev_clk), .rst_n(dev_chn_rst_n), .in(chn_ctl[1]), .out(chn_run));

//////////////////////////////////////////////////
//3. Stream Receiver
//////////////////////////////////////////////////
DMA_RXD dma_rxd(
    .src_clk                             (src_clk                                      ) ,
    .src_rst_n                           (src_chn_rst_n                                ) ,
    .s_axis_tdata                        (s_axis_tdata                                 ) ,
    .s_axis_tlast                        (s_axis_tlast                                 ) ,
    .s_axis_tvalid                       (s_axis_tvalid                                ) ,
    .s_axis_tready                       (s_axis_tready                                ) ,
    .chn_ctl                             (chn_ctl                                      ) ,
    .chn_en                              (rxd_en                                       ) ,
    .fifo_full                           (fifo_full                                    ) ,
    .fifo_wr_ready                       (fifo_wr_ready                                ) ,
    .fifo_wdat                           (fifo_wdat                                    ) ,
    .fifo_winc                           (fifo_winc                                    )
);

//////////////////////////////////////////////////
//4. FIFO
//////////////////////////////////////////////////
assign fifo_rst      = ~src_rst_n | ~dev_rst_n | chn_ctl[8];
assign fifo_wr_ready = ~fifo_wr_rst_busy;
assign fifo_rd_ready = ~fifo_rd_rst_busy;

ASYNC_512X256_FIFO dma_fifo(
    .rst                                 (fifo_rst                                     ) ,
    .wr_clk                              (src_clk                                      ) ,
    .rd_clk                              (dev_clk                                      ) ,
    .din                                 (fifo_wdat                                    ) ,
    .wr_en                               (fifo_winc                                    ) ,
    .rd_en                               (fifo_rinc                                    ) ,
    .dout                                (fifo_rdat                                    ) ,
    .full                                (fifo_full                                    ) ,
    .empty                               (fifo_empty                                   ) ,
    .rd_data_count                       (fifo_rlevel                                  ) ,
    .wr_rst_busy                         (fifo_wr_rst_busy                             ) ,
    .rd_rst_busy                         (fifo_rd_rst_busy                             )
);

//////////////////////////////////////////////////
//5. AXI Write Transmitter
//////////////////////////////////////////////////
DMA_TXD dma_txd(
    .dev_clk                             (dev_clk                                      ) ,
    .dev_rst_n                           (dev_chn_rst_n                                ) ,
    .chn_addr                            (chn_addr                                     ) ,
    .chn_num                             (chn_num[12:0]                                ) ,
    .chn_ctl                             (chn_ctl                                      ) ,
    .chn_en                              (chn_en                                       ) ,
    .chn_run                             (chn_run                                      ) ,
    .fifo_rdat                           (fifo_rdat                                    ) ,
    .fifo_empty                          (fifo_empty                                   ) ,
    .fifo_rlevel                         (fifo_rlevel                                  ) ,
    .fifo_rd_ready                       (fifo_rd_ready                                ) ,
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
    .txd_busy                            (txd_busy                                     ) ,
    .half_trans                          (half_trans                                   ) ,
    .trans_comp                          (trans_comp                                   ) ,
    .axi_error                           (axi_error                                    ) ,
    .run_clear                           (run_clear                                    )
);

endmodule
