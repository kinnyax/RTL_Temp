---
type: module_current_state
module_name: ADC_TOP
date: 2026-08-14
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_upk_release_review
accepting_review_handoff_sha256: 5f540a8f860bb02113a010db275703ac2a59bd87faf3297c14586bed2ae7cb9d
tags:
  - FPGA/IP
  - Status
---

# ADC_TOP Current State

## Current Baseline

- Stage: `READY_FOR_VCS` is the intended final stage for this frozen baseline; VCS/Verdi execution remains user-owned and `NOT_RUN`.
- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md` v1.1, SHA256 `ca40cd68dcc207c2a7f876075bdc3f92198a6e43814cb3774508bb07002016f9`; contract/profile/class `RTL_MODULE_CONTRACT_V1` / `VERILOG_2001_EXPLICIT_V1` / `MODIFIED_THIRD_PARTY_RTL`.
- Frozen RTL: ADC_RXD `26aa5811127ba977cde8d86e2a7d63f6a86c370eb1bdc01df87f4125a96c8571`; ADC_CHN `30f1eb0d7c51540a9c222df310f39d581f97d4268e454dcb541ecd1d161f9a78`; CHN_SYNC `c98892f9f831c5a7b3c38f0c1fbe575cd4aae1cdd4fb193c51b84e45ef6ca742`; ADC_PKT `9761a3bbfe7296d056a6f61e69fb6b422ff1698506476af9b5720d7cdb74d867`.
- ADI third-party and PUB provenance are retained by the finalized design and module provenance records. Official-IP replacement remains a future integration task; `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`.
- Constraint: `DEFERRED_TO_TOP`; review SHA256 `8c9e8a91e6ed3a98be01a00e58892a3d82464c7e9bfdbdeab2834d6aa3b3e584`; dependency manifest SHA256 `e59d3202aba28824b15da4bf886fafabbf927686d8a9d8c6c5c5cfe9de08e87d`; no XDC and `VIVADO_RESOLUTION_NOT_RUN`.
- VMware preflight: `VMWARE_PREFLIGHT_PASS`, receipt SHA256 `8c60ba632f17e12f85494347d286a7af9c3d9e5591f1e29789c3e055771c15f8`.
- Verification: run `ADC_TOP_5919384c91544c329654ee2bbdc3d444`; VIF `f724cfdcbed1010b27cbc5c7a5245e68d928276af8c2651edd348f77ce1a243d`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; lint/simulation 0/0; 12/12 PASS; seed `20260730`; timeout `600`. This sixth fresh batch was explicitly authorized by the user beyond the default five.
- Sidecar: `.work\state\ADC_TOP_Release_Baseline.json`; roster: Lead `/root`, RTL `/root/adc_upk_rtl`, Simulation `/root/adc_upk_sim`, Constraint `/root/adc_upk_constraint`, Verification `/root/adc_upk_verify`, Docs `/root/adc_upk_release_docs`.
- PPA status: `HYPOTHESIS`; no Vivado synthesis/PPA observation.

## Next Task

- User-owned next action after `READY_FOR_VCS`: start the separate non-UVM SystemVerilog VCS/Verdi task. VCS is `NOT_RUN`; integrated XSIM, synthesis, implementation, timing closure, bitstream, and board validation are `NOT_RUN`.

## Distillation Status

- Knowledge candidate: NONE; no Wiki writeback or Archive publication is authorized.
