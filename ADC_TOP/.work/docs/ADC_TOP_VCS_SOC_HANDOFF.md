---
type: vcs_soc_handoff
module_name: ADC_TOP
date: 2026-08-14
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_upk_release_review
accepting_review_handoff_sha256: 5f540a8f860bb02113a010db275703ac2a59bd87faf3297c14586bed2ae7cb9d
tags:
  - FPGA/VCS
  - Verification
---

# ADC_TOP VCS SoC Verification Handoff

## Source Baseline

- Design v1.1: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `ca40cd68dcc207c2a7f876075bdc3f92198a6e43814cb3774508bb07002016f9`; `RTL_MODULE_CONTRACT_V1`, `VERILOG_2001_EXPLICIT_V1`, `MODIFIED_THIRD_PARTY_RTL`.
- Frozen RTL: ADC_RXD `26aa5811127ba977cde8d86e2a7d63f6a86c370eb1bdc01df87f4125a96c8571`; ADC_CHN `30f1eb0d7c51540a9c222df310f39d581f97d4268e454dcb541ecd1d161f9a78`; CHN_SYNC `c98892f9f831c5a7b3c38f0c1fbe575cd4aae1cdd4fb193c51b84e45ef6ca742`; ADC_PKT `9761a3bbfe7296d056a6f61e69fb6b422ff1698506476af9b5720d7cdb74d867`. TB `3e475026a933d5ac23639c581b34728f56e751303aaa921d4055e0dd966cd321`; manifest `221c9d6f4eb78acd0c8bb6046ad70f363f2af0ca5a5bd050be4defea16ad02da`.
- VMware run `ADC_TOP_5919384c91544c329654ee2bbdc3d444`: VIF `f724cfdcbed1010b27cbc5c7a5245e68d928276af8c2651edd348f77ce1a243d`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; lint/simulation exit 0/0; 12/12 PASS; seed `20260730`; timeout `600`. It is the user-authorized sixth fresh batch.
- Constraint `DEFERRED_TO_TOP`; review `8c9e8a91e6ed3a98be01a00e58892a3d82464c7e9bfdbdeab2834d6aa3b3e584`; dependency manifest `e59d3202aba28824b15da4bf886fafabbf927686d8a9d8c6c5c5cfe9de08e87d`; no XDC and `VIVADO_RESOLUTION_NOT_RUN`.

## Boundary And User-Owned Next Action

- ADI/PUB provenance is recorded in the finalized design and module records. `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; official-IP latency/reset/flag behavior and topology constraints remain unproved.
- This `READY_FOR_VCS` handoff starts the user-owned separate `NON_UVM_SYSTEMVERILOG_SOC` VCS/Verdi task. Re-prove reset, FIFO-clear, AXI/AXIS backpressure, link recovery, packets, normal configurations, and official-IP behavior with scoreboards/assertions.
- VCS execution/evidence is `NOT_RUN`; integrated XSIM, synthesis, implementation, timing closure, bitstream, and board validation are `NOT_RUN`.
