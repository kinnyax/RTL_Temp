<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_accum_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_SPEC_handoff_03.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>User-selected Option A, preserved through the accepted v1.15 design: no duplicate word; dec/ddc beat-region FSM and two-beat accumulator; zero-beat bypass; block-granular DDC; normal shutdown distinct from DDC abort.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>84315b234a46d6313025f3ec1212b19c6fa6adc06a92cda50f61ec9abf046160</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_REVIEW>/root/adc_accum_design_review; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_FINAL_DESIGN_REVIEW_handoff_06.md; SHA256 333491beb4e878439950b563e8707f1107353dcfdd93fb8a0818681f1c178f2b; ACCEPTED.</DESIGN_REVIEW>
  <PRE_REVIEW_CONTRIBUTOR_SET>Lead /root. Evidence Researcher /root/adc_decim_evidence: 2026-08-18_EVIDENCE_RESEARCH_handoff_05.md SHA256 47f70fe8389ceeb6090523fb0e2ec788208f93dc5ef8740951add48d016f3dc8 and _06.md SHA256 c5a778d2b8617895704282b4403fb6e1602bc70428565d1be4575e678ab88837. Architecture Analyst /root/adc_accum_arch2: 2026-08-18_ARCHITECTURE_handoff_04.md SHA256 bbe4c53d0d7c9ebd5aa0f9f7d6e3dc5863eee16d2c77bbf896226d0f9a246140. Design Author /root/adc_accum_design: 2026-08-18_DESIGN_AUTHOR_handoff_04.md SHA256 23f8d2362185cf0314a25081cc5eeaba52bac506ff9b831ebb5824dc5f4f6455, _05.md SHA256 541caab446dc9f558b1c624adea1b737e88e2ff520a7a7ab1fe72a15156daaab, and _06.md SHA256 b6648cd563ebd1d69a988766cac8d7176103146877b99c212f4a23932767ad01. Blocked /root/adc_accum_arch produced no artifact and is not a contributor.</PRE_REVIEW_CONTRIBUTOR_SET>
  <FINAL_CONTRIBUTOR_SET>PRE_REVIEW_CONTRIBUTOR_SET plus independent Final Design Review Worker /root/adc_accum_design_review and finalization Docs Worker /root/adc_accum_design_docs. Final identity/hash uniqueness check is owned by the Lead after this handoff closes.</FINAL_CONTRIBUTOR_SET>
  <DECISION_RECORD>The accepted v1.15 design selects the dec/ddc beat-region FSM and two-beat accumulator. The user correction forbids duplicate words. The user-confirmed duplicate deviation remains labelled as a SPEC deviation rather than a primary-source FACT. Earlier absolute/head/window/slice behavior is not the current design.</DECISION_RECORD>
  <INVALIDATED_EVIDENCE>All earlier READY_FOR_VCS, v1.12 RTL, VMware sanity, and review evidence is historical and invalid for v1.15 behavior. No v1.15 RTL/TB/XDC or v1.15 verification result exists.</INVALIDATED_EVIDENCE>
  <PPA_INTENT>HYPOTHESIS</PPA_INTENT>
  <MODEL_BOUNDARY>VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, bitstream, and board validation are NOT_RUN for v1.15. No model-equivalence or vendor-equivalence claim is made.</MODEL_BOUNDARY>
  <RESIDUAL_RISKS>Board lane-rate/electrical feasibility and a future conflict between primary evidence and the user-confirmed duplicate deviation remain outside the accepted design baseline.</RESIDUAL_RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_SPEC_handoff_03.md; D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>After implementation validation and only with user authorization, consider combining the confirmed user RTL preferences with the rtl-vibe RTL schema in the appropriate reusable knowledge target. Do not write Wiki, Archive, or skills now.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE. The user-confirmed no-duplicate preference is deliberately retained as a documented SPEC deviation, not elevated to a primary-source FACT.</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT: recompute the design SHA256, perform final contributor identity/path/hash audit, retain WORKFLOW_STATUS=AWAITING_COMPLETION_CONFIRMATION, and on user confirmation recommend a fresh rtl-vibe task.</NEXT_OWNER>
</DOCS_HANDOFF>
