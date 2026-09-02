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
wire                                        tgc_ack                                        ;
wire                                        tgc_req_pending                                ;
wire                                        tgc_src_pending_sync                           ;
wire                                        tgc_start                                      ;
wire                                        tgc_fsm_idle                                   ;
wire                                        tgc_apply                                      ;
wire                                        tgc_slope_phase                                ;

reg                                         tgc_req                                        ;
reg                                         tgc_src_pending                                ;
reg                     [ 1:0]              tgc_ack_sync                                   ;
reg                     [ 2:0]              tgc_req_sync                                   ;
reg                     [ 1:0]              tgc_fsm                                        ;
reg                     [ 1:0]              tgc_fsm_nx                                     ;

//////////////////////////////////////////////////
//1. Run Event CDC
//////////////////////////////////////////////////
assign tgc_ack = tgc_ack_sync[1];

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        tgc_req <= #UDLY 1'd0;
    else if(tgc_ack)
        tgc_req <= #UDLY 1'd0;
    else if(tgc_chn[0])
        tgc_req <= #UDLY 1'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        tgc_src_pending <= #UDLY 1'd0;
    else if(tgc_chn[0])
        tgc_src_pending <= #UDLY 1'd1;
    else if(~tgc_req & ~tgc_ack)
        tgc_src_pending <= #UDLY 1'd0;
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        tgc_req_sync <= #UDLY 3'd0;
    else
        tgc_req_sync <= #UDLY {tgc_req_sync[1:0],tgc_req};
end

assign tgc_run_sync    = tgc_req_sync[1] & ~tgc_req_sync[2];
assign tgc_req_pending = |tgc_req_sync[2:1];

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        tgc_ack_sync <= #UDLY 2'd0;
    else
        tgc_ack_sync <= #UDLY {tgc_ack_sync[0],tgc_req_sync[2]};
end

level_sync tgc_src_pending_level_sync(.clk(afe_clk),.rst_n(afe_rst_n),.in(tgc_src_pending),.out(tgc_src_pending_sync));

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
assign tgc_fsm_idle    = (tgc_fsm == TGC_IDLE);
assign tgc_idle        = tgc_fsm_idle & ~tgc_req_pending & ~tgc_src_pending_sync;
assign tgc_start       = tgc_fsm_idle & chn_en & tgc_run_sync;
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
