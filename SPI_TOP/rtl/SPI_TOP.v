`timescale 1ns / 1ps
`default_nettype none

module SPI_TOP #(
    parameter integer       AXI_ADDR_WIDTH              = 15            ,
    parameter integer       UDLY                        = 1
)(
    input   wire                            SYS_CLK                     ,
    input   wire                            SYS_RST_N                   ,
    input   wire                            SPI_RST_EN                  ,
    input   wire                            SPI_CLK                     ,
    input   wire                            SPI_RST_N                   ,
    input   wire        [AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR               ,
    input   wire        [2:0]               S_AXI_AWPROT                ,
    input   wire                            S_AXI_AWVALID               ,
    output  wire                            S_AXI_AWREADY               ,
    input   wire        [31:0]              S_AXI_WDATA                ,
    input   wire        [3:0]               S_AXI_WSTRB                ,
    input   wire                            S_AXI_WVALID               ,
    output  wire                            S_AXI_WREADY               ,
    output  wire        [1:0]               S_AXI_BRESP                ,
    output  wire                            S_AXI_BVALID               ,
    input   wire                            S_AXI_BREADY               ,
    input   wire        [AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR               ,
    input   wire        [2:0]               S_AXI_ARPROT                ,
    input   wire                            S_AXI_ARVALID               ,
    output  wire                            S_AXI_ARREADY               ,
    output  wire        [31:0]              S_AXI_RDATA                ,
    output  wire        [1:0]               S_AXI_RRESP                ,
    output  wire                            S_AXI_RVALID               ,
    input   wire                            S_AXI_RREADY               ,
    input   wire                            spi_miso_i                  ,
    output  wire                            spi_mosi_o                  ,
    output  wire                            spi_sck_o                   ,
    output  wire        [3:0]               spi_nss_code_o              ,
    output  wire                            busy_o
);

wire                                spi_enable_sys                      ;
wire                                run_request_sys                     ;
wire                                tx_fifo_clear                       ;
wire                                rx_fifo_clear                       ;
wire        [7:0]                   command_sys                         ;
wire        [11:0]                  address_sys                         ;
wire        [15:0]                  length_sys                          ;
wire        [7:0]                   command_spi                         ;
wire        [11:0]                  address_spi                         ;
wire        [15:0]                  length_spi                          ;
wire                                enable_spi                          ;
wire                                run_pulse_spi                       ;
wire                                busy_spi                            ;
wire                                done_spi                            ;
wire                                error_spi                           ;
wire                                done_sys                            ;
wire                                error_sys                           ;
wire                                tx_underflow_spi                    ;
wire                                tx_underflow_sys                    ;
wire                                rx_overflow_spi                     ;
wire                                rx_overflow_sys                     ;
wire                                tx_fifo_wen                         ;
wire        [31:0]                  tx_fifo_wdata                       ;
wire                                tx_fifo_ren                         ;
wire        [31:0]                  tx_fifo_rdata                       ;
wire                                tx_fifo_full                        ;
wire                                tx_fifo_empty                       ;
wire        [8:0]                   tx_fifo_level                       ;
wire                                rx_fifo_wen                         ;
wire        [31:0]                  rx_fifo_wdata                       ;
wire                                rx_fifo_ren                         ;
wire        [31:0]                  rx_fifo_rdata                       ;
wire                                rx_fifo_full                        ;
wire                                rx_fifo_empty                       ;
wire        [8:0]                   rx_fifo_level                       ;
wire                                tx_unit_take                        ;
wire                                unit_is_16bit                       ;
wire        [15:0]                  tx_unit_data                        ;
wire                                rx_unit_valid                       ;
wire                                rx_unit_last                        ;
wire        [15:0]                  rx_unit_data                        ;

SPI_REG #(
    .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH                    ),
    .UDLY                   (UDLY                              )
) spi_registers (
    .SYS_CLK                (SYS_CLK                           ),
    .SYS_RST_N              (SYS_RST_N                         ),
    .SPI_RST_EN             (SPI_RST_EN                        ),
    .S_AXI_AWADDR           (S_AXI_AWADDR                      ),
    .S_AXI_AWPROT           (S_AXI_AWPROT                      ),
    .S_AXI_AWVALID          (S_AXI_AWVALID                     ),
    .S_AXI_AWREADY          (S_AXI_AWREADY                     ),
    .S_AXI_WDATA            (S_AXI_WDATA                       ),
    .S_AXI_WSTRB            (S_AXI_WSTRB                       ),
    .S_AXI_WVALID           (S_AXI_WVALID                      ),
    .S_AXI_WREADY           (S_AXI_WREADY                      ),
    .S_AXI_BRESP            (S_AXI_BRESP                       ),
    .S_AXI_BVALID           (S_AXI_BVALID                      ),
    .S_AXI_BREADY           (S_AXI_BREADY                      ),
    .S_AXI_ARADDR           (S_AXI_ARADDR                      ),
    .S_AXI_ARPROT           (S_AXI_ARPROT                      ),
    .S_AXI_ARVALID          (S_AXI_ARVALID                     ),
    .S_AXI_ARREADY          (S_AXI_ARREADY                     ),
    .S_AXI_RDATA            (S_AXI_RDATA                       ),
    .S_AXI_RRESP            (S_AXI_RRESP                       ),
    .S_AXI_RVALID           (S_AXI_RVALID                      ),
    .S_AXI_RREADY           (S_AXI_RREADY                      ),
    .busy_sys               (busy_o                            ),
    .done_pulse_sys         (done_sys                          ),
    .error_pulse_sys        (error_sys                         ),
    .tx_underflow_sys       (tx_underflow_sys                  ),
    .rx_overflow_sys        (rx_overflow_sys                   ),
    .tx_fifo_full           (tx_fifo_full                      ),
    .tx_fifo_level          (tx_fifo_level                     ),
    .rx_fifo_empty          (rx_fifo_empty                     ),
    .rx_fifo_level          (rx_fifo_level                     ),
    .rx_fifo_rdata          (rx_fifo_rdata                     ),
    .tx_fifo_wen            (tx_fifo_wen                       ),
    .tx_fifo_wdata          (tx_fifo_wdata                     ),
    .rx_fifo_ren            (rx_fifo_ren                       ),
    .spi_enable             (spi_enable_sys                    ),
    .run_request            (run_request_sys                   ),
    .tx_fifo_clear          (tx_fifo_clear                     ),
    .rx_fifo_clear          (rx_fifo_clear                     ),
    .spi_command            (command_sys                       ),
    .spi_address            (address_sys                       ),
    .spi_length             (length_sys                        )
);

SPI_SYNC #(
    .UDLY                   (UDLY                              )
) spi_synchronizers (
    .SYS_CLK                (SYS_CLK                           ),
    .SYS_RST_N              (SYS_RST_N                         ),
    .SPI_CLK                (SPI_CLK                           ),
    .SPI_RST_N              (SPI_RST_N                         ),
    .run_request_sys        (run_request_sys                   ),
    .command_sys            (command_sys                       ),
    .address_sys            (address_sys                       ),
    .length_sys             (length_sys                        ),
    .enable_sys             (spi_enable_sys                    ),
    .busy_spi               (busy_spi                          ),
    .done_spi               (done_spi                          ),
    .error_spi              (error_spi                         ),
    .tx_underflow_spi       (tx_underflow_spi                  ),
    .rx_overflow_spi        (rx_overflow_spi                   ),
    .run_pulse_spi          (run_pulse_spi                     ),
    .command_spi            (command_spi                       ),
    .address_spi            (address_spi                       ),
    .length_spi             (length_spi                        ),
    .enable_spi             (enable_spi                        ),
    .busy_sys               (busy_o                            ),
    .done_sys               (done_sys                          ),
    .error_sys              (error_sys                         ),
    .tx_underflow_sys       (tx_underflow_sys                  ),
    .rx_overflow_sys        (rx_overflow_sys                   )
);

SPI_TXD #(
    .UDLY                   (UDLY                              )
) spi_transmit_data (
    .SPI_CLK                (SPI_CLK                           ),
    .SPI_RST_N              (SPI_RST_N                         ),
    .pack_reset             (run_pulse_spi                     ),
    .unit_is_16bit          (unit_is_16bit                     ),
    .unit_take              (tx_unit_take                      ),
    .fifo_empty             (tx_fifo_empty                     ),
    .fifo_rdata             (tx_fifo_rdata                     ),
    .fifo_ren               (tx_fifo_ren                       ),
    .unit_data              (tx_unit_data                      ),
    .underflow_pulse        (tx_underflow_spi                  )
);

SPI_RXD #(
    .UDLY                   (UDLY                              )
) spi_receive_data (
    .SPI_CLK                (SPI_CLK                           ),
    .SPI_RST_N              (SPI_RST_N                         ),
    .pack_reset             (run_pulse_spi                     ),
    .unit_is_16bit          (unit_is_16bit                     ),
    .unit_valid             (rx_unit_valid                     ),
    .unit_last              (rx_unit_last                      ),
    .unit_data              (rx_unit_data                      ),
    .fifo_full              (rx_fifo_full                      ),
    .fifo_wen               (rx_fifo_wen                       ),
    .fifo_wdata             (rx_fifo_wdata                     ),
    .overflow_pulse         (rx_overflow_spi                   )
);

SPI_CTL #(
    .UDLY                   (UDLY                              )
) spi_controller (
    .SPI_CLK                (SPI_CLK                           ),
    .SPI_RST_N              (SPI_RST_N                         ),
    .enable_spi             (enable_spi                        ),
    .run_pulse              (run_pulse_spi                     ),
    .command                (command_spi                       ),
    .address                (address_spi                       ),
    .length                 (length_spi                        ),
    .spi_miso_i             (spi_miso_i                        ),
    .tx_unit_data           (tx_unit_data                      ),
    .tx_unit_take           (tx_unit_take                      ),
    .unit_is_16bit          (unit_is_16bit                     ),
    .rx_unit_valid          (rx_unit_valid                     ),
    .rx_unit_last           (rx_unit_last                      ),
    .rx_unit_data           (rx_unit_data                      ),
    .spi_mosi_o             (spi_mosi_o                        ),
    .spi_sck_o              (spi_sck_o                         ),
    .spi_nss_code_o         (spi_nss_code_o                    ),
    .busy_spi               (busy_spi                          ),
    .done_pulse             (done_spi                          ),
    .error_pulse            (error_spi                         )
);

SPI_TX_FIFO_256X32 spi_transmit_fifo (
    .rst                    (~SYS_RST_N |
                             ~SPI_RST_N |
                             tx_fifo_clear                    ),
    .wr_clk                 (SYS_CLK                           ),
    .rd_clk                 (SPI_CLK                           ),
    .din                    (tx_fifo_wdata                     ),
    .wr_en                  (tx_fifo_wen                       ),
    .rd_en                  (tx_fifo_ren                       ),
    .dout                   (tx_fifo_rdata                     ),
    .full                   (tx_fifo_full                      ),
    .empty                  (tx_fifo_empty                     ),
    .wr_data_count          (tx_fifo_level                     )
);

SPI_RX_FIFO_256X32 spi_receive_fifo (
    .rst                    (~SYS_RST_N |
                             ~SPI_RST_N |
                             rx_fifo_clear                    ),
    .wr_clk                 (SPI_CLK                           ),
    .rd_clk                 (SYS_CLK                           ),
    .din                    (rx_fifo_wdata                     ),
    .wr_en                  (rx_fifo_wen                       ),
    .rd_en                  (rx_fifo_ren                       ),
    .dout                   (rx_fifo_rdata                     ),
    .full                   (rx_fifo_full                      ),
    .empty                  (rx_fifo_empty                     ),
    .rd_data_count          (rx_fifo_level                     )
);

endmodule

`default_nettype wire
