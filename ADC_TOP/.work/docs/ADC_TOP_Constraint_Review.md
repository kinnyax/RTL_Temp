---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-19
reviewer: /root/adc_fmt_constraint
design_sha256: 95f274fa2cae62e09c6c9addc3bcfe5ac62d6490ad1d946b96bc844f5602e7ef
accepted_design_review_sha256: 45be60c7164c465a5582afec2f876d2dc2f6c70e1d23037767353593519f38a9
rtl_sha256: 045c45194e54e2ffc33099302d8e0ce6ab4e3c7b66813a8192946c7f52532f57
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
static_review_status: NOT_APPLICABLE
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP Constraint Review

## Decision

- Classification: `DEFERRED_TO_TOP`.
- Deferred owner: `Detector_v1 system-integration owner`, with CMU/RMU, JESD PHY/GTH, board I/O and official FIFO/IP owners.
- XDC: none. `D:\Codex\RTL_Temp\ADC_TOP\xdc\ADC_TOP.xdc` is not required and has not been created.
- Static XDC review: `NOT_APPLICABLE`; no standalone XDC exists to syntax- or endpoint-review.
- Vivado resolution: `VIVADO_RESOLUTION_NOT_RUN`.
- Dependency scope: `EXTERNAL_ONLY`.

The accepted v1.26 AC9810 normalized-word mapping delta and current ADC_RXD retain the public interface, external clocks/resets, CDC primitives and physical-IP boundary. The changed internal anchors are the AFE-domain `mapped_raw` channel reorder, `mapped_data_right` precision-specific sign extension, and `frame_fmt` output select. `FRAME_FMT=1` preserves each received N'=16 container; `FRAME_FMT=0` right-aligns its signed payload using `SMP_PREC=10/12/14`. At each AFE edge, `upk_vld`, `upk_trig` and `rxd_clr` use current pre-edge raw `adi_rx_data`, `adi_rx_valid` and `adi_rx_somf[0]` at the documented raw marker boundary. `fifo_wr_valid` has a single AFE sequential owner; `rxd_clr` (including `fifo_clr`) clears its local request with priority, loss creates no new request, and `ddc_abort_afe` blocks later requests. These are same-domain behaviors, not clock sources, generated-clock anchors, internal pins/cells or exception endpoints for a standalone XDC. The manifest is freshly rebound to v1.26 while preserving `DEFERRED_TO_TOP/EXTERNAL_ONLY`.

## Clock, Reset and CDC Audit

`sys_clk`, `adc_clk` and `afe_clk` are external `REGISTER_CLOCK` inputs. `jesd_clk[7:0]` are external recovered PHY register clocks. Their source pins, parents, periods, duty cycles, start/stop behavior, phase and deterministic relationships are unavailable at this module boundary; Detector_v1 integration owns their definitions and relationships. `sysref_in` is an external `SAMPLED_SIGNAL`, not a module-generated clock.

RMU owns asynchronous reset assertion and domain-safe release for `sys_rst_n`, `adc_rst_n`, `afe_rst_n` and each `jesd_rst_n[n]`. In ADC_RXD, `jesd_core_reset` remains in the JESD ownership chain; `device_core_reset`, the decoded four-state region FSM, `prefix_cnt`/region/pair state, two per-lane buffers, the combinational software-format mapping, FIFO-request clear/priority and DDC recovery logic remain in the AFE domain (`afe_clk`/`afe_rst_n`). There is no alignment-pipeline storage or new CDC channel.

The encoded ADI state is not transferred bitwise across domains. ADC_RXD source-decodes single-bit `link_ready`, then crosses only through `level_sync link_ready_to_afe` to `afe_clk`/`afe_rst_n`. The direct raw RXD and local FIFO-request behavior do not alter that crossing or introduce another CDC primitive. `CHN_SYNC` retains JESD/AFE event-pulse CDC to `adc_clk`/`adc_rst_n`; `ADC_SYNC` retains SYS/ADC/AFE CDC. Each `ADC_CHN` retains the PUB FWFT asynchronous FIFO with `afe_clk` write, `adc_clk` read and combined reset `fifo_rst_n = afe_rst_n & adc_rst_n & ~fifo_clr`.

No module-level asynchronous clock group, false path or internal `set_*` exception is justified. Any later exception must name exact Vivado-resolved endpoints after CMU/RMU, PHY and FIFO topology is known.

## Interfaces and Vendor Interaction

Public interfaces remain: AXI4-Lite under `sys_clk`; eight JESD PHY interfaces under `jesd_clk[n]`; eight AXIS outputs under `adc_clk`; and eight TGC groups under `afe_clk`. Board locations, IOSTANDARD/drive/slew, I/O delays, SYSREF capture relation, recovered/generated JESD clocks, PHY/GTH and FIFO XCI constraints, vendor-XDC processing order and precedence are system-integration or IP-owner responsibilities.

The PHY/GTH and official FIFO portions remain `DEFERRED_TO_VENDOR_IP`, but their separate vendor-owned constraints do not make an ADC_TOP-local XDC required. This workflow writes neither XDC nor project Tcl; later integration must resolve object names, ordering and vendor-XDC conflict checks.

## Dependency Manifest

`D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Dependency_Manifest.tsv` is UTF-8/LF, deterministic and ordered by kind/identifier. It records every standalone-boundary clock, reset, sampled event, public-port set, relevant CDC/FIFO/IP source anchor, the direct pre-edge raw data/valid/SOMF boundary, v1.26 `mapped_raw`/`mapped_data_right`/`frame_fmt` format-mapping anchor, FIFO-request clear/loss/abort anchors, and the absence of module-level internal constraint objects or exceptions.

- Scope: `EXTERNAL_ONLY`.
- SHA256: `a50414cbca11fd50d349120e9f4324fc3f991a19ed89d8a8b7c0d593d3d171f0`.
- Reuse condition: every manifest row and its referenced source hash/structural anchor must remain unchanged.

## Residual Risks

- Vivado has not resolved ports, cells, clocks, generated clocks, exception endpoints, processing order or vendor-XDC interaction.
- Integrated CMU/RMU/PHY topology may establish related or asynchronous clock relationships differently from this standalone view.
- PUB FWFT and the future official FIFO still require integrated clear/recovery and status-timing evidence.
- The direct pre-edge raw boundary, v1.26 format-mapping equations, FIFO-request clear/loss priority and same-edge two-beat accumulator can affect timing/PPA but create no standalone XDC intent; synthesis/integration owns timing analysis.
- CDC recognition and any precise timing exception require resolved integration objects; no wildcard exception is justified.
