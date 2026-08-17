---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-17
reviewer: /root/adc_config_constraint
design_sha256: 010556a566a6af24fa1dae3b7ab8ba2c487582487cd0760d3ee899a8f41f7ce2
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP Constraint Review

## Decision

- Classification: `DEFERRED_TO_TOP`.
- Deferred owner: `Detector_v1 system-integration owner`, together with CMU/RMU, JESD PHY/GTH, selected FIFO IP, board-I/O and vendor-XDC owners.
- XDC path: `NONE`. ADC_TOP owns no physical pin, clock source/buffer, generated-clock generator, real clock period, I/O delay or resolvable module-owned timing-exception endpoint.
- Static XDC review: `NOT_APPLICABLE` for this `EXTERNAL_ONLY` classification.
- Vivado resolution: `VIVADO_RESOLUTION_NOT_RUN`.

## Audited Baseline

- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `010556a566a6af24fa1dae3b7ab8ba2c487582487cd0760d3ee899a8f41f7ce2`, finalized v1.9.
- Source order: `D:\Codex\RTL_Temp\ADC_TOP\rtl\filelist.f`, SHA256 `76aa2d06650dc14aae941c422ef6a2d183be3cd0076386c84d8085aa44a0f648`.
- Changed RTL: `ADC_RXD.v`, SHA256 `0f465fdadb38dc16acbb5816b4d1a6c27e596e31c0328e828586e02dd0627275`.
- Dependency manifest: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Dependency_Manifest.tsv`; scope `EXTERNAL_ONLY`; its exact SHA256 is supplied in this worker handoff.

## Delta Applicability

The ADC_RXD delta removes only static software-configuration legality gates, retains the existing JESD-to-AFE `link_ready` level synchronizer and existing runtime recovery controls, and rewrites the payload-prefix combinational expressions for inspection. The pure-ADC prefix remains an explicit compile-time `adc_num = (16 + 96 + 16) / 8 = 16` AFE-beat quantity. The decimation and DDC prefix expressions remain wholly combinational AFE-domain scheduler inputs (`dec_num`, `ddc_num`, then `skip_num`).

The final internal structure introduces combinational `rxd_clr = !upk_vld || fifo_clr` and uses it consistently in existing AFE-domain state/data registers. The three-state RXD next-state block remains `afe_clk`/`afe_rst_n` owned, while the prefix counter and word/terminal/phase registers are split into explicit conditional-enable sequential blocks instead of a synchronous state `case`. These are internal control-structure changes only: no clock, reset, CDC primitive, public port, physical interface, generated-clock source, timing-exception endpoint, FIFO port, or vendor-IP boundary is added or moved.

## Clock, Reset and CDC Audit

`sys_clk`, `adc_clk` and `afe_clk` are external register clocks. `jesd_clk[7:0]` are external recovered PHY clocks. Their sources, periods, duty cycles, start/stop behavior, parent relations and generated-clock definitions are not visible at this standalone module boundary and remain integration-owned. `sysref_in` is an externally sampled JESD event rather than a module-generated clock.

RMU owns asynchronous reset assertion and per-domain synchronous release. `sys_rst_n` serves SYS logic; `adc_rst_n` serves ADC logic; `afe_rst_n` serves AFE logic; each `jesd_rst_n[n]` serves its corresponding JESD link. ADC_RXD keeps `jesd_core_reset` in the JESD ownership chain and `device_core_reset`, unpack state, history, payload scheduler and RXD FSM in the AFE ownership chain.

The encoded two-bit JESD state is not transferred across domains. ADC_RXD source-decodes the single-bit `link_ready` and transfers it locally through `level_sync link_ready_to_afe` with destination `afe_clk/afe_rst_n`; this path is unchanged. CHN_SYNC retains ADC-facing CDC: JESD/AFE event pulses use `pulse_sync2` with matching source reset and `adc_clk/adc_rst_n` destination, while status levels synchronize into `adc_clk`. ADC_SYNC retains SYS/ADC/AFE CDC with the reset corresponding to each source and destination clock endpoint.

Each ADC_CHN directly instantiates the PUB FWFT asynchronous FIFO with `afe_clk` write and `adc_clk` read. `fifo_rst_n = afe_rst_n & adc_rst_n & ~fifo_clr`; either domain reset or software clear resets the entire FIFO. Exact clear assertion/recovery cycles, stable `FIFO_EMPTY`, synchronizer recognition and vendor-FIFO constraints remain integration evidence.

No module-level broad asynchronous clock group, false path or internal `set_*` exception is emitted. Synchronizer/FIFO primitives establish CDC architecture but do not justify unresolved wildcard exceptions. Any later exception must target exact Vivado-resolved objects after CMU/RMU/PHY/FIFO topology is known.

## Public Ports and Vendor Interaction

All public interfaces remain externally integrated: AXI4-Lite under `sys_clk`, eight JESD PHY interfaces under their corresponding `jesd_clk[n]`, eight AXIS outputs under `adc_clk`, and eight TGC groups under `afe_clk`. Board locations, IOSTANDARD/drive/slew, I/O delays, SYSREF capture relation, JESD PHY/GTH generated clocks, FIFO XCI constraints and vendor-XDC precedence belong to the Detector_v1 integration and IP owners. The PHY/GTH part is separately `DEFERRED_TO_VENDOR_IP`; that does not require an ADC_TOP-local XDC.

## Residual Risks

- No Vivado run resolved ports, cells, clocks or exception endpoints.
- Integrated CMU/RMU/PHY topology may establish related or asynchronous clock relationships differently from this module-only view.
- PUB FWFT and the future official FIFO require integrated clear/recovery and status-timing evidence.
- CDC recognition and any precise timing exception require resolved integration objects; no standalone wildcard is justified.
