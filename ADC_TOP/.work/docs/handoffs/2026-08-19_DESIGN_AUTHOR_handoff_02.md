<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_fmt_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_DESIGN_AUTHOR_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>用户消息 2026-08-19：确认 FRAME_FMT、SMP_PREC 是 FPGA 对 AC9810 已传递 16-bit 数据的 software-format requirement；随后确认 FRAME_FMT=0 为 right-aligned signed 16-bit、FRAME_FMT=1 为 left-aligned lossless 16-bit，并授权修改和后续 GitHub 上传。</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>95f274fa2cae62e09c6c9addc3bcfe5ac62d6490ad1d946b96bc844f5602e7ef</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>PASS: RTL_MODULE_CONTRACT_V1 frontmatter is finalized/v1.26; all Module_Schema sections and pre-RTL checklist remain present. Deterministic validator returned DESIGN_CONTRACT_PRECHECK_PASS for the exact fingerprint.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>USER_SEMANTIC_REVISION: Replaced the v1.25 low-bit 10/12/14 extraction rule. The v1.26 contract freezes normalized N'=16 source words: p=10/12/14 payloads are S[15:6]/S[15:4]/S[15:2]; FRAME_FMT=0 sign-extends that high-bit code to a right-aligned 16-bit word; FRAME_FMT=1 returns raw S bit-for-bit. It also freezes SMP_PREC header semantics, static software/device configuration precondition, and six-combination high-bit-sensitive verification acceptance.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE. The user explicitly supplied the FPGA FRAME_FMT polarity and SMP_PREC software contract. The design marks AC9810 device programming, p=16, sign-magnitude, and unsigned as outside this revision rather than unresolved behavior.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. The primary manual defines N'=16 padding but not FPGA register polarity; the user-supplied software contract resolves that boundary without contradicting the device evidence.</CONFLICT_REPORT>
  <SOURCES>AC9810-32 用户手册 v03 (2025-12-08), physical PDF pp.94-95 / printed pp.91-92, §3.4.9.2/Table 3-33/3-34; AC9810-32 寄存器手册 v03, CFG_DATA_MODE 0x104; AC9810 chip-configuration and JESD framing workbooks; Evidence Researcher handoff D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_EVIDENCE_RESEARCH_handoff.md SHA256 4931197b7291995be335d619f7fa8539fb652e8c59a15cc2d624d995bacc91d3.</SOURCES>
  <INVALIDATED_EVIDENCE>All v1.25 mapping-dependent RTL, TB, independent review, VMware sanity, release/manifest, and prior READY_FOR_VCS claim are invalid for v1.26. No RTL, TB, XDC, verification, VMware, VCS/Verdi, synthesis, implementation, or board action was performed by this worker.</INVALIDATED_EVIDENCE>
  <RESIDUAL_RISKS>Right alignment assumes the software-configured AC9810 source is two's-complement and its device width equals SMP_PREC p=10/12/14. FRAME_FMT/SMP_PREC do not program or report CFG_DATA_MODE/cfg_data_type. p=16, sign-magnitude, and unsigned require a future design revision before implementation.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for final independent design review of the exact v1.26 fingerprint, then a separate rtl-vibe implementation/reverification/release workflow.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
