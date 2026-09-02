`timescale 1ns / 1ps

module CMU_SYS(
    input                                   ext_clk_p                                      ,
    input                                   ext_clk_n                                      ,

    output    wire                          sys_clk                                        ,
    output    reg                           sys_clk_ready                                  ,
    output    reg                           mmcm_locked                                    ,
    output    wire                          jesd_drp_clk
);

parameter                                   UDLY                     = 1                   ;

wire                                        sys_clk_src                                    ;
wire                                        clk_40m_src                                    ;
wire                                        root_locked                                    ;

reg                                         root_locked_r                                  ;
reg                     [ 3:0]              locked_cnt                                     ;

//////////////////////////////////////////////////
//1. Root Clock Generation
//////////////////////////////////////////////////
CMU_CLK_WIZ cmu_clk_wiz(.SYS_CLK_SRC(sys_clk_src), .CLK_40M_SRC(clk_40m_src), .locked(root_locked), .clk_in1_p(ext_clk_p), .clk_in1_n(ext_clk_n));

XIL_CLK_BUFFER sys_clk_buf(.clk_in(sys_clk_src), .clk_out(sys_clk));
XIL_CLK_BUFFER jesd_drp_clk_buf(.clk_in(clk_40m_src), .clk_out(jesd_drp_clk));

//////////////////////////////////////////////////
//2. Root Lock Synchronization
//////////////////////////////////////////////////
always @(posedge sys_clk) begin
    root_locked_r <= #UDLY root_locked;
    mmcm_locked   <= #UDLY root_locked_r;
end

//////////////////////////////////////////////////
//3. System Clock Qualification
//////////////////////////////////////////////////
always @(posedge sys_clk) begin
    if(~mmcm_locked)
        locked_cnt <= #UDLY 4'd0;
    else if(~sys_clk_ready) begin
        if(locked_cnt != 4'd15)
            locked_cnt <= #UDLY locked_cnt + 4'd1;
    end
end

always @(posedge sys_clk) begin
    if(~mmcm_locked)
        sys_clk_ready <= #UDLY 1'd0;
    else if(locked_cnt == 4'd15)
        sys_clk_ready <= #UDLY 1'd1;
end

endmodule
