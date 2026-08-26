`timescale 1ns / 1ps
`default_nettype none

// Exact logical 256-entry occupancy around Vivado FIFO Generator FWFT cores.
// PG057 states that an independent-clock FWFT FIFO configured for depth 256
// has an effective depth of 257 and that native data_count can over-report near
// empty.  This tracker counts only successful logical transfers, gates the
// 257th write, and synchronizes Gray event counters between clock domains.
module SPI_FIFO_LEVEL_TRACKER (
    input  wire         wr_rst,
    input  wire         rd_rst,
    input  wire         wr_clk,
    input  wire         rd_clk,
    input  wire         wr_accept,
    input  wire         rd_accept,
    output wire         wr_full,
    output wire         rd_empty,
    output wire [8:0]   wr_level,
    output wire [8:0]   rd_level
);

reg [8:0] wr_pointer;
reg [8:0] rd_pointer;

wire [8:0] wr_pointer_gray;
wire [8:0] rd_pointer_gray;
(* ASYNC_REG = "TRUE" *) reg [8:0] wr_gray_rd_meta;
(* ASYNC_REG = "TRUE" *) reg [8:0] wr_gray_rd_sync;
(* ASYNC_REG = "TRUE" *) reg [8:0] rd_gray_wr_meta;
(* ASYNC_REG = "TRUE" *) reg [8:0] rd_gray_wr_sync;

wire [8:0] wr_pointer_rd;
wire [8:0] rd_pointer_wr;

function [8:0] gray_to_binary;
    input [8:0] gray_value;
    integer bit_index;
    begin
        gray_to_binary[8] = gray_value[8];
        for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
            gray_to_binary[bit_index] =
                gray_to_binary[bit_index + 1] ^ gray_value[bit_index];
    end
endfunction

assign wr_pointer_gray = (wr_pointer >> 1) ^ wr_pointer;
assign rd_pointer_gray = (rd_pointer >> 1) ^ rd_pointer;
assign wr_pointer_rd   = gray_to_binary(wr_gray_rd_sync);
assign rd_pointer_wr   = gray_to_binary(rd_gray_wr_sync);

assign wr_level = wr_pointer - rd_pointer_wr;
assign rd_level = wr_pointer_rd - rd_pointer;
assign wr_full  = (wr_level == 9'd256);
assign rd_empty = (rd_level == 9'd0);

always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst)
        wr_pointer <= 9'd0;
    else if (wr_accept)
        wr_pointer <= wr_pointer + 9'd1;
end

always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst)
        rd_pointer <= 9'd0;
    else if (rd_accept)
        rd_pointer <= rd_pointer + 9'd1;
end

always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst) begin
        wr_gray_rd_meta <= 9'd0;
        wr_gray_rd_sync <= 9'd0;
    end
    else begin
        wr_gray_rd_meta <= wr_pointer_gray;
        wr_gray_rd_sync <= wr_gray_rd_meta;
    end
end

always @(posedge wr_clk or posedge wr_rst) begin
    if (wr_rst) begin
        rd_gray_wr_meta <= 9'd0;
        rd_gray_wr_sync <= 9'd0;
    end
    else begin
        rd_gray_wr_meta <= rd_pointer_gray;
        rd_gray_wr_sync <= rd_gray_wr_meta;
    end
end

endmodule

module SPI_TX_FIFO_256X32 (
    input  wire         rst,
    input  wire         wr_clk,
    input  wire         rd_clk,
    input  wire [31:0]  din,
    input  wire         wr_en,
    input  wire         rd_en,
    output wire [31:0]  dout,
    output wire         full,
    output wire         empty,
    output wire [8:0]   wr_data_count
);

wire core_full;
wire core_empty;
wire logical_full;
wire logical_empty;
wire [8:0] read_level;
wire core_wr_en;
wire core_rd_en;
wire wr_rst_n;
wire rd_rst_n;
wire wr_local_rst;
wire rd_local_rst;

assign full       = logical_full | core_full;
assign empty      = logical_empty | core_empty;
assign core_wr_en = wr_en & ~wr_local_rst & ~full;
assign core_rd_en = rd_en & ~rd_local_rst & ~empty;

// Reuse the SPI-scoped PUB level synchronizer with a constant-one input.
// The raw reset asserts both pipelines asynchronously.  Their active-low
// outputs release only after two clean edges in the respective destination
// domains, so a SYS-domain FIFO clear cannot release SPI-domain state
// asynchronously (and vice versa).
SPI_LEVEL_SYNC #(
    .UDLY                   (0),
    .DS                     (2),
    .RV                     (1'b0)
) wr_reset_release_sync (
    .clk                    (wr_clk),
    .rst_n                  (~rst),
    .in                     (1'b1),
    .out                    (wr_rst_n)
);

SPI_LEVEL_SYNC #(
    .UDLY                   (0),
    .DS                     (2),
    .RV                     (1'b0)
) rd_reset_release_sync (
    .clk                    (rd_clk),
    .rst_n                  (~rst),
    .in                     (1'b1),
    .out                    (rd_rst_n)
);

assign wr_local_rst = ~wr_rst_n;
assign rd_local_rst = ~rd_rst_n;

SPI_FIFO_256X32_CORE fifo_core (
    .rst                    (rst),
    .wr_clk                 (wr_clk),
    .rd_clk                 (rd_clk),
    .din                    (din),
    .wr_en                  (core_wr_en),
    .rd_en                  (core_rd_en),
    .dout                   (dout),
    .full                   (core_full),
    .empty                  (core_empty)
);

SPI_FIFO_LEVEL_TRACKER level_tracker (
    .wr_rst                 (wr_local_rst),
    .rd_rst                 (rd_local_rst),
    .wr_clk                 (wr_clk),
    .rd_clk                 (rd_clk),
    .wr_accept              (core_wr_en),
    .rd_accept              (core_rd_en),
    .wr_full                (logical_full),
    .rd_empty               (logical_empty),
    .wr_level               (wr_data_count),
    .rd_level               (read_level)
);

endmodule

module SPI_RX_FIFO_256X32 (
    input  wire         rst,
    input  wire         wr_clk,
    input  wire         rd_clk,
    input  wire [31:0]  din,
    input  wire         wr_en,
    input  wire         rd_en,
    output wire [31:0]  dout,
    output wire         full,
    output wire         empty,
    output wire [8:0]   rd_data_count
);

wire core_full;
wire core_empty;
wire logical_full;
wire logical_empty;
wire [8:0] write_level;
wire core_wr_en;
wire core_rd_en;
wire wr_rst_n;
wire rd_rst_n;
wire wr_local_rst;
wire rd_local_rst;

assign full       = logical_full | core_full;
assign empty      = logical_empty | core_empty;
assign core_wr_en = wr_en & ~wr_local_rst & ~full;
assign core_rd_en = rd_en & ~rd_local_rst & ~empty;

SPI_LEVEL_SYNC #(
    .UDLY                   (0),
    .DS                     (2),
    .RV                     (1'b0)
) wr_reset_release_sync (
    .clk                    (wr_clk),
    .rst_n                  (~rst),
    .in                     (1'b1),
    .out                    (wr_rst_n)
);

SPI_LEVEL_SYNC #(
    .UDLY                   (0),
    .DS                     (2),
    .RV                     (1'b0)
) rd_reset_release_sync (
    .clk                    (rd_clk),
    .rst_n                  (~rst),
    .in                     (1'b1),
    .out                    (rd_rst_n)
);

assign wr_local_rst = ~wr_rst_n;
assign rd_local_rst = ~rd_rst_n;

SPI_FIFO_256X32_CORE fifo_core (
    .rst                    (rst),
    .wr_clk                 (wr_clk),
    .rd_clk                 (rd_clk),
    .din                    (din),
    .wr_en                  (core_wr_en),
    .rd_en                  (core_rd_en),
    .dout                   (dout),
    .full                   (core_full),
    .empty                  (core_empty)
);

SPI_FIFO_LEVEL_TRACKER level_tracker (
    .wr_rst                 (wr_local_rst),
    .rd_rst                 (rd_local_rst),
    .wr_clk                 (wr_clk),
    .rd_clk                 (rd_clk),
    .wr_accept              (core_wr_en),
    .rd_accept              (core_rd_en),
    .wr_full                (logical_full),
    .rd_empty               (logical_empty),
    .wr_level               (write_level),
    .rd_level               (rd_data_count)
);

endmodule

`default_nettype wire
