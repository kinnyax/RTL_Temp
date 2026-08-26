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

localparam              [2:0]               TGC_IDLE                 = 3'd0                ;
localparam              [2:0]               TGC_APPLY                = 3'd1                ;
localparam              [2:0]               TGC_SLOPE                = 3'd2                ;
localparam              [2:0]               TGC_DONE                 = 3'd3                ;
localparam              [2:0]               TGC_CANCEL               = 3'd4                ;

reg                     [2:0]               tgc_fsm                                        ;
reg                     [2:0]               tgc_fsm_nx                                     ;

assign tgc_idle = (tgc_fsm == TGC_IDLE) & !tgc_cmd_evt;

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n)
        tgc_fsm <= #UDLY TGC_IDLE;
    else
        tgc_fsm <= #UDLY tgc_fsm_nx;
end

always @(*) begin
    tgc_fsm_nx = tgc_fsm;

    case(tgc_fsm)
        TGC_IDLE:
            if(tgc_cmd_evt)
                tgc_fsm_nx = chn_en ? TGC_APPLY : TGC_CANCEL;

        TGC_APPLY:
            tgc_fsm_nx = chn_en ? TGC_SLOPE : TGC_CANCEL;

        TGC_SLOPE:
            tgc_fsm_nx = chn_en ? TGC_DONE : TGC_CANCEL;

        TGC_DONE:
            tgc_fsm_nx = TGC_IDLE;

        TGC_CANCEL:
            tgc_fsm_nx = TGC_IDLE;

        default:
            tgc_fsm_nx = TGC_IDLE;
    endcase
end

always @(posedge afe_clk or negedge afe_rst_n) begin
    if(!afe_rst_n) begin
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
        end

        case(tgc_fsm)
            TGC_IDLE:
                if(tgc_cmd_evt & chn_en) begin
                    tgc_slope <= #UDLY 1'b0;
                    tgc_up_dn <= #UDLY up_dn;
                    tgc_prof1 <= #UDLY profile_sel[0];
                    tgc_prof2 <= #UDLY profile_sel[1];
                end

            TGC_APPLY:
                if(chn_en)
                    tgc_slope <= #UDLY 1'b1;

            TGC_SLOPE:
                if(chn_en) begin
                    tgc_slope    <= #UDLY 1'b0;
                    tgc_done_evt <= #UDLY 1'b1;
                end

            TGC_CANCEL: begin
                tgc_slope    <= #UDLY 1'b0;
                tgc_up_dn    <= #UDLY 1'b0;
                tgc_prof1    <= #UDLY 1'b0;
                tgc_prof2    <= #UDLY 1'b0;
                tgc_done_evt <= #UDLY 1'b1;
            end

            default: begin
            end
        endcase
    end
end

endmodule
