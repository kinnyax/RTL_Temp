`timescale 1ns / 1ps

// =====
// 1. TGC Control
// =====
module ADC_TGC(
    input  wire                             afe_clk                                     ,
    input  wire                             afe_rst_n                                   ,
    input  wire                             tgc_req                                     ,
    input  wire [7:0]                       afe_mask                                    ,
    input  wire [1:0]                       profile_sel                                 ,
    input  wire                             up_dn                                       ,
    input  wire                             slope_trig                                  ,
    output reg [7:0]                        tgc_slope                                   ,
    output reg [7:0]                        tgc_up_dn                                   ,
    output reg [7:0]                        tgc_prof1                                   ,
    output reg [7:0]                        tgc_prof2                                   ,
    output wire                             tgc_busy                                    ,
    output wire                             tgc_done
);

parameter                                  UDLY          = 1                            ;

localparam [1:0]                           TGC_IDLE      = 2'd0                         ;
localparam [1:0]                           TGC_WAIT1     = 2'd1                         ;
localparam [1:0]                           TGC_WAIT2     = 2'd2                         ;
localparam [1:0]                           TGC_FIRE      = 2'd3                         ;

reg [1:0]                                   tgc_fsm                                     ;
reg [1:0]                                   tgc_fsm_nx                                  ;
reg [7:0]                                   mask_r                                      ;
reg                                         slope_r                                     ;

assign tgc_busy = (tgc_fsm != TGC_IDLE);
assign tgc_done = (tgc_fsm == TGC_FIRE);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n)
        tgc_fsm <= #UDLY TGC_IDLE;
    else
        tgc_fsm <= #UDLY tgc_fsm_nx;
end

always @* begin
    tgc_fsm_nx = tgc_fsm;
    case (tgc_fsm)
        TGC_IDLE : if (tgc_req) tgc_fsm_nx = TGC_WAIT1;
        TGC_WAIT1:               tgc_fsm_nx = TGC_WAIT2;
        TGC_WAIT2:               tgc_fsm_nx = TGC_FIRE;
        TGC_FIRE :               tgc_fsm_nx = TGC_IDLE;
        default  :               tgc_fsm_nx = TGC_IDLE;
    endcase
end

always @* begin
    tgc_slope = 8'd0;
    if ((tgc_fsm == TGC_FIRE) && slope_r)
        tgc_slope = mask_r;
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        mask_r  <= 8'd0;
        slope_r <= 1'b0;
    end else if ((tgc_fsm == TGC_IDLE) && tgc_req) begin
        mask_r  <= afe_mask;
        slope_r <= slope_trig;
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        tgc_up_dn <= 8'd0;
        tgc_prof1 <= 8'd0;
        tgc_prof2 <= 8'd0;
    end else if ((tgc_fsm == TGC_IDLE) && tgc_req) begin
        tgc_up_dn <= (tgc_up_dn & ~afe_mask) | ({8{up_dn}} & afe_mask);
        tgc_prof1 <= (tgc_prof1 & ~afe_mask) |
                       ({8{profile_sel[0]}} & afe_mask);
        tgc_prof2 <= (tgc_prof2 & ~afe_mask) |
                       ({8{profile_sel[1]}} & afe_mask);
    end
end

endmodule

