`timescale 1ns / 1ps

module DMA_SYNC #(
    parameter integer                       UDLY                        = 1
)(
    input  wire                             SYS_CLK                                     ,
    input  wire                             DMA_AXIS_RST_N                              ,
    input  wire                             M_AXI_ACLK                                  ,
    input  wire                             DMA_RST_N                                   ,
    input  wire [7:0]                       ch_en_sys                                   ,
    input  wire [255:0]                     ch_addr_shadow                              ,
    input  wire [255:0]                     ch_num_shadow                               ,
    input  wire [71:0]                      ch_ctl_shadow                               ,
    input  wire [7:0]                       half_event_m                                ,
    input  wire [7:0]                       full_event_m                                ,
    input  wire [7:0]                       error_event_m                               ,
    input  wire [7:0]                       stop_event_m                                ,
    input  wire [7:0]                       ch_busy_m                                   ,
    input  wire [7:0]                       axi_busy_m                                  ,
    input  wire [7:0]                       fifo_empty_m                                ,
    output reg  [7:0]                       ch_en_m                                     ,
    output reg  [255:0]                     ch_addr_active                              ,
    output reg  [255:0]                     ch_num_active                               ,
    output reg  [71:0]                      ch_ctl_active                               ,
    output wire [7:0]                       half_event_sys                              ,
    output wire [7:0]                       full_event_sys                              ,
    output wire [7:0]                       error_event_sys                             ,
    output wire [7:0]                       stop_event_sys                              ,
    output wire [7:0]                       ch_busy_sys                                 ,
    output wire [7:0]                       axi_busy_sys                                ,
    output wire [7:0]                       fifo_empty_sys
);

wire [7:0]                               ch_en_level_sync                              ;
wire [7:0]                               ch_en_rise                                    ;
wire [23:0]                              live_status_m                                 ;
wire [23:0]                              live_status_sys                               ;
reg                                      snapshot_valid0                               ;
reg                                      snapshot_valid1                               ;
reg                                      snapshot_valid2                               ;
reg                                      snapshot_valid3                               ;
reg                                      snapshot_valid4                               ;
reg                                      snapshot_valid5                               ;
reg                                      snapshot_valid6                               ;
reg                                      snapshot_valid7                               ;

assign live_status_m = {
    fifo_empty_m ,
    axi_busy_m   ,
    ch_busy_m
};

assign ch_busy_sys    = live_status_sys[7:0];
assign axi_busy_sys   = live_status_sys[15:8];
assign fifo_empty_sys = live_status_sys[23:16];
//////////////////////////////////////////////////
//1. Dynamic Level Synchronization
//////////////////////////////////////////////////

levels_sync #(
    .DS                                  (8                              ),
    .RV                                  (1'b0                           )
) channel_enable_level_sync_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_sys                      ),
    .out                                 (ch_en_level_sync               )
);

levels_sync #(
    .DS                                  (24                             ),
    .RV                                  (1'b0                           )
) live_status_level_sync_inst (
    .clk                                 (SYS_CLK                        ),
    .rst_n                               (DMA_AXIS_RST_N                 ),
    .in                                  (live_status_m                  ),
    .out                                 (live_status_sys                )
);

// ch_en_m is released only from the previous-cycle snapshot_valid values.
// Therefore Active configuration has one complete M_AXI_ACLK cycle to settle
// after the level_pos pulse before DMA_CHN can observe enable.
always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        ch_en_m <= #UDLY 8'd0;
    else
        ch_en_m <= #UDLY {
            snapshot_valid7 & ch_en_level_sync[7],
            snapshot_valid6 & ch_en_level_sync[6],
            snapshot_valid5 & ch_en_level_sync[5],
            snapshot_valid4 & ch_en_level_sync[4],
            snapshot_valid3 & ch_en_level_sync[3],
            snapshot_valid2 & ch_en_level_sync[2],
            snapshot_valid1 & ch_en_level_sync[1],
            snapshot_valid0 & ch_en_level_sync[0]
        };
end

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch0_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[0]            ),
    .out                                 (ch_en_rise[0]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch1_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[1]            ),
    .out                                 (ch_en_rise[1]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch2_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[2]            ),
    .out                                 (ch_en_rise[2]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch3_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[3]            ),
    .out                                 (ch_en_rise[3]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch4_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[4]            ),
    .out                                 (ch_en_rise[4]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch5_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[5]            ),
    .out                                 (ch_en_rise[5]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch6_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[6]            ),
    .out                                 (ch_en_rise[6]                  )
);

DMA_LEVEL_POS #(
    .UDLY                                (UDLY                           )
) ch7_enable_rise_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .in                                  (ch_en_level_sync[7]            ),
    .out                                 (ch_en_rise[7]                  )
);

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid0 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[0])
        snapshot_valid0 <= #UDLY 1'b0;
    else if(ch_en_rise[0])
        snapshot_valid0 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid1 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[1])
        snapshot_valid1 <= #UDLY 1'b0;
    else if(ch_en_rise[1])
        snapshot_valid1 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid2 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[2])
        snapshot_valid2 <= #UDLY 1'b0;
    else if(ch_en_rise[2])
        snapshot_valid2 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid3 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[3])
        snapshot_valid3 <= #UDLY 1'b0;
    else if(ch_en_rise[3])
        snapshot_valid3 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid4 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[4])
        snapshot_valid4 <= #UDLY 1'b0;
    else if(ch_en_rise[4])
        snapshot_valid4 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid5 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[5])
        snapshot_valid5 <= #UDLY 1'b0;
    else if(ch_en_rise[5])
        snapshot_valid5 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid6 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[6])
        snapshot_valid6 <= #UDLY 1'b0;
    else if(ch_en_rise[6])
        snapshot_valid6 <= #UDLY 1'b1;
end

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N)
        snapshot_valid7 <= #UDLY 1'b0;
    else if(!ch_en_level_sync[7])
        snapshot_valid7 <= #UDLY 1'b0;
    else if(ch_en_rise[7])
        snapshot_valid7 <= #UDLY 1'b1;
end

//////////////////////////////////////////////////
//2. Static Configuration Activation
//////////////////////////////////////////////////

always @(posedge M_AXI_ACLK or negedge DMA_RST_N) begin
    if(!DMA_RST_N) begin
        ch_addr_active <= #UDLY 256'd0;
        ch_num_active  <= #UDLY 256'd0;
        ch_ctl_active  <= #UDLY 72'd0;
    end
    else begin
        if(ch_en_rise[0]) begin
            ch_addr_active[31:0] <= #UDLY ch_addr_shadow[31:0];
            ch_num_active[31:0]  <= #UDLY ch_num_shadow[31:0];
            ch_ctl_active[8:0]   <= #UDLY ch_ctl_shadow[8:0];
        end
        if(ch_en_rise[1]) begin
            ch_addr_active[63:32] <= #UDLY ch_addr_shadow[63:32];
            ch_num_active[63:32]  <= #UDLY ch_num_shadow[63:32];
            ch_ctl_active[17:9]   <= #UDLY ch_ctl_shadow[17:9];
        end
        if(ch_en_rise[2]) begin
            ch_addr_active[95:64] <= #UDLY ch_addr_shadow[95:64];
            ch_num_active[95:64]  <= #UDLY ch_num_shadow[95:64];
            ch_ctl_active[26:18]  <= #UDLY ch_ctl_shadow[26:18];
        end
        if(ch_en_rise[3]) begin
            ch_addr_active[127:96] <= #UDLY ch_addr_shadow[127:96];
            ch_num_active[127:96]  <= #UDLY ch_num_shadow[127:96];
            ch_ctl_active[35:27]   <= #UDLY ch_ctl_shadow[35:27];
        end
        if(ch_en_rise[4]) begin
            ch_addr_active[159:128] <= #UDLY ch_addr_shadow[159:128];
            ch_num_active[159:128]  <= #UDLY ch_num_shadow[159:128];
            ch_ctl_active[44:36]    <= #UDLY ch_ctl_shadow[44:36];
        end
        if(ch_en_rise[5]) begin
            ch_addr_active[191:160] <= #UDLY ch_addr_shadow[191:160];
            ch_num_active[191:160]  <= #UDLY ch_num_shadow[191:160];
            ch_ctl_active[53:45]    <= #UDLY ch_ctl_shadow[53:45];
        end
        if(ch_en_rise[6]) begin
            ch_addr_active[223:192] <= #UDLY ch_addr_shadow[223:192];
            ch_num_active[223:192]  <= #UDLY ch_num_shadow[223:192];
            ch_ctl_active[62:54]    <= #UDLY ch_ctl_shadow[62:54];
        end
        if(ch_en_rise[7]) begin
            ch_addr_active[255:224] <= #UDLY ch_addr_shadow[255:224];
            ch_num_active[255:224]  <= #UDLY ch_num_shadow[255:224];
            ch_ctl_active[71:63]    <= #UDLY ch_ctl_shadow[71:63];
        end
    end
end

//////////////////////////////////////////////////
//3. Event Pulse Synchronization
//////////////////////////////////////////////////

pulse_sync2 ch0_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[0]                ),
    .out                                 (half_event_sys[0]              )
);

pulse_sync2 ch1_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[1]                ),
    .out                                 (half_event_sys[1]              )
);

pulse_sync2 ch2_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[2]                ),
    .out                                 (half_event_sys[2]              )
);

pulse_sync2 ch3_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[3]                ),
    .out                                 (half_event_sys[3]              )
);

pulse_sync2 ch4_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[4]                ),
    .out                                 (half_event_sys[4]              )
);

pulse_sync2 ch5_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[5]                ),
    .out                                 (half_event_sys[5]              )
);

pulse_sync2 ch6_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[6]                ),
    .out                                 (half_event_sys[6]              )
);

pulse_sync2 ch7_half_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (half_event_m[7]                ),
    .out                                 (half_event_sys[7]              )
);

pulse_sync2 ch0_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[0]                ),
    .out                                 (full_event_sys[0]              )
);

pulse_sync2 ch1_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[1]                ),
    .out                                 (full_event_sys[1]              )
);

pulse_sync2 ch2_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[2]                ),
    .out                                 (full_event_sys[2]              )
);

pulse_sync2 ch3_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[3]                ),
    .out                                 (full_event_sys[3]              )
);

pulse_sync2 ch4_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[4]                ),
    .out                                 (full_event_sys[4]              )
);

pulse_sync2 ch5_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[5]                ),
    .out                                 (full_event_sys[5]              )
);

pulse_sync2 ch6_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[6]                ),
    .out                                 (full_event_sys[6]              )
);

pulse_sync2 ch7_full_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (full_event_m[7]                ),
    .out                                 (full_event_sys[7]              )
);

pulse_sync2 ch0_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[0]               ),
    .out                                 (error_event_sys[0]             )
);

pulse_sync2 ch1_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[1]               ),
    .out                                 (error_event_sys[1]             )
);

pulse_sync2 ch2_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[2]               ),
    .out                                 (error_event_sys[2]             )
);

pulse_sync2 ch3_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[3]               ),
    .out                                 (error_event_sys[3]             )
);

pulse_sync2 ch4_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[4]               ),
    .out                                 (error_event_sys[4]             )
);

pulse_sync2 ch5_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[5]               ),
    .out                                 (error_event_sys[5]             )
);

pulse_sync2 ch6_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[6]               ),
    .out                                 (error_event_sys[6]             )
);

pulse_sync2 ch7_error_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (error_event_m[7]               ),
    .out                                 (error_event_sys[7]             )
);

pulse_sync2 ch0_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[0]                ),
    .out                                 (stop_event_sys[0]              )
);

pulse_sync2 ch1_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[1]                ),
    .out                                 (stop_event_sys[1]              )
);

pulse_sync2 ch2_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[2]                ),
    .out                                 (stop_event_sys[2]              )
);

pulse_sync2 ch3_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[3]                ),
    .out                                 (stop_event_sys[3]              )
);

pulse_sync2 ch4_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[4]                ),
    .out                                 (stop_event_sys[4]              )
);

pulse_sync2 ch5_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[5]                ),
    .out                                 (stop_event_sys[5]              )
);

pulse_sync2 ch6_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[6]                ),
    .out                                 (stop_event_sys[6]              )
);

pulse_sync2 ch7_stop_event_sync_inst (
    .clka                                (M_AXI_ACLK                     ),
    .clkb                                (SYS_CLK                        ),
    .rst_n_a                             (DMA_RST_N                      ),
    .rst_n_b                             (DMA_AXIS_RST_N                 ),
    .in                                  (stop_event_m[7]                ),
    .out                                 (stop_event_sys[7]              )
);

endmodule
