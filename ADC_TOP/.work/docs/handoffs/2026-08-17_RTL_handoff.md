---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-08-17
verification_status: REVIEW_PENDING
accepting_review_agent_id: ACCEPTING_REVIEW_AGENT_ID
accepting_review_handoff_sha256: ACCEPTING_REVIEW_HANDOFF_SHA256
tags: [FPGA/Handoff, RTL]
---
# ADC_TOP RTL Handoff

## Scope And Changed Baseline

- Root: `D:\Codex\RTL_Temp\ADC_TOP`; design v1.5 SHA256 `62bc9f85b66f7a17f7796d26986a0b2fb475747e0d1650413ae93e84990cca7c`; accepted design review SHA256 `edde586d16ee724e026f6cf8bb24151c2f2f085c42657780278c001d78e90eac`.
- `RTL_MODULE_CONTRACT_V1` / `VERILOG_2001_EXPLICIT_V1` / `MODIFIED_THIRD_PARTY_RTL`.
- `ADC_RXD.v` SHA256 `a2203f25f6ecf3c2cc568d6c912db3510543cdee08f98e71ac03dd1ef380a217`: former packed LUT is replaced by 3 unsigned 11-bit bases and 5 exact formulas. User indentation remains preserved; other RTL/ADI/PUB unchanged. PUB manifest SHA256 `5b598ccd8fb78fe9360b960b14f0139bc738596d87783245421fab573af1d34c`.

## Reuse And Evidence

- TB `test_ADC_TOP.py` SHA256 `3222ed83e0a27ac8961123d1a4f003d8398ade91f4155607ea46cb2397d51967`; manifest SHA256 `c1a7097d1af661b8fe767c768ecb8c1b32dfb593174ed47a978ddb6e14d3698e`. Reuse is valid because interfaces/behavior/test intent remain unchanged and scheduler matrix directly covers formula branches.
- Preflight PASS, receipt SHA256 `058f2289e1c91791599f2b3a32a741de8c897cc2c2b2cb0650fa3462afe82e31`. Fresh bundled VMware run `ADC_TOP_451c77448cea4cdf831b2fad5b3cefab`, VIF `9a62cdd2c66cba0010663447a9818f2cd5fb4463d1c3a5d3ccedd2544e43df00`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`: 13/13 PASS, lint/sim 0/0, 183.214893 s, cleanup PASS; evidence `.work\verification\sim`.
- Constraint review SHA256 `02c08ff4ce9ba5b70b880e12ec566b3c2addb620aaa1f204f1ca197280148a2`; dependency manifest SHA256 `8cc282ae0b97376ac9b1cc9c7f144a08dda336cdf6738f5ff75ce77f282d139e`; `DEFERRED_TO_TOP`, `EXTERNAL_ONLY`, `VIVADO_RESOLUTION_NOT_RUN`.

## Status And Next Task

- Sidecar `.work\state\ADC_TOP_Release_Baseline.json` is `REVIEW_PENDING`; patch `.work\state\ADC_TOP_Finalization_Patch.json` alone converts frontmatter after acceptance. Roster is Lead `/root`; contributors `/root/adc_gap_rtl`, `/root/adc_unpack_sim`, `/root/adc_gap_constraint`, `/root/adc_gap_verify`, `/root/adc_gap_docs`; Review must remain distinct.
- Intended final stage `READY_FOR_VCS`; PPA `HYPOTHESIS`; `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`. VCS/Verdi, XSIM, synthesis, implementation, timing closure, bitstream, and hardware are `NOT_RUN`.
- User-owned next action: `NON_UVM_SYSTEMVERILOG_SOC` VCS/Verdi verification. Knowledge candidate: `NONE`.
