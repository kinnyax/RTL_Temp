`timescale 1ns / 1ps

module ADC_TGC(
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,

    input                                   chn_en                                         ,
    input                                   tgc_cmd_evt                                    ,
    input               [ 1:0]              profile_sel                                    ,
    input                                   up_dn                                          ,

    output    reg                           tgc_done_evt                                   ,
    output    wire                          tgc_idle                                       ,
    output    reg                           tgc_slope                                      ,
    output    reg                           tgc_up_dn                                      ,
    output    reg                           tgc_prof1                                      ,
    output    reg                           tgc_prof2
);

parameter                                   UDLY                     = 1                   ;

localparam                                  TGC_IDLE                 = 3'd0                ;
localparam                                  TGC_APPLY                = 3'd1                ;
localparam                                  TGC_SLOPE                = 3'd2                ;
localparam                                  TGC_DONE                 = 3'd3                ;
localparam                                  TGC_CANCEL               = 3'd4                ;

reg                     [ 2:0]              tgc_fsm                                        ;
reg                     [ 2:0]              tgc_fsm_nx                                     ;


always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0)
        tgc_fsm <= #UDLY TGC_IDLE;
    else
        tgc_fsm <= #UDLY tgc_fsm_nx;
end

always @(*) begin
    case(tgc_fsm)
        TGC_IDLE : begin
            if(chn_en && tgc_cmd_evt)
                tgc_fsm_nx = TGC_APPLY;
            else
                tgc_fsm_nx = TGC_IDLE;
        end
        TGC_APPLY : begin
            if(!chn_en)
                tgc_fsm_nx = TGC_CANCEL;
            else
                tgc_fsm_nx = TGC_SLOPE;
        end
        TGC_SLOPE : begin
            if(!chn_en)
                tgc_fsm_nx = TGC_CANCEL;
            else
                tgc_fsm_nx = TGC_DONE;
        end
        TGC_DONE : begin
            tgc_fsm_nx = TGC_IDLE;
        end
        TGC_CANCEL : begin
            tgc_fsm_nx = TGC_IDLE;
        end
        default : begin
            tgc_fsm_nx = TGC_IDLE;
        end
    endcase
end

assign tgc_idle = (tgc_fsm==TGC_IDLE);

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(afe_rst_n==1'b0) begin
        tgc_done_evt <= #UDLY 1'b0;
        tgc_slope    <= #UDLY 1'b0;
        tgc_up_dn    <= #UDLY 1'b0;
        tgc_prof1    <= #UDLY 1'b0;
        tgc_prof2    <= #UDLY 1'b0;
    end
    else begin
        tgc_done_evt <= #UDLY 1'b0;
        if(!chn_en) begin
            tgc_slope <= #UDLY 1'b0;
            tgc_up_dn <= #UDLY 1'b0;
            tgc_prof1 <= #UDLY 1'b0;
            tgc_prof2 <= #UDLY 1'b0;
            if((tgc_fsm==TGC_APPLY) || (tgc_fsm==TGC_SLOPE))
                tgc_done_evt <= #UDLY 1'b1;
        end
        else begin
            case(tgc_fsm)
                TGC_IDLE : begin
                    if(tgc_cmd_evt) begin
                        tgc_slope <= #UDLY 1'b0;
                        tgc_up_dn <= #UDLY up_dn;
                        tgc_prof1 <= #UDLY profile_sel[0];
                        tgc_prof2 <= #UDLY profile_sel[1];
                    end
                end
                TGC_APPLY : begin
                    tgc_slope <= #UDLY 1'b1;
                end
                TGC_SLOPE : begin
                    tgc_slope    <= #UDLY 1'b0;
                    tgc_done_evt <= #UDLY 1'b1;
                end
                TGC_CANCEL : begin
                    tgc_slope <= #UDLY 1'b0;
                    tgc_up_dn <= #UDLY 1'b0;
                    tgc_prof1 <= #UDLY 1'b0;
                    tgc_prof2 <= #UDLY 1'b0;
                end
                default : begin
                    tgc_slope <= #UDLY tgc_slope;
                end
            endcase
        end
    end
end

endmodule
