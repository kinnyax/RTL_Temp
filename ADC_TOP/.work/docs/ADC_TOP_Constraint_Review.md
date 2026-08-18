---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-17
reviewer: /root/adc_style_constraint
design_sha256: afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8
rtl_sha256: 416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP Constraint Review

## Decision

- Classification: `DEFERRED_TO_TOP`.
- Deferred owner: `Detector_v1 system-integration owner`, together with CMU/RMU, JESD PHY and official FIFO/IP owners.
- Static review: `STATIC_XDC_REVIEW_PASS` for the `DEFERRED_TO_TOP` decision. No ADC_TOP-local XDC exists or is required.
- Vivado resolution: `VIVADO_RESOLUTION_NOT_RUN`.
- Dependency scope: `EXTERNAL_ONLY`.

The v1.10 contract and current RTL retain every top-level port, clock, reset, CDC primitive and physical-IP boundary. The only relevant ADC_RXD structural change is the AFE-domain reception control organization: state names are `RXD_IDLE/RXD_PREF/RXD_PAYL`; `word_pos_r` is a dedicated sequential owner; and `next_term_r/term_phase_r` remain together in their terminal scheduler owner. This introduces no clock source, generated-clock anchor, reset endpoint, internal constraint object or timing exception endpoint.

## Clock, Reset and CDC Audit

`sys_clk`, `adc_clk` and `afe_clk` are external register clocks. `jesd_clk[7:0]` are external recovered PHY clocks. Their source pins, parents, periods, duty cycles, start/stop behavior, deterministic relationships and generated-clock definitions are unavailable at this standalone boundary; all remain system-integration owned. `sysref_in` is an externally sampled JESD event, not a module-generated clock.

RMU owns asynchronous reset assertion and domain-safe release: `sys_rst_n` for SYS, `adc_rst_n` for ADC, `afe_rst_n` for AFE, and `jesd_rst_n[n]` for each JESD link. In ADC_RXD, `jesd_core_reset` remains in the JESD ownership chain, while `device_core_reset`, the three-state RXD FSM, prefix, word-position, terminal/phase scheduler and unpack context remain AFE-owned.

The encoded two-bit ADI state is not transferred across domains. ADC_RXD source-decodes the single-bit `link_ready` and transfers it only through `level_sync link_ready_to_afe`, destination `afe_clk/afe_rst_n`. This CDC structure is unchanged. CHN_SYNC retains JESD/AFE event pulse CDC to `adc_clk/adc_rst_n`, and ADC_SYNC retains SYS/ADC/AFE level/pulse CDC. Each ADC_CHN retains the PUB FWFT async FIFO with `afe_clk` write and `adc_clk` read; `fifo_rst_n = afe_rst_n & adc_rst_n & ~fifo_clr` is unchanged.

No module-level broad asynchronous clock group, false path or internal `set_*` exception is warranted. Any later exception must name exact Vivado-resolved endpoints after CMU/RMU/PHY/FIFO topology is known.

## Public Interfaces and Vendor Interaction

Public interfaces remain externally integrated: AXI4-Lite under `sys_clk`, eight JESD PHY interfaces under `jesd_clk[n]`, eight AXIS outputs under `adc_clk`, and eight TGC groups under `afe_clk`. Board locations, IOSTANDARD/drive/slew, I/O delays, SYSREF capture relation, JESD PHY/GTH generated clocks, FIFO XCI constraints and vendor-XDC precedence are owned by the Detector_v1 integration and IP owners. The PHY/GTH part remains separately `DEFERRED_TO_VENDOR_IP`; it does not create an ADC_TOP-local XDC requirement.

## Dependency Manifest

`D:\\Codex\\RTL_Temp\\ADC_TOP\\.work\\docs\\ADC_TOP_Constraint_Dependency_Manifest.tsv` is deterministic UTF-8/LF, ordered by kind and identifier, and has scope `EXTERNAL_ONLY`. SHA256: `895093b4dd32640aa77f4826d807068b3af7073d0d1070cf41ba20de4c8df25e`.

## Residual Risks

- Vivado has not resolved ports, cells, clocks, generated clocks or exception endpoints.
- Integrated CMU/RMU/PHY topology may establish related or asynchronous clock relationships differently from the standalone module view.
- PUB FWFT and the future official FIFO still require integrated clear/recovery and status-timing evidence.
- CDC recognition and any precise timing exception require resolved integration objects; no standalone wildcard is justified.
