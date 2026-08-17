<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_upk_design_docs2</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_SPEC_handoff_03.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>Current 2026-08-14 conversation: user approved the proposed rational ADC_RXD refactor, required positive increment-only counting rather than a decrement/countdown form, required compact naming consistent with their current RTL edits, and requested deletion-first fixed-configuration unpack logic while retaining correct mapping, software-visible status, and software-owned recovery.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>a3a1f7d9ec91236f1d73e9164fc12161d4b6fc1ff1b11fab05aa229d9a784622</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_CONTRACT_PRECHECK>PASS: DESIGN_CONTRACT_PRECHECK_PASS for the exact v1.2 design fingerprint.</DESIGN_CONTRACT_PRECHECK>
  <DESIGN_REVIEW>/root/adc_upk_design_review2, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_FINAL_DESIGN_REVIEW_handoff_07.md, SHA256 fb282d5987b724873f6ffcf227bc6779983b6e7ff708020623f4887489a73005, ACCEPTED</DESIGN_REVIEW>
  <PRE_REVIEW_CONTRIBUTOR_SET>Lead /root; Evidence Researcher /root/adc_upk_evidence, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-13_EVIDENCE_RESEARCH_handoff.md, SHA256 233e6b4f6dc83cd672646280440e99e3e4d55348b434ff83d1af1ef0aee5c8bb; Architecture Analyst /root/adc_upk_arch, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_04.md, SHA256 0e28b4dfcf5a29319990201a860be49f896fc27f49251d45890f5ef40fa68beb; Design Author /root/adc_upk_design_author2, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_DESIGN_AUTHOR_handoff_07.md, SHA256 d30db7f806c2c4a8bce9d57fb4e3ec5b361efeaaf4b3a741f25343742c086870.</PRE_REVIEW_CONTRIBUTOR_SET>
  <FINAL_CONTRIBUTOR_SET>PRE_REVIEW_CONTRIBUTOR_SET plus Final Design Review /root/adc_upk_design_review2 and Docs Worker /root/adc_upk_design_docs2. All identities are distinct. Option Challenge is NOT_REQUIRED because the user selected the reviewed architecture hybrid.</FINAL_CONTRIBUTOR_SET>
  <DECISIONS>Preserve current user RTL naming/format edits; use short semantic names and *_r registers; keep encoded ADI state local to jesd_clk and cross only decoded independent status; move private link_ready JESD-to-AFE CDC into ADC_RXD; retain ADC-facing crossings in CHN_SYNC; define upk_vld; use SOMF[0] plus positive prefix-beat accumulation and a 64-bit positive next-terminal scheduler; delete generic marker/non-aligned and multi-terminal tree paths; retain all legal pure ADC/decimation/DDC maps, 384-bit history, mid-beat slices, DDC two-slot admission/abort, PUB WC=0 FIFO behavior, and software-only disable/clear/relink recovery.</DECISIONS>
  <SOURCES>Accepted Evidence, Architecture, Design Author, and Final Design Review handoffs listed above; finalized design v1.2; current user decisions in this conversation.</SOURCES>
  <ASSUMPTIONS>Static configuration remains stable while the channel is effectively enabled; RMU provides safe domain-reset release; software follows FIFO implementation convergence/empty requirements after clear; 64-bit natural scheduler wrap is outside practical continuous acquisition.</ASSUMPTIONS>
  <PPA_INTENT>HYPOTHESIS: v1.2 replaces the encoded-state CDC and wide positional/terminal compare network with source-decoded single-bit CDC, positive prefix counting, one scheduler and a small gap mux, while retaining the necessary history window and slices. No synthesis evidence exists.</PPA_INTENT>
  <MODEL_BOUNDARY>MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT. ADI/PUB source is not official Vivado PHY/FIFO equivalence. No RTL/TB/XDC, VMware, VCS/Verdi, XSIM, synthesis, implementation, timing, bitstream, or board verification was performed for v1.2.</MODEL_BOUNDARY>
  <RISKS>Fresh implementation must prove scheduler table fidelity and every legal block-end offset, DDC I/Q/abort cases, FIFO WC=0 behavior, reset/clear recovery and first-board ILAS/controller mapping. Prior READY_FOR_VCS evidence is historical/non-applicable because both contract and user-edited RTL changed.</RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_SPEC_handoff_03.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE: no separate Wiki or Archive write authorization was granted.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <NEXT_TASK>Fresh rtl-vibe implementation and VMware lint/simulation for exact design v1.2, followed by independent implementation review before READY_FOR_VCS.</NEXT_TASK>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</DOCS_HANDOFF>
