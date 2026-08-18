<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_style_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_SPEC_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>Current user request: preserve the manually edited ADC_RXD calculation and naming direction; use RXD_IDLE/RXD_PREF/RXD_PAYL, dec_fra, upk_trig, pref_fra/pref_del/pref_num, concise ternary combinational expressions, and split the sequential scheduler into word_pos_r-only plus next_term_r/term_phase_r ownership. Software guarantees legal, stable static configuration.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_REVIEW>/root/adc_style_design_review; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_FINAL_DESIGN_REVIEW_handoff.md; SHA256 5f8744e23c4c3615837d0aec07d6a0be5ac5d76fbd882428c9d3e4a15c2dff0c; ACCEPTED</DESIGN_REVIEW>
  <FINALIZATION_STATUS>DESIGN_READY / AWAITING_COMPLETION_CONFIRMATION. Docs-only writes do not change the reviewed design fingerprint.</FINALIZATION_STATUS>
  <DECISIONS>v1.10 preserves the accepted three-clock/reset architecture and user-managed legal/static configuration. It freezes the stated naming, assign/ternary combinational-form preference, marker-inclusive positive prefix arithmetic, and the separate sequential owners: prefix_beat_r; word_pos_r; next_term_r plus term_phase_r.</DECISIONS>
  <SOURCES>Finalized design v1.10; Design Author handoff SHA256 c68085c4a4356fedbfa2a030b65ec0ecf43488d76125e2fc903f347304fcb45f; independent final Design Review handoff SHA256 5f8744e23c4c3615837d0aec07d6a0be5ac5d76fbd882428c9d3e4a15c2dff0c; reused evidence and architecture contributors exactly as recorded by the final Review handoff.</SOURCES>
  <ASSUMPTIONS>Software programs only legal static configuration and holds it stable while the RXD path is active. No RTL-affecting open question remains.</ASSUMPTIONS>
  <PPA_INTENT>HYPOTHESIS; concise selection logic and separated sequential ownership improve reviewability. No synthesis measurement was performed.</PPA_INTENT>
  <MODEL_BOUNDARY>MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT.</MODEL_BOUNDARY>
  <LIFECYCLE_BOUNDARY>User-manual ADC_RXD RTL edits are unverified. All prior RTL review, VMware sanity, release-sidecar and READY_FOR_VCS evidence is historical and non-applicable to the v1.10/current-RTL acceptance baseline. No RTL/TB/XDC edit, lint, simulation, VMware sanity, VCS/Verdi, Vivado/XSIM, synthesis, implementation, bitstream, or board validation was performed by this Docs Worker.</LIFECYCLE_BOUNDARY>
  <RESIDUAL_RISKS>rtl-vibe must preserve the manual RTL calculations/naming, reconcile declarations and syntax, implement the v1.10 sequential split, perform fresh independent RTL review, and run lint plus VMware sanity. Software remains responsible for legal/stable static configuration and recovery orchestration outside this contract.</RESIDUAL_RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_SPEC_handoff.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE: module-local implementation style and signal naming change; no authorized reusable knowledge change.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT; then a scoped rtl-vibe implementation task for ADC_TOP.</NEXT_OWNER>
</DOCS_HANDOFF>
