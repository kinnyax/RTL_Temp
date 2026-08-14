<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_reset_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-12_SPEC_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>Current-task clarification: the former 5 ms FIFO_CLR assertion and recovery waits were an informal BRAM-FIFO example, not a contract. Use the selected FIFO implementation's required clear cycles/convergence and stable FIFO_EMPTY; ADC_TOP RTL must contain no fixed wall-clock timer.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Chat\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>bd97a436bcaada0d7a278e57a33748d7fa8cb5452c4cb0f8995b0429707bc3d9</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_CONTRACT_PRECHECK>PASS</DESIGN_CONTRACT_PRECHECK>
  <DESIGN_REVIEW>/root/adc_reset_design_review; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-12_FINAL_DESIGN_REVIEW_handoff_02.md; SHA256=f4053c1520a3000bc74f102bbabcfea47eaa5d9ab012de1a87a64adac2cd5633; ACCEPTED</DESIGN_REVIEW>
  <PRE_REVIEW_CONTRIBUTOR_SET>Lead /root; Design Author /root/adc_reset_design_author, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-12_DESIGN_AUTHOR_handoff_02.md, SHA256=28070a2739ff3f90572fa560123de41f857925568ced2b93355907629b4cfd27. Evidence Researcher, Architecture Analyst, and OPTION_CHALLENGE were NOT_REQUIRED because no evidence or architectural decision changed.</PRE_REVIEW_CONTRIBUTOR_SET>
  <FINAL_CONTRIBUTOR_SET>Lead /root; Design Author /root/adc_reset_design_author; final Design Review /root/adc_reset_design_review; Docs Worker /root/adc_reset_design_docs. All identities are distinct.</FINAL_CONTRIBUTOR_SET>
  <DECISIONS>Fixed 5 ms FIFO clear/recovery timing is non-contractual and replaced by selected-FIFO documented reset/clear assertion cycles, convergence, and stable FIFO_EMPTY. Both FIFO clocks must run while clear is performed. Retained: three reset domains, external RMU release, fifo_rst_n=afe_rst_n &amp; adc_rst_n &amp; ~fifo_clr, full-FIFO clear on either AFE or ADC reset, and no old/new data mixing.</DECISIONS>
  <ASSUMPTIONS>Exact numeric clear and recovery periods are intentionally outside ADC_TOP. They must be derived from each selected FIFO implementation and recorded by implementation/integration verification.</ASSUMPTIONS>
  <PPA_INTENT>No quantified PPA change is claimed. Avoiding an RTL wall-clock timer keeps the control contract implementation-agnostic.</PPA_INTENT>
  <MODEL_BOUNDARY>MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT. PUB FIFO behavior does not establish official Vivado FIFO/IP equivalence; SYSTEM_XSIM must close that boundary.</MODEL_BOUNDARY>
  <RESIDUAL_RISKS>Minimum clear assertion/recovery cycles are not yet observed for PUB or official FIFO. Independent AFE or ADC reset intentionally drops buffered data. RTL/TB, VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, bitstream, and board validation were not performed for this active design baseline.</RESIDUAL_RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-12_SPEC_handoff.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE. No separate Wiki or Archive write authorization was supplied; the correction is recorded in the existing module design contract and this continuity record.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE. The active design and accepted final review consistently remove only the old fixed-time FIFO clear requirement; historical 5 ms material is not active evidence for this baseline.</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</DOCS_HANDOFF>
