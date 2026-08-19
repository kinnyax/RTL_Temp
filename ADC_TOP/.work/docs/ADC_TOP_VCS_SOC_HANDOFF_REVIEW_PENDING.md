---
type: vcs_soc_handoff
module_name: ADC_TOP
date: 2026-08-19
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_rework_rtlreview
accepting_review_handoff_sha256: a2c339bd5461f82cb59529f577db30c222326b3dba1cd3bfc66954ea608c1e99
tags: [FPGA/VCS, Verification]
---

# ADC_TOP VCS SoC Verification Handoff

## Source Baseline

- Finalized design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`.
- DUT inputs: frozen `D:\Codex\RTL_Temp\ADC_TOP\rtl\filelist.f` and module RTL sources; PUB dependencies remain read-only and are selected by `pub_filelist.f`.
- Constraint applicability: DEFERRED_TO_TOP / EXTERNAL_ONLY; VIVADO_RESOLUTION_NOT_RUN.
- VMware preflight and local gates passed. The exact fresh run, input fingerprint, toolchain fingerprint and returned evidence are owned by the assembled release sidecar and are not duplicated in this draft.

## Environment Contract

- Methodology: NON_UVM_SYSTEMVERILOG_SOC.
- Target simulator/debugger: VCS / Verdi.
- Official IP availability: UNAVAILABLE in VMware; model equivalence is NON_VENDOR_EQUIVALENT.

## Required SoC Focus

- Check reset/relink, pre-edge marker/P0/P1 scheduling, normalized AC9810 formatting, dec/DDC scoreboards, DDC atomic pair admission/drop, FIFO clear recovery, AXI-Lite and AXIS backpressure.
- Preserve the public source boundary: ADC_RXD wrapper, ADC_UPK unpack/map/FIFO request block, and ADC_CHN integration.

## Residual Risks And Next Status

- This draft is REVIEW_PENDING only. It has no VMware PASS and must not be finalized until a corrected RTL batch completes fresh VMware sanity, release assembly and independent review.
- VCS pass advances status to VCS_SOC_VERIFIED.
- VCS execution/evidence in this handoff: NOT_RUN.
