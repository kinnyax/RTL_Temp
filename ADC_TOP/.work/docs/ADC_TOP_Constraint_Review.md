---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-14
reviewer: /root/adc_upk_constraint
design_baseline_fingerprint: ca40cd68dcc207c2a7f876075bdc3f92198a6e43814cb3774508bb07002016f9
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP Constraint Review

## Decision

- Classification: `DEFERRED_TO_TOP`.
- Deferred owner: Detector_v1 system-integration owner, using `D:\Codex\Item\Detector\Detector\Detector_v1\constraints\Detector_v1.xdc` with CMU/RMU, JESD PHY, selected FIFO, and vendor-IP XDC owners.
- XDC path: `NONE`. ADC_TOP owns no physical pins, clock source/buffer, generated-clock generator, real clock period, I/O delay, or integrated exception endpoint.
- Static XDC review: `NOT_APPLICABLE`; no module XDC exists for this external-only classification.
- Vivado object/scope/processing-order/vendor-XDC resolution: `VIVADO_RESOLUTION_NOT_RUN`.

## Reviewed Baseline

- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `ca40cd68dcc207c2a7f876075bdc3f92198a6e43814cb3774508bb07002016f9`, `RTL_MODULE_CONTRACT_V1`, v1.1.
- Source order: `D:\Codex\RTL_Temp\ADC_TOP\rtl\filelist.f`, SHA256 `76aa2d06650dc14aae941c422ef6a2d183be3cd0076386c84d8085aa44a0f648`.
- Complete dependency record: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Dependency_Manifest.tsv`; scope `EXTERNAL_ONLY`.

## Clock, Reset, and CDC Audit

`sys_clk`, `adc_clk`, and `afe_clk` are externally supplied register clocks. Their real source, period, duty cycle, start/stop policy, and relationships belong to integrated CMU/RMU. `jesd_clk[n]` are externally supplied recovered PHY clocks; their actual parent/generated-clock relation, phase, GT placement, and vendor interaction require integrated JESD PHY evidence. `sysref_in` is a sampled external event, not a generated clock. ADC_TOP creates, forwards, and buffers none of these clocks.

RMU owns asynchronous assertion and domain-safe synchronous release for `sys_rst_n/sys_clk`, `adc_rst_n/adc_clk`, `afe_rst_n/afe_clk`, and `jesd_rst_n[n]/jesd_clk[n]`. The module neither contains an RMU nor a reset-release synchronizer. `ADC_RXD` link logic uses `jesd_rst_n`; its device and unpack logic use `afe_rst_n`. `ADC_PKT` and ADC-side CDC endpoints use `adc_rst_n`; AFE-side CDC endpoints use `afe_rst_n`.

Each channel directly instantiates the PUB FWFT asynchronous FIFO with `afe_clk` write and `adc_clk` read. `fifo_rst_n = afe_rst_n & adc_rst_n & ~fifo_clr`; either domain reset or software clear resets the complete FIFO. The selected PUB FIFO and the future official Vivado FIFO must be separately proven for clear assertion/recovery and stable `FIFO_EMPTY`; both clocks must stay running during the software recovery sequence.

The v1.1 fail-closed path forms `ddc_admit_ok_afe = ~ddc_abort_afe` in `ADC_CHN`, then transfers that single AFE-domain level through `CHN_SYNC` by `level_sync ddc_admit_ok_to_adc(.clk(adc_clk), .rst_n(adc_rst_n), .in(ddc_admit_ok_afe), .out(ddc_admit_ok_adc))`. The source state is created and reset in the `afe_clk/afe_rst_n` domain; the destination synchronizer and `ADC_PKT` admission gate use `adc_clk/adc_rst_n`. Because the destination synchronizer resets low, ADC reset assertion and release remain fail-closed until the healthy source level is sampled. The level is not a clock, generated clock, asynchronous data bus, timing-exception endpoint, or external port. It gates only new `packet_start`; it does not interrupt an admitted packet. No module-level XDC is justified by this CDC primitive; synchronizer recognition and any precise exception must be based on resolved integrated objects.

No module-owned broad asynchronous clock group, false path, internal pin/cell, generated-clock anchor, or precise exception endpoint is justified. CDC architecture uses declared PUB synchronizer primitives and FIFO. Actual clock groups, synchronizer recognition, FIFO/IP timing, and any precise exception must be constrained only after CMU/RMU/PHY/FIFO topology is resolved at Detector_v1 integration.

## External Ports and Vendor Obligations

All ADC_TOP ports remain externally integrated: AXI4-Lite under `sys_clk`; eight PHY/JESD interfaces under individual `jesd_clk[n]`; eight AXIS outputs under `adc_clk`; eight TGC groups under `afe_clk`; clock, reset, and SYSREF inputs. Board/package locations, IOSTANDARD/drive/slew, I/O delays, SYSREF capture relation, CMU/RMU clock definition, JESD PHY generated clocks, selected FIFO constraints, and vendor-XDC precedence belong to Detector_v1 integration. Project fileset processing order and vendor-XDC interaction must be reviewed there.

## Residual Risks

- No Vivado run resolved a port, cell, generated clock, or exception endpoint.
- PUB FWFT and replacement official FIFO clear/recovery behavior must be proved by their implementation documentation and integrated verification.
- Actual CMU/RMU/PHY topology may establish related or asynchronous clocks differently from this module-only view.
- `ddc_admit_ok` relies on the resolved integrated level synchronizer implementation; fail-closed admission does not replace software FIFO clear/relink recovery.
