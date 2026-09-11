`timescale 1ns / 1ps

module ADC_ARB(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,

    input               [255:0]             s_axis_afe0_tdata                              ,
    input               [31:0]              s_axis_afe0_tkeep                              ,
    input                                   s_axis_afe0_tvalid                             ,
    input                                   s_axis_afe0_tlast                              ,
    output    wire                          s_axis_afe0_tready                             ,
    input               [255:0]             s_axis_afe1_tdata                              ,
    input               [31:0]              s_axis_afe1_tkeep                              ,
    input                                   s_axis_afe1_tvalid                             ,
    input                                   s_axis_afe1_tlast                              ,
    output    wire                          s_axis_afe1_tready                             ,
    input               [255:0]             s_axis_afe2_tdata                              ,
    input               [31:0]              s_axis_afe2_tkeep                              ,
    input                                   s_axis_afe2_tvalid                             ,
    input                                   s_axis_afe2_tlast                              ,
    output    wire                          s_axis_afe2_tready                             ,
    input               [255:0]             s_axis_afe3_tdata                              ,
    input               [31:0]              s_axis_afe3_tkeep                              ,
    input                                   s_axis_afe3_tvalid                             ,
    input                                   s_axis_afe3_tlast                              ,
    output    wire                          s_axis_afe3_tready                             ,
    input               [255:0]             s_axis_afe4_tdata                              ,
    input               [31:0]              s_axis_afe4_tkeep                              ,
    input                                   s_axis_afe4_tvalid                             ,
    input                                   s_axis_afe4_tlast                              ,
    output    wire                          s_axis_afe4_tready                             ,
    input               [255:0]             s_axis_afe5_tdata                              ,
    input               [31:0]              s_axis_afe5_tkeep                              ,
    input                                   s_axis_afe5_tvalid                             ,
    input                                   s_axis_afe5_tlast                              ,
    output    wire                          s_axis_afe5_tready                             ,
    input               [255:0]             s_axis_afe6_tdata                              ,
    input               [31:0]              s_axis_afe6_tkeep                              ,
    input                                   s_axis_afe6_tvalid                             ,
    input                                   s_axis_afe6_tlast                              ,
    output    wire                          s_axis_afe6_tready                             ,
    input               [255:0]             s_axis_afe7_tdata                              ,
    input               [31:0]              s_axis_afe7_tkeep                              ,
    input                                   s_axis_afe7_tvalid                             ,
    input                                   s_axis_afe7_tlast                              ,
    output    wire                          s_axis_afe7_tready                             ,

    output    wire      [255:0]             m_axis_tdata                                   ,
    output    wire      [31:0]              m_axis_tkeep                                   ,
    output    wire                          m_axis_tvalid                                  ,
    output    wire                          m_axis_tlast                                   ,
    input                                   m_axis_tready
);

wire                    [2047:0]            s_axis_tdata                                   ;
wire                    [255:0]             s_axis_tkeep                                   ;
wire                    [ 7:0]              s_axis_tvalid                                  ;
wire                    [ 7:0]              s_axis_tlast                                   ;
wire                    [ 7:0]              s_axis_tready                                  ;

//////////////////////////////////////////////////
//1. Input Packing
//////////////////////////////////////////////////
assign s_axis_tdata = {s_axis_afe7_tdata,s_axis_afe6_tdata,
                       s_axis_afe5_tdata,s_axis_afe4_tdata,
                       s_axis_afe3_tdata,s_axis_afe2_tdata,
                       s_axis_afe1_tdata,s_axis_afe0_tdata};
assign s_axis_tkeep = {s_axis_afe7_tkeep,s_axis_afe6_tkeep,
                       s_axis_afe5_tkeep,s_axis_afe4_tkeep,
                       s_axis_afe3_tkeep,s_axis_afe2_tkeep,
                       s_axis_afe1_tkeep,s_axis_afe0_tkeep};
assign s_axis_tvalid = {s_axis_afe7_tvalid,s_axis_afe6_tvalid,
                        s_axis_afe5_tvalid,s_axis_afe4_tvalid,
                        s_axis_afe3_tvalid,s_axis_afe2_tvalid,
                        s_axis_afe1_tvalid,s_axis_afe0_tvalid};
assign s_axis_tlast = {s_axis_afe7_tlast,s_axis_afe6_tlast,
                       s_axis_afe5_tlast,s_axis_afe4_tlast,
                       s_axis_afe3_tlast,s_axis_afe2_tlast,
                       s_axis_afe1_tlast,s_axis_afe0_tlast};
assign {s_axis_afe7_tready,s_axis_afe6_tready,
        s_axis_afe5_tready,s_axis_afe4_tready,
        s_axis_afe3_tready,s_axis_afe2_tready,
        s_axis_afe1_tready,s_axis_afe0_tready} = s_axis_tready;

//////////////////////////////////////////////////
//2. Packet Arbitration
//////////////////////////////////////////////////
AXIS_8x1_ARB axis_8x1_arb(
    .aclk                                (adc_clk                                      ),
    .aresetn                             (adc_rst_n                                    ),
    .s_axis_tvalid                       (s_axis_tvalid                                ),
    .s_axis_tready                       (s_axis_tready                                ),
    .s_axis_tdata                        (s_axis_tdata                                 ),
    .s_axis_tkeep                        (s_axis_tkeep                                 ),
    .s_axis_tlast                        (s_axis_tlast                                 ),
    .m_axis_tvalid                       (m_axis_tvalid                                ),
    .m_axis_tready                       (m_axis_tready                                ),
    .m_axis_tdata                        (m_axis_tdata                                 ),
    .m_axis_tkeep                        (m_axis_tkeep                                 ),
    .m_axis_tlast                        (m_axis_tlast                                 ),
    .s_req_suppress                      (8'd0                                         ),
    .s_decode_err                        (                                             )
);

endmodule
