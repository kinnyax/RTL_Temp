---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-14
reviewer: /root/adc_unpack_constraint
design_sha256: a3a1f7d9ec91236f1d73e9164fc12161d4b6fc1ff1b11fab05aa229d9a784622
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP Constraint Review

## Decision

- Classification: `DEFERRED_TO_TOP`.
- Deferred owner: Detector_v1 system-integration owner. The integration XDC must resolve CMU/RMU clocks and resets, JESD PHY/GTH generated clocks, selected FIFO IP constraints, board I/O, AXI timing, SYSREF capture timing, and vendor-XDC order.
- XDC path: `NONE`. This module has no physical pin, clock generator/buffer, real clock period, I/O delay, or resolvable module-owned timing-exception endpoint.
- Static XDC review: `NOT_APPLICABLE` for this external-only module classification.
- Vivado resolution: `VIVADO_RESOLUTION_NOT_RUN`.

## Audited Baseline

- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `a3a1f7d9ec91236f1d73e9164fc12161d4b6fc1ff1b11fab05aa229d9a784622`.
- Source order: `D:\Codex\RTL_Temp\ADC_TOP\rtl\filelist.f`, SHA256 `76aa2d06650dc14aae941c422ef6a2d183be3cd0076386c84d8085aa44a0f648`.
- Dependency manifest: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Dependency_Manifest.tsv`; scope `EXTERNAL_ONLY`; SHA256 recorded after document finalization.

## Clock, Reset, and CDC Audit

`sys_clk`, `adc_clk`, and `afe_clk` are external register clocks. `jesd_clk[7:0]` are external recovered PHY clocks. Their sources, periods, duty cycles, start/stop behavior, parent relations, and generated-clock definitions are not visible at this standalone boundary and remain integration-owned. `sysref_in` is an externally sampled JESD event, not a module-generated clock.

RMU owns asynchronous reset assertion and per-domain synchronous release. `sys_rst_n` is consumed in SYS logic; `adc_rst_n` in ADC logic; `afe_rst_n` in AFE logic; each `jesd_rst_n[n]` in its matching JESD link logic. `ADC_RXD` correctly keeps ADI/JESD reset (`jesd_core_reset`) in the JESD reset ownership chain, while device/unpack reset (`device_core_reset`) and its unpack state use `afe_rst_n`.

The former encoded two-bit JESD-state transfer is absent. `ADC_RXD` decodes `link_ready` in the JESD domain and transfers that single level locally through `level_sync link_ready_to_afe` with destination `afe_clk/afe_rst_n`. This is a valid single-bit status CDC and does not create an XDC endpoint at standalone module scope.

`CHN_SYNC` retains ADC-facing CDC: JESD/AFE-to-ADC status levels use `level_sync`/`levels_sync` with destination `adc_clk/adc_rst_n`; source event pulses use `pulse_sync2` with their source-domain reset and `adc_rst_n` destination reset. `ADC_SYNC` similarly uses PUB primitives with the reset associated with each source and destination clock endpoint. The observed reset ownership is consistent with the three-clock-domain contract.

Each channel directly instantiates the PUB FWFT asynchronous FIFO with `afe_clk` write and `adc_clk` read. `fifo_rst_n = afe_rst_n & adc_rst_n & ~fifo_clr`; either AFE or ADC reset and software clear reset the entire FIFO. The integration must constrain and verify the selected FIFO implementation, keep both clocks running for software recovery, and prove required clear assertion/recovery cycles plus stable `FIFO_EMPTY`.

No broad asynchronous clock groups, false paths, or internal `set_*` exceptions are emitted here. PUB synchronizer/FIFO architecture is not a substitute for resolved project constraints. If integration exposes concrete synchronizer cells or FIFO/PHY endpoints, the Detector_v1 constraint owner must use exact resolved objects and topology rather than copying a module-level wildcard exception.

## Public Ports and Vendor Interaction

All public interfaces remain external: AXI4-Lite (`sys_clk`), eight JESD PHY connections (`jesd_clk[n]`), eight AXIS outputs (`adc_clk`), and eight TGC groups (`afe_clk`). Board locations, IOSTANDARD/drive/slew, I/O delays, JESD PHY/GTH generated clocks, SYSREF relationship, selected FIFO XCI constraints, and vendor-XDC precedence are delegated to Detector_v1 integration and its IP owners.

## Residual Risks

- No Vivado run resolved ports, cells, clocks, or exception endpoints.
- Actual CMU/RMU/PHY topology can establish related or asynchronous clock relationships differently from this module-only audit.
- PUB FWFT and the replacement official FIFO must be verified for clear/recovery and status timing in integrated flow.
- The new internal `link_ready` CDC is structurally reviewed only; CDC recognition and any targeted timing exception require resolved integrated objects.
