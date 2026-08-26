`timescale 1ns / 1ps
`default_nettype none

// Synchronize the Clocking Wizard lock indication and require a continuous
// stable window before allowing RMU to release system resets.
module CMU_READY(
    input   wire                            SYS_CLK                     ,
    input   wire                            EXT_RST_N                   ,
    input   wire                            MMCM_LOCKED                 ,
    output  wire                            MMCM_LOCKED_SYNC            ,
    output  reg                             SYS_CLK_READY
);

parameter               READY_STABLE_CYC    = 16                        ;
parameter               READY_CNT_W         = 5                         ;
parameter               UDLY                = 1                         ;

localparam  [READY_CNT_W-1:0] READY_LAST     = READY_STABLE_CYC - 1      ;

(* ASYNC_REG = "TRUE" *)
reg         [1:0]                   mmcm_locked_sync_r                ;
reg         [READY_CNT_W-1:0]       ready_count                       ;
wire                                ready_rst_n                       ;

assign ready_rst_n = EXT_RST_N & MMCM_LOCKED;

// Raw lock loss is a safety reset source: assertion clears the synchronizer
// immediately; lock reacquisition still releases through two SYS_CLK stages.
always @(posedge SYS_CLK or negedge ready_rst_n) begin
    if(!ready_rst_n)
        mmcm_locked_sync_r <= #UDLY 2'b00;
    else
        mmcm_locked_sync_r <= #UDLY {mmcm_locked_sync_r[0], 1'b1};
end

assign MMCM_LOCKED_SYNC = mmcm_locked_sync_r[1];

always @(posedge SYS_CLK or negedge ready_rst_n) begin
    if(!ready_rst_n) begin
        ready_count   <= #UDLY {READY_CNT_W{1'b0}};
        SYS_CLK_READY <= #UDLY 1'b0;
    end else if(!MMCM_LOCKED_SYNC) begin
        ready_count   <= #UDLY {READY_CNT_W{1'b0}};
        SYS_CLK_READY <= #UDLY 1'b0;
    end else if(!SYS_CLK_READY) begin
        if(ready_count == READY_LAST) begin
            ready_count   <= #UDLY ready_count;
            SYS_CLK_READY <= #UDLY 1'b1;
        end else begin
            ready_count   <= #UDLY ready_count + {{(READY_CNT_W-1){1'b0}}, 1'b1};
            SYS_CLK_READY <= #UDLY 1'b0;
        end
    end else begin
        ready_count   <= #UDLY ready_count;
        SYS_CLK_READY <= #UDLY 1'b1;
    end
end

endmodule

`default_nettype wire
