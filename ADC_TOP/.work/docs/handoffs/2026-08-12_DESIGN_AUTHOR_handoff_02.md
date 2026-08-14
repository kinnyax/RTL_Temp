<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_reset_design_author</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-12_DESIGN_AUTHOR_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>Current-task user clarification supplied by Lead: the former 5 ms FIFO_CLR assertion and post-release waits were an informal BRAM-FIFO experience example, not an absolute requirement. Replace all fixed-time requirements with implementation-derived clock/status protocol; RTL must not implement a 5 ms timer. Preserve every other v0.7 reset-domain decision.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Chat\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>bd97a436bcaada0d7a278e57a33748d7fa8cb5452c4cb0f8995b0429707bc3d9</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>PASS: status=finalized; sections 2 through 20 present; all 23 Pre-RTL checklist entries checked; validate_design_contract.py returned DESIGN_CONTRACT_PRECHECK_PASS for the recorded exact bytes.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>User-directed behavioral clarification: removed every normative fixed/at-least 5 ms FIFO_CLR hold and recovery wait. Software must disable and observe AFE_IDLE, keep both FIFO clocks running, assert clear for the selected FIFO's documented requirement, deassert, then wait for reset/clear convergence and stable FIFO_EMPTY. PUB and official Vivado FIFO exact minimum periods are explicitly implementation/integration evidence obligations.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE for ADC_TOP RTL behavior or verification acceptance. Exact numeric clear cycles are intentionally not an ADC_TOP contract value; the selected FIFO implementation and integration evidence own their derivation and validation.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. This user clarification supersedes only the fixed 5 ms text in the prior candidate; it does not alter reset ownership, CDC reset mapping, FIFO reset formula, register map, or data behavior.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>Until each FIFO implementation is selected and evidenced, its exact minimum reset/clear assertion and recovery cycles remain unobserved implementation evidence, not a fixed ADC_TOP requirement. No RTL/TB, VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, bitstream, or board validation was run for this documentation correction.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for independent final Design Review routing against the new fingerprint.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
