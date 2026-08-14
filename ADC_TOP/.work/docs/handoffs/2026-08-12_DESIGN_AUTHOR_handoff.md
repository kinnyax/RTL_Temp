<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_reset_design_author</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-12_DESIGN_AUTHOR_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>Current-task user decision supplied by Lead: retain the three-clock architecture; make reset ownership one-to-one by clock domain; set fifo_rst_n=afe_rst_n &amp; adc_rst_n &amp; ~fifo_clr; preserve 5 ms FIFO clear protocol and ADI 160 MHz link / 40 MHz device relation; record approved default_nettype file-envelope exception.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Chat\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>a3235402e90da5fca6b632c9dc66d4982f4832a2665f7c2b6eeb53c94fee7b57</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>PASS: front matter has RTL_MODULE_CONTRACT_V1, status=finalized, rtl_profile=VERILOG_2001_EXPLICIT_V1, implementation_class=MODIFIED_THIRD_PARTY_RTL, v0.7 dated 2026-08-12; sections 2 through 20 present; all 23 Pre-RTL checklist entries checked; deterministic validate_design_contract.py returned DESIGN_CONTRACT_PRECHECK_PASS for the recorded fingerprint.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>NONE</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE. The selected reset ownership, CDC reset mapping, FIFO reset behavior, software clear timing, and ADI clock relation are fully specified.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. The previous v0.5/v0.6 AFE-domain reset rule is retained solely as superseded revision history; v0.7 explicitly replaces it.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>Any AFE or ADC reset intentionally discards that FIFO's stored data to prevent old/new-data mixing. This design document change has not run RTL/TB, VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, bitstream, or board validation. Vendor FIFO equivalence remains NON_VENDOR_EQUIVALENT until official-IP SYSTEM_XSIM evidence.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck confirmation and independent final Design Review routing.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
