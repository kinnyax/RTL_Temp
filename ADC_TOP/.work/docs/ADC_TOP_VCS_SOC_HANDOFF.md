---
type: vcs_soc_handoff
module_name: ADC_TOP
date: 2026-08-18
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_config_review
accepting_review_handoff_sha256: 00d32372a59918c9472327986313b18e61369b522dd334b2985716338a0f59bf
tags: [FPGA/VCS, Verification]
---

# ADC_TOP VCS SoC Verification Handoff

## Source Baseline

- Design v1.9 SHA256 `010556a566a6af24fa1dae3b7ab8ba2c487582487cd0760d3ee899a8f41f7ce2`; final design review `_11` SHA256 `c45b5d795601ec05c2ef0c1ae653a9a659be3093d03ec1c02a4f6cae8d24c4df`; contract/profile/class `RTL_MODULE_CONTRACT_V1` / `VERILOG_2001_EXPLICIT_V1` / `MODIFIED_THIRD_PARTY_RTL`.
- ADC_RXD SHA256 `0f465fdadb38dc16acbb5816b4d1a6c27e596e31c0328e828586e02dd0627275`; filelist SHA256 `76aa2d06650dc14aae941c422ef6a2d183be3cd0076386c84d8085aa44a0f648`; PUB manifest SHA256 `5b598ccd8fb78fe9360b960b14f0139bc738596d87783245421fab573af1d34c`.
- TB SHA256 `9cb39d4d605035aef500772fa8c6409c69e7e3f2bb32937fa256eb06a62f4486`; manifest SHA256 `4094d0b25d401bfe6cc1268e9e0690b94243c9bec4be6ec17f242f86abf0c5fc`.
- VMware `ADC_TOP_a068bcae19f94e85b1f32373b9e126f9`, VIF `b3c0cd58ffeaae731102a41cfa4ecca08d220b07670394b676f5728bd8ac7b74`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`, lint/sim `0/0`, 15/15 PASS, seed `20260818`, timeout `600`, cleanup PASS.
- Constraint `DEFERRED_TO_TOP` / `EXTERNAL_ONLY`; review SHA256 `55b1c8c4b3aff30bfbafb3f9dfaa38e8ac1bfbb060ca363cc205e02fd0355b25`; dependency manifest SHA256 `0a6ed286c4a575921822f65241f7c9f00c2442e8d88005a31dfcf02cbdc7c0e7`; `VIVADO_RESOLUTION_NOT_RUN`.

## VCS Scope

- Methodology `NON_UVM_SYSTEMVERILOG_SOC`; intended tools VCS / Verdi.
- Recheck v1.9 `adc_num`/`dec_num`/`ddc_num`/`skip_num` payload scheduling, pure-ADC sixteen-beat prefix, `rxd_clr` recovery, reset/FIFO clear, DDC recovery, AXI/AXIS backpressure, and official-IP integration with scoreboards/assertions.
- The static configuration contract is a software precondition: legal fields and stable configuration while active. Reserved/out-of-range values require no RTL behavior; VCS must not treat them as DUT error-recovery cases.
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; official FIFO/PHY replacement latency, reset, flags, lane-rate and electrical feasibility remain integration evidence.

## PPA, Risks And Status

- PPA `HYPOTHESIS`; no synthesis/timing observation exists.
- Intended final stage after review: `READY_FOR_VCS`; VCS execution/evidence: `NOT_RUN`; a VCS pass advances to `VCS_SOC_VERIFIED`.
- Integrated XSIM, synthesis, implementation, timing closure, bitstream and board validation are `NOT_RUN`.
