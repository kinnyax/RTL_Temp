<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_gap_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_SPEC_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>Current user approved formula-based replacement of the ADC_RXD packed gap LUT.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>62bc9f85b66f7a17f7796d26986a0b2fb475747e0d1650413ae93e84990cca7c</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_REVIEW>/root/adc_gap_design_review; 2026-08-17_FINAL_DESIGN_REVIEW_handoff.md; SHA256 edde586d16ee724e026f6cf8bb24151c2f2f085c42657780278c001d78e90eac; ACCEPTED</DESIGN_REVIEW>
  <FINALIZATION_STATUS>DESIGN_READY / AWAITING_COMPLETION_CONFIRMATION. The same reviewed design fingerprint was rechecked after Docs writes.</FINALIZATION_STATUS>
  <DECISIONS>v1.5 supersedes the packed-LUT representation with three unsigned 11-bit bases (16*n, 32*n, 64*n) and five formulas (64*n-48, 16*n-16, 64*n-96, 32*n-32, 64*n-64) for n=8..24. Phase selection and positive counter semantics are retained. User-owned RTL formatting/signal-name edits must be preserved during implementation.</DECISIONS>
  <SOURCES>Finalized design v1.5; current Design Author handoff SHA256 5e10cc59629d328eaa289a57d19359eaa784583c7bc8c3000890bb962c310664; accepted Final Design Review handoff; reused Evidence SHA256 233e6b4f6dc83cd672646280440e99e3e4d55348b434ff83d1af1ef0aee5c8bb; reused Architecture SHA256 418f3017fec788f30520591646115a54c77d174c5e30c452ae8608c9de95e4a6; reused v1.4 Author SHA256 2de1fc99281b7647abd0b0e3a5db1831828c2c9276545c12326aeb6b7f7f2f17.</SOURCES>
  <ASSUMPTIONS>NONE. No RTL-affecting open question remains.</ASSUMPTIONS>
  <PPA_INTENT>HYPOTHESIS; no synthesis measurement was performed.</PPA_INTENT>
  <MODEL_BOUNDARY>MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT.</MODEL_BOUNDARY>
  <LIFECYCLE_BOUNDARY>Prior v1.4 READY_FOR_VCS/VMware evidence is historical and non-applicable to v1.5 release acceptance because design bytes changed and an RTL delta is pending. No v1.5 RTL/TB/XDC edit, VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, bitstream, or board validation was performed here.</LIFECYCLE_BOUNDARY>
  <RESIDUAL_RISKS>Formula RTL is unimplemented/unverified. rtl-vibe must exhaustively check formula/table and phase equivalence for n=8..24, run scheduler/full regression, apply exact TB/constraint reuse gates, and perform fresh VMware sanity after RTL changes. Changes to legal range, gap sequence, phase mapping, counter/rebase, or compact-form requirement require new design revision/review.</RESIDUAL_RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_SPEC_handoff.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE: module-local readability choice; no authorized Wiki writeback.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT; then a scoped rtl-vibe implementation task for ADC_TOP.</NEXT_OWNER>
</DOCS_HANDOFF>
