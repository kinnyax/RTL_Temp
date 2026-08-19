---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-19
reviewer: /root/adc_rework_verdesign
design_sha256: cae9039ce6a84641a4b08518de40540a7c3d1ef7436d7d844e60d65cf62caa71
accepted_design_review_sha256: 3886dbe87503af9de61c32c3ee7837b29d1919cbf0a2415fe3837d7050536269
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
static_review_status: NOT_APPLICABLE
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP Constraint Review

## Decision

- Classification: `DEFERRED_TO_TOP`.
- Top-level owner: Detector_v1 system-integration owner, including CMU/RMU, JESD PHY/GTH, board I/O and official FIFO/IP owners.
- Module XDC: none; `ADC_TOP.xdc` is not required.
- Dependency scope: `EXTERNAL_ONLY`.
- Static XDC review: `NOT_APPLICABLE`; Vivado object resolution: `VIVADO_RESOLUTION_NOT_RUN`.

ADC_TOP has external SYS/ADC/AFE/JESD clocks and resets. Their periods, sources, relationships, board I/O, recovered-clock topology, FIFO implementation constraints, generated clocks and vendor-XDC ordering are unavailable at this project-independent boundary. No module-local physical, clock, generated-clock or exception constraint is justified.

## v1.32 Structural Audit

`ADC_RXD` is only the ADI/JESD wrapper. It crosses the decoded single-bit link level to AFE and forms `link_ready_afe = link_ready_sync & adi_rx_valid`. `ADC_UPK` consumes the local AFE tuple, owns region/FIFO-request behavior, and contains no clock generator or module-XDC endpoint. `fifo_clr` reaches only the asynchronous FIFO reset expression in `ADC_CHN`; it does not enter `ADC_UPK`.

The CDC/FIFO topology is unchanged in kind: status/event CDC is owned by CHN_SYNC/ADC_SYNC; data crosses through the PUB FWFT async FIFO with AFE write and ADC read clocks. Precise CDC exceptions and vendor interaction require resolved integrated objects and remain top-level work.

## Dependency Manifest

`D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Dependency_Manifest.tsv` records external clocks, resets, public port scope, source anchors and the absence of module constraint objects. Reuse requires unchanged anchor hashes and rows.

- Manifest SHA256: `f93d3fcc8f66704fd7803879241a69c7cce1df62e82e841edd5ace0b9312b0ff`.

## Residual Risks

No Vivado processing-order, endpoint-resolution, syntax, clock-interaction or vendor-XDC evidence has been run. Future integration must establish actual clock definitions/relationships, I/O delays, vendor-XDC precedence and precise CDC timing constraints.
