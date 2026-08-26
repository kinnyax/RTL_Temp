`timescale 1ns / 1ps
`default_nettype none

// PROJECT-OWNED CDC ADAPTATION
//
// Structural source:
//   D:\Codex\RTL\PUB\Lib.V, module pulse_sync
//   SHA256 7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
//
// Deliberate differences from pulse_sync:
// 1. The source and destination domains have independent authoritative resets.
//    The PUB pulse_sync/req_sync/req_ack modules have one shared rst_n and
//    therefore cannot be instantiated without coupling SYS_RST_N and SPI_RST_N.
// 2. The source request is held as a level until a synchronized destination
//    acknowledgement returns.
// 3. destination_rst_n asynchronously clears a source_clk-domain release pipe.
//    Its two-stage source_clk release produces source_channel_rst_n, so a
//    destination reset immediately cancels source_level and the returning ack
//    chain, but channel operation resumes synchronously in the source domain.
// 4. Both event pipelines reset to zero. A destination reset therefore cancels
//    every unacknowledged source request; release leaves source_level at zero
//    and cannot replay the cancelled request or create pulse_out.
//
// Recovery contract:
//   This channel uses reset-cancels-pending semantics, not at-least-once replay.
//   request_event is blocked until both authoritative resets are released and
//   destination release has crossed two source_clk edges. If pulse_in coincides
//   with either reset assertion, reset wins and the request is discarded. A
//   source reset cancels a source-held request; an event already captured by the
//   destination pipeline is considered transferred unless destination_rst_n is
//   also asserted. A source must not issue a second pulse until the first
//   request/acknowledgement round trip completes. SPI events naturally meet this
//   spacing, and RUN is blocked while RUN/BUSY is active.

module SPI_PULSE_HANDSHAKE #(
    parameter integer       UDLY                        = 1
)(
    input   wire            source_clk                                  ,
    input   wire            source_rst_n                                ,
    input   wire            destination_clk                             ,
    input   wire            destination_rst_n                           ,
    input   wire            pulse_in                                    ,
    output  wire            pulse_out
);

reg                         source_level                                ;
reg         [1:0]           acknowledge_pipe                            ;
reg         [2:0]           destination_pipe                            ;
reg         [1:0]           destination_release_pipe                    ;

wire                        acknowledge                                 ;
wire                        request_event                               ;
wire                        source_channel_rst_n                        ;

always @(posedge source_clk or negedge destination_rst_n) begin
    if(!destination_rst_n)
        destination_release_pipe <= #UDLY 2'b00;
    else
        destination_release_pipe <= #UDLY
                                    {destination_release_pipe[0], 1'b1};
end

assign source_channel_rst_n = source_rst_n &
                              destination_release_pipe[1];
assign request_event        = pulse_in & source_channel_rst_n;

always @(posedge source_clk or negedge source_channel_rst_n) begin
    if(!source_channel_rst_n)
        source_level <= #UDLY 1'b0;
    else if(acknowledge)
        source_level <= #UDLY 1'b0;
    else if(request_event)
        source_level <= #UDLY 1'b1;
end

always @(posedge destination_clk or negedge destination_rst_n) begin
    if(!destination_rst_n)
        destination_pipe <= #UDLY 3'b000;
    else
        destination_pipe <= #UDLY
                            {destination_pipe[1:0], source_level};
end

always @(posedge source_clk or negedge source_channel_rst_n) begin
    if(!source_channel_rst_n)
        acknowledge_pipe <= #UDLY 2'b00;
    else
        acknowledge_pipe <= #UDLY
                            {acknowledge_pipe[0], destination_pipe[2]};
end

assign pulse_out   = destination_pipe[1] & ~destination_pipe[2];
assign acknowledge = acknowledge_pipe[1];

endmodule

`default_nettype wire
