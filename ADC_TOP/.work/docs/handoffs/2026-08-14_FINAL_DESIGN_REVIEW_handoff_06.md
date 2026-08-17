<DESIGN_REVIEW_HANDOFF>
  <AGENT_ID>/root/adc_upk_design_review2</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_FINAL_DESIGN_REVIEW_handoff_06.md</HANDOFF_PATH>
  <STATUS>REJECTED</STATUS>
  <PRE_REVIEW_CONTRIBUTOR_SET>
    <ITEM>Lead: /root</ITEM>
    <ITEM>Evidence Researcher: /root/adc_upk_evidence, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-13_EVIDENCE_RESEARCH_handoff.md, SHA256 233e6b4f6dc83cd672646280440e99e3e4d55348b434ff83d1af1ef0aee5c8bb</ITEM>
    <ITEM>Architecture Analyst: /root/adc_upk_arch, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_04.md, SHA256 0e28b4dfcf5a29319990201a860be49f896fc27f49251d45890f5ef40fa68beb</ITEM>
    <ITEM>Design Author: /root/adc_upk_design_author2, D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_DESIGN_AUTHOR_handoff_06.md, SHA256 f1418e8cb3813f4d0f4ce9ba85fb2681c87751cc412be487dc35478dcf851fc6</ITEM>
  </PRE_REVIEW_CONTRIBUTOR_SET>
  <ROLE_SEPARATION_AUDIT>PASS: Review agent /root/adc_upk_design_review2 is distinct from every complete pre-review contributor. Supplied roster includes the previously omitted Evidence Researcher with verified matching handoff hash.</ROLE_SEPARATION_AUDIT>
  <REVIEW_STAGE>FINAL_DESIGN</REVIEW_STAGE>
  <REVIEWED_DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</REVIEWED_DESIGN_PATH>
  <REVIEWED_DESIGN_BASELINE_FINGERPRINT>6b4cb21b5c62d887734e54ae73690de537cb3ae3d0edde4b65f7d166c29a8d0d</REVIEWED_DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_CONTRACT_PRECHECK>PASS: independently ran validate_design_contract.py against the exact reviewed bytes; DESIGN_CONTRACT_PRECHECK_PASS and SHA256 equals 6b4cb21b5c62d887734e54ae73690de537cb3ae3d0edde4b65f7d166c29a8d0d.</DESIGN_CONTRACT_PRECHECK>
  <EXTERNAL_BASELINE_PROVENANCE_AUDIT>NOT_APPLICABLE: reviewed bytes are a Design Author semantic revision, not an unchanged external baseline.</EXTERNAL_BASELINE_PROVENANCE_AUDIT>
  <BLOCKING_FINDINGS>
    <FINDING severity="BLOCKER" owner="Design Author">ADC_TOP_Design.md:477 says `word_pos_r` advances by 8 and wraps by the current mode period, while lines 478-480 and the frozen table at 491-507 define `next_term_r` as an epoch-absolute 64-bit monotonically increasing position and explicitly prohibit implicit rebase. Periodic wrap of word_pos_r would make the equality check against an absolute next_term_r cease to match after the first period. Define one model only. The selected positive absolute scheduler requires `word_pos_r` to remain monotonic with `next_term_r` until the documented 64-bit natural wrap, not wrap at P.</FINDING>
    <FINDING severity="BLOCKER" owner="Design Author">ADC_TOP_Design.md:46 and 970 retain stale lifecycle statements that v1.1 is the unique next rtl-vibe input / finalized design contract awaiting review. The reviewed document is v1.2 and its v1.2 mapping changes implementation behavior. Replace those statements with v1.2 or remove the stale lifecycle copy so downstream rtl-vibe cannot select the superseded contract.</FINDING>
  </BLOCKING_FINDINGS>
  <EVIDENCE_AND_OPTION_AUDIT>PASS subject to the above correction. The exact frozen table at lines 491-507 now supplies payload units, D(d), first terminal, all positive gap sequences, DDC I/Q phases, invalid configurations, reset/re-arm behavior and 0..7 slice relation. Its gap sums equal the listed periods, and every minimum gap remains at least 16 for legal n=8..24. The table preserves the evidence-based aligned payload start and mid-beat completion boundary. All stale JESD_STATE/JESD_STA register and polling references scan cleanly; LINK_STA exposes only source-decoded single-bit LINK_READY, independent PHY summaries and reserved bits.</EVIDENCE_AND_OPTION_AUDIT>
  <MODULE_SCHEMA_AUDIT>Structural precheck PASS. Clocks/resets/CDC, FIFO clear, register map, DDC error policy, mode mapping, PPA hypotheses, third-party provenance, verification requirements and integration boundary are usable after resolving the two internal design-document contradictions identified above.</MODULE_SCHEMA_AUDIT>
  <USER_DECISION_FIDELITY>PARTIAL PASS. Candidate faithfully preserves the user-selected positive-only naming/counting approach, short semantic names, *_r state naming, encoded-state CDC removal, private link_ready CDC placement, CHN_SYNC boundary, upk_vld semantic, all modes/mid-beat slicing and software-owned recovery. The residual word_pos_r wrapping sentence conflicts with the required no-negative absolute counting model; the stale v1.1 handoff statements conflict with the user's requested v1.2 refactor.</USER_DECISION_FIDELITY>
  <RESIDUAL_RISKS>After a coherent correction, implementation must independently compare every legal scheduler table case and offset against the existing scoreboard. PPA remains HYPOTHESIS; board-level AC9810/ILAS mapping and official FIFO/IP equivalence remain downstream. No RTL/TB/XDC edits, VMware, VCS/Verdi, XSIM, synthesis, implementation or board verification were performed.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</DESIGN_REVIEW_HANDOFF>
