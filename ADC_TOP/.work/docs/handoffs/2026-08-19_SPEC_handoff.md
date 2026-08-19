<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_fmt_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_SPEC_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>用户消息 2026-08-19：FRAME_FMT、SMP_PREC 用于把 AC9810 已送入 FPGA 的 16-bit 数据整理为软件所需格式；随后确认 FRAME_FMT=0 为 signed right-aligned 16-bit，FRAME_FMT=1 为 raw/lossless left-aligned 16-bit，并授权修改与后续 GitHub 上传。</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>95f274fa2cae62e09c6c9addc3bcfe5ac62d6490ad1d946b96bc844f5602e7ef</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_REVIEW>/root/adc_fmt_design_review; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_FINAL_DESIGN_REVIEW_handoff_02.md; SHA256 45be60c7164c465a5582afec2f876d2dc2f6c70e1d23037767353593519f38a9; ACCEPTED.</DESIGN_REVIEW>
  <PRE_REVIEW_CONTRIBUTOR_SET>Lead /root (orchestration-only; user decision source). Evidence Researcher /root/adc_decim_evidence: D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_EVIDENCE_RESEARCH_handoff.md SHA256 4931197b7291995be335d619f7fa8539fb652e8c59a15cc2d624d995bacc91d3. Architecture Analyst NOT_REQUIRED because the user selected the unique software-format mapping after primary evidence, leaving no material architecture option. Design Author /root/adc_fmt_design: D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_DESIGN_AUTHOR_handoff_02.md SHA256 edda7c3629abc98a1be45ed5042d154ae105f048d6c925f5eb80863174cc28e2. OPTION_CHALLENGE NOT_REQUIRED because the user-selected mapping is uniquely resolved by the software contract and primary N'=16 placement evidence. Docs is excluded as orchestration-only.</PRE_REVIEW_CONTRIBUTOR_SET>
  <FINAL_CONTRIBUTOR_SET>PRE_REVIEW_CONTRIBUTOR_SET plus independent Final Design Review Worker /root/adc_fmt_design_review and finalization Docs Worker /root/adc_fmt_design_docs. Final identity/hash uniqueness audit is mechanical and Lead-owned after this handoff closes.</FINAL_CONTRIBUTOR_SET>
  <DECISION_RECORD>For normalized N'=16 source word S, p=10/12/14 payload is S[15:6]/S[15:4]/S[15:2] and low remaining bits are zero. FRAME_FMT=0 creates a signed right-aligned 16-bit software value from that high-bit code. FRAME_FMT=1 preserves S bit-for-bit. SMP_PREC reports p=10/12/14 and does not program or mirror AC9810 CFG_DATA_MODE.</DECISION_RECORD>
  <SOURCES>AC9810-32 用户手册 v03 (2025-12-08), §3.4.9.2/Table 3-33/3-34, physical PDF pp.94-95 / printed pp.91-92; AC9810-32 寄存器手册 v03, CFG_DATA_MODE 0x104; chip-configuration/JESD framing workbooks; evidence handoff above.</SOURCES>
  <ASSUMPTIONS>Software configures matching two's-complement AC9810 p=10/12/14 output before the formatting epoch. p=16, sign-magnitude and unsigned input are excluded from v1.26.</ASSUMPTIONS>
  <INVALIDATED_EVIDENCE>All v1.25 mapping-dependent RTL, TB, VMware, independent RTL review, release/manifest mapping evidence, and any READY_FOR_VCS assertion are invalid for v1.26 because they model the superseded low-p-bit extraction. No v1.26 RTL/TB/XDC or verification result exists yet.</INVALIDATED_EVIDENCE>
  <PPA_INTENT>HYPOTHESIS</PPA_INTENT>
  <MODEL_BOUNDARY>No v1.26 RTL/TB/XDC edit, VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, bitstream, or board validation was performed by this Docs Worker.</MODEL_BOUNDARY>
  <RESIDUAL_RISKS>Packet headers omit FRAME_FMT and AC9810 coding metadata; downstream consumers require the software contract. Incorrect device width/coding configuration invalidates right-alignment semantics. RTL and TB must specifically detect low-slice, padding, sign, and reorder regressions.</RESIDUAL_RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_SPEC_handoff.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE. This is an unimplemented module-specific software-format contract; retain the evidence in current module state until fresh implementation/verification and separate authorization.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE. The user supplied the FPGA register polarity; primary AC9810 evidence establishes only normalized source placement and does not contradict that software interface decision.</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT: mechanically verify final contributor identity/hash set and start a fresh rtl-vibe implementation/verification/review/release workflow. Do not reuse v1.25 verification or release evidence.</NEXT_OWNER>
</DOCS_HANDOFF>
