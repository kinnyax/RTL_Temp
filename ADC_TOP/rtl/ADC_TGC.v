`timescale 1ns / 1ps

// TGC control sequencer.
module ADC_TGC(
    // AFE clock domain
    input  wire                             afe_clk                                      ,
    input  wire                             afe_rst_n                                    ,

    // TGC command and configuration
    input  wire                             tgc_req                                      ,
    input  wire [7:0]                       afe_mask                                     ,
    input  wire [1:0]                       profile_sel                                  ,
    input  wire                             up_dn                                        ,
    input  wire                             slope_trig                                   ,

    // TGC control and status
    output reg  [7:0]                       tgc_slope                                    ,
    output reg  [7:0]                       tgc_up_dn                                    ,
    output reg  [7:0]                       tgc_prof1                                    ,
    output reg  [7:0]                       tgc_prof2                                    ,
    output wire                             tgc_busy                                     ,
    output wire                             tgc_done
);

parameter                                   UDLY                                         = 1        ;

localparam [1:0]                            TGC_IDLE                                     = 2'd0     ;
localparam [1:0]                            TGC_WAIT1                                    = 2'd1     ;
localparam [1:0]                            TGC_WAIT2                                    = 2'd2     ;
localparam [1:0]                            TGC_FIRE                                     = 2'd3     ;

reg      [1:0]                              tgc_fsm                                      ;
reg      [1:0]                              tgc_fsm_nx                                   ;
reg      [7:0]                              mask_r                                       ;
reg                                         slope_r                                      ;

wire                                        tgc_fsm_idle                                 ;
wire                                        tgc_fsm_fire                                 ;
wire                                        tgc_cmd_accept                               ;

assign tgc_fsm_idle   = (tgc_fsm == TGC_IDLE);
assign tgc_fsm_fire   = (tgc_fsm == TGC_FIRE);
assign tgc_cmd_accept = tgc_fsm_idle && tgc_req;
assign tgc_busy       = !tgc_fsm_idle;
assign tgc_done       = tgc_fsm_fire;

// 1. State register.
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        tgc_fsm <= #UDLY TGC_IDLE;
    end else begin
        tgc_fsm <= #UDLY tgc_fsm_nx;
    end
end

// 2. State transition.
always @* begin
    case (tgc_fsm)
        TGC_IDLE: begin
            if (tgc_req) begin
                tgc_fsm_nx = TGC_WAIT1;
            end else begin
                tgc_fsm_nx = TGC_IDLE;
            end
        end
        TGC_WAIT1: begin
            tgc_fsm_nx = TGC_WAIT2;
        end
        TGC_WAIT2: begin
            tgc_fsm_nx = TGC_FIRE;
        end
        TGC_FIRE: begin
            tgc_fsm_nx = TGC_IDLE;
        end
        default: begin
            tgc_fsm_nx = TGC_IDLE;
        end
    endcase
end

// 3. State output.
always @* begin
    tgc_slope = 8'd0;
    if (tgc_fsm_fire && slope_r)
        tgc_slope = mask_r;
end

// 4. Command context.
always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        mask_r  <= #UDLY 8'd0;
        slope_r <= #UDLY 1'b0;
    end else if (tgc_cmd_accept) begin
        mask_r  <= #UDLY afe_mask;
        slope_r <= #UDLY slope_trig;
    end
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if (!afe_rst_n) begin
        tgc_up_dn <= #UDLY 8'd0;
        tgc_prof1 <= #UDLY 8'd0;
        tgc_prof2 <= #UDLY 8'd0;
    end else if (tgc_cmd_accept) begin
        tgc_up_dn <= #UDLY (tgc_up_dn & ~afe_mask) | ({8{up_dn}} & afe_mask);
        tgc_prof1 <= #UDLY (tgc_prof1 & ~afe_mask) |
                           ({8{profile_sel[0]}} & afe_mask);
        tgc_prof2 <= #UDLY (tgc_prof2 & ~afe_mask) |
                           ({8{profile_sel[1]}} & afe_mask);
    end
end

endmodule
