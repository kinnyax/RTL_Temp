---
schema_type: rtl_module_spec
domain: FPGA_RTL
rule_version: v0.1
status: finalized
workflow_status: SPEC_READY
module_name: ADC_TOP
module_contract: RTL_MODULE_SPEC_V0_1
spec_version: v0.13
revision_date: 2026-08-26
author: Codex
---

# ADC_TOP RTL Module Specification

## 1. Module Purpose And Boundary

`ADC_TOP` is a fixed eight-channel acquisition module for eight AC9810 devices. It accepts decoded two-lane JESD204B PHY data/status, produces one 512-bit AXI4-Stream per device, exposes AXI4-Lite configuration/diagnostics, and drives one independent external-nonuniform TGC interface per device.

Its intended system use is continuous acquisition from software start until software stop for eight AFEs, two lanes per AFE, 256 total 16-bit channels, including the named 5 MHz RAW validation point and 20/30 MHz M24 DDC operating points. There is no business-level acquisition pause/resume function. AXIS emits only complete 256-entry blocks; stopping does not create a partial tail block.

It owns eight receive adapters, data-valid qualification, unpacking/formatting/DDC, complete-candidate FIFO admission, eight AFE-to-ADC FIFOs, fixed 256-entry AXIS block generation, register behavior, named CDC, enable/clear/recovery, and TGC pin actions. AXIS carries FIFO sample data only; this module does not prepend a header or calculate a data-path CRC.

External dependencies are decoded PHY signals, reset/clock management, AXIS consumers, the verified PUB asynchronous FIFO, and the third-party ADI `jesd204_rx`. Software owns legal/stable static configuration, AC9810 SPI/profile-table programming, stop/clear/relink sequencing, and TGC command ordering.

AC9810 register `0x14F=0x2772` is an AFE synchronization-word configuration owned by the external SPI/configuration flow. `ADC_RXD` normalizes received byte/word order. `ADC_UPK` uses that normalized stream to validate both required per-lane `sync_word ×16` segments against `16'h2772`, then owns region scheduling, formatting, four-beat packing, and complete-candidate admission.

Out of scope are GTH/PHY/DRP generation, AC9810 SPI, clock generation, board timing closure, AXIS arbitration, interrupts, synthesis, implementation, and board validation.

## 2. Architecture Overview

Per-channel data flow is:

```text
decoded PHY -> ADC_RXD -> ADC_UPK -> async_fifo -> ADC_PKT -> AXI4-Stream
                         |
                         + data_error_evt -> software diagnostics
```

Control/status flow is:

```text
AXI4-Lite -> ADC_REG --------------------> eight ADC_TGC instances
JESD/AFE local status -> CHN_SYNC -> ADC -> ADC_SYNC -> ADC_REG
AFE software-only events ----------------> ADC_SYNC -> ADC_REG
```

Domains are SYS (`sys_clk`), ADC (`adc_clk`), AFE (`afe_clk`), and JESD[n] (`jesd_clk[n]`). External resets are active low. Static sample configuration crosses by a software stability contract. FIFO data crosses through a 512-entry FWFT asynchronous FIFO. Its implementation may select either `WC=0` reject-on-full or `WC=1` write-continue-on-full behavior; ADC_TOP architectural correctness does not depend on that choice, but both choices must report a full write as overflow. Levels use level CDC and diagnostic occurrences use event CDC. Each `ADC_TGC` locally synchronizes its SYS-domain RUN level into AFE and detects one 0-to-1 launch; profile/direction remain stable before RUN rises and until software writes RUN back to 0.

`ADC_SYNC` is a pure CDC concentrator with no business state or policy. `CHN_SYNC` is the per-channel JESD/AFE-to-ADC boundary. Channel-enable CDC remains local to `ADC_CHN`.

TGC runs in `afe_clk`. AU5619 also sources the AC9810 ADC clock, but common source alone does not prove external setup/hold; integration must constrain frequency, phase, skew, jitter, board delay, and FPGA clock-to-output.

## 3. Module Hierarchy And Responsibilities

| Module | Kind | Instances | Responsibility | Clock / Reset | Connects To |
| --- | --- | ---: | --- | --- | --- |
| `ADC_TOP` | top | 1 | Fixed public interface and eight-channel aggregation. | SYS, ADC, AFE, JESD[7:0] | All children/external interfaces. |
| `ADC_REG` | submodule | 1 | AXI4-Lite, register map, W1C stickies, and stable SYS-domain TGC profile/direction/RUN levels. It owns no FSM. | SYS | `ADC_SYNC`, channels. |
| `ADC_SYNC` | submodule | 1 | Pure SYS/ADC/AFE CDC concentration. | SYS, ADC, AFE | `ADC_REG`, channels. |
| `ADC_CHN` | submodule | 8 | One AC9810 channel and local CDC/composition. | ADC, AFE, JESD[n] | Local children. |
| `ADC_RXD` | submodule | 8 | ADI TPL8 receive wrapper, 128-bit lane/byte/word normalization, receive-link qualification, and detailed diagnostics. | AFE, JESD[n] | PHY, UPK, sync. |
| `ADC_UPK` | submodule | 8 | Two-segment synchronization-word validation, region scheduling, formatting, natural-order complete candidates, FIFO admission, and error event. | AFE | RXD, FIFO. |
| `async_fifo` | submodule | 8 | 512 × 512-bit FWFT AFE-to-ADC CDC; implementation-selected `WC=0` or `WC=1`, with overflow occurrence required in either case. | AFE write, ADC read | UPK, packet, diagnostics. |
| `ADC_PKT` | submodule | 8 | FIFO read-side admission and one 256-entry, data-only AXIS block per admission. | ADC | FIFO, AXIS consumer. |
| `CHN_SYNC` | submodule | 8 | Local JESD/AFE-to-ADC levels/events and quiescence. | ADC, AFE, JESD[n] | channel/top. |
| `ADC_TGC` | submodule | 8 | One channel-local AC9810 RUN synchronizer/edge detector, three-phase action FSM, and pin action. | SYS input, AFE action | register levels, pins. |

Each `ADC_RXD` contains one third-party ADI `jesd204_rx` pinned to upstream commit `9738f97a82c2bddb9b7cb3a53e57a8f098bdcd11`, with `NUM_LANES=2`, `NUM_LINKS=1`, `LINK_MODE=1`, `DATA_PATH_WIDTH=4`, `TPL_DATA_PATH_WIDTH=8`, `ASYNC_CLK=1`, frame-align check/reset enabled, character replacement enabled, and `device_cfg_beats_per_multiframe=32`. The core outputs one 128-bit AFE beat containing two lanes × eight bytes. `ADC_RXD` does not aggregate beats or filter SYNC, ZERO, or DATA content; it normalizes lane/byte/word order and presents each beat directly to `ADC_UPK` as Lane0 in `rxd_data[63:0]` and Lane1 in `rxd_data[127:64]`. Within each lane, bits `[15:0]` contain the earliest normalized 16-bit word and later words occupy successively higher slices. `rxd_ready` is exactly the ADI authoritative link-ready functional level and is not combined with other diagnostics or used as ready/valid backpressure. SYSREF, frame-align, lane-state, disparity, not-in-table, and related PHY/JESD indications contribute only to software diagnostic levels/events. Its source-owned internal interface remains governed by the pinned upstream revision and is not a reusable boundary declared by this specification.

## 4. Interface Contract

The following single table is authoritative. Each row defines exactly one target boundary port. The target removes the obsolete packet metadata/CRC and channel-local `fifo_sta` boundaries while retaining the public `ADC_TOP` port set.

The clock/reset column uses two compact phrases inherited from the public boundary inventory. They are not unresolved placeholders; the following exhaustive resolver is normative:

- Public channel-indexed families `afe0` through `afe7` for `rx_*`, `pll_lock`, `byte_aligned`, `rx_encommalign`, and `sync_n`, plus the corresponding `ADC_CHN`/`ADC_RXD` `phy_*` ports, are in the matching `JESD[0]` through `JESD[7]` source domains and use the matching `jesd_rst_n[0]` through `jesd_rst_n[7]` active-low resets.
- `sysref_in` and the `sysref` inputs of `ADC_SYNC`, `ADC_CHN`, and `ADC_RXD` are external asynchronous levels. Each named consumer owns the synchronization required by its target domain; no combinational SYS/ADC/AFE policy depends on the asynchronous level.
- Every `ADC_REG` status/event input is already in `SYS / sys_rst_n` after `ADC_SYNC`; `adc_ctl`, `frm_cfg`, `tgc_run`, `tgc_profile`, and `tgc_up_dn` originate in SYS. Static `adc_ctl`/`frm_cfg` fields cross under the disabled-and-idle software stability contract.
- In `ADC_CHN`, `link_ready_sync`, `rx_fifo_empt`, `chn_idle_adc`, all `*_sync` PHY/JESD status outputs, and `sysref_seen_sync` are in `ADC / adc_rst_n`; `rx_fifo_of`, `fifo_full_afe`, and `data_error_evt` are in `AFE / afe_rst_n`. TGC pin outputs are in `AFE / afe_rst_n`.
- In `ADC_RXD`, `chn_en`, normalized RXD functional outputs, and ADI SYSREF event outputs are in `AFE / afe_rst_n`; ADI link/lane/CGS status and PHY/link diagnostic occurrences are in `JESD / jesd_rst_n` before `CHN_SYNC`.
- In `ADC_UPK`, `chn_en`, static configuration consumption, FIFO write data/request, data-error event, and idle are in `AFE / afe_rst_n`.
- For `async_fifo`, `wclr`, `winc`, `wdata`, `full`, `overflow`, and `wlevel` belong to `AFE / afe_rst_n`; `rclr`, `rinc`, `rdata`, `empty`, `underflow`, and `rlevel` belong to `ADC / adc_rst_n`; `wclk=afe_clk`, `rclk=adc_clk`, and `rst_n` is the common active-low dependency reset observed by both domains.
- In `ADC_PKT`, every non-reset port is in `ADC / adc_rst_n`. In `CHN_SYNC`, PHY/link/lane/CGS and disparity/not-in-table/link-error inputs are in `JESD / jesd_rst_n`, SYSREF-event and UPK/TGC-idle inputs are in `AFE / afe_rst_n`, and every `*_sync` output is in `ADC / adc_rst_n`. In `ADC_TGC`, `chn_en` and all action outputs are in `AFE / afe_rst_n`; RUN/profile/direction are stable SYS-origin levels with synchronization/capture owned by `ADC_TGC`.

| Module | Port | Direction | Width | Clock / Reset | Protocol / Role | Reset Behavior | Description |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| `ADC_TOP` | `sys_clk` | input | 1 | SYS | clock | not applicable | Final sys_clk boundary signal. |
| `ADC_TOP` | `sys_rst_n` | input | 1 | SYS / sys_rst_n | active-low reset | assertion resets associated state | Final sys_rst_n boundary signal. |
| `ADC_TOP` | `adc_clk` | input | 1 | ADC | clock | not applicable | Final adc_clk boundary signal. |
| `ADC_TOP` | `adc_rst_n` | input | 1 | ADC / adc_rst_n | active-low reset | assertion resets associated state | Final adc_rst_n boundary signal. |
| `ADC_TOP` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `ADC_TOP` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `ADC_TOP` | `jesd_clk` | input | 8 | JESD | clock | not applicable | Final jesd_clk boundary signal. |
| `ADC_TOP` | `jesd_rst_n` | input | 8 | source domain / associated reset | active-low reset | assertion resets associated state | Final jesd_rst_n boundary signal. |
| `ADC_TOP` | `sysref_in` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final sysref_in boundary signal. |
| `ADC_TOP` | `s_axi_awaddr` | input | 16 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_awaddr boundary signal. |
| `ADC_TOP` | `s_axi_awvalid` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_awvalid boundary signal. |
| `ADC_TOP` | `s_axi_awready` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_awready boundary signal. |
| `ADC_TOP` | `s_axi_wdata` | input | 32 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_wdata boundary signal. |
| `ADC_TOP` | `s_axi_wstrb` | input | 4 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_wstrb boundary signal. |
| `ADC_TOP` | `s_axi_wvalid` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_wvalid boundary signal. |
| `ADC_TOP` | `s_axi_wready` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_wready boundary signal. |
| `ADC_TOP` | `s_axi_bresp` | output | 2 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_bresp boundary signal. |
| `ADC_TOP` | `s_axi_bvalid` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_bvalid boundary signal. |
| `ADC_TOP` | `s_axi_bready` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_bready boundary signal. |
| `ADC_TOP` | `s_axi_araddr` | input | 16 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_araddr boundary signal. |
| `ADC_TOP` | `s_axi_arvalid` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_arvalid boundary signal. |
| `ADC_TOP` | `s_axi_arready` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_arready boundary signal. |
| `ADC_TOP` | `s_axi_rdata` | output | 32 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_rdata boundary signal. |
| `ADC_TOP` | `s_axi_rresp` | output | 2 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_rresp boundary signal. |
| `ADC_TOP` | `s_axi_rvalid` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_rvalid boundary signal. |
| `ADC_TOP` | `s_axi_rready` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_rready boundary signal. |
| `ADC_TOP` | `afe0_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe0_rx_data boundary signal. |
| `ADC_TOP` | `afe0_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe0_rx_charisk boundary signal. |
| `ADC_TOP` | `afe0_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe0_rx_disperr boundary signal. |
| `ADC_TOP` | `afe0_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe0_rx_notintable boundary signal. |
| `ADC_TOP` | `afe0_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe0_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe0_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe0_pll_lock boundary signal. |
| `ADC_TOP` | `afe0_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe0_byte_aligned boundary signal. |
| `ADC_TOP` | `afe0_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe0_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe0_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe0_sync_n boundary signal. |
| `ADC_TOP` | `afe1_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe1_rx_data boundary signal. |
| `ADC_TOP` | `afe1_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe1_rx_charisk boundary signal. |
| `ADC_TOP` | `afe1_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe1_rx_disperr boundary signal. |
| `ADC_TOP` | `afe1_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe1_rx_notintable boundary signal. |
| `ADC_TOP` | `afe1_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe1_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe1_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe1_pll_lock boundary signal. |
| `ADC_TOP` | `afe1_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe1_byte_aligned boundary signal. |
| `ADC_TOP` | `afe1_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe1_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe1_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe1_sync_n boundary signal. |
| `ADC_TOP` | `afe2_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe2_rx_data boundary signal. |
| `ADC_TOP` | `afe2_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe2_rx_charisk boundary signal. |
| `ADC_TOP` | `afe2_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe2_rx_disperr boundary signal. |
| `ADC_TOP` | `afe2_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe2_rx_notintable boundary signal. |
| `ADC_TOP` | `afe2_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe2_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe2_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe2_pll_lock boundary signal. |
| `ADC_TOP` | `afe2_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe2_byte_aligned boundary signal. |
| `ADC_TOP` | `afe2_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe2_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe2_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe2_sync_n boundary signal. |
| `ADC_TOP` | `afe3_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe3_rx_data boundary signal. |
| `ADC_TOP` | `afe3_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe3_rx_charisk boundary signal. |
| `ADC_TOP` | `afe3_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe3_rx_disperr boundary signal. |
| `ADC_TOP` | `afe3_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe3_rx_notintable boundary signal. |
| `ADC_TOP` | `afe3_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe3_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe3_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe3_pll_lock boundary signal. |
| `ADC_TOP` | `afe3_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe3_byte_aligned boundary signal. |
| `ADC_TOP` | `afe3_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe3_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe3_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe3_sync_n boundary signal. |
| `ADC_TOP` | `afe4_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe4_rx_data boundary signal. |
| `ADC_TOP` | `afe4_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe4_rx_charisk boundary signal. |
| `ADC_TOP` | `afe4_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe4_rx_disperr boundary signal. |
| `ADC_TOP` | `afe4_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe4_rx_notintable boundary signal. |
| `ADC_TOP` | `afe4_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe4_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe4_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe4_pll_lock boundary signal. |
| `ADC_TOP` | `afe4_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe4_byte_aligned boundary signal. |
| `ADC_TOP` | `afe4_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe4_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe4_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe4_sync_n boundary signal. |
| `ADC_TOP` | `afe5_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe5_rx_data boundary signal. |
| `ADC_TOP` | `afe5_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe5_rx_charisk boundary signal. |
| `ADC_TOP` | `afe5_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe5_rx_disperr boundary signal. |
| `ADC_TOP` | `afe5_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe5_rx_notintable boundary signal. |
| `ADC_TOP` | `afe5_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe5_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe5_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe5_pll_lock boundary signal. |
| `ADC_TOP` | `afe5_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe5_byte_aligned boundary signal. |
| `ADC_TOP` | `afe5_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe5_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe5_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe5_sync_n boundary signal. |
| `ADC_TOP` | `afe6_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe6_rx_data boundary signal. |
| `ADC_TOP` | `afe6_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe6_rx_charisk boundary signal. |
| `ADC_TOP` | `afe6_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe6_rx_disperr boundary signal. |
| `ADC_TOP` | `afe6_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe6_rx_notintable boundary signal. |
| `ADC_TOP` | `afe6_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe6_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe6_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe6_pll_lock boundary signal. |
| `ADC_TOP` | `afe6_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe6_byte_aligned boundary signal. |
| `ADC_TOP` | `afe6_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe6_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe6_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe6_sync_n boundary signal. |
| `ADC_TOP` | `afe7_rx_data` | input | 64 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe7_rx_data boundary signal. |
| `ADC_TOP` | `afe7_rx_charisk` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe7_rx_charisk boundary signal. |
| `ADC_TOP` | `afe7_rx_disperr` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe7_rx_disperr boundary signal. |
| `ADC_TOP` | `afe7_rx_notintable` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final afe7_rx_notintable boundary signal. |
| `ADC_TOP` | `afe7_rx_reset_done` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe7_rx_reset_done boundary signal. |
| `ADC_TOP` | `afe7_pll_lock` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe7_pll_lock boundary signal. |
| `ADC_TOP` | `afe7_byte_aligned` | input | 2 | associated domain / reset | control/data | ignored or inactive during associated reset | Final afe7_byte_aligned boundary signal. |
| `ADC_TOP` | `afe7_rx_encommalign` | output | 1 | associated domain / reset | control/data | 0 | Final afe7_rx_encommalign boundary signal. |
| `ADC_TOP` | `afe7_sync_n` | output | 1 | associated domain / reset | control/data | 0 | Final afe7_sync_n boundary signal. |
| `ADC_TOP` | `m_axis_afe0_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe0_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe0_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe0_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe0_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe0_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe0_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe0_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe0_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe0_tready boundary signal. |
| `ADC_TOP` | `tgc0_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc0_slope boundary signal. |
| `ADC_TOP` | `tgc0_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc0_up_dn boundary signal. |
| `ADC_TOP` | `tgc0_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc0_prof1 boundary signal. |
| `ADC_TOP` | `tgc0_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc0_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe1_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe1_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe1_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe1_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe1_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe1_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe1_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe1_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe1_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe1_tready boundary signal. |
| `ADC_TOP` | `tgc1_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc1_slope boundary signal. |
| `ADC_TOP` | `tgc1_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc1_up_dn boundary signal. |
| `ADC_TOP` | `tgc1_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc1_prof1 boundary signal. |
| `ADC_TOP` | `tgc1_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc1_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe2_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe2_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe2_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe2_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe2_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe2_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe2_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe2_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe2_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe2_tready boundary signal. |
| `ADC_TOP` | `tgc2_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc2_slope boundary signal. |
| `ADC_TOP` | `tgc2_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc2_up_dn boundary signal. |
| `ADC_TOP` | `tgc2_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc2_prof1 boundary signal. |
| `ADC_TOP` | `tgc2_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc2_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe3_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe3_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe3_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe3_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe3_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe3_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe3_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe3_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe3_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe3_tready boundary signal. |
| `ADC_TOP` | `tgc3_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc3_slope boundary signal. |
| `ADC_TOP` | `tgc3_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc3_up_dn boundary signal. |
| `ADC_TOP` | `tgc3_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc3_prof1 boundary signal. |
| `ADC_TOP` | `tgc3_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc3_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe4_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe4_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe4_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe4_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe4_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe4_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe4_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe4_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe4_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe4_tready boundary signal. |
| `ADC_TOP` | `tgc4_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc4_slope boundary signal. |
| `ADC_TOP` | `tgc4_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc4_up_dn boundary signal. |
| `ADC_TOP` | `tgc4_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc4_prof1 boundary signal. |
| `ADC_TOP` | `tgc4_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc4_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe5_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe5_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe5_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe5_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe5_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe5_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe5_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe5_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe5_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe5_tready boundary signal. |
| `ADC_TOP` | `tgc5_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc5_slope boundary signal. |
| `ADC_TOP` | `tgc5_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc5_up_dn boundary signal. |
| `ADC_TOP` | `tgc5_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc5_prof1 boundary signal. |
| `ADC_TOP` | `tgc5_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc5_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe6_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe6_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe6_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe6_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe6_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe6_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe6_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe6_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe6_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe6_tready boundary signal. |
| `ADC_TOP` | `tgc6_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc6_slope boundary signal. |
| `ADC_TOP` | `tgc6_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc6_up_dn boundary signal. |
| `ADC_TOP` | `tgc6_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc6_prof1 boundary signal. |
| `ADC_TOP` | `tgc6_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc6_prof2 boundary signal. |
| `ADC_TOP` | `m_axis_afe7_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe7_tdata boundary signal. |
| `ADC_TOP` | `m_axis_afe7_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe7_tkeep boundary signal. |
| `ADC_TOP` | `m_axis_afe7_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe7_tvalid boundary signal. |
| `ADC_TOP` | `m_axis_afe7_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_afe7_tlast boundary signal. |
| `ADC_TOP` | `m_axis_afe7_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream | ignored or inactive during associated reset | Final m_axis_afe7_tready boundary signal. |
| `ADC_TOP` | `tgc7_slope` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc7_slope boundary signal. |
| `ADC_TOP` | `tgc7_up_dn` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc7_up_dn boundary signal. |
| `ADC_TOP` | `tgc7_prof1` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc7_prof1 boundary signal. |
| `ADC_TOP` | `tgc7_prof2` | output | 1 | AFE / afe_rst_n | control/data | 0 | Final tgc7_prof2 boundary signal. |
| `ADC_REG` | `sys_clk` | input | 1 | SYS | clock | not applicable | Final sys_clk boundary signal. |
| `ADC_REG` | `sys_rst_n` | input | 1 | SYS / sys_rst_n | active-low reset | assertion resets associated state | Final sys_rst_n boundary signal. |
| `ADC_REG` | `s_axi_awaddr` | input | 16 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_awaddr boundary signal. |
| `ADC_REG` | `s_axi_awvalid` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_awvalid boundary signal. |
| `ADC_REG` | `s_axi_awready` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_awready boundary signal. |
| `ADC_REG` | `s_axi_wdata` | input | 32 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_wdata boundary signal. |
| `ADC_REG` | `s_axi_wstrb` | input | 4 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_wstrb boundary signal. |
| `ADC_REG` | `s_axi_wvalid` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_wvalid boundary signal. |
| `ADC_REG` | `s_axi_wready` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_wready boundary signal. |
| `ADC_REG` | `s_axi_bresp` | output | 2 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_bresp boundary signal. |
| `ADC_REG` | `s_axi_bvalid` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_bvalid boundary signal. |
| `ADC_REG` | `s_axi_bready` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_bready boundary signal. |
| `ADC_REG` | `s_axi_araddr` | input | 16 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_araddr boundary signal. |
| `ADC_REG` | `s_axi_arvalid` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_arvalid boundary signal. |
| `ADC_REG` | `s_axi_arready` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_arready boundary signal. |
| `ADC_REG` | `s_axi_rdata` | output | 32 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_rdata boundary signal. |
| `ADC_REG` | `s_axi_rresp` | output | 2 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_rresp boundary signal. |
| `ADC_REG` | `s_axi_rvalid` | output | 1 | SYS / sys_rst_n | AXI4-Lite | 0 | Final s_axi_rvalid boundary signal. |
| `ADC_REG` | `s_axi_rready` | input | 1 | SYS / sys_rst_n | AXI4-Lite | ignored or inactive during associated reset | Final s_axi_rready boundary signal. |
| `ADC_REG` | `link_ready` | input | 8 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final link_ready boundary signal. |
| `ADC_REG` | `fifo_empty` | input | 8 | associated domain / reset | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_empty boundary signal. |
| `ADC_REG` | `fifo_full` | input | 8 | associated domain / reset | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_full boundary signal. |
| `ADC_REG` | `chn_idle` | input | 8 | associated domain / reset | enable/quiescence | ignored or inactive during associated reset | Final chn_idle boundary signal. |
| `ADC_REG` | `pll_lock` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final pll_lock boundary signal. |
| `ADC_REG` | `rx_reset_done` | input | 8 | associated domain / reset | control/data | ignored or inactive during associated reset | Final rx_reset_done boundary signal. |
| `ADC_REG` | `lane_ready` | input | 16 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final lane_ready boundary signal. |
| `ADC_REG` | `byte_aligned` | input | 16 | associated domain / reset | control/data | ignored or inactive during associated reset | Final byte_aligned boundary signal. |
| `ADC_REG` | `comma_detected` | input | 16 | associated domain / reset | control/data | ignored or inactive during associated reset | Final comma_detected boundary signal. |
| `ADC_REG` | `sysref_level` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final sysref_level boundary signal. |
| `ADC_REG` | `fifo_overflow_evt` | input | 8 | associated domain / reset | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_overflow_evt boundary signal. |
| `ADC_REG` | `data_error_evt` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | One data-error occurrence. |
| `ADC_REG` | `link_error_evt` | input | 8 | source domain / associated reset | status/event | ignored or inactive during associated reset | Final link_error_evt boundary signal. |
| `ADC_REG` | `sysref_seen_evt` | input | 8 | associated domain / reset | status/event | ignored or inactive during associated reset | Final sysref_seen_evt boundary signal. |
| `ADC_REG` | `disparity_evt` | input | 16 | associated domain / reset | status/event | ignored or inactive during associated reset | Final disparity_evt boundary signal. |
| `ADC_REG` | `notintable_evt` | input | 16 | associated domain / reset | status/event | ignored or inactive during associated reset | Final notintable_evt boundary signal. |
| `ADC_REG` | `adc_ctl` | output | 32 | associated domain / reset | configuration/metadata | 0 | Final adc_ctl boundary signal. |
| `ADC_REG` | `frm_cfg` | output | 32 | associated domain / reset | configuration/metadata | 0 | FRM_CFG register image. |
| `ADC_REG` | `tgc_run` | output | 8 | SYS / sys_rst_n | TGC run level | 0 | Per-channel software-held RUN level; software must write 0 before a later 0-to-1 launch. |
| `ADC_REG` | `tgc_profile` | output | 16 | SYS / sys_rst_n | TGC stable configuration level | 0 | Per-channel profile selector, stable before RUN rises and while RUN remains 1. |
| `ADC_REG` | `tgc_up_dn` | output | 8 | SYS / sys_rst_n | TGC stable configuration level | 0 | Per-channel direction, stable before RUN rises and while RUN remains 1. |
| `ADC_SYNC` | `sys_clk` | input | 1 | SYS | clock | not applicable | Final sys_clk boundary signal. |
| `ADC_SYNC` | `sys_rst_n` | input | 1 | SYS / sys_rst_n | active-low reset | assertion resets associated state | Final sys_rst_n boundary signal. |
| `ADC_SYNC` | `adc_clk` | input | 1 | ADC | clock | not applicable | Final adc_clk boundary signal. |
| `ADC_SYNC` | `adc_rst_n` | input | 1 | ADC / adc_rst_n | active-low reset | assertion resets associated state | Final adc_rst_n boundary signal. |
| `ADC_SYNC` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `ADC_SYNC` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `ADC_SYNC` | `sysref` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final sysref boundary signal. |
| `ADC_SYNC` | `link_ready_adc` | input | 8 | ADC / adc_rst_n | JESD data/control/status | ignored or inactive during associated reset | Final link_ready_adc boundary signal. |
| `ADC_SYNC` | `fifo_empty_adc` | input | 8 | ADC / adc_rst_n | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_empty_adc boundary signal. |
| `ADC_SYNC` | `afe_idle_adc` | input | 8 | ADC / adc_rst_n | control/data | ignored or inactive during associated reset | Final afe_idle_adc boundary signal. |
| `ADC_SYNC` | `pll_lock_adc` | input | 8 | ADC / adc_rst_n | control/data | ignored or inactive during associated reset | Final pll_lock_adc boundary signal. |
| `ADC_SYNC` | `rx_reset_done_adc` | input | 8 | ADC / adc_rst_n | control/data | ignored or inactive during associated reset | Final rx_reset_done_adc boundary signal. |
| `ADC_SYNC` | `lane_ready_adc` | input | 16 | ADC / adc_rst_n | JESD data/control/status | ignored or inactive during associated reset | Final lane_ready_adc boundary signal. |
| `ADC_SYNC` | `byte_aligned_adc` | input | 16 | ADC / adc_rst_n | control/data | ignored or inactive during associated reset | Final byte_aligned_adc boundary signal. |
| `ADC_SYNC` | `comma_detected_adc` | input | 16 | ADC / adc_rst_n | control/data | ignored or inactive during associated reset | Final comma_detected_adc boundary signal. |
| `ADC_SYNC` | `link_error_evt_adc` | input | 8 | ADC / adc_rst_n | status/event | ignored or inactive during associated reset | Final link_error_evt_adc boundary signal. |
| `ADC_SYNC` | `sysref_seen_evt_adc` | input | 8 | ADC / adc_rst_n | status/event | ignored or inactive during associated reset | Final sysref_seen_evt_adc boundary signal. |
| `ADC_SYNC` | `disparity_evt_adc` | input | 16 | ADC / adc_rst_n | status/event | ignored or inactive during associated reset | Final disparity_evt_adc boundary signal. |
| `ADC_SYNC` | `notintable_evt_adc` | input | 16 | ADC / adc_rst_n | status/event | ignored or inactive during associated reset | Final notintable_evt_adc boundary signal. |
| `ADC_SYNC` | `fifo_overflow_evt_afe` | input | 8 | AFE / afe_rst_n | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_overflow_evt_afe boundary signal. |
| `ADC_SYNC` | `link_ready_sys` | output | 8 | SYS / sys_rst_n | JESD data/control/status | 0 | Final link_ready_sys boundary signal. |
| `ADC_SYNC` | `fifo_empty_sys` | output | 8 | SYS / sys_rst_n | FIFO data/control/status | 1 after convergence | Final fifo_empty_sys boundary signal. |
| `ADC_SYNC` | `fifo_full_sys` | output | 8 | SYS / sys_rst_n | FIFO data/control/status | 0 | Final fifo_full_sys boundary signal. |
| `ADC_SYNC` | `afe_idle_sys` | output | 8 | SYS / sys_rst_n | control/data | 1 | Final afe_idle_sys boundary signal. |
| `ADC_SYNC` | `pll_lock_sys` | output | 8 | SYS / sys_rst_n | control/data | 0 | Final pll_lock_sys boundary signal. |
| `ADC_SYNC` | `rx_reset_done_sys` | output | 8 | SYS / sys_rst_n | control/data | 0 | Final rx_reset_done_sys boundary signal. |
| `ADC_SYNC` | `lane_ready_sys` | output | 16 | SYS / sys_rst_n | JESD data/control/status | 0 | Final lane_ready_sys boundary signal. |
| `ADC_SYNC` | `byte_aligned_sys` | output | 16 | SYS / sys_rst_n | control/data | 0 | Final byte_aligned_sys boundary signal. |
| `ADC_SYNC` | `comma_detected_sys` | output | 16 | SYS / sys_rst_n | control/data | 0 | Final comma_detected_sys boundary signal. |
| `ADC_SYNC` | `sysref_level_sys` | output | 1 | SYS / sys_rst_n | control/data | 0 | Final sysref_level_sys boundary signal. |
| `ADC_SYNC` | `fifo_overflow_evt_sys` | output | 8 | SYS / sys_rst_n | FIFO data/control/status | 0 | Final fifo_overflow_evt_sys boundary signal. |
| `ADC_SYNC` | `data_error_evt_sys` | output | 8 | SYS / sys_rst_n | status/event | 0 | Final data_error_evt_sys boundary signal. |
| `ADC_SYNC` | `link_error_evt_sys` | output | 8 | SYS / sys_rst_n | status/event | 0 | Final link_error_evt_sys boundary signal. |
| `ADC_SYNC` | `sysref_seen_evt_sys` | output | 8 | SYS / sys_rst_n | status/event | 0 | Final sysref_seen_evt_sys boundary signal. |
| `ADC_SYNC` | `disparity_evt_sys` | output | 16 | SYS / sys_rst_n | status/event | 0 | Final disparity_evt_sys boundary signal. |
| `ADC_SYNC` | `notintable_evt_sys` | output | 16 | SYS / sys_rst_n | status/event | 0 | Final notintable_evt_sys boundary signal. |
| `ADC_SYNC` | `fifo_full_afe` | input | 8 | AFE / afe_rst_n | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_full_afe boundary signal. |
| `ADC_SYNC` | `data_error_evt_afe` | input | 8 | AFE / afe_rst_n | status/event | ignored or inactive during associated reset | Final data_error_evt_afe boundary signal. |
| `ADC_CHN` | `adc_clk` | input | 1 | ADC | clock | not applicable | Final adc_clk boundary signal. |
| `ADC_CHN` | `adc_rst_n` | input | 1 | ADC / adc_rst_n | active-low reset | assertion resets associated state | Final adc_rst_n boundary signal. |
| `ADC_CHN` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `ADC_CHN` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `ADC_CHN` | `jesd_clk` | input | 1 | JESD | clock | not applicable | Final jesd_clk boundary signal. |
| `ADC_CHN` | `jesd_rst_n` | input | 1 | source domain / associated reset | active-low reset | assertion resets associated state | Final jesd_rst_n boundary signal. |
| `ADC_CHN` | `chn_en` | input | 1 | associated domain / reset | enable/quiescence | ignored or inactive during associated reset | Final chn_en boundary signal. |
| `ADC_CHN` | `fifo_clr` | input | 1 | associated domain / reset | FIFO data/control/status | ignored or inactive during associated reset | Final fifo_clr boundary signal. |
| `ADC_CHN` | `sysref` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final sysref boundary signal. |
| `ADC_CHN` | `adc_ctl` | input | 32 | associated domain / reset | configuration/metadata | ignored or inactive during associated reset | Final adc_ctl boundary signal. |
| `ADC_CHN` | `frm_cfg` | input | 32 | associated domain / reset | configuration/metadata | ignored or inactive during associated reset | FRM_CFG register image. |
| `ADC_CHN` | `phy_rx_data` | input | 64 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_data boundary signal. |
| `ADC_CHN` | `phy_rx_charisk` | input | 8 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_charisk boundary signal. |
| `ADC_CHN` | `phy_rx_disperr` | input | 8 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_disperr boundary signal. |
| `ADC_CHN` | `phy_rx_notintable` | input | 8 | source domain / associated reset | status/event | ignored or inactive during associated reset | Final phy_rx_notintable boundary signal. |
| `ADC_CHN` | `phy_rx_reset_done` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_reset_done boundary signal. |
| `ADC_CHN` | `phy_pll_lock` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_pll_lock boundary signal. |
| `ADC_CHN` | `phy_byte_aligned` | input | 2 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_byte_aligned boundary signal. |
| `ADC_CHN` | `phy_rx_encommalign` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_rx_encommalign boundary signal. |
| `ADC_CHN` | `phy_sync_n` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_sync_n boundary signal. |
| `ADC_CHN` | `m_axis_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_tdata boundary signal. |
| `ADC_CHN` | `m_axis_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_tkeep boundary signal. |
| `ADC_CHN` | `m_axis_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_tvalid boundary signal. |
| `ADC_CHN` | `m_axis_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream | 0 | Final m_axis_tlast boundary signal. |
| `ADC_CHN` | `m_axis_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream read-side backpressure | ignored or inactive during associated reset | Pauses only local FIFO reads; acquisition and FIFO writes continue. |
| `ADC_CHN` | `link_ready_sync` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final link_ready_sync boundary signal. |
| `ADC_CHN` | `rx_fifo_empt` | output | 1 | associated domain / reset | FIFO data/control/status | 1 after convergence | Final rx_fifo_empt boundary signal. |
| `ADC_CHN` | `chn_idle_adc` | output | 1 | ADC / adc_rst_n | enable/quiescence | 1 | Final chn_idle_adc boundary signal. |
| `ADC_CHN` | `phy_pll_lock_sync` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_pll_lock_sync boundary signal. |
| `ADC_CHN` | `phy_rx_reset_done_sync` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_rx_reset_done_sync boundary signal. |
| `ADC_CHN` | `lane_ready_sync` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final lane_ready_sync boundary signal. |
| `ADC_CHN` | `phy_byte_aligned_sync` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final phy_byte_aligned_sync boundary signal. |
| `ADC_CHN` | `cgs_ready_sync` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final cgs_ready_sync boundary signal. |
| `ADC_CHN` | `rx_fifo_of` | output | 1 | associated domain / reset | FIFO data/control/status | 0 | Final rx_fifo_of boundary signal. |
| `ADC_CHN` | `link_error_sync` | output | 1 | source domain / associated reset | status/event | 0 | Final link_error_sync boundary signal. |
| `ADC_CHN` | `sysref_seen_sync` | output | 1 | associated domain / reset | status/event | 0 | Final sysref_seen_sync boundary signal. |
| `ADC_CHN` | `phy_disparity_sync` | output | 2 | source domain / associated reset | status/event | 0 | Final phy_disparity_sync boundary signal. |
| `ADC_CHN` | `phy_notintable_sync` | output | 2 | source domain / associated reset | status/event | 0 | Final phy_notintable_sync boundary signal. |
| `ADC_CHN` | `tgc_run` | input | 1 | SYS / sys_rst_n | TGC run level | ignored or inactive during associated reset | Software-held RUN level passed directly to the local ADC_TGC for its internal SYS-to-AFE synchronization. |
| `ADC_CHN` | `tgc_profile` | input | 2 | SYS / sys_rst_n | TGC stable configuration level | ignored or inactive during associated reset | Stable profile selector passed directly to the local ADC_TGC. |
| `ADC_CHN` | `tgc_up_dn` | input | 1 | SYS / sys_rst_n | TGC stable configuration level | ignored or inactive during associated reset | Stable direction passed directly to the local ADC_TGC. |
| `ADC_CHN` | `tgc_slope` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_slope boundary signal. |
| `ADC_CHN` | `tgc_up_dn_o` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_up_dn_o boundary signal. |
| `ADC_CHN` | `tgc_prof1` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_prof1 boundary signal. |
| `ADC_CHN` | `tgc_prof2` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_prof2 boundary signal. |
| `ADC_CHN` | `fifo_full_afe` | output | 1 | AFE / afe_rst_n | FIFO data/control/status | 0 | Final fifo_full_afe boundary signal. |
| `ADC_CHN` | `data_error_evt` | output | 1 | associated domain / reset | status/event | 0 | One data-error occurrence. |
| `ADC_RXD` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `ADC_RXD` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `ADC_RXD` | `jesd_clk` | input | 1 | JESD | clock | not applicable | Final jesd_clk boundary signal. |
| `ADC_RXD` | `jesd_rst_n` | input | 1 | source domain / associated reset | active-low reset | assertion resets associated state | Final jesd_rst_n boundary signal. |
| `ADC_RXD` | `chn_en` | input | 1 | associated domain / reset | enable/quiescence | ignored or inactive during associated reset | Final chn_en boundary signal. |
| `ADC_RXD` | `sysref` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final sysref boundary signal. |
| `ADC_RXD` | `phy_rx_data` | input | 64 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_data boundary signal. |
| `ADC_RXD` | `phy_rx_charisk` | input | 8 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_charisk boundary signal. |
| `ADC_RXD` | `phy_rx_disperr` | input | 8 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_disperr boundary signal. |
| `ADC_RXD` | `phy_rx_notintable` | input | 8 | source domain / associated reset | status/event | ignored or inactive during associated reset | Final phy_rx_notintable boundary signal. |
| `ADC_RXD` | `phy_rx_reset_done` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_reset_done boundary signal. |
| `ADC_RXD` | `phy_pll_lock` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_pll_lock boundary signal. |
| `ADC_RXD` | `phy_rx_encommalign` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_rx_encommalign boundary signal. |
| `ADC_RXD` | `phy_sync_n` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_sync_n boundary signal. |
| `ADC_RXD` | `rxd_data` | output | 128 | AFE / afe_rst_n | normalized receive data | 0 | One TPL8 beat: `[63:0]` Lane0, `[127:64]` Lane1; in each lane `[15:0]` is the earliest normalized 16-bit word and later words rise in bit position. May contain SYNC, ZERO, or DATA source regions. |
| `ADC_RXD` | `rxd_data_vld` | output | 1 | AFE / afe_rst_n | receive-data continuity qualification | 0 | In IDLE, qualifies the first beat of a new enabled acquisition; after entry to SYNC/DATA, low indicates a continuity error. |
| `ADC_RXD` | `rxd_ready` | output | 1 | AFE / afe_rst_n | authoritative receive-link qualification | 0 | Exactly the ADI authoritative link-ready functional level; no other diagnostic is combined, and this provides no backpressure. |
| `ADC_RXD` | `adi_sysref_error` | output | 1 | source domain / associated reset | status/event | 0 | Final adi_sysref_error boundary signal. |
| `ADC_RXD` | `adi_sysref_seen` | output | 1 | source domain / associated reset | status/event | 0 | Final adi_sysref_seen boundary signal. |
| `ADC_RXD` | `adi_link_ready` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final adi_link_ready boundary signal. |
| `ADC_RXD` | `adi_lane_ready` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final adi_lane_ready boundary signal. |
| `ADC_RXD` | `adi_cgs_ready` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final adi_cgs_ready boundary signal. |
| `ADC_RXD` | `phy_disparity` | output | 2 | source domain / associated reset | status/event | 0 | Final phy_disparity boundary signal. |
| `ADC_RXD` | `phy_notintable` | output | 2 | source domain / associated reset | status/event | 0 | Final phy_notintable boundary signal. |
| `ADC_RXD` | `link_error` | output | 1 | source domain / associated reset | software diagnostic occurrence | 0 | OR-reduced SYSREF, frame-align, lane-state, PHY disparity/not-in-table, and related retained link-fault indications; never qualifies UPK data. |
| `ADC_UPK` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `ADC_UPK` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `ADC_UPK` | `chn_en` | input | 1 | associated domain / reset | enable/quiescence | ignored or inactive during associated reset | Final chn_en boundary signal. |
| `ADC_UPK` | `rxd_data` | input | 128 | AFE / afe_rst_n | normalized receive data | ignored or inactive during associated reset | TPL8 beat with Lane0 in `[63:0]`, Lane1 in `[127:64]`, and earliest per-lane 16-bit word in the lowest slice; this order supports numeric `16'h2772` comparison and time-ordered packing. |
| `ADC_UPK` | `rxd_data_vld` | input | 1 | AFE / afe_rst_n | receive-data continuity qualification | ignored or inactive during associated reset | Required with `rxd_ready` to start from IDLE; low in SYNC or DATA is a continuity error, not a pause or stall request. |
| `ADC_UPK` | `rxd_ready` | input | 1 | AFE / afe_rst_n | receive-link qualification level | ignored or inactive during associated reset | Functional status input; loss during SYNC or DATA causes error lockout. It is not AXIS-style ready and never backpressures RXD. |
| `ADC_UPK` | `adc_ctl` | input | 32 | associated domain / reset | configuration/metadata | ignored or inactive during associated reset | Final adc_ctl boundary signal. |
| `ADC_UPK` | `frm_cfg` | input | 32 | associated domain / reset | configuration/metadata | ignored or inactive during associated reset | FRM_CFG register image. |
| `ADC_UPK` | `rx_fifo_wdat` | output | 512 | AFE / afe_rst_n | FIFO data/control/status | 0 | Preserved FIFO write-data name. |
| `ADC_UPK` | `rx_fifo_winc` | output | 1 | AFE / afe_rst_n | FIFO data/control/status | 0 | Preserved FIFO write-request name. |
| `ADC_UPK` | `data_error_evt` | output | 1 | AFE / afe_rst_n | status/event | 0 | One-cycle occurrence for synchronization mismatch or `rxd_ready`/`rxd_data_vld` loss in SYNC/DATA; FIFO capacity never feeds back into UPK. |
| `ADC_UPK` | `upk_idle` | output | 1 | AFE / afe_rst_n | enable/quiescence | 1 | Final upk_idle boundary signal. |
| `async_fifo` | `wclk` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final wclk boundary signal. |
| `async_fifo` | `rclk` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final rclk boundary signal. |
| `async_fifo` | `wclr` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final wclr boundary signal. |
| `async_fifo` | `rclr` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final rclr boundary signal. |
| `async_fifo` | `rst_n` | input | 1 | associated domain / reset | active-low reset | assertion resets associated state | Final rst_n boundary signal. |
| `async_fifo` | `winc` | input | 1 | associated domain / reset | write request | ignored or inactive during associated reset | A full request causes overflow; `WC=0` rejects that write, while `WC=1` continues it and may overwrite unread data. |
| `async_fifo` | `rinc` | input | 1 | associated domain / reset | control/data | ignored or inactive during associated reset | Final rinc boundary signal. |
| `async_fifo` | `wdata` | input | 512 | associated domain / reset | control/data | ignored or inactive during associated reset | Final wdata boundary signal. |
| `async_fifo` | `rdata` | output | 512 | associated domain / reset | control/data | 0 | Final rdata boundary signal. |
| `async_fifo` | `full` | output | 1 | associated domain / reset | FIFO real-time status | 0 | Current write-side full level; selected WC behavior determines whether a simultaneous write is rejected or continued. |
| `async_fifo` | `empty` | output | 1 | associated domain / reset | control/data | 1 after convergence | Final empty boundary signal. |
| `async_fifo` | `overflow` | output | 1 | associated domain / reset | FIFO overflow occurrence | 0 | Asserted for `winc & full`; software retains the occurrence in W1C FIFO_OF. |
| `async_fifo` | `underflow` | output | 1 | associated domain / reset | control/data | 0 | Final underflow boundary signal. |
| `async_fifo` | `wlevel` | output | 10 | associated domain / reset | control/data | 0 | Final wlevel boundary signal. |
| `async_fifo` | `rlevel` | output | 10 | associated domain / reset | control/data | 0 | Final rlevel boundary signal. |
| `ADC_PKT` | `adc_clk` | input | 1 | ADC | clock | not applicable | Final adc_clk boundary signal. |
| `ADC_PKT` | `adc_rst_n` | input | 1 | ADC / adc_rst_n | active-low reset | assertion resets associated state | Final adc_rst_n boundary signal. |
| `ADC_PKT` | `chn_en` | input | 1 | ADC / adc_rst_n | synchronized packet-run source | ignored or inactive during reset | Synchronized channel enable sampled into `pkt_run_shadow` only while IDLE or at the 256th-handshake completion boundary; BUSY ignores changes. |
| `ADC_PKT` | `rx_fifo_rdat` | input | 512 | ADC / adc_rst_n | FIFO data/control/status | ignored or inactive during associated reset | Preserved FWFT read-data name. |
| `ADC_PKT` | `rx_fifo_empty` | input | 1 | associated domain / reset | FIFO data/control/status | ignored or inactive during associated reset | Final rx_fifo_empty boundary signal. |
| `ADC_PKT` | `rx_fifo_rlevel` | input | 10 | ADC / adc_rst_n | FIFO data/control/status | ignored or inactive during associated reset | Preserved occupied-level name. |
| `ADC_PKT` | `rx_fifo_rinc` | output | 1 | ADC / adc_rst_n | FIFO pop | 0 | Asserted only for an AXIS handshake in an active block. |
| `ADC_PKT` | `m_axis_tdata` | output | 512 | ADC / adc_rst_n | AXI4-Stream data | 0 | Current FIFO head entry; stable with TVALID during backpressure. |
| `ADC_PKT` | `m_axis_tkeep` | output | 64 | ADC / adc_rst_n | AXI4-Stream byte qualifier | 0 | All ones for every valid transfer; stable during backpressure. |
| `ADC_PKT` | `m_axis_tvalid` | output | 1 | ADC / adc_rst_n | AXI4-Stream valid | 0 | Asserted for each entry of an admitted block and held until handshake. |
| `ADC_PKT` | `m_axis_tlast` | output | 1 | ADC / adc_rst_n | AXI4-Stream block boundary | 0 | Asserted only with the 256th entry of an admitted block and held during backpressure. |
| `ADC_PKT` | `m_axis_tready` | input | 1 | ADC / adc_rst_n | AXI4-Stream read-side backpressure | ignored or inactive during associated reset | Pauses only FIFO read-side handshakes; it does not pause AFE acquisition or FIFO writes. |
| `ADC_PKT` | `chn_idle` | output | 1 | ADC / adc_rst_n | enable/quiescence | 1 | High exactly when no 256-entry block is active. |
| `CHN_SYNC` | `adc_clk` | input | 1 | ADC | clock | not applicable | Final adc_clk boundary signal. |
| `CHN_SYNC` | `adc_rst_n` | input | 1 | ADC / adc_rst_n | active-low reset | assertion resets associated state | Final adc_rst_n boundary signal. |
| `CHN_SYNC` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `CHN_SYNC` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `CHN_SYNC` | `jesd_clk` | input | 1 | JESD | clock | not applicable | Final jesd_clk boundary signal. |
| `CHN_SYNC` | `jesd_rst_n` | input | 1 | source domain / associated reset | active-low reset | assertion resets associated state | Final jesd_rst_n boundary signal. |
| `CHN_SYNC` | `phy_rx_reset_done` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_rx_reset_done boundary signal. |
| `CHN_SYNC` | `phy_rx_reset_done_sync` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_rx_reset_done_sync boundary signal. |
| `CHN_SYNC` | `phy_pll_lock` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_pll_lock boundary signal. |
| `CHN_SYNC` | `phy_pll_lock_sync` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final phy_pll_lock_sync boundary signal. |
| `CHN_SYNC` | `phy_byte_aligned` | input | 2 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final phy_byte_aligned boundary signal. |
| `CHN_SYNC` | `phy_byte_align_sync` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final phy_byte_align_sync boundary signal. |
| `CHN_SYNC` | `sysref_error` | input | 1 | associated domain / reset | status/event | ignored or inactive during associated reset | Final sysref_error boundary signal. |
| `CHN_SYNC` | `sysref_seen` | input | 1 | associated domain / reset | status/event | ignored or inactive during associated reset | Final sysref_seen boundary signal. |
| `CHN_SYNC` | `sysref_seen_sync` | output | 1 | associated domain / reset | status/event | 0 | Final sysref_seen_sync boundary signal. |
| `CHN_SYNC` | `link_ready` | input | 1 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final link_ready boundary signal. |
| `CHN_SYNC` | `link_ready_sync` | output | 1 | source domain / associated reset | JESD data/control/status | 0 | Final link_ready_sync boundary signal. |
| `CHN_SYNC` | `lane_ready` | input | 2 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final lane_ready boundary signal. |
| `CHN_SYNC` | `lane_ready_sync` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final lane_ready_sync boundary signal. |
| `CHN_SYNC` | `cgs_ready` | input | 2 | source domain / associated reset | JESD data/control/status | ignored or inactive during associated reset | Final cgs_ready boundary signal. |
| `CHN_SYNC` | `cgs_ready_sync` | output | 2 | source domain / associated reset | JESD data/control/status | 0 | Final cgs_ready_sync boundary signal. |
| `CHN_SYNC` | `phy_disparity` | input | 2 | source domain / associated reset | status/event | ignored or inactive during associated reset | Final phy_disparity boundary signal. |
| `CHN_SYNC` | `phy_disparity_sync` | output | 2 | source domain / associated reset | status/event | 0 | Final phy_disparity_sync boundary signal. |
| `CHN_SYNC` | `phy_notintable` | input | 2 | source domain / associated reset | status/event | ignored or inactive during associated reset | Final phy_notintable boundary signal. |
| `CHN_SYNC` | `phy_notintable_sync` | output | 2 | source domain / associated reset | status/event | 0 | Final phy_notintable_sync boundary signal. |
| `CHN_SYNC` | `link_error` | input | 1 | source domain / associated reset | status/event | ignored or inactive during associated reset | Final link_error boundary signal. |
| `CHN_SYNC` | `link_error_sync` | output | 1 | source domain / associated reset | status/event | 0 | Final link_error_sync boundary signal. |
| `CHN_SYNC` | `upk_idle` | input | 1 | AFE / afe_rst_n | enable/quiescence | ignored or inactive during associated reset | Final upk_idle boundary signal. |
| `CHN_SYNC` | `upk_idle_sync` | output | 1 | associated domain / reset | control/data | 1 | Final upk_idle_sync boundary signal. |
| `CHN_SYNC` | `tgc_idle` | input | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | ignored or inactive during associated reset | Handshake/action quiescence. |
| `CHN_SYNC` | `tgc_idle_sync` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 1 | Final tgc_idle_sync boundary signal. |
| `ADC_TGC` | `afe_clk` | input | 1 | AFE | clock | not applicable | Final afe_clk boundary signal. |
| `ADC_TGC` | `afe_rst_n` | input | 1 | AFE / afe_rst_n | active-low reset | assertion resets associated state | Final afe_rst_n boundary signal. |
| `ADC_TGC` | `chn_en` | input | 1 | associated domain / reset | enable/quiescence | ignored or inactive during associated reset | Final chn_en boundary signal. |
| `ADC_TGC` | `tgc_run` | input | 1 | SYS / sys_rst_n | TGC run level | ignored or inactive during associated reset | Software-held RUN level; ADC_TGC internally synchronizes it into AFE and launches only on a synchronized 0-to-1 transition. |
| `ADC_TGC` | `profile_sel` | input | 2 | SYS / sys_rst_n | TGC stable configuration level | ignored or inactive during associated reset | Stable before RUN rises and while RUN remains 1; captured for one launch. |
| `ADC_TGC` | `up_dn` | input | 1 | SYS / sys_rst_n | TGC stable configuration level | ignored or inactive during associated reset | Stable before RUN rises and while RUN remains 1; captured for one launch. |
| `ADC_TGC` | `tgc_idle` | output | 1 | AFE / afe_rst_n | TGC command/configuration/pin | 1 | Command/action quiescence. |
| `ADC_TGC` | `tgc_slope` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_slope boundary signal. |
| `ADC_TGC` | `tgc_up_dn` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_up_dn boundary signal. |
| `ADC_TGC` | `tgc_prof1` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_prof1 boundary signal. |
| `ADC_TGC` | `tgc_prof2` | output | 1 | AFE / afe_rst_n | TGC handshake/configuration/pin | 0 | Final tgc_prof2 boundary signal. |

## 5. Functional Behavior

### 5.0 FSM contract

| FSM | Owner Module | Reset State | State | Meaning |
| --- | --- | --- | --- | --- |
| `UPK_FSM` | `ADC_UPK` | `IDLE` | `IDLE` | Disabled, awaiting an initial enable, or locked after error until disable then re-enable. |
| `UPK_FSM` | `ADC_UPK` | `IDLE` | `SYNC` | Validate the first sync-word segment, skip the configured leading ZERO region, and validate the second sync-word segment. |
| `UPK_FSM` | `ADC_UPK` | `IDLE` | `DATA` | Schedule valid and periodic ZERO regions, form natural-order candidates, and admit complete candidates only. |
| `AXIS_BLOCK_FSM` | `ADC_PKT` | `IDLE` | `IDLE` | No admitted 256-entry output block. |
| `AXIS_BLOCK_FSM` | `ADC_PKT` | `IDLE` | `BUSY` | One admitted block is active until 256 FIFO entries handshake. |
| `TGC_ACTION_FSM` | `ADC_TGC` | `IDLE` | `IDLE` | Wait for one synchronized RUN 0-to-1 transition. |
| `TGC_ACTION_FSM` | `ADC_TGC` | `IDLE` | `APPLY` | Edge N applies profile/direction, slope low. |
| `TGC_ACTION_FSM` | `ADC_TGC` | `IDLE` | `SLOPE` | Edge N+1 drives slope high. |

| FSM | Current State | Event / Condition | Next State | Observable Action / Error |
| --- | --- | --- | --- | --- |
| `UPK_FSM` | any | `chn_en=0` | `IDLE` | Clear all context without error and authorize one later enabled restart. |
| `UPK_FSM` | `IDLE` | authorized restart, `chn_en=1`, `rxd_ready=1`, and `rxd_data_vld=1` | `SYNC` | Accept this beat as the first beat of first-segment synchronization-word validation. |
| `UPK_FSM` | `IDLE` | error lockout without an observed disable/re-enable | `IDLE` | Write nothing and do not restart even if `rxd_ready` recovers. |
| `UPK_FSM` | `SYNC` or `DATA` | `rxd_ready=0` or `rxd_data_vld=0` | `IDLE` | Treat as acquisition discontinuity: write nothing that cycle, clear all context, emit one data error, and lock out restart until disable then re-enable. |
| `UPK_FSM` | `SYNC` | any checked synchronization word is not `16'h2772` | `IDLE` | Write nothing, clear all context, emit one data error, and lock out restart until disable then re-enable. |
| `UPK_FSM` | `SYNC` | four first-segment beats match | `SYNC` | Skip the configured leading ZERO beats without content comparison. |
| `UPK_FSM` | `SYNC` | four second-segment beats match after the leading ZERO region | `DATA` | Synchronization succeeds; initialize DATA-region scheduling and packing. |
| `UPK_FSM` | `DATA` | qualified valid-region beat | `DATA` | Advance region counting and contribute the beat to natural-order 512-bit packing. |
| `UPK_FSM` | `DATA` | qualified periodic-ZERO beat | `DATA` | Advance region timing only; do not advance FIFO packing or write FIFO. |
| `AXIS_BLOCK_FSM` | `IDLE` | `pkt_run_shadow=1` and FIFO occupied level at least 256 | `BUSY` | Admit one data-only block and reserve its 256 FIFO entries. |
| `AXIS_BLOCK_FSM` | `IDLE` | FIFO occupied level below 256 or `pkt_run_shadow=0` | `IDLE` | Do not start and do not emit a partial tail block; retain FIFO contents unless software clears them. |
| `AXIS_BLOCK_FSM` | `BUSY` | handshake index below 255 | `BUSY` | Transfer and pop one FIFO entry; ignore synchronized `chn_en` changes. |
| `AXIS_BLOCK_FSM` | `BUSY` | handshake index 255 | `IDLE` | Assert TLAST, complete the block, and update `pkt_run_shadow` from synchronized `chn_en` at this boundary. |
| `TGC_ACTION_FSM` | `IDLE` | synchronized RUN 0-to-1 transition and enabled | `APPLY` | Capture the stable profile/direction bundle and consume this launch edge once. |
| `TGC_ACTION_FSM` | `APPLY` | next AFE edge | `SLOPE` | Assert slope. |
| `TGC_ACTION_FSM` | `SLOPE` | next AFE edge while enabled | `IDLE` | Drive slope low, retain profile/direction, and become idle immediately; synchronized RUN remaining 1 does not retrigger. |
| `TGC_ACTION_FSM` | `APPLY` or `SLOPE` | enable low before success | `IDLE` | Cancel the in-flight action, clear all TGC pins, and become idle immediately without modifying RUN. |
| `TGC_ACTION_FSM` | `IDLE` | enable low | `IDLE` | Keep pins low; RUN must still return to 0 before any later 0-to-1 launch. |

### 5.1 Enable, validity, error, and recovery

`chn_en` owns channel activity. `ADC_CHN` synchronizes it locally into ADC and AFE; `ADC_SYNC` never handles enable. `ADC_RXD.rxd_ready` is exactly the ADI authoritative link-ready functional level in AFE, without combination of SYSREF, frame-align, lane-state, disparity, not-in-table, or other diagnostic indications. It is not a downstream ready signal, never backpressures ADI, and does not form a ready/valid transfer pair with `rxd_data_vld`. Those detailed ADI/PHY indications are OR-reduced into the existing link-error occurrence path for software only and never feed the UPK functional qualification.

`ADC_RXD` normalizes lane/byte/word order and directly presents each official 128-bit TPL8 beat. `rxd_data[63:0]` is Lane0 and `rxd_data[127:64]` is Lane1. Within each 64-bit lane, `[15:0]` is the earliest normalized 16-bit word, followed in time by `[31:16]`, `[47:32]`, and `[63:48]`. The beat may contain any source region, including synchronization words, zeros, or ADC data; RXD does not inspect or discard content. RXD owns any byte/word reordering required at the real ADI/PHY boundary so every synchronization word is numerically visible to UPK as `16'h2772`.

Reset or `chn_en=0` clears UPK context and authorizes the next enable attempt without error. On one newly authorized enable, IDLE waits until `rxd_ready=1` and `rxd_data_vld=1`, then consumes that same beat as the first SYNC beat. From that transition until software stop, acquisition is continuous: either `rxd_ready=0` or `rxd_data_vld=0` in SYNC/DATA is a receive discontinuity. That discontinuity or a synchronization mismatch writes nothing for the failing cycle, produces one `data_error_evt`, clears all UPK context, and returns to IDLE. Recovery is deliberately not automatic: UPK remains locked in IDLE until it observes `chn_en=0` and a later `chn_en=1`. No additional timeout exists because the first missing valid cycle is already an error. Channel disable has priority over these error conditions and performs a clean, non-error teardown. FIFO full/overflow never changes UPK state, counters, packing, or DATA_ERROR behavior.

There is no channel-local FIFO-validity state and AXIS carries no error sideband. Software observes synchronization/receive-continuity errors through the existing SYS-domain W1C `ADC_PD.DATA_ERROR` bits; FIFO capacity/write failures and diagnostic link failures remain visible through `FIFO_FULL`, `FIFO_OF`, and `LINK_ERROR`. The same physical fault may set DATA_ERROR and LINK_ERROR concurrently. None of these diagnostics gates UPK or ADC_PKT. FIFO_FULL is the real-time stop condition and may be transient; FIFO_OF is sticky confirmation that a write was attempted while full. Observing either invalidates the current enable-to-stop/clear acquisition interval and requires software stop, even though UPK continues producing complete 512-bit candidates until enable is removed.

Recovery is disable, wait `AFE_IDLE`, assert/hold `FIFO_CLR` while AFE/ADC clocks run, wait empty/status convergence, release clear, relink/reconfigure, enable. Clearing an active 256-entry AXIS block is illegal. Common asynchronous FIFO-reset release remains an integration risk.

### 5.2 UPK, formatting, and admission

An accepted UPK input beat is 128 bits: two lanes × eight bytes, or four normalized 16-bit words per lane. Four consecutive DATA-region beats form one 512-bit candidate containing 32 × 16-bit channel samples. Time order is low-bit first: beat0 maps to candidate `[127:0]`, beat1 to `[255:128]`, beat2 to `[383:256]`, and beat3 to `[511:384]`. Combined with the frozen per-lane order, this mapping is the complete RXD-to-FIFO data-order contract. Numeric zero inside a valid DATA region remains data; a scheduled ZERO region is identified only by region counting and contributes no FIFO entry.

Let N=`DEC_M[7:2]`, f=`DEC_M[1:0]`; the software-legal contract is decimation N=1..63 and DDC N=2..63. Software must not enable acquisition with N outside those ranges. Hardware need not sanitize, reject, diagnose, or define behavior for an illegal configuration, and illegal cases are excluded from acceptance. Because each 128-bit beat contains four 16-bit words per lane, DATA-region scheduling uses these integral beat counts:

| Mode | f | Valid beats | ZERO beats | Period beats |
| --- | ---: | ---: | ---: | ---: |
| dec | 0 | 4 | `4N-4` | `4N` |
| dec | 1 | 16 | `16N-12` | `16N+4` |
| dec | 2 | 8 | `8N-4` | `8N+4` |
| dec | 3 | 16 | `16N-4` | `16N+12` |
| DDC | 0 | 8 | `4N-8` | `4N` |
| DDC | 1 | 32 | `16N-28` | `16N+4` |
| DDC | 2 | 32 | `8N-12` | `8N+20` |
| DDC | 3 | 32 | `16N-20` | `16N+12` |

`SMP_MODE=0/1/2` selects direct, decimation, and DDC; reserved value 3 is sanitized to 0 and behaves as direct mode. Direct mode is RAW/pure ADC: after the second synchronization segment, every continuous 128-bit input beat belongs to DATA, there is no periodic ZERO region, and every four beats form one 512-bit candidate. `FRAME_FMT=0` arithmetic-right-aligns high valid p bits of the normalized two's-complement word and sign-extends; 1 preserves all 16 bits. `SMP_PREC=00/01/10` means p=10/12/14; reserved value 11 is sanitized to 00 and therefore uses p=10. Only encodings identified by this specification as reserved default to zero; source-defined valid encodings retain their documented meaning.

SYNC validates two complete synchronization segments. Each 128-bit beat contains four normalized 16-bit words from each of two lanes. Therefore each per-lane `sync_word ×16` segment occupies exactly four consecutive valid beats; all 32 words across those four beats must equal `16'h2772`. UPK checks the complete first segment, skips the configured leading ZERO beats, then checks the complete second segment. It enters DATA only after both segments match. No separate PREFIX or ZERO FSM state exists.

Direct, decimation, and DDC all use the same natural-order candidate path. The UPK does not identify or pair DDC I/Q data. Every complete candidate directly produces one FIFO write request without observing FIFO full, level, free-space, or overflow status. FIFO capacity and selected WC behavior never change UPK scheduling, packing, state, or DATA_ERROR behavior. Partial candidates never produce a write request. In decimation/DDC DATA operation, periodic ZERO-region beats advance source-region counting but never advance the four-beat FIFO packer and never write zeros. Direct mode has no periodic ZERO. Consequently each requested FIFO item is one complete 512-bit candidate, while software observation of FIFO_FULL or FIFO_OF invalidates the acquisition interval under either WC choice.

### 5.3 FIFO and idle

Each FIFO is 512 × 512-bit FWFT. FIFO clear or either data-domain reset discards all contents. Clear does not clear UPK context; legal software already disabled and waited idle. Clear/reset wins a same-edge pending FIFO sample. The final RTL may select either supported full-write behavior: with `WC=0`, `winc=1 && full=1` rejects that write and asserts overflow; with `WC=1`, the same condition performs the write, may overwrite unread data, and asserts overflow. The WC selection is an implementation/dependency choice, not an ADC_TOP architectural correctness premise. `FIFO_FULL` is the synchronized real-time early-or-simultaneous software stop condition and may be transient. `ADC_PD.FIFO_OF` is the W1C sticky confirmation that a full write was attempted and preserves evidence after FULL deasserts.

Software observing either FIFO_FULL or FIFO_OF treats the current acquisition interval as erroneous under either WC choice and immediately stops/sets `AFE_EN=0`. Hardware itself does not stop UPK or PKT. If only FULL was observed and no overflow occurred, software still uses the same recovery: wait idle, assert `FIFO_CLR` while clocks run, wait empty/status convergence, release clear, clear W1C `FIFO_OF` if set, and enable again. Data from an interval that asserted FULL or FIFO_OF is not a complete continuous acquisition record.

`AFE_IDLE[n]=1` requires disabled local consumers, no accepted RXD beat, UPK quiescent, AXIS block control quiescent, and no local TGC command in flight with all TGC pins at zero. FIFO empty is excluded.

### 5.4 Data-only AXIS blocks

`ADC_PKT` is a FIFO reader and AXIS block controller with exactly two states, IDLE and BUSY. It has no link-status input or link-based policy. Synchronized `chn_en` is the packet-run source. Reset clears `pkt_run_shadow`; while IDLE it refreshes the shadow from synchronized `chn_en` before making an admission decision, and the 256th-handshake completion boundary samples it before any following admission. The shadow is frozen throughout BUSY. Thus an observed stop in IDLE cannot admit a new block, and an observed stop during BUSY takes effect at that block's completion boundary. Admission requires IDLE, `pkt_run_shadow=1`, and FIFO occupied level at least 256, and reserves exactly 256 entries. FIFO occupancy below 256 never starts a block. Disable does not clear retained FIFO contents.

Every admitted block contains exactly 256 FIFO entries and no header. While BUSY, `TVALID` presents each reserved FIFO entry until it handshakes; each successful handshake transfers and removes one 512-bit FIFO entry in FIFO order. `TKEEP` is all ones for every valid beat. `TLAST` is asserted only with the 256th transferred entry. While `m_axis_tready=0`, `TVALID`, `TDATA`, `TKEEP`, and `TLAST` remain stable and the FIFO read side pauses. This AXIS backpressure does not pause AFE acquisition: UPK continues requesting every complete write, including requests while full; the selected WC behavior is contained within the FIFO. FIFO data is not modified by `ADC_PKT`.

There is no packet metadata, sequence, header, CRC, partial tail block, or AXIS error sideband. Software stop may leave FIFO contents at any occupancy because AXIS backpressure and ongoing acquisition are independent; after `pkt_run_shadow` observes stop, none of those retained entries starts a new block. In particular, 1..255 entries are never emitted as a tail. A later enable without `FIFO_CLR` may immediately admit an already-complete retained block or append new accepted entries in FIFO order until the 256-entry threshold is reached. This is start/stop behavior, not a hardware pause/resume facility. If software must isolate two acquisitions, it uses disable→idle→`FIFO_CLR`→enable and thereby explicitly discards the residue. A UPK continuity error does not stop an already active block or prevent later block admission; software uses `ADC_PD.DATA_ERROR` and the retained diagnostics to determine continuity and data usability. Because ZERO regions produce no FIFO entries, high decimation/DDC ratios can increase the time required to accumulate the 256 entries needed for admission.

### 5.5 TGC

Each channel independently stores SYS-domain profile selector, up/down, and RUN. Selector chooses one of four SPI-owned AC9810 internal profiles; tables may differ across devices. ADC_REG holds these levels and does not pass them through ADC_SYNC.

When RUN=0, a full-word write may update profile/direction. Software establishes those fields before launching. A write that raises RUN from 0 to 1 while enabled freezes the stored profile/direction and holds visible RUN high. While RUN=1, writes that also present RUN=1 retain the existing profile/direction; a write with RUN=0 clears/rearms RUN and may update profile/direction for the next launch. Each `ADC_TGC` internally synchronizes RUN into AFE and detects the synchronized 0-to-1 transition exactly once. Completion returns the action FSM to IDLE but does not clear RUN and cannot retrigger while synchronized RUN remains 1. A RUN rise while disabled is silently rejected as an action launch; software still returns RUN to 0 before attempting a later launch. AFE reset or disable/re-enable while RUN remains 1 does not create a new launch; a synchronized low must be observed before the next synchronized 0-to-1 is armed. There is no hardware command/done event CDC, hardware RUN clear, software busy, cfg_load, cfg_valid, group run, target/reentry error, or done sticky.

Each `ADC_CHN` contains exactly one `ADC_TGC`, and only that module owns the channel's RUN synchronization/edge detection and action FSM. `ADC_REG` owns no FSM and RUN changes only through software write or reset. Reset/disable wins an in-flight action. Completion means FPGA pin action completion only, not AC9810 conversion and not a software-visible done event.

The action has three phases. On acceptance of one synchronized RUN rising edge at AFE edge N, `ADC_TGC` captures profile/direction and holds slope low. At edge N+1 it drives slope high. At edge N+2 it drives slope low and is immediately idle while retaining the successful profile/direction pins. Disable during APPLY or SLOPE cancels only that in-flight action: all TGC pins clear and the controller becomes idle on that same sampled edge. Disable while already IDLE clears/keeps pins low. Neither success nor cancellation changes RUN or emits a returned event.

### 5.6 AXI4-Lite registers

All completed accesses return OKAY. WSTRB is ignored; full WDATA is processed and software must use `4'hf`. Reserved/unmapped reads return 0; writes do nothing. W1C hardware set wins same-cycle clear. Static format/region fields update only when `AFE_EN=0 && AFE_IDLE=8'hff`; unsafe writes retain them and return OKAY.

`ADC_PD`, `LANE_PD`, and `SYSREF_STA.SYSREF[7:0]` are sticky occurrence fields with the stated W1C/set-wins priority. `SYSREF_STA.SYSREF_COUNT` increments once in a SYS cycle when one or more per-channel SYSREF-seen occurrences arrive in that cycle; simultaneous channel occurrences count as one, the 16-bit count wraps modulo 65536, and only SYS reset clears it. `SYSREF_STA.SYSREF_LEVEL`, `ADC_STA`, `PHY_STA`, `LANE_STA`, and `COMMA_STA` are synchronized real-time levels rather than sticky history.

| Address | Register | Fields | Access / Reset |
| ---: | --- | --- | --- |
| `0x0000` | `ADC_CTL` | 7:0 AFE_EN; 15:8 FIFO_CLR; 24:16 reserved; 25 FRAME_FMT; 27:26 SMP_MODE; 29:28 reserved; 31:30 SMP_PREC | RW/0 |
| `0x0004` | `FRM_CFG` | 7:0 DEC_M; 9:8 DEC_DEL_MODE; 31:10 reserved | RW/0 |
| `0x0008+4n` | `TGC_CHn`, n=0..7 | 0 RUN; 2:1 PROFILE_SEL; 3 UP_DN; 31:4 reserved | RW/reset0; RUN is software-cleared and launches only on 0→1 |
| `0x0028` | `ADC_STA` | 7:0 LINK_READY; 15:8 FIFO_EMPTY; 23:16 FIFO_FULL; 31:24 AFE_IDLE | RO/0 |
| `0x002c` | `ADC_PD` | 7:0 FIFO_OF; 15:8 DATA_ERROR; 23:16 LINK_ERROR; 31:24 reserved | W1C/0 |
| `0x0030` | `PHY_STA` | 7:0 LINK_READY; 15:8 reserved; 23:16 PLL_LOCK; 31:24 RX_RESET_DONE | RO/0 |
| `0x0034` | `SYSREF_STA` | 7:0 SYSREF; 8 SYSREF_LEVEL; 15:9 reserved; 31:16 SYSREF_COUNT | mixed W1C/RO, reset0 |
| `0x0038` | `LANE_STA` | 15:0 LANE_READY; 31:16 BYTE_ALIGNED | RO/0 |
| `0x003c` | `COMMA_STA` | 15:0 COMMA_DETECTED; 31:16 reserved | RO/0 |
| `0x0040` | `LANE_PD` | 15:0 DISPARITY; 31:16 NOTINTABLE | W1C/0 |

No field name carries `_PD`. There is no sequence, DATA_DROP, group TGC, TGC error, software busy/done sticky, cfg_load, or cfg_valid.

## 6. Constraints And Acceptance

| Requirement | Value / Rule | Basis | Acceptance Observation |
| --- | --- | --- | --- |
| Channels | Exactly 8. | User requirement. | Eight independent public paths. |
| JESD | M16/L2/N'16/S1/F16/K16; pinned ADI core uses TPL8 and 32 device beats per multiframe. | AC9810 evidence and pinned-source research. | Official 128-bit data and configured multiframe behavior match at the real-IP boundary. |
| RXD functional beat | Each valid TPL8 128-bit beat is normalized and passed directly; it contains two lanes × eight bytes = four 16-bit words per lane. | User decision. | Every valid beat preserves the lane/byte/word order required for numeric `16'h2772` comparison. |
| RXD qualification | `rxd_ready` is exactly the ADI authoritative link-ready functional level, not ready/valid backpressure and not a composite of diagnostics. | User decision. | UPK never controls RXD flow; other PHY/JESD indications affect software diagnostics only. |
| RXD data order | `rxd_data[63:0]` is Lane0 and `[127:64]` is Lane1; within each lane the earliest normalized 16-bit word occupies the lowest slice and later words rise in bit position. | User decision. | Real-IP mapping exposes synchronization words as numeric `16'h2772` and preserves the frozen lane/time order. |
| Synchronization | IDLE/SYNC/DATA only; SYNC checks two per-lane `sync_word ×16` segments, each exactly four valid 128-bit beats, with every word equal to `16'h2772`. | User decision and AFE sync-word configuration. | Any of the 64 checked lane words mismatching rejects synchronization and reports one data error. |
| Validity | IDLE waits for `rxd_ready && rxd_data_vld`; after entry to SYNC/DATA, either signal low is an immediate continuity error and locks restart until disable then re-enable. No business pause or additional timeout exists. | User decision. | Every loss position writes nothing that cycle, clears context, reports one DATA_ERROR occurrence, and requires the named restart sequence. |
| Candidate | 512 bits, 32 × 16-bit samples, four consecutive DATA-region 128-bit beats; beat0/1/2/3 map to `[127:0]`/`[255:128]`/`[383:256]`/`[511:384]`. | User decision/evidence. | Complete writes only, exact time order is preserved, and ZERO beats never advance packing. |
| DDC | Natural FIFO order with no I/Q identification or paired admission. | User decision. | DDC candidates use the same one-entry admission rule as direct/decimation. |
| ZERO compression | Consume scheduled 128-bit ZERO beats and advance region counting only; produce no FIFO entry and do not advance four-beat packing. | User decision. | Every ZERO-region beat has no FIFO write, and the following DATA beats retain word order. |
| UPK/FIFO decoupling | Every complete candidate requests one FIFO write; UPK has no full/level/overflow input and capacity never changes UPK behavior or DATA_ERROR. | User decision. | Full and non-full cases have identical UPK state, counters, candidate order, and write-request behavior. |
| FIFO | 512 × 512 FWFT; implementation may choose `WC=0` reject-on-full or `WC=1` write-continue-on-full, and both must report a full write as overflow. | User decision. | Under WC=0 the full write is rejected; under WC=1 it continues with possible overwrite; both set the same overflow occurrence. |
| AXIS block | Data-only block of exactly 256 FIFO entries; no header or CRC. | User decision. | Exactly 256 handshakes per admission; only the final handshake has TLAST. |
| Block admission | ADC_PKT is IDLE/BUSY; new block requires IDLE, `pkt_run_shadow=1`, and FIFO occupied level at least 256. There is no link-ready input or gate. | User decision. | No admission below threshold or after run shadow clears; link changes have no effect on FIFO output. |
| Packet run shadow | Synchronized `chn_en` updates the shadow only in IDLE or at the 256th-handshake completion boundary; BUSY ignores changes. | User decision. | Stop never truncates an active block and prevents the following admission at the completion boundary. |
| Stop residue | After the active block completes, stop starts no new block. Any occupancy may remain under backpressure; 1..255 entries are specifically retained without a tail. Later enable may drain retained full blocks or join sub-256 residue with new data, unless software clears to isolate runs. | User decision and backpressure consequence. | No post-stop admission or tail transfer/TLAST; retained and newly appended entries preserve FIFO order. |
| Backpressure | AXIS TREADY pauses only FIFO reads; it does not pause AFE acquisition or FIFO writes. | AXI contract and user decision. | Arbitrary read-side stalls preserve AXIS values/order while write-side acquisition continues until normal capacity handling applies. |
| Clear | Active-block clear illegal; disable→idle→clear. | User decision. | Legal recovery has no underflow/leak. |
| Diagnostics | No AXIS error sideband; FIFO_OF, DATA_ERROR, LINK_ERROR and all retained PHY/JESD status remain software-visible. SYSREF/frame-align/lane-state/disparity/not-in-table and related faults contribute to link-error occurrence only. | User decision. | Diagnostic sources set their W1C status without gating data; one fault may set DATA_ERROR and LINK_ERROR concurrently. |
| SYSREF diagnostics | Per-channel SYSREF bits are W1C sticky; count increments once for any nonempty same-SYS-cycle event vector, wraps modulo 65536, and clears only on SYS reset; SYSREF_LEVEL is live. | Preserved register behavior. | Single- and multi-channel simultaneous events, wrap, reset, W1C/set priority, and live-level behavior match exactly. |
| FIFO stop/recovery | FIFO_FULL is a possibly transient real-time stop condition; sticky FIFO_OF confirms that a full write occurred. Software observing either invalidates the interval and sets enable low; hardware does not self-gate. | User decision. | FULL-only and FIFO_OF cases both use stop/disable→idle→FIFO clear→FIFO_OF clear if set→enable; every full write remains evidenced by FIFO_OF. |
| TGC action | RUN rise accepted at N, slope high N+1, slope low/immediate idle N+2; in-flight disable cancels immediately; no returned done event. | User decision. | Pins and idle timing are exact; success/cancel never changes software RUN. |
| TGC CDC | ADC_TGC internally synchronizes the software-held RUN level and detects one 0→1; profile/direction are stable bundled levels and ADC_SYNC has no TGC ports. | User decision. | RUN held at 1 triggers once only; AFE reset or disable/re-enable cannot synthesize another launch; software 1→0 rearms and a later 0→1 triggers once. |
| TGC pins | setup>3ns, hold>2ns vs AC9810 ADC_CLK; slope rate≤ADC_CLK. | Device evidence. | Integration timing/board budget passes. |
| Static writes | Legal/stable; update disabled+idle only. | User decision. | Unsafe write holds prior value. |
| Reserved encodings | SMP_MODE 3→direct/0, SMP_PREC 11→p10/00, DEC_DEL_MODE 11→delete-0/00; other source-defined valid values are unchanged. | User decision. | Each named reserved value has the same boundary behavior as its zero encoding. |
| AXI writes | Full-word, WSTRB ignored, OKAY. | Preserved contract. | All strobe values behave identically. |
| Idle | Disabled and UPK/packet/TGC quiescent; FIFO empty excluded. | User decision. | Retained FIFO can coexist with idle. |
| Event CDC | Supported bursts may coalesce to at least one sticky occurrence. | Existing contract. | At least one SYS set unless reset. |
| Intended acquisition points | Continuous acquisition until software stop; RAW validation at 5 MHz and formal M24 DDC operation at 20/30 MHz are system-level scenarios. | Detector system specification. | Boundary throughput and accumulation behavior are checked for each named scenario without assuming an unconditional 160 MHz device clock. |

Acceptance shall cover official TPL8 128-bit behavior at the pinned real-IP boundary; authoritative ADI-only `rxd_ready`; software-only diagnostic OR sources and concurrent DATA_ERROR/LINK_ERROR; Lane0/1 placement, earliest-word-low per-lane ordering, and numeric `16'h2772` visibility; IDLE waiting for simultaneous ready/valid; all four beats and 32 words of each `sync_word ×16` segment; every first/second-segment mismatch; every exact 128-bit leading-ZERO skip count; every `rxd_ready` or `rxd_data_vld` loss point in SYNC/DATA with immediate DATA_ERROR and disable/re-enable lockout; every software-legal mode/N/f/delete/format/precision combination; direct-mode all-DATA/no-periodic-ZERO behavior; the named reserved-encoding sanitization cases; all legal decimation/DDC DATA valid/ZERO endpoints; corrected decimation f=2; normalized positive/negative samples; exact beat0-through-beat3 low-to-high 512-bit packing; UPK behavior independent of FIFO status and WC choice; both WC=0 rejected-full-write and WC=1 continued-full-write semantics; FIFO_FULL-only stop, FIFO_OF sticky confirmation, either-condition interval invalidation, and unified recovery; natural DDC order; ZERO suppression; ADC_PKT IDLE/BUSY naming, run-shadow sampling boundaries, no link input/gate, 256-entry admission, AXIS TREADY stalls isolated to the FIFO read side while acquisition continues, stop at every FIFO occupancy including no-tail 1..255 residue, retained full blocks/sub-256 residue after a later enable, explicit-clear run isolation, and active-block completion across stop; AXI/W1C priority; TGC local RUN synchronization, one-shot 0→1 launch, software rearm, three-phase success/cancel/idle behavior without returned done or hardware RUN clear; independent resets; named system acquisition points; and complete software recovery. Illegal `DEC_M.N` configurations are excluded from acceptance.

Historical local lint/cocotb evidence predates this v0.13 target and does not validate the direct 128-bit RXD normalization/qualification interface, authoritative `rxd_ready`, diagnostic OR behavior, frozen lane/word/candidate ordering, continuous ready/valid requirement, four-beat synchronization segments, revised leading-ZERO equations, direct-mode all-DATA behavior, three-state UPK, FIFO-status/WC-independent writes, either supported WC overflow semantic, FIFO_FULL/FIFO_OF stop policy and unified recovery, four-beat FIFO packing, ZERO suppression, natural-order DDC admission, IDLE/BUSY packet run-shadow behavior, data-only full-block AXIS behavior, stop-residue joining, removed CRC/header, removed `fifo_sta`, local RUN-synchronized three-phase TGC behavior, or the complete finalized register/diagnostic contract. RTL/TB/XDC revision, simulation, synthesis, implementation, real-ADI integration, and board validation were not performed by this specification task.

## 7. Sources, Decisions And Revision

| Source | Version / Date | Anchor | Used For |
| --- | --- | --- | --- |
| Same-path pre-rewrite document | v1.32 / 2026-08-19; SHA256 `cae9039ce6a84641a4b08518de40540a7c3d1ef7436d7d844e60d65cf62caa71` | Historical hierarchy/interfaces/region evidence | Historical compatibility anchor only; superseded normatively. |
| `D:\Codex\RTL_Temp\ADC_TOP\rtl\*.v` | observed 2026-08-25 | Module declarations and pre-v0.13 behavior | FACT: current implementation baseline and preserved SYSREF diagnostic behavior; not normative evidence for other v0.13 target changes. |
| Historical local `rtl/ADI_JESD204/jesd204_rx.v` (not present in this delivery) | analogdevicesinc/hdl commit `9d5de2fc21b6069675104567c9041bcdbfbe9baa`; historical local SHA256 `3b30e702ef440d19fb04656be61f0fc088103f3823846c4f6825b8163f873fc7` | Historical parameters/source boundary only | FACT: old reference; the current delivery does not bundle or modify ADI source. |
| analogdevicesinc/hdl `library/jesd204/jesd204_rx` | commit `9738f97a82c2bddb9b7cb3a53e57a8f098bdcd11`, inspected 2026-08-26 | TPL data width and `jesd204_frame_mark` cases | FACT: TPL8 produces 128-bit data. A TPL8 marker exists, but the target RXD-to-UPK functional contract does not consume it. |
| `D:\Codex\RTL_Temp\ASU_TOP\rtl\CRC16.v` | observed 2026-08-26 through accepted research | byte-update mechanism | FACT: poly `0x1021`, MSB-first mechanism; comparison only, not an ADC_TOP dependency. |
| `D:\Codex\RTL\PUB\Lib.v` | observed 2026-08-24 | CDC categories | FACT: verified dependency choices available. |
| `D:\Codex\RTL\PUB\async_fifo_fwft` | observed 2026-08-24 | Ports/reset/levels | FACT: FIFO dependency and release risk. |
| `D:\Codex\Vault\Wiki\Modules\AFE\AC9810\AC9810_JESD204B_CBB_配置.md` | accessed 2026-08-25 | §§1,2.3–2.5 | FACT: JESD parameters/mapping. |
| `D:\Codex\Vault\Wiki\Modules\AFE\AC9810\AC9810_JESD204B_组帧场景.md` | accessed 2026-08-25 | §§1,2.1–2.2 | FACT: framing/regions. |
| `D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx` | accessed 2026-08-26 | 2 CML framing scenarios and delete-mode tables | FACT: prefix length, valid/zero region length, and delete-8/delete-16 increments used by `ADC_UPK`. |
| `D:\Codex\Vault\Wiki\Modules\AFE\AC9810\AC9810_寄存器配置流程.md` | accessed 2026-08-26 | PARAM_SYNC row, register `0x14F=0x2772` | FACT: AC9810 synchronization-word configuration and expected comparison value. |
| `D:\Codex\Vault\Archive\Modules\System\Detector_Spec.docx` | archived system specification, §1.5 physical pp.2–6 | acquisition topology, rates, and protocol status | FACT: continuous acquisition until stop, 8 AFE × 2 lanes, 256 channels, 16-bit samples, 5 MHz RAW validation, and 20/30 MHz M24 DDC formal modes; header was listed as pending. Later legacy ADC header/tail rules conflict with and are superseded by the current user decision. The archived document is not modified. |
| `D:\Codex\Vault\Wiki\Modules\AFE\AC9810\AC9810_DTGC_配置.md` | accessed 2026-08-25 | §§1,2.2,2.4 | FACT: four SPI-owned profiles/external nonuniform. |
| `D:\Codex\Vault\RAW\Datasheet\AC9810-32\01-Data Sheet\AC9810-32 用户手册.pdf` | v03 / 2025-12-08 | physical pp.94–95; user-supplied TGC pin timing anchors | FACT: normalized words and pin timing. |
| Current architecture discussion | 2026-08-24–2026-08-26 | User decisions in task | Selected architecture/behavior through v0.13; current decisions override conflicting legacy header/tail, SOMF-start, 256-bit RXD aggregation, data-valid stall, business-pause, UPK capacity feedback, packet link gating, fixed-WC dependency, FIFO_FULL non-stop interpretation, and TGC event/auto-clear interpretations. |

| Decision | Selected Result | Reason / Tradeoff | User Confirmation |
| --- | --- | --- | --- |
| RXD | Pinned ADI TPL8 128-bit data; normalize and pass each beat directly; expose `rxd_data[127:0]`, `rxd_data_vld`, and non-backpressuring `rxd_ready`; define `rxd_ready` solely from the ADI authoritative link-ready functional level; freeze Lane0 low/Lane1 high and earliest per-lane word low; OR other retained faults only into software link diagnostics. | Match the official TPL8 functional boundary, prevent diagnostic coupling into data qualification, and make data order reviewable. | 2026-08-26. |
| UPK synchronization | Exactly IDLE/SYNC/DATA; compare all words in two per-lane `sync_word ×16` segments against `16'h2772`, four valid 128-bit beats per segment, with an integral-beat leading-ZERO skip between them; do not use SOMF. | Establish phase from explicit normalized content without aggregation, half-beat stitching, or extra PREFIX/ZERO states. | 2026-08-26. |
| UPK data | Direct mode is continuous RAW DATA with no periodic ZERO; DEC/DDC ZERO is consumed but suppressed; all modes use one natural-order candidate path; ready loss, valid loss, or sync mismatch errors and locks restart; four beats pack low-to-high. UPK has no FIFO status input and always requests each complete candidate write. | Keep UPK content/synchronization behavior independent of buffering capacity. | 2026-08-26. |
| Errors | DATA_DROP and channel-local `fifo_sta` removed; FIFO_OF, DATA_ERROR, and LINK_ERROR remain W1C diagnostics; AXIS has no error sideband. | Keep error reporting in the control plane without altering FIFO data. | 2026-08-26. |
| FIFO | 512×512 FWFT; final RTL may use `WC=0` or `WC=1`. Software observing either real-time FIFO_FULL or sticky FIFO_OF stops the channel and uses the same clear/recovery sequence; FIFO_OF confirms an attempted full write. | WC choice changes the local damage mode, not ADC_TOP correctness or the user-selected conservative stop policy. | 2026-08-26. |
| Packet | Independent IDLE/BUSY `ADC_PKT`; no link input/gate; synchronized enable is captured as `pkt_run_shadow` only in IDLE or at block completion; every admission transfers exactly 256 data-only beats. | Preserve complete active blocks, make stop deterministic at a block boundary, and remove receive-link coupling from FIFO output. | 2026-08-26. |
| CRC | No CRC exists in the ADC data path. ASU_TOP uses the same poly1021/MSB-first family, but ADC has no CRC consumer and does not depend on another RTL_Temp module. | Avoid an unused module and cross-temporary-module dependency. | 2026-08-26. |
| TGC | Eight local three-phase `ADC_TGC` controllers internally synchronize software-held RUN and launch once per 0→1; success/cancel returns immediately to idle without a done event or hardware RUN clear. | Remove command/config/done CDC plumbing while preserving pin timing and software-controlled rearm. | 2026-08-26. |
| CDC | Local CHN_SYNC/enable; top ADC_SYNC for non-TGC levels/events; TGC RUN synchronizes within each ADC_TGC while stable profile/direction bypass ADC_SYNC. | Preserve handled CDC and remove obsolete TGC event round trips. | 2026-08-26. |
| Registers | Control 0x00..0x24, status 0x28..0x40, FRM_CFG, sticky register names retained. | Contiguous map. | 2026-08-25. |
| Recovery | UPK synchronization/continuity error requires disable then re-enable; observing FIFO_FULL or FIFO_OF requires stop/disable→idle→FIFO clear→FIFO_OF clear if set→enable; active AXIS block forbids clear. | Preserve the user-selected stop-on-full policy independently of WC behavior. | 2026-08-26. |

### 7.1 Knowledge-base conclusions used by the target architecture

This subsection records the information that could not be determined from the original top-level interface alone and therefore had to be reconciled against the AC9810 knowledge base and the framing workbook. It is an implementation aid, not a replacement for the preserved source material.

#### 7.1.1 `DEC_M` and delete-mode interpretation

- `DEC_M[7:2]` is integer `N`; `DEC_M[1:0]` is fractional selector `f=0/1/2/3`.
- `FRM_CFG.DEC_DEL_MODE[1:0]`: `00/01/10` select delete-0/delete-8/delete-16 respectively. Reserved value `11` is sanitized to `00` and therefore contributes no deletion. The same default-to-zero rule is used for other reserved encodings implemented by this module.
- `ADC_UPK` calculates integral 128-bit beat counts from `DEC_M + DEC_DEL_MODE`; software does not provide a separate unpack length.

One normalized 128-bit beat contains eight bytes per lane. Let `Z` be the leading-ZERO byte count per lane between the two complete synchronization segments. Each synchronization segment consumes four beats, so the total SYNC-prefix length is exactly `P = 4 + Z/8 + 4 = 8 + Z/8` valid 128-bit beats.

Direct mode has `Z=96` bytes per lane and therefore `P=20`: first sync 4 beats, leading ZERO 12 beats, second sync 4 beats.

For the workbook's **2 CML** decimation/DDC delete-0 cases, the recorded leading-ZERO byte counts and resulting total prefix lengths are:

| `f` | Delete-0 `Z` bytes/lane | Delete-0 `P` beats |
| ---: | ---: | ---: |
| 0 | `16N+152` | `2N+27` |
| 1 | `64N+168` | `8N+29` |
| 2 | `32N+168` | `4N+29` |
| 3 | `64N+200` | `8N+33` |

Let `M=N+f/4`. Delete mode `01` adds `128M` bytes per lane to `Z`, and delete mode `10` adds `256M` bytes per lane. Because each beat is eight bytes per lane, the corresponding integral additions to `P` are:

| `f` | Delete `01` increment to `P` | Delete `10` increment to `P` |
| ---: | ---: | ---: |
| 0 | `16N` | `32N` |
| 1 | `16N+4` | `32N+8` |
| 2 | `16N+8` | `32N+16` |
| 3 | `16N+12` | `32N+24` |

For every legal mode/f/delete combination, `Z/8` is integral. Within SYNC, beats 0..3 are the first complete sync-word segment, the next `P-8` valid beats are the leading ZERO region, and beats `P-4`..`P-1` are the second complete sync-word segment. DATA scheduling begins after beat `P-1`.

#### 7.1.2 Normalized synchronization-word relationship

The RXD-to-UPK functional boundary contains only normalized `rxd_data[127:0]`, `rxd_data_vld`, and `rxd_ready`. It has no SOMF input and no downstream backpressure. Lane0 occupies `[63:0]`, Lane1 occupies `[127:64]`, and each lane's earliest 16-bit word occupies its lowest slice. Synchronization is content-based:

1. IDLE waits for `rxd_ready=1` and `rxd_data_vld=1`, then accepts that beat as the first synchronization beat;
2. each accepted 128-bit beat exposes four normalized 16-bit words per lane in the frozen low-to-high time order;
3. four consecutive valid beats provide all 16 words per lane in one sync segment, and every word must numerically equal `16'h2772`;
4. after the first segment, UPK skips the configured integral number of leading ZERO beats and validates the second segment identically;
5. after both checks, DATA scheduling suppresses periodic ZERO regions and admits only candidates containing four valid DATA beats.

After the first SYNC beat is accepted, `rxd_data_vld=0` or `rxd_ready=0` in SYNC/DATA is an immediate receive discontinuity. It writes nothing on that cycle, clears UPK context, reports one data error, and requires a disable/re-enable restart. No separate timeout or business-level pause mechanism exists.

### 7.2 ADI `jesd204_rx` third-party IP integration

The required upstream dependency is analogdevicesinc/hdl `library/jesd204/jesd204_rx` pinned at commit `9738f97a82c2bddb9b7cb3a53e57a8f098bdcd11`. It is a third-party black box: `ADC_TOP`, `ADC_RXD`, `ADC_UPK`, and all other delivered RTL in this directory are newly self-written; no ADI RTL is copied into this module and no ADI source is modified.

`ADC_RXD` instantiates the upstream module with the following relevant configuration:

| Parameter / configuration | Value |
| --- | ---: |
| `NUM_LANES` | 2 |
| `NUM_LINKS` | 1 |
| `LINK_MODE` | 1 (JESD204B) |
| `DATA_PATH_WIDTH` | 4 |
| `TPL_DATA_PATH_WIDTH` | 8 |
| `ASYNC_CLK` | 1 |
| `cfg_octets_per_frame` | 16 |
| `cfg_octets_per_multiframe` | 256 |
| `device_cfg_beats_per_multiframe` | 32 |
| Scrambler disabled | yes |
| Frame-align check/reset and character replacement | enabled |

The official template-side data beat is `rx_data[127:0]` plus `rx_valid`, corresponding to two lanes with four 16-bit words per lane in each AFE-clock beat. `ADC_RXD` normalizes the real source mapping into Lane0 at `[63:0]`, Lane1 at `[127:64]`, and earliest per-lane word at the lowest 16-bit slice, then presents that same-width beat directly to `ADC_UPK`. Receive-link status produces the separate `rxd_ready` qualification level.

#### 7.2.1 TPL8 normalization and direct transfer

The pinned upstream implementation is used at TPL8 to obtain the required 128-bit beat width. Although that source revision has a TPL8 frame-marker path, the target RXD-to-UPK functional contract does not use SOMF and does not synthesize a local periodic marker.

Each official 128-bit beat is presented as one normalized 128-bit functional beat with `rxd_data_vld` indicating source continuity. RXD passes SYNC, ZERO, and DATA regions without content filtering or beat aggregation; UPK alone performs synchronization-word validation, DATA-region ZERO suppression, and low-to-high time-ordered four-beat 512-bit packing/admission.

#### 7.2.2 Downstream integration obligations

- Fetch the complete ADI HDL dependency tree for commit `9738f97a82c2bddb9b7cb3a53e57a8f098bdcd11`; do not substitute a moving branch without a new review.
- Add the ADI-owned sources and include paths required by `jesd204_rx` to the downstream project compile order. `rtl/filelist.f` intentionally lists only this module's self-written RTL and verified PUB dependencies.
- Preserve ADI sources as immutable third-party code and comply with the upstream license; do not copy them into this module as if they were self-written deliverables.
- Check compilation, reset/link bring-up, receive-link qualification, direct 128-bit source mapping, Lane0-low/Lane1-high placement, earliest-word-low per-lane ordering, visibility of all four beats in both complete `16'h2772` synchronization segments, integral leading-ZERO beat counts, and DATA-region payload/candidate order with the real pinned IP and board stream. A local `jesd204_rx_model.v`, if used later, is verification-only and must not be synthesized or shipped as the ADI implementation.
- Real-ADI behavioral proof, RTL verification, VCS/Verdi integration, synthesis, implementation, and board validation remain `NOT_RUN` for v0.13.

### 7.3 Revision history

| Version | Date | Author | Change | Compatibility Impact |
| --- | --- | --- | --- | --- |
| `v0.1` | 2026-08-25 | Codex | Whole-document rewrite plus structural-validator correction. | Necessary new names are limited to `frm_cfg`, data-error/FIFO-state, per-channel TGC handshake, and CRC16; other observed boundary names are retained. TGC, register addresses, header status, CRC, CDC, and recovery are incompatible with v1.32. |
| `v0.2` | 2026-08-25 | Codex | User-directed TGC ownership correction: remove the ADC_REG source FSM and replace held request/acknowledge with per-channel command/completion event CDC. | TGC CDC ports and lifecycle change from v0.1; one `ADC_TGC` remains inside each `ADC_CHN`. |
| `v0.3` | 2026-08-26 | Codex | Record knowledge-base-derived 2 CML prefix/delete equations, SOMF-to-byte interpretation, and the ADI `jesd204_rx` third-party integration boundary/workaround. | Documentation only; no RTL interface or behavior change. |
| `v0.4` | 2026-08-26 | Codex | Select official ADI TPL8 SOMF with 128-to-256-bit RXD aggregation; suppress ZERO writes; unify DEC/DDC admission; turn FIFO-capacity failure into data-error/resync; replace header/CRC packetization with 256-beat data-only AXIS blocks; remove `CRC16`, channel ID metadata, and `fifo_sta`; reduce TGC to three immediate-idle phases. | Incompatible AXIS protocol and internal hierarchy/behavior revision: header and CRC disappear, each block is 256 rather than 257 transfers, ADC_CHN/ADC_PKT/ADC_RXD boundaries change, `CRC16`, channel ID metadata, and `fifo_sta` boundaries disappear, RXD timing/width adaptation changes, and UPK/TGC recovery semantics change. The public `ADC_TOP` port set and register map remain unchanged. |
| `v0.5` | 2026-08-26 | Codex | Replace SOMF-based UPK startup with normalized two-segment `16'h2772` validation; rename the functional link-status level to non-backpressuring `rxd_ready`; reduce UPK to IDLE/SYNC/DATA; make data-valid low a stall and ready loss/mismatch/capacity failure a disable/re-enable lockout; freeze full-block-only stop residue behavior and record the detector-system source conflict. | Incompatible ADC_RXD/ADC_UPK functional interface and recovery behavior relative to v0.4: `rxd_somf` is removed, RXD data/valid names are normalized, `rxd_ready` is added, synchronization and restart semantics change, and legacy header/tail rules remain superseded. Public `ADC_TOP` ports, the no-header AXIS protocol, register map, 512×512 FIFO, and 256-transfer block boundary remain unchanged. |
| `v0.6` | 2026-08-26 | Codex | Select a direct normalized 128-bit RXD-to-UPK interface; remove 128-to-256 aggregation and half-beat alignment; expand each sync segment to four valid beats; derive all leading-ZERO prefix counts in native 128-bit beats; pack four DATA beats per 512-bit FIFO candidate. | Incompatible ADC_RXD/ADC_UPK boundary and timing revision relative to v0.5: `rxd_data` narrows from 256 to 128 bits, aggregation state disappears, synchronization/prefix counts double to native beat units, and candidate formation changes from two 256-bit tuples to four 128-bit beats. Public `ADC_TOP` ports, error lockout, FIFO, register map, and AXIS behavior remain unchanged. |
| `v0.7` | 2026-08-26 | Codex | Freeze Lane0/Lane1, per-lane word, and four-beat candidate order; require continuous ready/valid after SYNC starts; define TREADY as FIFO-read-only backpressure; distinguish software stop residue from any pause/resume function. | Incompatible receive-valid/error timing relative to v0.6: `rxd_data_vld=0` in SYNC/DATA now reports DATA_ERROR and locks restart rather than stalling. Public `ADC_TOP` ports, FIFO dimensions, register map, and full-block AXIS wire protocol remain unchanged; RXD/UPK ordering and stop/restart semantics are now normative. |
| `v0.8` | 2026-08-26 | Codex | Make ADC_PKT an IDLE/BUSY run-shadow reader without link gating; remove all FIFO-status feedback from UPK; select FIFO `WC=1` overflow semantics and software recovery; define authoritative ADI-only `rxd_ready` and diagnostic OR behavior; freeze direct-mode DATA; replace TGC event round-trip/auto-clear with local RUN synchronization and software rearm. | Incompatible internal interfaces and recovery/control behavior relative to v0.7: ADC_PKT loses `link_ready`, UPK loses write-level feedback, full writes may overwrite unread data, TGC ports/CDC/RUN lifetime change, and link diagnostics no longer qualify data. Public ADC_TOP ports, register addresses, FIFO dimensions, 128-bit receive order, and 256-transfer AXIS block wire protocol remain unchanged. |
| `v0.9` | 2026-08-26 | Codex | Make FIFO `WC=0` or `WC=1` an implementation choice with common overflow/sticky/recovery behavior; move illegal `DEC_M.N` completely into the software-legal configuration contract and exclude it from hardware behavior and acceptance. | Documentation/contract relaxation relative to v0.8: fixed `WC=1` is no longer an architecture requirement, and illegal N no longer blocks specification closure. No public or internal functional port change is introduced beyond the already selected v0.8 architecture. |
| `v0.10` | 2026-08-26 | Codex | Restore the conservative software policy that observing either FIFO_FULL or FIFO_OF invalidates the current interval and requires stop/clear recovery; distinguish transient FULL stop indication from sticky FIFO_OF full-write confirmation. | Behavioral/software-contract clarification relative to v0.9; WC remains implementation-selectable and no public or internal port changes are introduced. |
| `v0.11` | 2026-08-26 | Codex | Complete whole-document consistency review; add the exhaustive clock/reset resolver for compact interface-table domain labels; preserve and explicitly define SYSREF sticky/count/live-level diagnostics; remove no active target behavior; advance the reviewed contract to finalized/SPEC_READY. | Documentation finalization with no architecture, port, AXIS wire protocol, FIFO policy, TGC behavior, or software-recovery change relative to v0.10. |
| `v0.12` | 2026-08-26 | Codex | Replace the validator-sensitive channel-index placeholder in the normative clock/reset resolver with explicit channel-family and index-range prose. | Documentation-only validator correction with no architecture, port, behavior, acceptance, or compatibility change relative to v0.11. |
| `v0.13` | 2026-08-26 | Codex | Align the current-target evidence and verification-scope references with the finalized specification version. | Documentation-only version-reference correction with no architecture, port, behavior, acceptance, or compatibility change relative to v0.12. |

Residual risks: common asynchronous FIFO-reset release is not proven domain-safe; event bursts may coalesce; a WC=0 overflow drops the full write, while a WC=1 overflow may overwrite unread data before software reacts; FIFO_FULL may be transient, so software observation latency matters even though FIFO_OF preserves every actual full-write occurrence; AXIS carries no in-band indication of a continuity, FULL, or overflow error; AXIS backpressure cannot stop AFE acquisition; ZERO compression and full-block-only output can increase latency and retain a sub-256-entry stop residue that will join later data unless software clears it; stable bundled TGC profile/direction and local RUN synchronization require the stated software ordering; external TGC setup greater than 3 ns, hold greater than 2 ns, slope-rate, phase, skew, jitter, board-delay, and FPGA clock-to-output requirements remain integration constraints; ADI behavior is source-owned; and TPL8 authoritative link-ready behavior, diagnostic OR mapping, 128-bit Lane0/Lane1 byte/word/time normalization, numeric `16'h2772` visibility, continuous ready/valid behavior, leading-ZERO beat counts, real pinned ADI integration, RTL/TB/XDC conformance, simulation, synthesis, implementation, and board behavior remain unverified. Software compliance with the legal `DEC_M.N` ranges is an integration obligation, not an undefined hardware-design risk.

## SPEC_READY Checklist

- [x] Front matter is `finalized` / `SPEC_READY` after whole-document semantic and structural review.
- [x] Purpose, use, boundary, dependencies, and exclusions are unambiguous.
- [x] Selected architecture and CDC ownership are frozen in this candidate.
- [x] Hierarchy responsibilities are clear and every kind is `top` or `submodule`.
- [x] Every declared module and submodule has a complete one-port-per-row strict interface definition in the candidate.
- [x] One state table and one transition table cover all selected FSMs.
- [x] Widths, timing, buffering, protocols, clear, recovery, and acceptance are defined.
- [x] Sources, decisions, compatibility impact, and residual risks are traceable.
- [x] No unresolved design item changes hierarchy, ports, behavior, constraints, or acceptance; software owns the documented legal `DEC_M.N` ranges.
