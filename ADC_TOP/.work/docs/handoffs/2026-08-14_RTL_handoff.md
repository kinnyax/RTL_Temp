---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-08-14
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_upk_release_review
accepting_review_handoff_sha256: 5f540a8f860bb02113a010db275703ac2a59bd87faf3297c14586bed2ae7cb9d
tags:
  - FPGA/Handoff
  - RTL
---

# ADC_TOP RTL Handoff

## Frozen Baseline

- Design v1.1 SHA256 `ca40cd68dcc207c2a7f876075bdc3f92198a6e43814cb3774508bb07002016f9`; `RTL_MODULE_CONTRACT_V1`; `VERILOG_2001_EXPLICIT_V1`; `MODIFIED_THIRD_PARTY_RTL`.
- ADC_RXD `26aa5811127ba977cde8d86e2a7d63f6a86c370eb1bdc01df87f4125a96c8571`; ADC_CHN `30f1eb0d7c51540a9c222df310f39d581f97d4268e454dcb541ecd1d161f9a78`; CHN_SYNC `c98892f9f831c5a7b3c38f0c1fbe575cd4aae1cdd4fb193c51b84e45ef6ca742`; ADC_PKT `9761a3bbfe7296d056a6f61e69fb6b422ff1698506476af9b5720d7cdb74d867`.
- ADI/PUB provenance is recorded by the design and module records. `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; no vendor-equivalence claim is made.

## Evidence And Classification

- VMware run `ADC_TOP_5919384c91544c329654ee2bbdc3d444`, VIF `f724cfdcbed1010b27cbc5c7a5245e68d928276af8c2651edd348f77ce1a243d`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`: lint/simulation 0/0; 12/12 PASS; seed `20260730`; timeout `600`. User explicitly authorized this sixth batch beyond the default five.
- Constraints are `DEFERRED_TO_TOP`; review SHA256 `8c9e8a91e6ed3a98be01a00e58892a3d82464c7e9bfdbdeab2834d6aa3b3e584`; no XDC and `VIVADO_RESOLUTION_NOT_RUN`.

## Next Action

- Final stage: `READY_FOR_VCS`. The user owns the subsequent VCS/Verdi SoC verification task; VCS, integrated XSIM, synthesis, implementation, timing closure, bitstream, and board validation are `NOT_RUN`; PPA status is `HYPOTHESIS`.

## Knowledge Candidate

- NONE; no knowledge writeback or publication is authorized.
