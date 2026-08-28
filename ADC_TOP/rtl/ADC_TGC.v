`timescale 1ns / 1ps

module ADC_TGC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   chn_en                                         ,
    input               [ 3:0]              tgc_chn                                        ,

    output    wire                          tgc_idle                                       ,
    output    reg                           tgc_slope                                      ,
    output    reg                           tgc_up_dn                                      ,
    output    reg                           tgc_prof1                                      ,
    output    reg                           tgc_prof2
);

parameter                                   UDLY                     = 1                   ;

localparam                                  TGC_IDLE                 = 2'd0                ;
localparam                                  TGC_APPLY                = 2'd1                ;
localparam                                  TGC_SLOPE                = 2'd2                ;

wire                                        tgc_run_sync                                   ;
wire                                        tgc_start                                      ;
wire                                        tgc_apply                                      ;
wire                                        tgc_slope_phase                                ;

reg                     [ 1:0]              tgc_fsm                                        ;
reg                     [ 1:0]              tgc_fsm_nx                                     ;

//////////////////////////////////////////////////
//1. Run Event CDC
//////////////////////////////////////////////////
pulse_sync tgc_run_pulse_sync(
    .clka                                (sys_clk                                      ),
    .clkb                                (afe_clk                                      ),
    .rst_n_a                             (sys_rst_n                                    ),
    .rst_n_b                             (afe_rst_n                                    ),
    .in                                  (tgc_chn[0]                                   ),
    .out                                 (tgc_run_sync                                 )
);

//////////////////////////////////////////////////
//2. State Machine
//////////////////////////////////////////////////
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        tgc_fsm <= #UDLY TGC_IDLE;
    else if(~chn_en)
        tgc_fsm <= #UDLY TGC_IDLE;
    else
        tgc_fsm <= #UDLY tgc_fsm_nx;
end

always @(*) begin
    case(tgc_fsm)
        TGC_IDLE : begin
            if(tgc_start)
                tgc_fsm_nx = TGC_APPLY;
            else
                tgc_fsm_nx = TGC_IDLE;
        end
        TGC_APPLY : begin
            tgc_fsm_nx = TGC_SLOPE;
        end
        TGC_SLOPE : begin
            tgc_fsm_nx = TGC_IDLE;
        end
        default : begin
            tgc_fsm_nx = TGC_IDLE;
        end
    endcase
end

//////////////////////////////////////////////////
//3. State Decode And Pin Action
//////////////////////////////////////////////////
assign tgc_idle        = (tgc_fsm == TGC_IDLE);
assign tgc_start       = tgc_idle & chn_en & tgc_run_sync;
assign tgc_apply       = (tgc_fsm == TGC_APPLY);
assign tgc_slope_phase = (tgc_fsm == TGC_SLOPE);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n) begin
        tgc_slope <= #UDLY 1'd0;
        tgc_up_dn <= #UDLY 1'd0;
        tgc_prof1 <= #UDLY 1'd0;
        tgc_prof2 <= #UDLY 1'd0;
    end
    else if(~chn_en) begin
        tgc_slope <= #UDLY 1'd0;
        tgc_up_dn <= #UDLY 1'd0;
        tgc_prof1 <= #UDLY 1'd0;
        tgc_prof2 <= #UDLY 1'd0;
    end
    else if(tgc_start) begin
        tgc_slope <= #UDLY 1'd0;
        tgc_up_dn <= #UDLY tgc_chn[3];
        tgc_prof1 <= #UDLY tgc_chn[1];
        tgc_prof2 <= #UDLY tgc_chn[2];
    end
    else if(tgc_apply)
        tgc_slope <= #UDLY 1'd1;
    else if(tgc_slope_phase)
        tgc_slope <= #UDLY 1'd0;
end

endmodule
