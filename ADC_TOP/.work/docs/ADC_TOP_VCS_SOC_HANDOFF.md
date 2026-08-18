---
type: vcs_soc_handoff
module_name: ADC_TOP
date: 2026-08-18
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_unpack_review
accepting_review_handoff_sha256: 1cc90cb33603487bbfa3dc74c0fc85429d0a19e389867e284e065a7084a0d6e3
tags: [FPGA/VCS, Verification]
---

# ADC_TOP VCS SoC Verification Handoff

## Source Baseline

- Design v1.10 SHA256 `afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8`; `RTL_MODULE_CONTRACT_V1`, `VERILOG_2001_EXPLICIT_V1`, `MODIFIED_THIRD_PARTY_RTL`.
- ADC_RXD SHA256 `416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8`; TB/manifest SHA256 `d79a3f9e814950243feb44ccdee7967effcd7fb6fddd2cfd3297c94cb7468471` / `2373439d7cb4d6d906f339e313342d0ede5beda10f99281c8286ad80f974ba0d`.
- Constraint `DEFERRED_TO_TOP/EXTERNAL_ONLY`; review SHA256 `f369a63160feecf5276074762281b3dfe642f498935cb17b35c75de121f3e4d7`; dependency manifest SHA256 `895093b4dd32640aa77f4826d807068b3af7073d0d1070cf41ba20de4c8df25e`; `VIVADO_RESOLUTION_NOT_RUN`.
- User-authorized seventh VMware run `ADC_TOP_33bc74bdf97d4f17a739919f36ea22d7`, VIF `3fb3f3029656bddd3893d0e506b789738effa87f679402d3b61e8e37437717f1`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`, lint/sim `0/0`, 16/16 PASS, JUnit SHA256 `8888d486cb93e77e060f79af48c56222e7b82f2c6729467a8609e9ec8e418ced`.

## VCS Scope

- Methodology `NON_UVM_SYSTEMVERILOG_SOC`; intended tools VCS / Verdi.
- Recheck three-state RXD ownership, separate word-position/terminal timing blocks, reset/FIFO clear, scheduler maps, DDC recovery, AXI/AXIS backpressure and official-IP integration.
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; previous release evidence is stale.

## PPA, Risks And Status

- PPA `HYPOTHESIS`; no synthesis/timing observation exists.
- Intended final stage `READY_FOR_VCS`; user-owned VCS execution is `NOT_RUN`; a VCS pass advances to `VCS_SOC_VERIFIED`.
- Official FIFO/PHY equivalence and downstream Vivado/board phases remain unproved.
