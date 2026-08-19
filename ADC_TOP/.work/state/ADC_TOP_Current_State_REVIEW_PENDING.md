---
type: module_current_state
module_name: ADC_TOP
date: 2026-08-19
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_rework_rtlreview
accepting_review_handoff_sha256: a2c339bd5461f82cb59529f577db30c222326b3dba1cd3bfc66954ea608c1e99
tags: [FPGA/IP, Status]
---

# ADC_TOP Current State

## Canonical Locations

- Temporary module work root: `D:\Codex\RTL_Temp\ADC_TOP`.
- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`.
- RTL review-pending draft: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_RTL_handoff_05.md`.
- VCS draft: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_VCS_SOC_HANDOFF_REVIEW_PENDING.md`.

## Current Baseline

- Contract/profile/class: RTL_MODULE_CONTRACT_V1 / VERILOG_2001_EXPLICIT_V1 / MODIFIED_THIRD_PARTY_RTL.
- Frozen RTL/filelist and TB/manifest are the selected batch inputs; no input is changed by this release worker.
- Constraint decision: DEFERRED_TO_TOP, EXTERNAL_ONLY; VIVADO_RESOLUTION_NOT_RUN.
- VMware preflight: PASS; receipt at `D:\Codex\RTL_Temp\ADC_TOP\.work\verification\state\vmware_preflight_receipt.json`.
- Local verification gates: PASS; 18 sources and 19 testcases.
- Verification batch: frozen fresh-run inputs; verification input/run/evidence and toolchain identity are sidecar-owned and not duplicated here.
- Release baseline manifest, sidecar-bound roster, and finalization patch: script-owned; REVIEW_PENDING after a complete observed PASS assembly.
- PPA: HYPOTHESIS. Model equivalence: NON_VENDOR_EQUIVALENT.

## Next Task

- Independent Review validates the assembled release baseline; VCS execution remains NOT_RUN.
- VCS execution: NOT_RUN.

## Distillation Status

- Wiki candidate: NONE. Wiki/Archive authorization: FALSE.
