`timescale 1ns / 1ps

module SPI_TOP(
    input                                   sys_clk                                        ,
    input                                   spi_clk                                        ,
    input                                   rst_n                                          ,

    input               [31:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    wire                          s_axi_awready                                  ,
    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    wire                          s_axi_wready                                   ,
    output    wire      [ 1:0]              s_axi_bresp                                    ,
    output    wire                          s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,
    input               [31:0]              s_axi_araddr                                   ,
    input                                   s_axi_arvalid                                  ,
    output    wire                          s_axi_arready                                  ,
    output    wire      [31:0]              s_axi_rdata                                    ,
    output    wire      [ 1:0]              s_axi_rresp                                    ,
    output    wire                          s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    input                                   spi_sck_in                                     ,
    output    wire                          spi_sck_out                                    ,
    output    wire                          spi_sck_oe                                     ,
    input                                   spi_mosi_in                                    ,
    output    wire                          spi_mosi_out                                   ,
    output    wire                          spi_mosi_oe                                    ,
    input                                   spi_miso_in                                    ,
    output    wire                          spi_miso_out                                   ,
    output    wire                          spi_miso_oe                                    ,
    input               [ 3:0]              spi_cs_in                                      ,
    output    wire      [ 3:0]              spi_cs_out                                     ,
    output    wire      [ 3:0]              spi_cs_oe
);

parameter                                   UDLY                     = 1                   ;

wire                    [31:0]              spi_ctl                                        ;
wire                    [31:0]              sck_div                                        ;
wire                    [31:0]              cs_cfg                                         ;
wire                                        spi_en                                         ;
wire                    [ 5:0]              spi_io                                         ;
wire                                        cs_sel                                         ;
wire                                        spi_cs_n                                       ;
wire                                        spi_busy                                       ;
wire                                        spi_busy_sync                                  ;
wire                                        sample_trig                                    ;
wire                                        bit_end                                        ;

wire                    [31:0]              tx_fifo_wdata                                  ;
wire                                        tx_fifo_winc                                   ;
wire                    [31:0]              tx_fifo_rdata                                  ;
wire                                        tx_fifo_rinc                                   ;
wire                    [ 5:0]              tx_fifo_level                                  ;
wire                                        tx_fifo_full                                   ;
wire                                        tx_fifo_empty                                  ;
wire                                        tx_fifo_of                                     ;
wire                                        tx_fifo_uf                                     ;
wire                                        tx_fifo_empty_sync                             ;
wire                                        tx_fifo_uf_sync                                ;
wire                                        txf_rst_n                                      ;

wire                    [31:0]              rx_fifo_wdata                                  ;
wire                                        rx_fifo_winc                                   ;
wire                    [31:0]              rx_fifo_rdata                                  ;
wire                                        rx_fifo_rinc                                   ;
wire                                        rx_fifo_full                                   ;
wire                                        rx_fifo_empty                                  ;
wire                                        rx_fifo_of                                     ;
wire                                        rx_fifo_uf                                     ;
wire                                        rx_fifo_full_sync                              ;
wire                                        rx_fifo_of_sync                                ;
wire                                        rxf_rst_n                                      ;

//////////////////////////////////////////////////
//1. Configuration And Physical Input CDC
//////////////////////////////////////////////////
level_sync #(.RV(1'd0)) spi_enable_level_sync(.clk(spi_clk), .rst_n(rst_n), .in(spi_ctl[0]), .out(spi_en));
levels_sync #(.DS(6), .RV(1'd0)) spi_io_levels_sync(.clk(spi_clk), .rst_n(rst_n), .in({spi_sck_in, spi_cs_in, spi_mosi_in}), .out(spi_io));

//////////////////////////////////////////////////
//2. Register And Status CDC
//////////////////////////////////////////////////
SPI_REG spi_reg(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (rst_n                                        ),
    .s_axi_awaddr                        (s_axi_awaddr                                 ),
    .s_axi_awvalid                       (s_axi_awvalid                                ),
    .s_axi_awready                       (s_axi_awready                                ),
    .s_axi_wdata                         (s_axi_wdata                                  ),
    .s_axi_wstrb                         (s_axi_wstrb                                  ),
    .s_axi_wvalid                        (s_axi_wvalid                                 ),
    .s_axi_wready                        (s_axi_wready                                 ),
    .s_axi_bresp                         (s_axi_bresp                                  ),
    .s_axi_bvalid                        (s_axi_bvalid                                 ),
    .s_axi_bready                        (s_axi_bready                                 ),
    .s_axi_araddr                        (s_axi_araddr                                 ),
    .s_axi_arvalid                       (s_axi_arvalid                                ),
    .s_axi_arready                       (s_axi_arready                                ),
    .s_axi_rdata                         (s_axi_rdata                                  ),
    .s_axi_rresp                         (s_axi_rresp                                  ),
    .s_axi_rvalid                        (s_axi_rvalid                                 ),
    .s_axi_rready                        (s_axi_rready                                 ),
    .spi_ctl                             (spi_ctl                                      ),
    .sck_div                             (sck_div                                      ),
    .cs_cfg                              (cs_cfg                                       ),
    .spi_busy                            (spi_busy_sync                                ),
    .tx_fifo_empty                       (tx_fifo_empty_sync                           ),
    .tx_fifo_full                        (tx_fifo_full                                 ),
    .tx_fifo_of                          (tx_fifo_of                                   ),
    .tx_fifo_uf                          (tx_fifo_uf_sync                              ),
    .rx_fifo_empty                       (rx_fifo_empty                                ),
    .rx_fifo_full                        (rx_fifo_full_sync                            ),
    .rx_fifo_of                          (rx_fifo_of_sync                              ),
    .rx_fifo_uf                          (rx_fifo_uf                                   ),
    .tx_fifo_wdata                       (tx_fifo_wdata                                ),
    .tx_fifo_winc                        (tx_fifo_winc                                 ),
    .rx_fifo_rdata                       (rx_fifo_rdata                                ),
    .rx_fifo_rinc                        (rx_fifo_rinc                                 )
);

SPI_SYNC spi_sync(
    .sys_clk                             (sys_clk                                      ),
    .spi_clk                             (spi_clk                                      ),
    .rst_n                               (rst_n                                        ),
    .spi_busy                            (spi_busy                                     ),
    .spi_busy_sync                       (spi_busy_sync                                ),
    .tx_fifo_empty                       (tx_fifo_empty                                ),
    .tx_fifo_empty_sync                  (tx_fifo_empty_sync                           ),
    .rx_fifo_full                        (rx_fifo_full                                 ),
    .rx_fifo_full_sync                   (rx_fifo_full_sync                            ),
    .tx_fifo_uf                          (tx_fifo_uf                                   ),
    .tx_fifo_uf_sync                     (tx_fifo_uf_sync                              ),
    .rx_fifo_of                          (rx_fifo_of                                   ),
    .rx_fifo_of_sync                     (rx_fifo_of_sync                              )
);

//////////////////////////////////////////////////
//3. SPI Data Path And Pin Coding
//////////////////////////////////////////////////
SPI_TXD spi_txd(
    .spi_clk                             (spi_clk                                      ),
    .rst_n                               (rst_n                                        ),
    .spi_en                              (spi_en                                       ),
    .spi_ctl                             (spi_ctl                                      ),
    .sck_div                             (sck_div                                      ),
    .spi_sck_in                          (spi_io[5]                                    ),
    .cs_sel                              (cs_sel                                       ),
    .tx_fifo_rdata                       (tx_fifo_rdata                                ),
    .tx_fifo_empty                       (tx_fifo_empty                                ),
    .tx_fifo_level                       (tx_fifo_level                                ),
    .tx_fifo_rinc                        (tx_fifo_rinc                                 ),
    .spi_busy                            (spi_busy                                     ),
    .spi_cs_n                            (spi_cs_n                                     ),
    .spi_sck_out                         (spi_sck_out                                  ),
    .spi_sck_oe                          (spi_sck_oe                                   ),
    .spi_mosi_out                        (spi_mosi_out                                 ),
    .spi_mosi_oe                         (spi_mosi_oe                                  ),
    .spi_miso_out                        (spi_miso_out                                 ),
    .spi_miso_oe                         (spi_miso_oe                                  ),
    .spi_cs_oe                           (spi_cs_oe                                    ),
    .sample_trig                         (sample_trig                                  ),
    .bit_end                             (bit_end                                      )
);

SPI_RXD spi_rxd(
    .spi_clk                             (spi_clk                                      ),
    .rst_n                               (rst_n                                        ),
    .spi_en                              (spi_en                                       ),
    .spi_ctl                             (spi_ctl                                      ),
    .sample_trig                         (sample_trig                                  ),
    .bit_end                             (bit_end                                      ),
    .spi_busy                            (spi_busy                                     ),
    .spi_miso_in                         (spi_miso_in                                  ),
    .spi_mosi_in                         (spi_io[0]                                    ),
    .rx_fifo_wdata                       (rx_fifo_wdata                                ),
    .rx_fifo_winc                        (rx_fifo_winc                                 )
);

SPI_CODE spi_code(
    .spi_ctl                             (spi_ctl                                      ),
    .cs_cfg                              (cs_cfg                                       ),
    .spi_cs_n                            (spi_cs_n                                     ),
    .spi_cs_in                           (spi_io[4:1]                                  ),
    .spi_cs_out                          (spi_cs_out                                   ),
    .cs_sel                              (cs_sel                                       )
);

//////////////////////////////////////////////////
//4. Asynchronous FIFOs
//////////////////////////////////////////////////
assign txf_rst_n = rst_n & ~spi_ctl[9];

async_fifo #(
    .AS                                  (5                                            ),
    .DS                                  (32                                           ),
    .RSTEN                               (0                                            ),
    .WC                                  (0                                            ),
    .RC                                  (0                                            )
) tx_async_fifo(
    .wclk                                (sys_clk                                      ),
    .rclk                                (spi_clk                                      ),
    .wclr                                (1'd0                                         ),
    .rclr                                (1'd0                                         ),
    .rst_n                               (txf_rst_n                                    ),
    .winc                                (tx_fifo_winc                                 ),
    .rinc                                (tx_fifo_rinc                                 ),
    .wdata                               (tx_fifo_wdata                                ),
    .rdata                               (tx_fifo_rdata                                ),
    .full                                (tx_fifo_full                                 ),
    .empty                               (tx_fifo_empty                                ),
    .overflow                            (tx_fifo_of                                   ),
    .underflow                           (tx_fifo_uf                                   ),
    .wlevel                              (                                             ),
    .rlevel                              (tx_fifo_level                                )
);

assign rxf_rst_n = rst_n & ~spi_ctl[10];

async_fifo #(
    .AS                                  (5                                            ),
    .DS                                  (32                                           ),
    .RSTEN                               (0                                            ),
    .WC                                  (0                                            ),
    .RC                                  (0                                            )
) rx_async_fifo(
    .wclk                                (spi_clk                                      ),
    .rclk                                (sys_clk                                      ),
    .wclr                                (1'd0                                         ),
    .rclr                                (1'd0                                         ),
    .rst_n                               (rxf_rst_n                                    ),
    .winc                                (rx_fifo_winc                                 ),
    .rinc                                (rx_fifo_rinc                                 ),
    .wdata                               (rx_fifo_wdata                                ),
    .rdata                               (rx_fifo_rdata                                ),
    .full                                (rx_fifo_full                                 ),
    .empty                               (rx_fifo_empty                                ),
    .overflow                            (rx_fifo_of                                   ),
    .underflow                           (rx_fifo_uf                                   ),
    .wlevel                              (                                             ),
    .rlevel                              (                                             )
);

endmodule
