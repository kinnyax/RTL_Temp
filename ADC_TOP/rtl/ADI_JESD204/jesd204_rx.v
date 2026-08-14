// Consolidated Analog Devices JESD204 RX source for ADC_TOP.
// Upstream: https://github.com/analogdevicesinc/hdl.git
// Frozen commit: 9d5de2fc21b6069675104567c9041bcdbfbe9baa
// This file consolidates the selected ADI modules.  ADC_TOP additionally
// declares one upstream implicit net and extends jesd204_frame_mark's generic
// power-of-two path to the contract-required 16-octet device datapath.
// Original copyright and GPLv2/commercial-license notices remain below.
// Moving or consolidating the source does not change its license or ownership.

// ============================================================================
// BEGIN UPSTREAM FILE: library/common/ad_pack.v
// ============================================================================
// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2020 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

// Packer:
//   - pack I_W number of data units into O_W number of data units
//   - data unit defined in bits by UNIT_W e.g 8 is a byte
//
// Constraints:
//   - O_W >= I_W
//   - no backpressure
//
// Data format:
//  idata  [U(I_W-1) .... U(0)]
//  odata [U(O_W-1) .... U(0)] 
//
// e.g 
//  I_W = 4
//  O_W = 6
//  UNIT_W = 8
//
//  idata : [B3,B2,B1,B0],[B7,B6,B5,B4],[B11,B10,B9,B8]
//  odata:                             [B5,B4,B3,B2,B1,B0],[B11,B10,B9,B8,B7,B6]
//

module ad_pack #(
  parameter I_W = 4,
  parameter O_W = 6,
  parameter UNIT_W = 8,
  parameter I_REG = 0,
  parameter O_REG = 1
) (
  input                   clk,
  input                   reset,
  input [I_W*UNIT_W-1:0]  idata,
  input                   ivalid,

  output reg [O_W*UNIT_W-1:0] odata = 'h0,
  output reg                  ovalid = 'b0
);

// Width of shift reg is integer multiple of input data width
localparam SH_W = ((O_W/I_W)+|(O_W % I_W))*I_W;
localparam STEP = O_W % I_W;

reg [O_W*UNIT_W-1:0] idata_packed;
reg [SH_W*UNIT_W-1:0] idata_d = 'h0;
reg ivalid_d  = 'h0;
reg [SH_W*UNIT_W-1:0] idata_dd = 'h0;
reg [SH_W-1:0] in_use = 'b0;
reg [SH_W-1:0] out_mask;

wire [SH_W*UNIT_W-1:0] idata_dd_nx;
wire [SH_W-1:0] in_use_nx;
wire pack_wr;

generate
  if (I_REG) begin : i_reg

    always @(posedge clk) begin
      ivalid_d <= ivalid;
      idata_d <= idata;
    end

  end else begin

    always @(*) begin
      ivalid_d = ivalid;
      idata_d = idata;
    end

  end
endgenerate

assign idata_dd_nx = {idata_d,idata_dd[SH_W*UNIT_W-1:I_W*UNIT_W]};
assign in_use_nx = {{I_W{ivalid_d}},in_use[SH_W-1:I_W]};

always @(posedge clk) begin
  if (reset) begin
    in_use <= 'h0;
  end else if (ivalid_d) begin
    in_use <= in_use_nx &(~out_mask);
  end
end

always @(posedge clk) begin
  if (ivalid_d) begin
    idata_dd <= idata_dd_nx;
  end
end

integer i;
always @(*) begin
  out_mask = 'b0;
  idata_packed = 'bx;
  if (STEP>0) begin
    for (i = SH_W-O_W; i >= 0; i=i-STEP) begin
      if (in_use_nx[i]) begin
        out_mask = {O_W{1'b1}} << i;
        idata_packed = idata_dd_nx >> i*UNIT_W;
      end
    end
  end else begin
    if (in_use_nx[0]) begin
      out_mask = {O_W{1'b1}};
      idata_packed = idata_dd_nx;
    end
  end
end

assign pack_wr = ivalid_d & |in_use_nx[SH_W-O_W:0];

generate
  if (O_REG) begin : o_reg

    always @(posedge clk) begin
      if (reset) begin
        ovalid <= 1'b0;
      end else begin
        ovalid <= pack_wr;
      end
    end

    always @(posedge clk) begin
      odata <= idata_packed;
    end

  end else begin

    always @(*) begin
      ovalid = pack_wr;
      odata = idata_packed;
    end

  end
endgenerate

endmodule


// END UPSTREAM FILE: library/common/ad_pack.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/util_cdc/sync_bits.v
// ============================================================================
// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

/*
 * Helper module for synchronizing bit signals from one clock domain to another.
 * It uses the standard approach of 2 FF in series.
 * Note, that while the module allows to synchronize multiple bits at once it is
 * only able to synchronize multi-bit signals where at max one bit changes per
 * clock cycle (e.g. a gray counter).
 */

`timescale 1ns/100ps

module sync_bits #(

  // Number of bits to synchronize
  parameter NUM_OF_BITS = 1,
  // Whether input and output clocks are asynchronous, if 0 the synchronizer will
  // be bypassed and the output signal equals the input signal.
  parameter ASYNC_CLK = 1)(

  input [NUM_OF_BITS-1:0] in_bits,
  input out_resetn,
  input out_clk,
  output [NUM_OF_BITS-1:0] out_bits);

generate if (ASYNC_CLK == 1) begin
  reg [NUM_OF_BITS-1:0] cdc_sync_stage1 = 'h0;
  reg [NUM_OF_BITS-1:0] cdc_sync_stage2 = 'h0;

  always @(posedge out_clk)
  begin
    if (out_resetn == 1'b0) begin
      cdc_sync_stage1 <= 'b0;
      cdc_sync_stage2 <= 'b0;
    end else begin
      cdc_sync_stage1 <= in_bits;
      cdc_sync_stage2 <= cdc_sync_stage1;
    end
  end

  assign out_bits = cdc_sync_stage2;
end else begin
  assign out_bits = in_bits;
end endgenerate

endmodule

// END UPSTREAM FILE: library/util_cdc/sync_bits.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/util_cdc/sync_event.v
// ============================================================================
// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module sync_event #(
  parameter NUM_OF_EVENTS = 1,
  parameter ASYNC_CLK = 1
) (
  input in_clk,
  input [NUM_OF_EVENTS-1:0] in_event,
  input out_clk,
  output reg [NUM_OF_EVENTS-1:0] out_event
);

generate
if (ASYNC_CLK == 1) begin

wire out_toggle;
wire in_toggle;

reg out_toggle_d1 = 1'b0;
reg in_toggle_d1 = 1'b0;

sync_bits i_sync_out (
  .in_bits(in_toggle_d1),
  .out_clk(out_clk),
  .out_resetn(1'b1),
  .out_bits(out_toggle)
);

sync_bits i_sync_in (
  .in_bits(out_toggle_d1),
  .out_clk(in_clk),
  .out_resetn(1'b1),
  .out_bits(in_toggle)
);

wire in_ready = in_toggle == in_toggle_d1;
wire load_out = out_toggle ^ out_toggle_d1;

reg [NUM_OF_EVENTS-1:0] in_event_sticky = 'h00;
wire [NUM_OF_EVENTS-1:0] pending_events = in_event_sticky | in_event;
wire [NUM_OF_EVENTS-1:0] out_event_s;

always @(posedge in_clk) begin
  if (in_ready == 1'b1) begin
    in_event_sticky <= {NUM_OF_EVENTS{1'b0}};
    if (|pending_events == 1'b1) begin
      in_toggle_d1 <= ~in_toggle_d1;
    end
  end else begin
    in_event_sticky <= pending_events;
  end
end

if (NUM_OF_EVENTS > 1) begin
  reg [NUM_OF_EVENTS-1:0] cdc_hold = 'h00;

  always @(posedge in_clk) begin
    if (in_ready == 1'b1) begin
      cdc_hold <= pending_events;
    end
  end

  assign out_event_s = cdc_hold;
end else begin
  // When there is only one event, we know that it is set.
  assign out_event_s = 1'b1;
end

always @(posedge out_clk) begin
  if (load_out == 1'b1) begin
    out_event <= out_event_s;
  end else begin
    out_event <= {NUM_OF_EVENTS{1'b0}};
  end
  out_toggle_d1 <= out_toggle;
end

end else begin
  always @(*) begin
    out_event <= in_event;
  end
end
endgenerate

endmodule

// END UPSTREAM FILE: library/util_cdc/sync_event.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_common/pipeline_stage.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module pipeline_stage #(
  parameter REGISTERED = 1,
  parameter WIDTH = 1
) (
  input clk,
  input [WIDTH-1:0] in,
  output [WIDTH-1:0] out
);

generate if (REGISTERED == 0) begin

  assign out = in;

end else begin

  (* shreg_extract = "no" *)  reg [REGISTERED*WIDTH-1:0] in_dly;

  always @(posedge clk) in_dly <= {in_dly,in};

  assign out = in_dly[REGISTERED*WIDTH-1 -: WIDTH];

end endgenerate

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_common/pipeline_stage.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_lmfc.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_lmfc #(
  parameter LINK_MODE = 1, // 2 - 64B/66B;  1 - 8B/10B
  parameter DATA_PATH_WIDTH = 4
) (
  input clk,
  input reset,

  input sysref,

  input [9:0] cfg_octets_per_multiframe,
  input [7:0] cfg_beats_per_multiframe,
  input [7:0] cfg_lmfc_offset,
  input cfg_sysref_oneshot,
  input cfg_sysref_disable,

  output reg lmfc_edge,
  output reg lmfc_clk,
  output reg [7:0] lmfc_counter,

  // Local MultiBlock clock edge
  output reg lmc_edge,
  output reg lmc_quarter_edge,
  // End of Extended MultiBlock
  output reg eoemb,

  output reg sysref_edge,
  output reg sysref_alignment_error
);

localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 : DATA_PATH_WIDTH == 4 ? 2 : 1;
localparam BEATS_PER_MF_WIDTH = 10-DPW_LOG2;

//wire [BEATS_PER_MF_WIDTH-1:0]     cfg_beats_per_multiframe = cfg_octets_per_multiframe[9:DPW_LOG2];
reg  [BEATS_PER_MF_WIDTH:0]       cfg_whole_beats_per_multiframe;

reg sysref_r = 1'b0;
reg sysref_d1 = 1'b0;
reg sysref_d2 = 1'b0;
reg sysref_d3 = 1'b0;

reg sysref_captured;

/* lmfc_octet_counter = lmfc_counter * (char_clock_rate / device_clock_rate) */
reg [7:0] lmfc_counter_next = 'h00;

reg lmfc_clk_p1 = 1'b1;

reg lmfc_active = 1'b0;

always @(posedge clk) begin
  sysref_r <= sysref;
end

/*
 * Unfortunately setup and hold are often ignored on the sysref signal relative
 * to the device clock. The device will often still work fine, just not
 * deterministic. Reduce the probability that the meta-stability creeps into the
 * reset of the system and causes non-reproducible issues.
 */
always @(posedge clk) begin
  sysref_d1 <= sysref_r;
  sysref_d2 <= sysref_d1;
  sysref_d3 <= sysref_d2;
end

always @(posedge clk) begin
  if (sysref_d3 == 1'b0 && sysref_d2 == 1'b1 && cfg_sysref_disable == 1'b0) begin
    sysref_edge <= 1'b1;
  end else begin
    sysref_edge <= 1'b0;
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    sysref_captured <= 1'b0;
  end else if (sysref_edge == 1'b1) begin
    sysref_captured <= 1'b1;
  end
end

/*
 * The configuration must be static when the core is out of reset. Otherwise
 * undefined behaviour might occur.
 * E.g. lmfc_counter > beats_per_multiframe
 *
 * To change the configuration first assert reset, then update the configuration
 * setting, finally deassert reset.
 */

/*
 * For DATA_PATH_WIDTH == 8, F*K%8=4, set
 * cfg_beats_per_multiframe = cfg_beats_per_multiframe*2
 * LMFC will be twice the actual length
 */
always @(*) begin
  if((LINK_MODE == 1) && (DATA_PATH_WIDTH == 8) && ~cfg_octets_per_multiframe[2]) begin
    cfg_whole_beats_per_multiframe = cfg_beats_per_multiframe*2;
  end else begin
    cfg_whole_beats_per_multiframe = cfg_beats_per_multiframe;
  end
end

always @(*) begin
  if (lmfc_counter == cfg_whole_beats_per_multiframe) begin
    lmfc_counter_next = 'h00;
  end else begin
    lmfc_counter_next = lmfc_counter + 1'b1;
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    lmfc_counter <= 'h01;
    lmfc_active <= cfg_sysref_disable;
  end else begin
    /*
     * In oneshot mode only the first occurence of the
     * SYSREF signal is used for alignment.
     */
    if (sysref_edge == 1'b1 &&
        (cfg_sysref_oneshot == 1'b0 || sysref_captured == 1'b0)) begin
      lmfc_counter <= cfg_lmfc_offset;
      lmfc_active <= 1'b1;
    end else begin
      lmfc_counter <= lmfc_counter_next;
    end
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    sysref_alignment_error <= 1'b0;
  end else begin
    /*
     * Alignement error is reported regardless of oneshot mode
     * setting.
     */
    sysref_alignment_error <= 1'b0;
    if (sysref_edge == 1'b1 && lmfc_active == 1'b1 &&
        lmfc_counter_next != cfg_lmfc_offset) begin
      sysref_alignment_error <= 1'b1;
    end
  end
end

always @(posedge clk) begin
  if (lmfc_counter == 'h00 && lmfc_active == 1'b1) begin
    lmfc_edge <= 1'b1;
  end else begin
    lmfc_edge <= 1'b0;
  end
end

// 1 MultiBlock = 32 blocks
always @(posedge clk) begin
  if (lmfc_counter[4:0] == 'h00 && lmfc_active == 1'b1) begin
    lmc_edge <= 1'b1;
  end else begin
    lmc_edge <= 1'b0;
  end
end
always @(posedge clk) begin
  if (lmfc_counter[2:0] == 'h00 && lmfc_active == 1'b1) begin
    lmc_quarter_edge <= 1'b1;
  end else begin
    lmc_quarter_edge <= 1'b0;
  end
end
// End of Extended MultiBlock
always @(posedge clk) begin
  if (lmfc_active == 1'b1) begin
    eoemb <= lmfc_counter[7:5] == cfg_whole_beats_per_multiframe[7:5];
  end else begin
    eoemb <= 1'b0;
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    lmfc_clk_p1 <= 1'b0;
  end else if (lmfc_active == 1'b1) begin
    if (lmfc_counter == cfg_whole_beats_per_multiframe) begin
      lmfc_clk_p1 <= 1'b1;
    end else if (lmfc_counter == cfg_whole_beats_per_multiframe[7:1]) begin
      lmfc_clk_p1 <= 1'b0;
    end
  end

  lmfc_clk <= lmfc_clk_p1;
end

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_lmfc.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_frame_mark.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

// Limitations:
//  for DATA_PATH_WIDTH = 4, 8
//    F*K=4, multiples of DATA_PATH_WIDTH
//    F=1,2,3,4,6, and multiples of DATA_PATH_WIDTH
//  for DATA_PATH_WIDTH = 6
//    F=3,6
//  for DATA_PATH_WIDTH = 12
//    F=3,6,12

`timescale 1ns/100ps

module jesd204_frame_mark #(
  parameter DATA_PATH_WIDTH = 4
) (
  input                             clk,
  input                             reset,
  input [9:0]                       cfg_octets_per_multiframe,
  input [7:0]                       cfg_beats_per_multiframe,
  input [7:0]                       cfg_octets_per_frame,

  output reg [DATA_PATH_WIDTH-1:0]  sof,
  output reg [DATA_PATH_WIDTH-1:0]  eof,
  output reg [DATA_PATH_WIDTH-1:0]  somf,
  output reg [DATA_PATH_WIDTH-1:0]  eomf
);

localparam MAX_OCTETS_PER_FRAME = 32;
localparam DPW_LOG2 = DATA_PATH_WIDTH == 16 ? 4 :
                      DATA_PATH_WIDTH == 8  ? 3 :
                      DATA_PATH_WIDTH == 4  ? 2 : 1;
localparam CW = MAX_OCTETS_PER_FRAME > 128 ? 8 :
  MAX_OCTETS_PER_FRAME > 64 ? 7 :
  MAX_OCTETS_PER_FRAME > 32 ? 6 :
  MAX_OCTETS_PER_FRAME > 16 ? 5 :
  MAX_OCTETS_PER_FRAME > 8 ? 4 :
  MAX_OCTETS_PER_FRAME > 4 ? 3 :
  MAX_OCTETS_PER_FRAME > 2 ? 2 : 1;
localparam BEATS_PER_FRAME_WIDTH = CW-DPW_LOG2;
localparam BEATS_PER_MF_WIDTH = 10-DPW_LOG2;

// For DATA_PATH_WIDTH = 8, special case if F*K%8=4
wire                              octets_per_mf_4_mod_8 = (DATA_PATH_WIDTH == 8) && ~cfg_octets_per_multiframe[2];
reg [BEATS_PER_MF_WIDTH-1:0]      cur_beats_per_multiframe;
reg                               mf_phase;
reg [1:0]                         beat_cnt_mod_3;
reg [BEATS_PER_FRAME_WIDTH-1:0]   beat_cnt_frame;
wire                              cur_sof;
wire                              cur_eof;
reg [BEATS_PER_MF_WIDTH-1:0]      beat_cnt_mf;
wire                              cur_somf;
wire                              cur_eomf;
wire [DATA_PATH_WIDTH-1:0]        default_sof;
wire [DATA_PATH_WIDTH-1:0]        default_eof;

wire [BEATS_PER_FRAME_WIDTH-1:0]  cfg_beats_per_frame = cfg_octets_per_frame[CW-1:DPW_LOG2];
reg [DATA_PATH_WIDTH-1:0] sof_f_3[2:0];
reg [DATA_PATH_WIDTH-1:0] eof_f_3[2:0];
reg [DATA_PATH_WIDTH-1:0] sof_f_6[2:0];
reg [DATA_PATH_WIDTH-1:0] eof_f_6[2:0];
reg [DATA_PATH_WIDTH-1:0] sof_f_12[2:0];
reg [DATA_PATH_WIDTH-1:0] eof_f_12[2:0];

generate
if(DATA_PATH_WIDTH == 4) begin : gen_dp_4
initial begin
  sof_f_3[0] = {4'b1001};
  sof_f_3[1] = {4'b0100};
  sof_f_3[2] = {4'b0010};
  eof_f_3[0] = {4'b0100};
  eof_f_3[1] = {4'b0010};
  eof_f_3[2] = {4'b1001};
  sof_f_6[0] = {4'b0001};
  sof_f_6[1] = {4'b0100};
  sof_f_6[2] = {4'b0000};
  eof_f_6[0] = {4'b0000};
  eof_f_6[1] = {4'b0010};
  eof_f_6[2] = {4'b1000};
end
end else if(DATA_PATH_WIDTH == 6) begin : gen_dp_6
initial begin
  sof_f_3[0] = {6'b001001};
  sof_f_3[1] = {6'b001001};
  sof_f_3[2] = {6'b001001};
  eof_f_3[0] = {6'b100100};
  eof_f_3[1] = {6'b100100};
  eof_f_3[2] = {6'b100100};
  sof_f_6[0] = {6'b000001};
  sof_f_6[1] = {6'b000001};
  sof_f_6[2] = {6'b000001};
  eof_f_6[0] = {6'b100000};
  eof_f_6[1] = {6'b100000};
  eof_f_6[2] = {6'b100000};
end
end else if(DATA_PATH_WIDTH == 8) begin : gen_dp_8
initial begin
  sof_f_3[0]  = {8'b01001001};
  sof_f_3[1]  = {8'b10010010};
  sof_f_3[2]  = {8'b00100100};
  eof_f_3[0]  = {8'b00100100};
  eof_f_3[1]  = {8'b01001001};
  eof_f_3[2]  = {8'b10010010};
  sof_f_6[0]  = {8'b01000001};
  sof_f_6[1]  = {8'b00010000};
  sof_f_6[2]  = {8'b00000100};
  eof_f_6[0]  = {8'b00100000};
  eof_f_6[1]  = {8'b00001000};
  eof_f_6[2]  = {8'b10000010};
  sof_f_12[0] = {8'b00000001};
  sof_f_12[1] = {8'b00010000};
  sof_f_12[2] = {8'b00000000};
  eof_f_12[0] = {8'b00000000};
  eof_f_12[1] = {8'b00001000};
  eof_f_12[2] = {8'b10000000};
end
end
// Beat count % 3, to support F=3, 6, 12
always @(posedge clk) begin
  if(reset) begin
    beat_cnt_mod_3 <= 2'd0;
  end else begin
    if(beat_cnt_mod_3 == 2'd2) begin
      beat_cnt_mod_3 <= 2'd0;
    end else begin
      beat_cnt_mod_3 <= beat_cnt_mod_3 + 1'b1;
    end
  end
end

// Beat count per frame
always @(posedge clk) begin
  if(reset) begin
    beat_cnt_frame <= {BEATS_PER_FRAME_WIDTH{1'b0}};
  end else begin
    if(beat_cnt_frame == cfg_beats_per_frame) begin
      beat_cnt_frame <= {BEATS_PER_FRAME_WIDTH{1'b0}};
    end else begin
      beat_cnt_frame <= beat_cnt_frame + 1'b1;
    end
  end
end

assign cur_sof = beat_cnt_frame == 0;
assign cur_eof = beat_cnt_frame == cfg_beats_per_frame;

assign default_sof = {{DATA_PATH_WIDTH-1{1'b0}}, cur_sof};
assign default_eof = {cur_eof, {DATA_PATH_WIDTH-1{1'b0}}};

// cfg_octets_per_frame must be a multiple of DATA_PATH_WIDTH
// except for the following supported special cases
always @(*) begin
  case(cfg_octets_per_frame)
    8'd0:
      begin
        sof = {DATA_PATH_WIDTH{1'b1}};
        eof = {DATA_PATH_WIDTH{1'b1}};
      end
    8'd1:
      begin
        sof = {DATA_PATH_WIDTH/2{2'b01}};
        eof = {DATA_PATH_WIDTH/2{2'b10}};
      end
    8'd2:
      begin
        sof = sof_f_3[beat_cnt_mod_3];
        eof = eof_f_3[beat_cnt_mod_3];
      end
    8'd3:
      begin
        sof = {DATA_PATH_WIDTH/4{4'b0001}};
        eof = {DATA_PATH_WIDTH/4{4'b1000}};
      end
    8'd5:
      begin
        sof = sof_f_6[beat_cnt_mod_3];
        eof = eof_f_6[beat_cnt_mod_3];
      end
    8'd11:
      begin
        sof = (DATA_PATH_WIDTH == 4) ? default_sof : sof_f_12[beat_cnt_mod_3];
        eof = (DATA_PATH_WIDTH == 4) ? default_eof : eof_f_12[beat_cnt_mod_3];
      end
    default:
      begin
        sof = default_sof;
        eof = default_eof;
      end
  endcase
end

// Beat count per multiframe
// Only support F*K%4=0
// If DATA_PATH_WIDTH == 4, or if DATA_PATH_WIDTH == 8 and F*K%8=0,
// then multiframes always start/end at the first/last octet in the data bus
// Otherwise, start/end of multiframe have more complicated patterns
always @(posedge clk) begin
  if(reset) begin
    beat_cnt_mf <= 8'b0;
    mf_phase <= 1'b0;
  end else begin
    if(beat_cnt_mf == cur_beats_per_multiframe) begin
      beat_cnt_mf <= 8'b0;
      mf_phase <= ~mf_phase;
    end else begin
      beat_cnt_mf <= beat_cnt_mf + 1'b1;
    end
  end
end

assign cur_somf = beat_cnt_mf == 0;
assign cur_eomf = beat_cnt_mf == cur_beats_per_multiframe;

if(DATA_PATH_WIDTH == 4 || DATA_PATH_WIDTH == 6 || DATA_PATH_WIDTH == 16) begin : gen_mf_power_of_two
always @(*) begin
  cur_beats_per_multiframe = cfg_beats_per_multiframe;
  somf = {{DATA_PATH_WIDTH-1{1'b0}}, cur_somf};
  eomf = {cur_eomf, {DATA_PATH_WIDTH-1{1'b0}}};
end
end else if(DATA_PATH_WIDTH == 8) begin : gen_mf_dp_8
always @(*) begin
   // cfg_octets_per_multiframe = 4
   if(cfg_octets_per_multiframe[9:2] == 0) begin
     cur_beats_per_multiframe = 8'hXX;
     somf = 8'h11;
     eomf = 8'h88;
   end else if(~octets_per_mf_4_mod_8) begin
     cur_beats_per_multiframe = cfg_beats_per_multiframe;
     somf = {{DATA_PATH_WIDTH-1{1'b0}}, cur_somf};
     eomf = {cur_eomf, {DATA_PATH_WIDTH-1{1'b0}}};
   end else begin
      cur_beats_per_multiframe = cfg_beats_per_multiframe - mf_phase;
      if((mf_phase == 0) && (beat_cnt_mf == 0)) begin
        somf = 8'h01;
      end else if((mf_phase == 0) && (beat_cnt_mf == cur_beats_per_multiframe)) begin
        somf = 8'h10;
      end else begin
        somf = 8'b0;
      end

      if((mf_phase == 0) && (beat_cnt_mf == cur_beats_per_multiframe)) begin
        eomf = 8'h08;
      end else if((mf_phase == 1) && (beat_cnt_mf == cur_beats_per_multiframe)) begin
        eomf = 8'h80;
      end else begin
        eomf = 8'b0;
      end
   end
end
end
endgenerate

endmodule


// END UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_frame_mark.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_frame_align_replace.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

// Limitations:
//   DATA_PATH_WIDTH = 4, 8
//   F=1,2,3,4,6, and multiples of DATA_PATH_WIDTH

`timescale 1ns/100ps

module jesd204_frame_align_replace #(
  parameter DATA_PATH_WIDTH = 4,
  parameter IS_RX = 1'b1,
  parameter ENABLED = 1'b1
) (
  input                             clk,
  input                             reset,

  input [7:0]                       cfg_octets_per_frame,
  input                             cfg_disable_char_replacement,
  input                             cfg_disable_scrambler,

  input [DATA_PATH_WIDTH*8-1:0]     data,
  input [DATA_PATH_WIDTH-1:0]       eof,
  input [DATA_PATH_WIDTH-1:0]       rx_char_is_a,
  input [DATA_PATH_WIDTH-1:0]       rx_char_is_f,
  input [DATA_PATH_WIDTH-1:0]       tx_eomf,

  output [DATA_PATH_WIDTH*8-1:0]    data_out,
  output [DATA_PATH_WIDTH-1:0]      charisk_out
);

localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 : DATA_PATH_WIDTH == 4 ? 2 : 1;

wire                                  single_eof = cfg_octets_per_frame >= (DATA_PATH_WIDTH-1);
reg  [DATA_PATH_WIDTH*8-1:0]          data_d1;
reg  [DATA_PATH_WIDTH*8-1:0]          data_d2;
wire [DATA_PATH_WIDTH-1:0]            char_is_align;
reg  [DATA_PATH_WIDTH-1:0]            char_is_align_d1;
reg  [DATA_PATH_WIDTH-1:0]            char_is_align_d2;
wire [((DATA_PATH_WIDTH*2)+4)*8-1:0]  saved_data;
wire [((DATA_PATH_WIDTH*2)+4)-1:0]    saved_char_is_align;
wire [DATA_PATH_WIDTH*8-1:0]          data_replaced;
wire [DATA_PATH_WIDTH*8-1:0]          data_prev_eof;
wire [DATA_PATH_WIDTH*8-1:0]          data_prev_prev_eof;
reg  [7:0]                            data_prev_eof_single;
reg  [7:0]                            data_prev_eof_single_int;
reg                                   char_is_align_prev_single;

wire [DATA_PATH_WIDTH*8-1:0]          prev_data_1;
wire [DATA_PATH_WIDTH*8-1:0]          prev_prev_data_1;
wire [DATA_PATH_WIDTH-1:0]            prev_char_is_align_1;
wire [DATA_PATH_WIDTH*8-1:0]          prev_data_2;
wire [DATA_PATH_WIDTH*8-1:0]          prev_prev_data_2;
wire [DATA_PATH_WIDTH-1:0]            prev_char_is_align_2;
wire [DATA_PATH_WIDTH*8-1:0]          prev_data_3;
wire [DATA_PATH_WIDTH*8-1:0]          prev_prev_data_3;
wire [DATA_PATH_WIDTH-1:0]            prev_char_is_align_3;
wire [DATA_PATH_WIDTH*8-1:0]          prev_data_4;
wire [DATA_PATH_WIDTH*8-1:0]          prev_prev_data_4;
wire [DATA_PATH_WIDTH-1:0]            prev_char_is_align_4;
wire [DATA_PATH_WIDTH*8-1:0]          prev_data_6;
wire [DATA_PATH_WIDTH*8-1:0]          prev_prev_data_6;
wire [DATA_PATH_WIDTH-1:0]            prev_char_is_align_6;
reg  [DATA_PATH_WIDTH*8-1:0]          prev_data;
reg  [DATA_PATH_WIDTH*8-1:0]          prev_prev_data;
reg  [DATA_PATH_WIDTH-1:0]            prev_char_is_align;
reg  [DPW_LOG2:0]                     jj;
reg  [DPW_LOG2:0]                     ll;

always @(posedge clk) begin
  data_d1 <= data;
  data_d2 <= data_d1;
end

always @(posedge clk) begin
  if(reset) begin
    char_is_align_d1 <= 'b0;
    char_is_align_d2 <= 'b0;
  end else begin
    char_is_align_d1 <= char_is_align;
    char_is_align_d2 <= char_is_align_d1;
  end
end

// Capture single EOF in current cycle

always @(eof, data) begin
  data_prev_eof_single_int = 'b0;
  for(ll = 0; ll < DATA_PATH_WIDTH; ll=ll+1) begin
    data_prev_eof_single_int = data_prev_eof_single_int | (data[ll*8 +: 8] & {8{eof[ll]}});
  end
end

always @(posedge clk) begin
  if(reset) begin
    data_prev_eof_single <= 'b0;
  end else begin
    if(|eof && (!IS_RX || !(|char_is_align))) begin
      data_prev_eof_single <= data_prev_eof_single_int;
    end
  end
end

always @(posedge clk) begin
  if(reset) begin
    char_is_align_prev_single <= 'b0;
  end else begin
    if(|eof) begin
      char_is_align_prev_single <= |char_is_align;
    end
  end
end

assign saved_data = {data, data_d1, data_d2[(DATA_PATH_WIDTH*8)-1:(DATA_PATH_WIDTH-4)*8]};
assign saved_char_is_align = {char_is_align, char_is_align_d1, char_is_align_d2[DATA_PATH_WIDTH-1:DATA_PATH_WIDTH-4]};

genvar ii;
generate
for (ii = 0; ii < DATA_PATH_WIDTH; ii = ii + 1) begin: gen_replace_byte
  assign prev_data_1[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH+3+ii)*8 +: 8];
  assign prev_data_2[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH+2+ii)*8 +: 8];
  assign prev_data_3[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH+1+ii)*8 +: 8];
  assign prev_prev_data_1[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH+2+ii)*8 +: 8];
  assign prev_prev_data_2[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH+ii)*8 +: 8];
  assign prev_prev_data_3[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH-2+ii)*8 +: 8];
  assign prev_char_is_align_1[ii] = saved_char_is_align[(DATA_PATH_WIDTH+3+ii)];
  assign prev_char_is_align_2[ii] = saved_char_is_align[(DATA_PATH_WIDTH+2+ii)];
  assign prev_char_is_align_3[ii] = saved_char_is_align[(DATA_PATH_WIDTH+1+ii)];

  if(DATA_PATH_WIDTH == 8) begin : gen_dp_8
    assign prev_data_4[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH+ii)*8 +: 8];
    assign prev_data_6[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH-2+ii)*8 +: 8];
    assign prev_prev_data_4[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH-4+ii)*8 +: 8];
    assign prev_prev_data_6[ii*8 +:8] = saved_data[(DATA_PATH_WIDTH-8+ii)*8 +: 8];
    assign prev_char_is_align_4[ii] = saved_char_is_align[(DATA_PATH_WIDTH+ii)];
    assign prev_char_is_align_6[ii] = saved_char_is_align[(DATA_PATH_WIDTH-2+ii)];
  end else begin
    assign prev_data_4[ii*8 +:8] = 'bX;
    assign prev_data_6[ii*8 +:8] = 'bX;
    assign prev_prev_data_4[ii*8 +:8] = 'bX;
    assign prev_prev_data_6[ii*8 +:8] = 'bX;
    assign prev_char_is_align_4[ii] = 'bX;
    assign prev_char_is_align_6[ii] = 'bX;
  end

  always @(*) begin
    case(cfg_octets_per_frame)
      0:
        begin
          prev_data[ii*8 +:8] = prev_data_1[ii*8 +:8];
          prev_prev_data[ii*8 +:8] = prev_prev_data_1[ii*8 +:8];
          prev_char_is_align[ii] = prev_char_is_align_1[ii];
        end
      1:
        begin
          prev_data[ii*8 +:8] = prev_data_2[ii*8 +:8];
          prev_prev_data[ii*8 +:8] = prev_prev_data_2[ii*8 +:8];
          prev_char_is_align[ii] = prev_char_is_align_2[ii];
        end
      2:
        begin
          prev_data[ii*8 +:8] = prev_data_3[ii*8 +:8];
          prev_prev_data[ii*8 +:8] = prev_prev_data_3[ii*8 +:8];
          prev_char_is_align[ii] = prev_char_is_align_3[ii];
        end
      3:
        begin
          prev_data[ii*8 +:8] = prev_data_4[ii*8 +:8];
          prev_prev_data[ii*8 +:8] = prev_prev_data_4[ii*8 +:8];
          prev_char_is_align[ii] = prev_char_is_align_4[ii];
        end
      5:
        begin
          prev_data[ii*8 +:8] = prev_data_6[ii*8 +:8];
          prev_prev_data[ii*8 +:8] = prev_prev_data_6[ii*8 +:8];
          prev_char_is_align[ii] = prev_char_is_align_6[ii];
        end
      default:
        begin
          prev_data[ii*8 +:8] = 'bX;
          prev_prev_data[ii*8 +:8] = 'bX;
          prev_char_is_align[ii] = 1'bX;
        end
    endcase
  end

  if(IS_RX) begin : gen_rx
    // RX
    assign char_is_align[ii] = !reset && (rx_char_is_a[ii] | rx_char_is_f[ii]);
    assign data_replaced[ii*8 +: 8] = char_is_align[ii] ? data_prev_eof[ii*8 +: 8] : data[ii*8 +: 8];
    assign data_prev_eof[ii*8 +: 8] = single_eof ? data_prev_eof_single : prev_char_is_align[ii] ? data_prev_prev_eof[ii*8 +: 8] : prev_data[ii*8 +: 8];
    assign data_prev_prev_eof[ii*8 +: 8] = prev_prev_data[ii*8 +: 8];
  end else begin : gen_tx
    // TX
    assign data_prev_eof[ii*8 +: 8] = single_eof ? data_prev_eof_single : prev_data[ii*8 +: 8];
    assign char_is_align[ii] = !reset && (tx_eomf[ii] || (eof[ii] && !(single_eof ? char_is_align_prev_single : prev_char_is_align[ii]))) && (data[ii*8 +: 8] == data_prev_eof[ii*8 +: 8]);
    assign data_replaced[ii*8 +: 8] = char_is_align[ii] ? (tx_eomf[ii] ? 8'h7c : 8'hfc) : data[ii*8 +: 8];
  end
end
endgenerate

assign data_out = (cfg_disable_char_replacement || !cfg_disable_scrambler || ENABLED==0) ? data : data_replaced;
assign charisk_out = (IS_RX || !cfg_disable_scrambler || cfg_disable_char_replacement || ENABLED==0) ? 'b0 : char_is_align;

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_frame_align_replace.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_scrambler.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_scrambler #(
  parameter WIDTH = 32,
  parameter DESCRAMBLE = 0
) (
  input clk,
  input reset,

  input enable,

  input [WIDTH-1:0] data_in,
  output [WIDTH-1:0] data_out
);

reg [14:0] state = 'h7f80;
reg [WIDTH-1:0] swizzle_out;
wire [WIDTH-1:0] swizzle_in;
wire [WIDTH-1:0] feedback;
wire [WIDTH-1+15:0] full_state;

generate
genvar i;
for (i = 0; i < WIDTH / 8; i = i + 1) begin: gen_swizzle
  assign swizzle_in[WIDTH-1-i*8:WIDTH-i*8-8] = data_in[i*8+7:i*8];
  assign data_out[WIDTH-1-i*8:WIDTH-i*8-8] = swizzle_out[i*8+7:i*8];
end
endgenerate

assign full_state = {state,DESCRAMBLE ? swizzle_in : feedback};
assign feedback = full_state[WIDTH-1+15:15] ^ full_state[WIDTH-1+14:14] ^ swizzle_in;

always @(*) begin
  if (enable == 1'b0) begin
    swizzle_out = swizzle_in;
  end else begin
    swizzle_out = feedback;
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    state <= 'h7f80;
  end else begin
    state <= full_state[14:0];
  end
end

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_common/jesd204_scrambler.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/align_mux.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module align_mux #(
  parameter DATA_PATH_WIDTH = 4
) (
  input clk,
  input [2:0] align,
  input [DATA_PATH_WIDTH*8-1:0] in_data,
  input [DATA_PATH_WIDTH-1:0] in_charisk,
  output [DATA_PATH_WIDTH*8-1:0] out_data,
  output [DATA_PATH_WIDTH-1:0] out_charisk
);

localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 : DATA_PATH_WIDTH == 4 ? 2 : 1;

wire [DPW_LOG2-1:0]                align_int;
reg  [DATA_PATH_WIDTH*8-1:0]       in_data_d1;
reg  [DATA_PATH_WIDTH-1:0]         in_charisk_d1;
wire [(DATA_PATH_WIDTH*8*2)-1:0]   data;
wire [(DATA_PATH_WIDTH*2)-1:0]     charisk;

always @(posedge clk) begin
  in_data_d1 <= in_data;
  in_charisk_d1 <= in_charisk;
end

assign data = {in_data, in_data_d1};
assign charisk = {in_charisk, in_charisk_d1};

assign align_int = align[DPW_LOG2-1:0];

assign out_data = data[align_int*8 +: (DATA_PATH_WIDTH*8)];
assign out_charisk = charisk[align_int +: DATA_PATH_WIDTH];

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/align_mux.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/elastic_buffer.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module elastic_buffer #(
  parameter IWIDTH = 32,
  parameter OWIDTH = 48,
  parameter SIZE = 256,
  parameter ASYNC_CLK = 0
) (
  input clk,
  input reset,

  input device_clk,
  input device_reset,

  input [IWIDTH-1:0] wr_data,

  output reg [OWIDTH-1:0] rd_data,

  input ready_n,
  input do_release_n
);

localparam ADDR_WIDTH = SIZE > 128 ? 7 :
  SIZE > 64 ? 6 :
  SIZE > 32 ? 5 :
  SIZE > 16 ? 4 :
  SIZE > 8 ? 3 :
  SIZE > 4 ? 2 :
  SIZE > 2 ? 1 : 0;

localparam WIDTH = OWIDTH >= IWIDTH ? OWIDTH : IWIDTH;

reg [ADDR_WIDTH:0] wr_addr = 'h00;
reg [ADDR_WIDTH:0] rd_addr = 'h00;
(* ram_style = "distributed" *) reg [WIDTH-1:0] mem[0:SIZE - 1];

wire mem_wr;
wire [WIDTH-1:0] mem_wr_data;

generate if ((OWIDTH > IWIDTH) && ASYNC_CLK) begin
  ad_pack #(
    .I_W(IWIDTH/8),
    .O_W(OWIDTH/8),
    .UNIT_W(8)
  ) i_ad_pack (
    .clk(clk),
    .reset(ready_n),
    .idata(wr_data),
    .ivalid(1'b1),

    .odata(mem_wr_data),
    .ovalid(mem_wr)
  );
end else begin
  assign mem_wr = 1'b1;
  assign mem_wr_data = wr_data;
end
endgenerate

always @(posedge clk) begin
  if (ready_n == 1'b1) begin
    wr_addr <= 'h00;
  end else if (mem_wr) begin
    mem[wr_addr] <= mem_wr_data;
    wr_addr <= wr_addr + 1'b1;
  end
end

always @(posedge device_clk) begin
  if (do_release_n == 1'b1) begin
    rd_addr <= 'h00;
  end else begin
    rd_addr <= rd_addr + 1'b1;
    rd_data <= mem[rd_addr];
  end
end

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/elastic_buffer.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_ilas_monitor.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_ilas_monitor #(
  parameter DATA_PATH_WIDTH = 4
) (
  input clk,
  input reset,

  input [9:0] cfg_octets_per_multiframe,
  input [DATA_PATH_WIDTH*8-1:0] data,
  input [DATA_PATH_WIDTH-1:0] charisk28,

  output reg ilas_config_valid,
  output reg [1:0] ilas_config_addr,
  output reg [DATA_PATH_WIDTH*8-1:0] ilas_config_data,

  output data_ready_n
);


localparam STATE_ILAS = 1'b1;
localparam STATE_DATA = 1'b0;
localparam ILAS_DATA_LENGTH = (DATA_PATH_WIDTH == 4) ? 4 : 2;

wire octets_per_mf_4_mod_8 = (DATA_PATH_WIDTH == 8) && ~cfg_octets_per_multiframe[2];
reg state = STATE_ILAS;
reg next_state;
reg prev_was_last = 1'b0;
wire ilas_config_start;
reg ilas_config_valid_i;
reg [1:0] ilas_config_addr_i;
reg [DATA_PATH_WIDTH*8-1:0] ilas_config_data_i;

assign data_ready_n = next_state;

always @(*) begin
  next_state = state;
  if (reset == 1'b0 && prev_was_last == 1'b1) begin
    if (charisk28[0] != 1'b1 || data[7:5] != 3'h0) begin
      next_state = STATE_DATA;
    end
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    state <= STATE_ILAS;
  end else begin
    state <= next_state;
  end
end

always @(posedge clk) begin
  if (reset == 1'b1 || (charisk28[DATA_PATH_WIDTH-1] == 1'b1 && data[(DATA_PATH_WIDTH*8)-1:(DATA_PATH_WIDTH*8)-3] == 3'h3)) begin
    prev_was_last <= 1'b1;
  end else begin
    prev_was_last <= 1'b0;
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    ilas_config_valid_i <= 1'b0;
  end else if (state == STATE_ILAS) begin
    if (ilas_config_start) begin
      ilas_config_valid_i <= 1'b1;
    end else if (ilas_config_addr_i == (ILAS_DATA_LENGTH-1)) begin
      ilas_config_valid_i <= 1'b0;
    end
  end
end

always @(posedge clk) begin
  if (ilas_config_valid_i == 1'b0) begin
    ilas_config_addr_i <= 1'b0;
  end else if (ilas_config_valid_i == 1'b1) begin
    ilas_config_addr_i <= ilas_config_addr_i + 1'b1;
  end
end

always @(posedge clk) begin
  ilas_config_data_i <= data;
end


generate
if(DATA_PATH_WIDTH == 4) begin : gen_dp_4

assign ilas_config_start = charisk28[1] && (data[15:13] == 3'h4);

always @(*) begin
  ilas_config_valid = ilas_config_valid_i;
  ilas_config_addr = ilas_config_addr_i;
  ilas_config_data = ilas_config_data_i;
end

end else begin : gen_dp_8

assign ilas_config_start = octets_per_mf_4_mod_8 ? 
  (charisk28[5] && (data[47:45] == 3'h4)) :
  (charisk28[1] && (data[15:13] == 3'h4));

always @(posedge clk) begin
  if (reset == 1'b1) begin
    ilas_config_valid <= 1'b0;
  end else begin
    ilas_config_valid <= ilas_config_valid_i;
  end
end

always @(posedge clk) begin
  ilas_config_addr <= ilas_config_addr_i;
  ilas_config_data <= octets_per_mf_4_mod_8 ? {data[31:0], ilas_config_data_i[63:32]} : ilas_config_data_i;
end
end
endgenerate

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_ilas_monitor.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_lane_latency_monitor.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_lane_latency_monitor #(
  parameter NUM_LANES = 1,
  parameter DATA_PATH_WIDTH = 4
) (
  input clk,
  input reset,

  input [NUM_LANES-1:0] lane_ready,
  input [NUM_LANES*3-1:0] lane_frame_align,

  output [14*NUM_LANES-1:0] lane_latency,
  output [NUM_LANES-1:0] lane_latency_ready
);

localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 : DATA_PATH_WIDTH == 4 ? 2 : 1;
localparam BEAT_CNT_WIDTH = 14-DPW_LOG2;

reg [BEAT_CNT_WIDTH-1:0] beat_counter;

reg [BEAT_CNT_WIDTH-1:0] lane_latency_mem[0:NUM_LANES-1];
reg [NUM_LANES-1:0] lane_captured = 'h00;

always @(posedge clk) begin
  if (reset == 1'b1) begin
    beat_counter <= 'h0;
  end else if (beat_counter != {BEAT_CNT_WIDTH{1'b1}}) begin
    beat_counter <= beat_counter + 1'b1;
  end
end

generate
genvar i;

for (i = 0; i < NUM_LANES; i = i + 1) begin: gen_lane
  always @(posedge clk) begin
    if (reset == 1'b1) begin
      lane_latency_mem[i] <= 'h00;
      lane_captured[i] <= 1'b0;
    end else if (lane_ready[i] == 1'b1 && lane_captured[i] == 1'b0) begin
      lane_latency_mem[i] <= beat_counter;
      lane_captured[i] <= 1'b1;
    end
  end

  assign lane_latency[i*14+13:i*14] = {lane_latency_mem[i],lane_frame_align[(i*DPW_LOG2)+DPW_LOG2-1:i*DPW_LOG2]};
  assign lane_latency_ready[i] = lane_captured[i];
end
endgenerate

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_lane_latency_monitor.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_cgs.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_rx_cgs #(
  parameter DATA_PATH_WIDTH = 4
) (
  input clk,
  input reset,

  input [DATA_PATH_WIDTH-1:0] char_is_cgs,
  input [DATA_PATH_WIDTH-1:0] char_is_error,

  output ready,

  output [1:0] status_state
);

localparam CGS_STATE_INIT = 2'b00;
localparam CGS_STATE_CHECK = 2'b01;
localparam CGS_STATE_DATA = 2'b10;

reg [1:0] state = CGS_STATE_INIT;
reg rdy = 1'b0;
reg [1:0] beat_error_count = 'h00;

wire beat_is_cgs = &char_is_cgs;
wire beat_has_error = |char_is_error;
wire beat_is_all_error = &char_is_error;

assign ready = rdy;
assign status_state = state;

always @(posedge clk) begin
  if (state == CGS_STATE_INIT) begin
    beat_error_count <= 'h00;
  end else begin
    if (beat_has_error == 1'b1) begin
      beat_error_count <= beat_error_count + 1'b1;
    end else begin
      beat_error_count <= 'h00;
    end
  end
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    state <= CGS_STATE_INIT;
  end else begin
    case (state)
    CGS_STATE_INIT: begin
      if (beat_is_cgs == 1'b1) begin
        state <= CGS_STATE_CHECK;
      end
    end
    CGS_STATE_CHECK: begin
      if (beat_has_error == 1'b1) begin
        if (beat_error_count == 'h3 ||
            beat_is_all_error == 1'b1) begin
          state <= CGS_STATE_INIT;
        end
      end else begin
        state <= CGS_STATE_DATA;
      end
    end
    CGS_STATE_DATA: begin
      if (beat_has_error == 1'b1) begin
        state <= CGS_STATE_CHECK;
      end
    end
    endcase
  end
end

always @(posedge clk) begin
  case (state)
  CGS_STATE_INIT: rdy <= 1'b0;
  CGS_STATE_DATA: rdy <= 1'b1;
  default: rdy <= rdy;
  endcase
end

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_cgs.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_ctrl.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_rx_ctrl #(
  parameter NUM_LANES = 1,
  parameter NUM_LINKS = 1,
  parameter ENABLE_FRAME_ALIGN_ERR_RESET = 0
) (
  input clk,
  input reset,

  input [NUM_LANES-1:0] cfg_lanes_disable,
  input [NUM_LINKS-1:0] cfg_links_disable,

  input phy_ready,
  output phy_en_char_align,


  output [NUM_LANES-1:0] cgs_reset,
  input [NUM_LANES-1:0] cgs_ready,

  output [NUM_LANES-1:0] ifs_reset,

  input lmfc_edge,
  input [NUM_LANES-1:0] frame_align_err_thresh_met,

  output [NUM_LINKS-1:0] sync,
  output reg latency_monitor_reset,

  output [1:0] status_state,
  output event_data_phase
);

localparam STATE_RESET = 0;
localparam STATE_WAIT_FOR_PHY = 1;
localparam STATE_CGS = 2;
localparam STATE_SYNCHRONIZED = 3;

reg [2:0] state = STATE_RESET;
reg [2:0] next_state = STATE_RESET;

reg [NUM_LANES-1:0] cgs_rst = {NUM_LANES{1'b1}};
reg [NUM_LANES-1:0] ifs_rst = {NUM_LANES{1'b1}};
reg [NUM_LINKS-1:0] sync_n = {NUM_LINKS{1'b1}};
reg en_align = 1'b0;
reg state_good = 1'b0;

reg [7:0] good_counter = 'h00;

wire [7:0] good_cnt_limit_s;
wire       good_cnt_limit_reached_s;
wire       goto_next_state_s;

assign cgs_reset = cgs_rst;
assign ifs_reset = ifs_rst;
assign sync = sync_n;
assign phy_en_char_align = en_align;

assign status_state = state;

always @(posedge clk) begin
  case (state)
  STATE_RESET: begin
    cgs_rst <= {NUM_LANES{1'b1}};
    ifs_rst <= {NUM_LANES{1'b1}};
    sync_n <= {NUM_LINKS{1'b1}};
    latency_monitor_reset <= 1'b1;
  end
  STATE_CGS: begin
    sync_n <= cfg_links_disable;
    cgs_rst <= cfg_lanes_disable;
  end
  STATE_SYNCHRONIZED: begin
    if (lmfc_edge == 1'b1) begin
      sync_n <= {NUM_LINKS{1'b1}};
      ifs_rst <= cfg_lanes_disable;
      latency_monitor_reset <= 1'b0;
    end
  end
  endcase
end

always @(*) begin
  case (state)
  STATE_RESET: state_good = 1'b1;
  STATE_WAIT_FOR_PHY: state_good = phy_ready;
  STATE_CGS: state_good = &(cgs_ready | cfg_lanes_disable);
  STATE_SYNCHRONIZED: state_good = ENABLE_FRAME_ALIGN_ERR_RESET ?
                                   &(~frame_align_err_thresh_met | cfg_lanes_disable) :
                                   1'b1;
  default: state_good = 1'b0;
  endcase
end

assign good_cnt_limit_s = (state == STATE_CGS) ? 'hff : 'h7;
assign good_cnt_limit_reached_s = good_counter == good_cnt_limit_s;

assign goto_next_state_s = good_cnt_limit_reached_s || (state == STATE_SYNCHRONIZED);

always @(posedge clk) begin
  if (reset) begin
    good_counter <= 'h00;
  end else if (state_good == 1'b1) begin
    if (good_cnt_limit_reached_s) begin
      good_counter <= 'h00;
    end else begin
      good_counter <= good_counter + 1'b1;
    end
  end else begin
    good_counter <= 'h00;
  end
end

always @(posedge clk) begin
  case (state)
  STATE_CGS: en_align <= 1'b1;
  default: en_align <= 1'b0;
  endcase
end

always @(*) begin
  case (state)
  STATE_RESET: next_state = STATE_WAIT_FOR_PHY;
  STATE_WAIT_FOR_PHY: next_state = STATE_CGS;
  STATE_CGS: next_state = STATE_SYNCHRONIZED;
  default: next_state = state_good ? state : STATE_RESET;
  endcase
end

always @(posedge clk) begin
  if (reset == 1'b1) begin
    state <= STATE_RESET;
  end else begin
    if (goto_next_state_s) begin
      state <= next_state;
    end
  end
end

assign event_data_phase = state == STATE_CGS &&
                          next_state == STATE_SYNCHRONIZED &&
                          good_cnt_limit_reached_s;

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_ctrl.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_frame_align.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_rx_frame_align #(
  parameter DATA_PATH_WIDTH = 4,
  parameter ENABLE_CHAR_REPLACE = 0
) (
  input                             clk,
  input                             reset,
  input [9:0]                       cfg_octets_per_multiframe,
  input [7:0]                       cfg_octets_per_frame,
  input                             cfg_disable_char_replacement,
  input                             cfg_disable_scrambler,
  input [DATA_PATH_WIDTH-1:0]       charisk28,
  input [DATA_PATH_WIDTH*8-1:0]     data,

  output [DATA_PATH_WIDTH*8-1:0]    data_replaced,
  output reg [7:0]                  align_err_cnt
);

// Reset alignment error count on good multiframe alignment,
// or on good frame or multiframe alignment
// If disabled, misalignments could me masked if
// due to cfg_octets_per_multiframe mismatch or due to
// a slip of a multiple of cfg_octets_per_frame octets
localparam RESET_COUNT_ON_MF_ONLY = 1'b1;

localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 :
  DATA_PATH_WIDTH == 4 ? 2 : 1;

function automatic [DPW_LOG2*2:0] count_ones(input [DATA_PATH_WIDTH*2-1:0] val);
  reg [DPW_LOG2*2-1:0] ii;
  begin
    count_ones = 0;
    for(ii = 0; ii != (DATA_PATH_WIDTH*2-1); ii=ii+1) begin
      count_ones = count_ones + val[ii];
    end
  end
endfunction

reg  [DATA_PATH_WIDTH-1:0]        char_is_a;
reg  [DATA_PATH_WIDTH-1:0]        char_is_f;
wire [DATA_PATH_WIDTH-1:0]        eof;
wire [DATA_PATH_WIDTH-1:0]        eomf;
reg  [DATA_PATH_WIDTH-1:0]        eof_err;
reg  [DATA_PATH_WIDTH-1:0]        eof_good;
reg  [DATA_PATH_WIDTH-1:0]        eomf_err;
reg  [DATA_PATH_WIDTH-1:0]        eomf_good;
reg                               align_good;
reg                               align_err;
reg  [DPW_LOG2*2:0]               cur_align_err_cnt;
wire [8:0]                        align_err_cnt_next;

wire [7:0] cfg_beats_per_multiframe = cfg_octets_per_multiframe>>DPW_LOG2;

jesd204_frame_mark #(
  .DATA_PATH_WIDTH            (DATA_PATH_WIDTH)
) i_frame_mark (
  .clk                        (clk),
  .reset                      (reset),
  .cfg_octets_per_multiframe  (cfg_octets_per_multiframe),
  .cfg_beats_per_multiframe   (cfg_beats_per_multiframe),
  .cfg_octets_per_frame       (cfg_octets_per_frame),
  .sof                        (),
  .eof                        (eof),
  .somf                       (),
  .eomf                       (eomf)
);

genvar ii;
generate
for (ii = 0; ii < DATA_PATH_WIDTH; ii = ii + 1) begin: gen_k_char
  always @(*) begin
    char_is_a[ii] = 1'b0;
    char_is_f[ii] = 1'b0;

    if(charisk28[ii]) begin
      if(data[ii*8+7:ii*8+5] == 3'd3) begin
        char_is_a[ii] = 1'b1;
      end
      if(data[ii*8+7:ii*8+5] == 3'd7) begin
        char_is_f[ii] = 1'b1;
      end
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      eomf_err[ii] <= 1'b0;
      eomf_good[ii] <= 1'b0;
      eof_err[ii] <= 1'b0;
      eof_good[ii] <= 1'b0;
    end else begin
      eomf_err[ii]  <= char_is_a[ii] && !eomf[ii];
      eomf_good[ii] <= char_is_a[ii] && eomf[ii];
      eof_err[ii]   <= char_is_f[ii] && !eof[ii];
      eof_good[ii]  <= char_is_f[ii] && eof[ii];
    end
  end
end
endgenerate

always @(posedge clk) begin
  if(reset) begin
    align_good <= 1'b0;
    align_err <= 1'b0;
  end else begin
    if(RESET_COUNT_ON_MF_ONLY) begin
      align_good <= |eomf_good;
    end else begin
      align_good <= |({eomf_good, eof_good});
    end

    align_err <= |({eomf_err, eof_err});
  end
end

assign align_err_cnt_next = {1'b0, align_err_cnt} + cur_align_err_cnt;

// Alignment error counter
// Resets upon good alignment
always @(posedge clk) begin
  if(reset) begin
    align_err_cnt <= 8'd0;
    cur_align_err_cnt <= 'd0;
  end else begin
    cur_align_err_cnt <= count_ones({eomf_err, eof_err});

    if(align_good && !align_err) begin
      align_err_cnt <= 8'd0;
    end else if(align_err_cnt_next[8]) begin
      align_err_cnt <= 8'hFF;
    end else begin
      align_err_cnt <= align_err_cnt_next[7:0];
    end
  end
end

jesd204_frame_align_replace #(
  .DATA_PATH_WIDTH              (DATA_PATH_WIDTH),
  .IS_RX                        (1'b1),
  .ENABLED                      (ENABLE_CHAR_REPLACE)
) i_align_replace (
  .clk                          (clk),
  .reset                        (reset),
  .cfg_octets_per_frame         (cfg_octets_per_frame),
  .cfg_disable_char_replacement (cfg_disable_char_replacement),
  .cfg_disable_scrambler        (cfg_disable_scrambler),
  .data                         (data),
  .eof                          (eof),
  .rx_char_is_a                 (char_is_a),
  .rx_char_is_f                 (char_is_f),
  .tx_eomf                      ({DATA_PATH_WIDTH{1'b0}}),
  .data_out                     (data_replaced),
  .charisk_out                  ()
);

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_frame_align.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_lane.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_rx_lane #(
  parameter DATA_PATH_WIDTH = 4,
  parameter TPL_DATA_PATH_WIDTH = 4,
  parameter CHAR_INFO_REGISTERED = 0,
  parameter ALIGN_MUX_REGISTERED = 0,
  parameter SCRAMBLER_REGISTERED = 0,
  parameter ELASTIC_BUFFER_SIZE = 256,
  parameter ENABLE_FRAME_ALIGN_CHECK = 0,
  parameter ENABLE_CHAR_REPLACE = 0,
  parameter ASYNC_CLK = 0
) (
  input clk,
  input reset,

  input device_clk,
  input device_reset,

  input [DATA_PATH_WIDTH*8-1:0] phy_data,
  input [DATA_PATH_WIDTH-1:0] phy_charisk,
  input [DATA_PATH_WIDTH-1:0] phy_notintable,
  input [DATA_PATH_WIDTH-1:0] phy_disperr,

  input cgs_reset,
  output cgs_ready,

  input ifs_reset,

  output [TPL_DATA_PATH_WIDTH*8-1:0] rx_data,

  output buffer_ready_n,
  input buffer_release_n,

  input [9:0] cfg_octets_per_multiframe,
  input [7:0] cfg_octets_per_frame,
  input cfg_disable_char_replacement,
  input cfg_disable_scrambler,

  output ilas_config_valid,
  output [1:0] ilas_config_addr,
  output [DATA_PATH_WIDTH*8-1:0] ilas_config_data,

  input err_statistics_reset,
  input [2:0]ctrl_err_statistics_mask,
  output reg [31:0] status_err_statistics_cnt,

  output [1:0] status_cgs_state,
  output status_ifs_ready,
  output [2:0] status_frame_align,
  output [7:0] status_frame_align_err_cnt
);

localparam MAX_DATA_PATH_WIDTH = 8;
localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 : DATA_PATH_WIDTH == 4 ? 2 : 1;

wire [7:0] char[0:DATA_PATH_WIDTH-1];
wire [DATA_PATH_WIDTH-1:0] char_is_valid;
reg [DATA_PATH_WIDTH-1:0] char_is_cgs = 1'b0;        // K28.5 /K/

reg [DATA_PATH_WIDTH-1:0] char_is_error = 1'b0;
reg [DATA_PATH_WIDTH-1:0] charisk28 = 4'b0000;

wire cgs_beat_is_cgs = &char_is_cgs;
wire cgs_beat_has_error = |char_is_error;

reg ifs_ready = 1'b0;
reg [2:0] frame_align = 'h00;
reg [2:0] frame_align_int;

wire [DATA_PATH_WIDTH*8-1:0] phy_data_s;
wire [DATA_PATH_WIDTH-1:0] charisk28_aligned_s;
wire [DATA_PATH_WIDTH*8-1:0] data_aligned_s;
wire [DATA_PATH_WIDTH-1:0] charisk28_aligned;
wire [DATA_PATH_WIDTH*8-1:0] data_aligned;
wire [DATA_PATH_WIDTH*8-1:0] data_replaced;
wire [DATA_PATH_WIDTH*8-1:0] data_scrambled_s;
wire [DATA_PATH_WIDTH*8-1:0] data_scrambled;

reg  [DATA_PATH_WIDTH-1:0] unexpected_char;
reg  [DATA_PATH_WIDTH-1:0] phy_char_err;

wire ilas_monitor_reset_s;
wire ilas_monitor_reset;
wire buffer_ready_n_s;
reg  [DPW_LOG2:0] jj;
reg  align_found;

assign status_ifs_ready = ifs_ready;
assign status_frame_align = frame_align;

genvar i;
generate

for (i = 0; i < DATA_PATH_WIDTH; i = i + 1) begin: gen_char
  assign char[i] = phy_data[i*8+7:i*8];
  assign char_is_valid[i] = ~(phy_notintable[i] | phy_disperr[i]);

  always @(*) begin
    char_is_error[i] = ~char_is_valid[i];

    char_is_cgs[i] = 1'b0;
    charisk28[i] = 1'b0;
    unexpected_char[i] = 1'b0;

    if (phy_charisk[i] == 1'b1 && char_is_valid[i] == 1'b1) begin
      if (char[i][4:0] == 'd28) begin
        charisk28[i] = 1'b1;
        if (char[i][7:5] == 'd5) begin
          char_is_cgs[i] = 1'b1;
        end
      end else begin
        unexpected_char[i] = 1'b1;
      end
    end
  end
end
endgenerate

always @(posedge clk) begin
  if (cgs_ready == 1'b1) begin
    /*
     * Set the bit in phy_char_err if at least one of the monitored error
     * conditions has occured.
     */
    phy_char_err <= (~{DATA_PATH_WIDTH{ctrl_err_statistics_mask[0]}} & phy_disperr) |
                    (~{DATA_PATH_WIDTH{ctrl_err_statistics_mask[1]}} & phy_notintable) |
                    (~{DATA_PATH_WIDTH{ctrl_err_statistics_mask[2]}} & unexpected_char);
  end else begin
    phy_char_err <= {DATA_PATH_WIDTH{1'b0}};
  end
end

function [7:0] num_set_bits;
input [DATA_PATH_WIDTH-1:0] x;
integer j;
begin
  num_set_bits = 0;
  for (j = 0; j < DATA_PATH_WIDTH; j = j + 1) begin
    num_set_bits = num_set_bits + x[j];
  end
end
endfunction

always @(posedge clk) begin
  if (reset == 1'b1 || err_statistics_reset == 1'b1) begin
    status_err_statistics_cnt <= 32'h0;
  end else if (status_err_statistics_cnt[31:5] != 27'h7ffffff) begin
    status_err_statistics_cnt <= status_err_statistics_cnt + num_set_bits(phy_char_err);
  end
end

always @(posedge clk) begin
  if (ifs_reset == 1'b1) begin
    ifs_ready <= 1'b0;
  end else if (cgs_beat_is_cgs == 1'b0 && cgs_beat_has_error == 1'b0) begin
    ifs_ready <= 1'b1;
  end
end

always @(*) begin
  align_found = 1'b0;
  frame_align_int = 0;
  for(jj = 0; jj < DATA_PATH_WIDTH; jj=jj+1) begin
    if (!align_found && (char_is_cgs[jj] == 1'b0)) begin
      align_found = 1'b1;
      frame_align_int = jj;
    end
  end
end

always @(posedge clk) begin
  if (ifs_ready == 1'b0) begin
    frame_align <= frame_align_int;
  end
end

pipeline_stage #(
  .WIDTH(DATA_PATH_WIDTH*8),
  .REGISTERED(CHAR_INFO_REGISTERED)
) i_pipeline_stage0 (
  .clk(clk),
  .in(phy_data),
  .out(phy_data_s)
);

align_mux #(
  .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
) i_align_mux (
  .clk(clk),
  .align(frame_align),
  .in_data(phy_data_s),
  .out_data(data_aligned_s),
  .in_charisk(charisk28),
  .out_charisk(charisk28_aligned_s)
);

assign ilas_monitor_reset_s = ~ifs_ready;

pipeline_stage #(
  .WIDTH(1 + DATA_PATH_WIDTH * (8 + 1)),
  .REGISTERED(ALIGN_MUX_REGISTERED)
) i_pipeline_stage1 (
  .clk(clk),
  .in({
      ilas_monitor_reset_s,
      data_aligned_s,
      charisk28_aligned_s
    }),
  .out({
      ilas_monitor_reset,
      data_aligned,
      charisk28_aligned
    })
);

generate
if(ENABLE_FRAME_ALIGN_CHECK) begin : gen_frame_align
jesd204_rx_frame_align #(
  .DATA_PATH_WIDTH  (DATA_PATH_WIDTH),
  .ENABLE_CHAR_REPLACE (ENABLE_CHAR_REPLACE)
) i_frame_align (
  .clk                          (clk),
  .reset                        (buffer_ready_n_s),
  .cfg_octets_per_multiframe    (cfg_octets_per_multiframe),
  .cfg_octets_per_frame         (cfg_octets_per_frame),
  .cfg_disable_char_replacement (cfg_disable_char_replacement),
  .cfg_disable_scrambler        (cfg_disable_scrambler),
  .charisk28                    (charisk28_aligned),
  .data                         (data_aligned),
  .data_replaced                (data_replaced),
  .align_err_cnt                (status_frame_align_err_cnt)
);

end else begin : gen_no_frame_align_monitor
  assign status_frame_align_err_cnt = 32'd0;
  assign data_replaced = data_aligned;
end
endgenerate

jesd204_scrambler #(
  .WIDTH(DATA_PATH_WIDTH*8),
  .DESCRAMBLE(1)
) i_descrambler (
  .clk(clk),
  .reset(buffer_ready_n_s),
  .enable(~cfg_disable_scrambler),
  .data_in(data_replaced),
  .data_out(data_scrambled_s)
);

pipeline_stage #(
  .WIDTH(1 + DATA_PATH_WIDTH * 8),
  .REGISTERED(SCRAMBLER_REGISTERED)
) i_pipeline_stage2 (
  .clk(clk),
  .in({
      buffer_ready_n_s,
      data_scrambled_s
    }),
  .out({
      buffer_ready_n,
      data_scrambled
    })
);

elastic_buffer #(
  .IWIDTH(DATA_PATH_WIDTH*8),
  .OWIDTH(TPL_DATA_PATH_WIDTH*8),
  .SIZE(ELASTIC_BUFFER_SIZE),
  .ASYNC_CLK(ASYNC_CLK)
) i_elastic_buffer (
  .clk(clk),
  .reset(reset),

  .device_clk(device_clk),
  .device_reset(device_reset),

  .wr_data(data_scrambled),
  .rd_data(rx_data),

  .ready_n(buffer_ready_n),
  .do_release_n(buffer_release_n)
);

jesd204_ilas_monitor #(
  .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
) i_ilas_monitor (
  .clk(clk),
  .reset(ilas_monitor_reset),
  .cfg_octets_per_multiframe(cfg_octets_per_multiframe),
  .data(data_aligned),
  .charisk28(charisk28_aligned),

  .data_ready_n(buffer_ready_n_s),

  .ilas_config_valid(ilas_config_valid),
  .ilas_config_addr(ilas_config_addr),
  .ilas_config_data(ilas_config_data)
);

jesd204_rx_cgs #(
  .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
) i_cgs (
  .clk(clk),
  .reset(cgs_reset),

  .char_is_cgs(char_is_cgs),
  .char_is_error(char_is_error),

  .ready(cgs_ready),

  .status_state(status_cgs_state)
);

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx_lane.v

// ============================================================================
// BEGIN UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx.v
// ============================================================================
//
// The ADI JESD204 Core is released under the following license, which is
// different than all other HDL cores in this repository.
//
// Please read this, and understand the freedoms and responsibilities you have
// by using this source code/core.
//
// The JESD204 HDL, is copyright © 2016-2017 Analog Devices Inc.
//
// This core is free software, you can use run, copy, study, change, ask
// questions about and improve this core. Distribution of source, or resulting
// binaries (including those inside an FPGA or ASIC) require you to release the
// source of the entire project (excluding the system libraries provide by the
// tools/compiler/FPGA vendor). These are the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// This core  is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License version 2
// along with this source code, and binary.  If not, see
// <http://www.gnu.org/licenses/>.
//
// Commercial licenses (with commercial support) of this JESD204 core are also
// available under terms different than the General Public License. (e.g. they
// do not require you to accompany any image (FPGA or ASIC) using the JESD204
// core with any corresponding source code.) For these alternate terms you must
// purchase a license from Analog Devices Technology Licensing Office. Users
// interested in such a license should contact jesd204-licensing@analog.com for
// more information. This commercial license is sub-licensable (if you purchase
// chips from Analog Devices, incorporate them into your PCB level product, and
// purchase a JESD204 license, end users of your product will also have a
// license to use this core in a commercial setting without releasing their
// source code).
//
// In addition, we kindly ask you to acknowledge ADI in any program, application
// or publication in which you use this JESD204 HDL core. (You are not required
// to do so; it is up to your common sense to decide whether you want to comply
// with this request or not.) For general publications, we suggest referencing :
// “The design and implementation of the JESD204 HDL Core used in this project
// is copyright © 2016-2017, Analog Devices, Inc.”
//

`timescale 1ns/100ps

module jesd204_rx #(
  parameter NUM_LANES = 1,
  parameter NUM_LINKS = 1,
  parameter NUM_INPUT_PIPELINE = 1,
  parameter NUM_OUTPUT_PIPELINE = 1,
  parameter LINK_MODE = 1, // 2 - 64B/66B;  1 - 8B/10B
  /* Only 4 is supported at the moment for 8b/10b and 8 for 64b */
  parameter DATA_PATH_WIDTH = LINK_MODE == 2 ? 8 : 4,
  parameter ENABLE_FRAME_ALIGN_CHECK = 1,
  parameter ENABLE_FRAME_ALIGN_ERR_RESET = 0,
  parameter ENABLE_CHAR_REPLACE = 0,
  parameter ASYNC_CLK = 1,
  parameter TPL_DATA_PATH_WIDTH = LINK_MODE == 2 ? 8 : 4
) (
  input clk,   // Link clock, lane rate / 40 or lane rate / 20 or lane rate / 66
  input reset,

  input device_clk, // Integer multiple of frame clock
  input device_reset,

  input [DATA_PATH_WIDTH*8*NUM_LANES-1:0] phy_data,
  input [2*NUM_LANES-1:0] phy_header,
  input [DATA_PATH_WIDTH*NUM_LANES-1:0] phy_charisk,
  input [DATA_PATH_WIDTH*NUM_LANES-1:0] phy_notintable,
  input [DATA_PATH_WIDTH*NUM_LANES-1:0] phy_disperr,
  input [NUM_LANES-1:0] phy_block_sync,

  input sysref,
  output lmfc_edge,
  output lmfc_clk,

  output device_event_sysref_alignment_error,
  output device_event_sysref_edge,
  output event_frame_alignment_error,
  output event_unexpected_lane_state_error,

  output [NUM_LINKS-1:0] sync,

  output phy_en_char_align,

  output [TPL_DATA_PATH_WIDTH*8*NUM_LANES-1:0] rx_data,
  output rx_valid,
  output [TPL_DATA_PATH_WIDTH-1:0] rx_eof,
  output [TPL_DATA_PATH_WIDTH-1:0] rx_sof,
  output [TPL_DATA_PATH_WIDTH-1:0] rx_eomf,
  output [TPL_DATA_PATH_WIDTH-1:0] rx_somf,

  input [NUM_LANES-1:0] cfg_lanes_disable,
  input [NUM_LINKS-1:0] cfg_links_disable,
  input [9:0] cfg_octets_per_multiframe,
  input [7:0] cfg_octets_per_frame,
  input cfg_disable_scrambler,
  input cfg_disable_char_replacement,
  input [7:0] cfg_frame_align_err_threshold,

  input [9:0] device_cfg_octets_per_multiframe,
  input [7:0] device_cfg_octets_per_frame,
  input [7:0] device_cfg_beats_per_multiframe,
  input [7:0] device_cfg_lmfc_offset,
  input device_cfg_sysref_oneshot,
  input device_cfg_sysref_disable,
  input device_cfg_buffer_early_release,
  input [7:0] device_cfg_buffer_delay,

  input ctrl_err_statistics_reset,
  input [6:0] ctrl_err_statistics_mask,

  output [32*NUM_LANES-1:0] status_err_statistics_cnt,

  output [NUM_LANES-1:0] ilas_config_valid,
  output [NUM_LANES*2-1:0] ilas_config_addr,
  output [NUM_LANES*DATA_PATH_WIDTH*8-1:0] ilas_config_data,

  output [1:0] status_ctrl_state,
  output [2*NUM_LANES-1:0] status_lane_cgs_state,
  output [NUM_LANES-1:0] status_lane_ifs_ready,
  output [14*NUM_LANES-1:0] status_lane_latency,
  output [3*NUM_LANES-1:0] status_lane_emb_state,
  output [8*NUM_LANES-1:0] status_lane_frame_align_err_cnt,

  output [31:0] status_synth_params0,
  output [31:0] status_synth_params1,
  output [31:0] status_synth_params2
);

/*
 * Can be used to enable additional pipeline stages to ease timing. Usually not
 * necessary.
 */
localparam CHAR_INFO_REGISTERED = 0;
localparam ALIGN_MUX_REGISTERED = 1;
localparam SCRAMBLER_REGISTERED = 0;

/*
 * Maximum number of octets per multiframe for ADI JESD204 DACs is 256 (Adjust
 * as necessary). Divide by data path width.
 */
localparam MAX_OCTETS_PER_FRAME = 32;
localparam MAX_OCTETS_PER_MULTIFRAME =
  (MAX_OCTETS_PER_FRAME * 32) > 1024 ? 1024 : (MAX_OCTETS_PER_FRAME * 32);
localparam MAX_BEATS_PER_MULTIFRAME = MAX_OCTETS_PER_MULTIFRAME / DATA_PATH_WIDTH;
localparam ELASTIC_BUFFER_SIZE = MAX_BEATS_PER_MULTIFRAME;
localparam DPW_LOG2 = DATA_PATH_WIDTH == 8 ? 3 : DATA_PATH_WIDTH == 4 ? 2 : 1;

localparam LMFC_COUNTER_WIDTH = MAX_BEATS_PER_MULTIFRAME > 256 ? 9 :
  MAX_BEATS_PER_MULTIFRAME > 128 ? 8 :
  MAX_BEATS_PER_MULTIFRAME > 64 ? 7 :
  MAX_BEATS_PER_MULTIFRAME > 32 ? 6 :
  MAX_BEATS_PER_MULTIFRAME > 16 ? 5 :
  MAX_BEATS_PER_MULTIFRAME > 8 ? 4 :
  MAX_BEATS_PER_MULTIFRAME > 4 ? 3 :
  MAX_BEATS_PER_MULTIFRAME > 2 ? 2 : 1;

/* Helper for common expressions */
localparam DW = 8*DATA_PATH_WIDTH*NUM_LANES;
localparam ODW = 8*TPL_DATA_PATH_WIDTH*NUM_LANES;
localparam CW = DATA_PATH_WIDTH*NUM_LANES;
localparam HW = 2*NUM_LANES;

wire [7:0] cfg_beats_per_multiframe = cfg_octets_per_multiframe >> DPW_LOG2;
wire [7:0] device_cfg_beats_per_multiframe_s;

wire [NUM_LANES-1:0] cgs_reset;
wire [NUM_LANES-1:0] cgs_ready;
wire [NUM_LANES-1:0] ifs_reset;

reg buffer_release_n = 1'b1;
reg buffer_release_d1 = 1'b0;
wire [NUM_LANES-1:0] buffer_ready_n;
wire all_buffer_ready_n;
wire dev_all_buffer_ready_n;

reg eof_reset = 1'b1;
wire eof_reset_d;

wire [DW-1:0] phy_data_r;
wire [HW-1:0] phy_header_r;
wire [CW-1:0] phy_charisk_r;
wire [CW-1:0] phy_notintable_r;
wire [CW-1:0] phy_disperr_r;
wire [NUM_LANES-1:0] phy_block_sync_r;

wire [ODW-1:0] rx_data_s;

wire rx_valid_s = buffer_release_d1;

wire [7:0] lmfc_counter;
wire latency_monitor_reset;

wire [3*NUM_LANES-1:0] frame_align;
wire [NUM_LANES-1:0] ifs_ready;

wire event_data_phase;
wire err_statistics_reset;

wire lmfc_edge_synced;

reg [NUM_LANES-1:0] frame_align_err_thresh_met = {NUM_LANES{1'b0}};
reg [NUM_LANES-1:0] event_frame_alignment_error_per_lane = {NUM_LANES{1'b0}};

reg buffer_release_opportunity = 1'b0;

always @(posedge device_clk) begin
  if (lmfc_counter == device_cfg_buffer_delay ||
      device_cfg_buffer_early_release == 1'b1) begin
    buffer_release_opportunity <= 1'b1;
  end else begin
    buffer_release_opportunity <= 1'b0;
  end
end

assign all_buffer_ready_n = |(buffer_ready_n & ~cfg_lanes_disable);

sync_bits #(
  .NUM_OF_BITS (1),
  .ASYNC_CLK(ASYNC_CLK)
) i_all_buffer_ready_cdc (
  .in_bits(all_buffer_ready_n),
  .out_clk(device_clk),
  .out_resetn(1'b1),
  .out_bits(dev_all_buffer_ready_n)
);

always @(posedge device_clk) begin
  if (device_reset == 1'b1) begin
    buffer_release_n <= 1'b1;
  end else begin
    if (buffer_release_opportunity == 1'b1) begin
      buffer_release_n <= dev_all_buffer_ready_n;
    end
  end
  buffer_release_d1 <= ~buffer_release_n;
  eof_reset <= buffer_release_n;
end

pipeline_stage #(
  .WIDTH(NUM_LANES + (3 * CW) + HW + DW),
  .REGISTERED(NUM_INPUT_PIPELINE)
) i_input_pipeline_stage (
  .clk(clk),
  .in({
    phy_data,
    phy_header,
    phy_charisk,
    phy_notintable,
    phy_disperr,
    phy_block_sync
  }),
  .out({
    phy_data_r,
    phy_header_r,
    phy_charisk_r,
    phy_notintable_r,
    phy_disperr_r,
    phy_block_sync_r
  })
);

pipeline_stage #(
  .WIDTH(ODW+2),
  .REGISTERED(NUM_OUTPUT_PIPELINE)
) i_output_pipeline_stage (
  .clk(device_clk),
  .in({
    eof_reset,
    rx_data_s,
    rx_valid_s
  }),
  .out({
    eof_reset_d,
    rx_data,
    rx_valid
  })
);

// If input and output widths are symmetric keep the calculation for backwards
// compatibility of the software.
assign device_cfg_beats_per_multiframe_s = (TPL_DATA_PATH_WIDTH == DATA_PATH_WIDTH) ?
                                   device_cfg_octets_per_multiframe >> DPW_LOG2 :
                                   device_cfg_beats_per_multiframe;

jesd204_lmfc #(
  .LINK_MODE(LINK_MODE),
  .DATA_PATH_WIDTH(TPL_DATA_PATH_WIDTH)
) i_lmfc (
  .clk(device_clk),
  .reset(device_reset),

  .cfg_octets_per_multiframe(device_cfg_octets_per_multiframe),
  .cfg_beats_per_multiframe(device_cfg_beats_per_multiframe_s),
  .cfg_lmfc_offset(device_cfg_lmfc_offset),
  .cfg_sysref_oneshot(device_cfg_sysref_oneshot),
  .cfg_sysref_disable(device_cfg_sysref_disable),

  .sysref(sysref),
  .lmfc_edge(lmfc_edge),
  .lmfc_clk(lmfc_clk),
  .lmfc_counter(lmfc_counter),
  .lmc_edge(),
  .lmc_quarter_edge(),
  .eoemb(),

  .sysref_edge(device_event_sysref_edge),
  .sysref_alignment_error(device_event_sysref_alignment_error)
);

jesd204_frame_mark #(
  .DATA_PATH_WIDTH            (TPL_DATA_PATH_WIDTH)
) i_frame_mark (
  .clk                        (device_clk),
  .reset                      (eof_reset_d),
  .cfg_beats_per_multiframe   (device_cfg_beats_per_multiframe_s),
  .cfg_octets_per_multiframe  (device_cfg_octets_per_multiframe),
  .cfg_octets_per_frame       (device_cfg_octets_per_frame),
  .sof                        (rx_sof),
  .eof                        (rx_eof),
  .somf                       (rx_somf),
  .eomf                       (rx_eomf)
);

generate
genvar i;

sync_event #(
  .NUM_OF_EVENTS (1),
  .ASYNC_CLK(ASYNC_CLK)
) i_sync_lmfc (
  .in_clk(device_clk),
  .in_event(lmfc_edge),
  .out_clk(clk),
  .out_event(lmfc_edge_synced)
);

if (LINK_MODE[0] == 1) begin : mode_8b10b

wire unexpected_lane_state_error;
reg unexpected_lane_state_error_d = 1'b0;

jesd204_rx_ctrl #(
  .NUM_LANES(NUM_LANES),
  .NUM_LINKS(NUM_LINKS),
  .ENABLE_FRAME_ALIGN_ERR_RESET(ENABLE_FRAME_ALIGN_ERR_RESET)
) i_rx_ctrl (
  .clk(clk),
  .reset(reset),

  .cfg_lanes_disable(cfg_lanes_disable),
  .cfg_links_disable(cfg_links_disable),

  .phy_ready(1'b1),
  .phy_en_char_align(phy_en_char_align),

  .lmfc_edge(lmfc_edge_synced),
  .frame_align_err_thresh_met(frame_align_err_thresh_met),
  .sync(sync),

  .latency_monitor_reset(latency_monitor_reset),

  .cgs_reset(cgs_reset),
  .cgs_ready(cgs_ready),

  .ifs_reset(ifs_reset),

  .status_state(status_ctrl_state),

  .event_data_phase(event_data_phase)
);

assign err_statistics_reset = ctrl_err_statistics_reset ||
                              event_data_phase;

for (i = 0; i < NUM_LANES; i = i + 1) begin: gen_lane

  localparam D_START = i * DATA_PATH_WIDTH*8;
  localparam D_STOP = D_START + DATA_PATH_WIDTH*8-1;
  localparam OD_START = i * TPL_DATA_PATH_WIDTH*8;
  localparam OD_STOP = OD_START + TPL_DATA_PATH_WIDTH*8-1;
  localparam C_START = i * DATA_PATH_WIDTH;
  localparam C_STOP = C_START + DATA_PATH_WIDTH-1;

  jesd204_rx_lane #(
    .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
    .TPL_DATA_PATH_WIDTH(TPL_DATA_PATH_WIDTH),
    .CHAR_INFO_REGISTERED(CHAR_INFO_REGISTERED),
    .ALIGN_MUX_REGISTERED(ALIGN_MUX_REGISTERED),
    .SCRAMBLER_REGISTERED(SCRAMBLER_REGISTERED),
    .ELASTIC_BUFFER_SIZE(ELASTIC_BUFFER_SIZE),
    .ENABLE_FRAME_ALIGN_CHECK(ENABLE_FRAME_ALIGN_CHECK),
    .ENABLE_CHAR_REPLACE(ENABLE_CHAR_REPLACE),
    .ASYNC_CLK(ASYNC_CLK)
  ) i_lane (
    .clk(clk),
    .reset(reset),

    .device_clk(device_clk),
    .device_reset(device_reset),

    .phy_data(phy_data_r[D_STOP:D_START]),
    .phy_charisk(phy_charisk_r[C_STOP:C_START]),
    .phy_notintable(phy_notintable_r[C_STOP:C_START]),
    .phy_disperr(phy_disperr_r[C_STOP:C_START]),

    .cgs_reset(cgs_reset[i]),
    .cgs_ready(cgs_ready[i]),

    .ifs_reset(ifs_reset[i]),

    .rx_data(rx_data_s[OD_STOP:OD_START]),

    .buffer_release_n(buffer_release_n),
    .buffer_ready_n(buffer_ready_n[i]),

    .cfg_octets_per_multiframe(cfg_octets_per_multiframe),
    .cfg_octets_per_frame(cfg_octets_per_frame),
    .cfg_disable_char_replacement(cfg_disable_char_replacement),
    .cfg_disable_scrambler(cfg_disable_scrambler),

    .err_statistics_reset(err_statistics_reset),
    .ctrl_err_statistics_mask(ctrl_err_statistics_mask[2:0]),
    .status_err_statistics_cnt(status_err_statistics_cnt[32*i+31:32*i]),

    .ilas_config_valid(ilas_config_valid[i]),
    .ilas_config_addr(ilas_config_addr[2*i+1:2*i]),
    .ilas_config_data(ilas_config_data[D_STOP:D_START]),

    .status_cgs_state(status_lane_cgs_state[2*i+1:2*i]),
    .status_ifs_ready(ifs_ready[i]),
    .status_frame_align(frame_align[3*i+2:3*i]),

    .status_frame_align_err_cnt(status_lane_frame_align_err_cnt[8*i+7:8*i])
  );

  if(ENABLE_FRAME_ALIGN_CHECK) begin : gen_frame_align_err_thresh
    always @(posedge clk) begin
      if (reset) begin
        frame_align_err_thresh_met[i] <= 1'b0;
        event_frame_alignment_error_per_lane[i] <= 1'b0;
      end else begin
        if (status_lane_frame_align_err_cnt[8*i+7:8*i] >= cfg_frame_align_err_threshold) begin
          frame_align_err_thresh_met[i] <= cgs_ready[i];
          event_frame_alignment_error_per_lane[i] <= ~frame_align_err_thresh_met[i];
        end else begin
          frame_align_err_thresh_met[i] <= 1'b0;
          event_frame_alignment_error_per_lane[i] <= 1'b0;
        end
      end
    end
  end else begin : gen_no_frame_align_err_thresh
    always @(*) begin
      frame_align_err_thresh_met[i] <= 1'b0;
      event_frame_alignment_error_per_lane[i] <= 1'b0;
    end
  end
end

assign event_frame_alignment_error = |event_frame_alignment_error_per_lane;

/* If one of the enabled lanes falls out of DATA phase while the link is in DATA phase
 * report an error event */
assign unexpected_lane_state_error = |(~(cgs_ready|cfg_lanes_disable)) & &status_ctrl_state;
always @(posedge clk) begin
  unexpected_lane_state_error_d <= unexpected_lane_state_error;
end
assign event_unexpected_lane_state_error = unexpected_lane_state_error & ~unexpected_lane_state_error_d;


/* Delay matching based on the number of pipeline stages */
reg [NUM_LANES-1:0] ifs_ready_d1 = 1'b0;
reg [NUM_LANES-1:0] ifs_ready_d2 = 1'b0;
reg [NUM_LANES-1:0] ifs_ready_mux;

always @(posedge clk) begin
  ifs_ready_d1 <= ifs_ready;
  ifs_ready_d2 <= ifs_ready_d1;
end

always @(*) begin
  case (SCRAMBLER_REGISTERED + ALIGN_MUX_REGISTERED)
  1: ifs_ready_mux = ifs_ready_d1;
  2: ifs_ready_mux = ifs_ready_d2;
  default: ifs_ready_mux = ifs_ready;
  endcase
end

jesd204_lane_latency_monitor #(
  .NUM_LANES(NUM_LANES),
  .DATA_PATH_WIDTH(DATA_PATH_WIDTH)
) i_lane_latency_monitor (
  .clk(clk),
  .reset(latency_monitor_reset),

  .lane_ready(ifs_ready_mux),
  .lane_frame_align(frame_align),
  .lane_latency_ready(status_lane_ifs_ready),
  .lane_latency(status_lane_latency)
);

assign status_lane_emb_state = 'b0;

end

if (LINK_MODE[1] == 1) begin : mode_64b66b

wire [NUM_LANES-1:0] emb_lock;
wire link_buffer_release_n;

sync_bits #(
  .NUM_OF_BITS (1),
  .ASYNC_CLK(ASYNC_CLK)
) i_buffer_release_cdc (
  .in_bits(buffer_release_n),
  .out_clk(clk),
  .out_resetn(1'b1),
  .out_bits(link_buffer_release_n)
);

jesd204_rx_ctrl_64b  #(
  .NUM_LANES(NUM_LANES)
) i_jesd204_rx_ctrl_64b (
  .clk(clk),
  .reset(reset),

  .cfg_lanes_disable(cfg_lanes_disable),

  .phy_block_sync(phy_block_sync_r),
  .emb_lock(emb_lock),

  .all_emb_lock(all_emb_lock),
  .buffer_release_n(link_buffer_release_n),

  .status_state(status_ctrl_state),
  .event_unexpected_lane_state_error(event_unexpected_lane_state_error)
);

for (i = 0; i < NUM_LANES; i = i + 1) begin: gen_lane

  localparam D_START = i * DATA_PATH_WIDTH*8;
  localparam D_STOP = D_START + DATA_PATH_WIDTH*8-1;
  localparam TPL_D_START = i * TPL_DATA_PATH_WIDTH*8;
  localparam TPL_D_STOP = TPL_D_START + TPL_DATA_PATH_WIDTH*8-1;
  localparam H_START = i * 2;
  localparam H_STOP = H_START + 2-1;

  wire [7:0] status_lane_skew;

  jesd204_rx_lane_64b #(
    .ELASTIC_BUFFER_SIZE(ELASTIC_BUFFER_SIZE),
    .TPL_DATA_PATH_WIDTH(TPL_DATA_PATH_WIDTH),
    .ASYNC_CLK(ASYNC_CLK)
  ) i_lane (
    .clk(clk),
    .reset(reset),

    .device_clk(device_clk),
    .device_reset(device_reset),

    .phy_data(phy_data_r[D_STOP:D_START]),
    .phy_header(phy_header_r[H_STOP:H_START]),
    .phy_block_sync(phy_block_sync_r[i]),

    .cfg_disable_scrambler(cfg_disable_scrambler),
    .cfg_header_mode(2'b0),
    .cfg_rx_thresh_emb_err(5'd8),
    .cfg_beats_per_multiframe(cfg_beats_per_multiframe),

    .rx_data(rx_data_s[TPL_D_STOP:TPL_D_START]),

    .buffer_release_n(buffer_release_n),
    .buffer_ready_n(buffer_ready_n[i]),
    .all_buffer_ready_n(all_buffer_ready_n),

    .lmfc_edge(lmfc_edge_synced),
    .emb_lock(emb_lock[i]),

    .ctrl_err_statistics_reset(ctrl_err_statistics_reset),
    .ctrl_err_statistics_mask(ctrl_err_statistics_mask[6:3]),
    .status_err_statistics_cnt(status_err_statistics_cnt[32*i+31:32*i]),

    .status_lane_emb_state(status_lane_emb_state[3*i+2:3*i]),
    .status_lane_skew(status_lane_skew)
  );

assign status_lane_latency[14*(i+1)-1:14*i] = {3'b0,status_lane_skew,3'b0};

end

// Assign unused outputs
assign sync = 'b0;
assign phy_en_char_align = 1'b0;

assign ilas_config_valid ='b0;
assign ilas_config_addr = 'b0;
assign ilas_config_data = 'b0;
assign status_lane_cgs_state = 'b0;
assign status_lane_ifs_ready = {NUM_LANES{1'b1}};
assign event_frame_alignment_error = 1'b0;

end


endgenerate

// Core static parameters
assign status_synth_params0 = {NUM_LANES};
assign status_synth_params1 = {
                 /*31:16 */  16'b0,
                 /*15: 8 */  1'b0,TPL_DATA_PATH_WIDTH[6:0],
                 /* 7: 0 */  4'b0,DPW_LOG2[3:0]};
assign status_synth_params2 = {
                 /*31:19 */  13'b0,
                 /*   18 */  ENABLE_CHAR_REPLACE[0],
                 /*   17 */  ENABLE_FRAME_ALIGN_ERR_RESET[0],
                 /*   16 */  ENABLE_FRAME_ALIGN_CHECK[0],
                 /*15:13 */  3'b0,
                 /*   12 */  ASYNC_CLK[0],
                 /*11:10 */  2'b0,
                 /* 9: 8 */  LINK_MODE[1:0],
                 /* 7: 0 */  NUM_LINKS[7:0]};

endmodule

// END UPSTREAM FILE: library/jesd204/jesd204_rx/jesd204_rx.v

