`timescale 1ns / 1ps
`default_nettype none

module SPI_SYNC #(
    parameter integer       UDLY                        = 1
)(
    input   wire            SYS_CLK                                     ,
    input   wire            SYS_RST_N                                   ,
    input   wire            SPI_CLK                                     ,
    input   wire            SPI_RST_N                                   ,
    input   wire            run_request_sys                             ,
    input   wire    [7:0]   command_sys                                 ,
    input   wire    [11:0]  address_sys                                 ,
    input   wire    [15:0]  length_sys                                  ,
    input   wire            enable_sys                                  ,
    input   wire            busy_spi                                    ,
    input   wire            done_spi                                    ,
    input   wire            error_spi                                   ,
    input   wire            tx_underflow_spi                            ,
    input   wire            rx_overflow_spi                             ,
    output  wire            run_pulse_spi                               ,
    output  reg     [7:0]   command_spi                                 ,
    output  reg     [11:0]  address_spi                                 ,
    output  reg     [15:0]  length_spi                                  ,
    output  wire            enable_spi                                  ,
    output  wire            busy_sys                                    ,
    output  wire            done_sys                                    ,
    output  wire            error_sys                                   ,
    output  wire            tx_underflow_sys                            ,
    output  wire            rx_overflow_sys
);

SPI_PULSE_HANDSHAKE #(
    .UDLY               (UDLY                              )
) run_request_cdc (
    .source_clk         (SYS_CLK                           ),
    .source_rst_n       (SYS_RST_N                         ),
    .destination_clk    (SPI_CLK                           ),
    .destination_rst_n  (SPI_RST_N                         ),
    .pulse_in           (run_request_sys                    ),
    .pulse_out          (run_pulse_spi                      )
);

SPI_LEVEL_SYNC #(
    .UDLY               (UDLY                              ),
    .DS                 (2                                 ),
    .RV                 (1'b0                              )
) enable_cdc (
    .clk                (SPI_CLK                           ),
    .rst_n              (SPI_RST_N                         ),
    .in                 (enable_sys                        ),
    .out                (enable_spi                        )
);

SPI_LEVEL_SYNC #(
    .UDLY               (UDLY                              ),
    .DS                 (2                                 ),
    .RV                 (1'b0                              )
) busy_cdc (
    .clk                (SYS_CLK                           ),
    .rst_n              (SYS_RST_N                         ),
    .in                 (busy_spi                          ),
    .out                (busy_sys                          )
);

SPI_PULSE_HANDSHAKE #(
    .UDLY               (UDLY                              )
) done_cdc (
    .source_clk         (SPI_CLK                           ),
    .source_rst_n       (SPI_RST_N                         ),
    .destination_clk    (SYS_CLK                           ),
    .destination_rst_n  (SYS_RST_N                         ),
    .pulse_in           (done_spi                          ),
    .pulse_out          (done_sys                          )
);

SPI_PULSE_HANDSHAKE #(
    .UDLY               (UDLY                              )
) error_cdc (
    .source_clk         (SPI_CLK                           ),
    .source_rst_n       (SPI_RST_N                         ),
    .destination_clk    (SYS_CLK                           ),
    .destination_rst_n  (SYS_RST_N                         ),
    .pulse_in           (error_spi                         ),
    .pulse_out          (error_sys                         )
);

SPI_PULSE_HANDSHAKE #(
    .UDLY               (UDLY                              )
) tx_underflow_cdc (
    .source_clk         (SPI_CLK                           ),
    .source_rst_n       (SPI_RST_N                         ),
    .destination_clk    (SYS_CLK                           ),
    .destination_rst_n  (SYS_RST_N                         ),
    .pulse_in           (tx_underflow_spi                  ),
    .pulse_out          (tx_underflow_sys                  )
);

SPI_PULSE_HANDSHAKE #(
    .UDLY               (UDLY                              )
) rx_overflow_cdc (
    .source_clk         (SPI_CLK                           ),
    .source_rst_n       (SPI_RST_N                         ),
    .destination_clk    (SYS_CLK                           ),
    .destination_rst_n  (SYS_RST_N                         ),
    .pulse_in           (rx_overflow_spi                   ),
    .pulse_out          (rx_overflow_sys                   )
);

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        command_spi <= #UDLY 8'h00;
        address_spi <= #UDLY 12'h000;
        length_spi  <= #UDLY 16'h0000;
    end
    else if(run_pulse_spi) begin
        command_spi <= #UDLY command_sys;
        address_spi <= #UDLY address_sys;
        length_spi  <= #UDLY length_sys;
    end
end

endmodule

`default_nettype wire
