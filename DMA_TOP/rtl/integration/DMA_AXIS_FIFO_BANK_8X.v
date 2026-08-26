`timescale 1ns / 1ps
`default_nettype none

// Integration-only transport adapter.  Each lane is wired 1:1 to the
// corresponding official axis_data_fifo:2.0 instance; it adds no storage,
// arbitration, CDC, reset logic, or protocol behaviour.
module DMA_AXIS_FIFO_BANK_8X (
    input  wire          s_axis_aclk,
    input  wire [7:0]    s_axis_aresetn,
    input  wire [4095:0] s_axis_tdata,
    input  wire [511:0]  s_axis_tkeep,
    input  wire [7:0]    s_axis_tlast,
    input  wire [7:0]    s_axis_tvalid,
    output wire [7:0]    s_axis_tready,
    input  wire          m_axis_aclk,
    output wire [4095:0] m_axis_tdata,
    output wire [511:0]  m_axis_tkeep,
    output wire [7:0]    m_axis_tlast,
    output wire [7:0]    m_axis_tvalid,
    input  wire [7:0]    m_axis_tready,
    output wire [79:0]   axis_rd_data_count
);
    // axis_data_fifo:2.0 exposes a 32-bit count. DMA_TOP's accepted channel
    // contract consumes the low 10 bits (the configured FIFO depth is 512).
    wire [255:0] axis_rd_data_count_full;
    genvar count_lane;
    generate
        for (count_lane = 0; count_lane < 8; count_lane = count_lane + 1) begin : g_count_slice
            assign axis_rd_data_count[count_lane*10 +: 10] = axis_rd_data_count_full[count_lane*32 +: 10];
        end
    endgenerate
    genvar lane;
    generate
        for (lane = 0; lane < 8; lane = lane + 1) begin : g_axis_fifo
            if (lane == 0) begin : g0
                DMA_AXIS_FIFO_CH0 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else if (lane == 1) begin : g1
                DMA_AXIS_FIFO_CH1 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else if (lane == 2) begin : g2
                DMA_AXIS_FIFO_CH2 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else if (lane == 3) begin : g3
                DMA_AXIS_FIFO_CH3 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else if (lane == 4) begin : g4
                DMA_AXIS_FIFO_CH4 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else if (lane == 5) begin : g5
                DMA_AXIS_FIFO_CH5 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else if (lane == 6) begin : g6
                DMA_AXIS_FIFO_CH6 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end else begin : g7
                DMA_AXIS_FIFO_CH7 u_fifo (.s_axis_aresetn(s_axis_aresetn[lane]), .s_axis_aclk(s_axis_aclk), .s_axis_tvalid(s_axis_tvalid[lane]), .s_axis_tready(s_axis_tready[lane]), .s_axis_tdata(s_axis_tdata[lane*512 +: 512]), .s_axis_tkeep(s_axis_tkeep[lane*64 +: 64]), .s_axis_tlast(s_axis_tlast[lane]), .m_axis_aclk(m_axis_aclk), .m_axis_tvalid(m_axis_tvalid[lane]), .m_axis_tready(m_axis_tready[lane]), .m_axis_tdata(m_axis_tdata[lane*512 +: 512]), .m_axis_tkeep(m_axis_tkeep[lane*64 +: 64]), .m_axis_tlast(m_axis_tlast[lane]), .axis_rd_data_count(axis_rd_data_count_full[lane*32 +: 32]));
            end
        end
    endgenerate
endmodule

`default_nettype wire
