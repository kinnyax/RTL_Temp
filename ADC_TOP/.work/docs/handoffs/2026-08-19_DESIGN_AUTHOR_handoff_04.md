<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_rework_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_DESIGN_AUTHOR_handoff_04.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>User decision relayed by Lead, 2026-08-19: former ADC_JESD204 wrapper is ADC_RXD; former ADC_RXD unpack implementation is ADC_UPK; ADC_CHN connects the AFE-domain tuple. All v1.27 behavioral decisions remain frozen.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>26689c1a13cf041eebe78b3680af7c23255266fb60b303dfd819ff0c74bb5cd2</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>Deterministic RTL_MODULE_CONTRACT_V1 precheck PASS: schema/frontmatter, sections 2–20 and all checklist items pass.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>v1.28 exact module/file naming correction: ADC_RXD owns ADI/JESD wrapper; ADC_UPK owns unpack/map/DDC/FIFO request; ADC_CHN connects the AFE tuple.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC/verification work was performed. All v1.27 and earlier RTL/TB/review/VMware evidence is invalid for v1.28. ADC_TGC full-register/internal-decode refactor remains separately incomplete.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck routing and independent Design Review.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
