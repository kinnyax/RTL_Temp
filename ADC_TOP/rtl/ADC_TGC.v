`timescale 1ns / 1ps

module ADC_TGC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   chn_en                                         ,
    input               [ 3:0]              chn_tgc                                        ,

    output    wire                          tgc_done                                       ,
    output    wire                          tgc_sta_idle                                   ,
    output    reg                           tgc_slope                                      ,
    output    reg                           tgc_up_dn                                      ,
    output    reg                           tgc_prof1                                      ,
    output    reg                           tgc_prof2
);

localparam                                  TGC_IDLE                 = 2'd0                ;
localparam                                  TGC_APPLY                = 2'd1                ;
localparam                                  TGC_SLOPE                = 2'd2                ;
localparam                                  TGC_END                  = 2'd3                ;

wire                                        tgc_req                                        ;
wire                                        tgc_start                                      ;
wire                                        tgc_sta_apply                                  ;
wire                                        tgc_sta_slope                                  ;
wire                                        tgc_sta_end                                    ;

reg                                         tgc_ready                                      ;
reg                     [ 1:0]              tgc_fsm                                        ;
reg                     [ 1:0]              tgc_fsm_nx                                     ;

//////////////////////////////////////////////////
//1. Request CDC
//////////////////////////////////////////////////
req_sync tgc_req_sync(
    .clka                                (sys_clk                                      ),
    .clkb                                (afe_clk                                      ),
    .rst_n_a                             (sys_rst_n                                    ),
    .rst_n_b                             (afe_rst_n                                    ),
    .reqa                                (chn_tgc[0]                                   ),
    .rdya                                (tgc_done                                     ),
    .reqb                                (tgc_req                                      ),
    .rdyb                                (tgc_ready                                    )
);

always @(negedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        tgc_ready <= 1'd0;
    else if(tgc_sta_end)
        tgc_ready <= 1'd1;
    else
        tgc_ready <= 1'd0;
end

//////////////////////////////////////////////////
//2. State Machine
//////////////////////////////////////////////////
always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n)
        tgc_fsm <= TGC_IDLE;
    else
        tgc_fsm <= tgc_fsm_nx;
end

always @(*) begin
    case(tgc_fsm)
        TGC_IDLE : begin
            if(tgc_req & chn_en)
                tgc_fsm_nx = TGC_APPLY;
            else if(tgc_req)
                tgc_fsm_nx = TGC_END;
            else
                tgc_fsm_nx = TGC_IDLE;
        end
        TGC_APPLY : begin
            if(~chn_en)
                tgc_fsm_nx = TGC_END;
            else
                tgc_fsm_nx = TGC_SLOPE;
        end
        TGC_SLOPE : begin
            tgc_fsm_nx = TGC_END;
        end
        TGC_END : begin
            if(tgc_req)
                tgc_fsm_nx = TGC_END;
            else
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
assign tgc_sta_idle  = (tgc_fsm == TGC_IDLE);
assign tgc_start     = tgc_sta_idle & tgc_req & chn_en;
assign tgc_sta_apply = (tgc_fsm == TGC_APPLY);
assign tgc_sta_slope = (tgc_fsm == TGC_SLOPE);
assign tgc_sta_end   = (tgc_fsm == TGC_END);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(~afe_rst_n) begin
        tgc_slope <= 1'd0;
        tgc_up_dn <= 1'd0;
        tgc_prof1 <= 1'd0;
        tgc_prof2 <= 1'd0;
    end
    else if(~chn_en) begin
        tgc_slope <= 1'd0;
        tgc_up_dn <= 1'd0;
        tgc_prof1 <= 1'd0;
        tgc_prof2 <= 1'd0;
    end
    else if(tgc_start) begin
        tgc_slope <= 1'd0;
        tgc_up_dn <= chn_tgc[3];
        tgc_prof1 <= chn_tgc[1];
        tgc_prof2 <= chn_tgc[2];
    end
    else if(tgc_sta_apply)
        tgc_slope <= 1'd1;
    else if(tgc_sta_slope)
        tgc_slope <= 1'd0;
end

endmodule
