<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_upk_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_05.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <SCOPE>Read-only whole-ADC_RXD optimization audit. No design, RTL, TB, XDC, or verification change was made.</SCOPE>
  <INPUTS>
    <INPUT path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" sha256="6a699f0c5ac4fb680d9d0122304054eb742ce0fe31ddd5c81c2b5fbc914233e2">Current 777-line self-written ADC_RXD after the packed gap lookup and payload-start inline refactor.</INPUT>
    <INPUT path="D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md" sha256="ccf032b354ce64dca9918806e13966097616e33e82e119b782bb9ef29170173e">Final RTL_MODULE_CONTRACT_V1 design v1.3.</INPUT>
    <INPUT path="D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_04.md" sha256="0e28b4dfcf5a29319990201a860be49f896fc27f49251d45890f5ef40fa68beb">Prior architecture decision: source-domain link decode, private link_ready CDC, upk_vld, and positive next-terminal scheduler.</INPUT>
  </INPUTS>
  <NON_NEGOTIABLE_BEHAVIOR>
    <ITEM>Keep ports, fixed ADI link parameters, pure ADC/decimation/DDC legal configurations, sample history and ordering, 512-bit FIFO payload, immediate normal/DDC writes, DDC two-slot reservation, conservative abort, software recovery, and all public event semantics unchanged.</ITEM>
    <ITEM>Keep position-driven padding removal. Zero-valued payload is legal and must not be filtered by value.</ITEM>
    <ITEM>No generate, function, or business-data loop. Remain Verilog-2001 explicit RTL.</ITEM>
  </NON_NEGOTIABLE_BEHAVIOR>
  <PROVEN_INVARIANTS>
    <ITEM>`word_pos_r` is reset to 0, loaded with 8 at payload entry, and thereafter changes only by +8. Therefore `word_pos_r[2:0]` is always 0 in every reachable binary state.</ITEM>
    <ITEM>`next_term_r` starts at 15 and advances only after a completion by a positive legal `term_gap`; every legal gap is at least 16 words. Hence the next terminal cannot be behind the current beat and at most one terminal occurs in an eight-word beat.</ITEM>
    <ITEM>A terminal is in the current beat exactly when `word_pos_r[63:3] == next_term_r[63:3]`; its end offset is exactly `next_term_r[2:0]`. This remains true across 64-bit modulo wrap because the beat base stays eight-aligned and neither counter width is changed.</ITEM>
    <ITEM>All frozen prefix expressions are divisible by eight. Converting the existing zero-word formulas directly to beat formulas is exact 64-bit integer algebra, not a rounded or narrowed calculation.</ITEM>
  </PROVEN_INVARIANTS>
  <RANKED_CANDIDATES>
    <CANDIDATE rank="1" confidence="HIGH" behavior="EQUIVALENT">
      <NAME>Collapse eight terminal-hit comparators to one beat-coordinate comparator</NAME>
      <EXACT_CHANGE>Delete `term_hit_w0` through `term_hit_w7`. Define `block_complete = map_vld &amp;&amp; payload_active_r &amp;&amp; (word_pos_r[63:3] == next_term_r[63:3])`; define `block_end_offset = next_term_r[2:0]`. Retain `word_pos_r`, `next_term_r`, `term_phase_r`, block I/Q classification, history, and all gap logic.</EXACT_CHANGE>
      <CODE_REDUCTION>Deletes eight 64-bit add/equality expressions, their OR tree, eight wires, and the terminal priority encoder.</CODE_REDUCTION>
      <PPA_HYPOTHESIS>Material combinational reduction: one 61-bit equality replaces eight 64-bit equalities plus seven increments/constant-add forms and a priority encoder. Synthesis could already share some logic, so exact LUT/timing benefit remains unmeasured.</PPA_HYPOTHESIS>
      <RISK>Low under the frozen invariants. Verification must especially prove offsets 0 through 7, first terminal offset 7, every legal gap schedule, and long-running counter wrap reasoning/equivalence.</RISK>
    </CANDIDATE>
    <CANDIDATE rank="2" confidence="HIGH" behavior="EQUIVALENT">
      <NAME>Compute prefix length directly in beats and delete zero_words</NAME>
      <EXACT_CHANGE>Make the existing internal `payload_start_beat` the explicit 64-bit combinational result. Pure ADC is 64'd16. For nonzero sample mode, by `dec_m[1:0]`: r0=`({56'd0,dec_n}&lt;&lt;1)+23`; r1=`({56'd0,dec_n}&lt;&lt;3)+25`; r2=`({56'd0,dec_n}&lt;&lt;2)+25`; r3=`({56'd0,dec_n}&lt;&lt;3)+29`. Then add delay d1=`{56'd0,dec_m}&lt;&lt;2`, d2=`{56'd0,dec_m}&lt;&lt;3`, otherwise zero. Delete `zero_words` and `(zero_words+32)&gt;&gt;3`. Do not narrow `payload_start_beat` or `prefix_beat_r`.</EXACT_CHANGE>
      <CODE_REDUCTION>Removes one 64-bit intermediate register and the final 64-bit add/shift expression while retaining the same explicit configuration table.</CODE_REDUCTION>
      <PPA_HYPOTHESIS>Small reduction in combinational width/depth before the prefix comparator; constant shifts remain wiring. The main gain is semantic clarity because the counter and configuration are both in beat units.</PPA_HYPOTHESIS>
      <RISK>Low. Check all DEC_M=32..96, all three delay modes, all three legal sample modes, and invalid configurations remaining write-silent.</RISK>
    </CANDIDATE>
    <CANDIDATE rank="3" confidence="HIGH" behavior="PUBLIC_EQUIVALENT">
      <NAME>Open unused ADI diagnostic outputs at the instance</NAME>
      <EXACT_CHANGE>Delete local wires `adi_rx_sof`, `adi_rx_eof`, `adi_rx_eomf`, `adi_ilas_valid`, `adi_ilas_addr`, `adi_ilas_data`, and `adi_err_statistics`; connect the corresponding named ADI output ports to empty `()` exactly as already done for other unused ADI outputs. Retain `adi_rx_somf`, `adi_status_state`, lane state, sysref/error and data/valid outputs.</EXACT_CHANGE>
      <CODE_REDUCTION>Seven unused declarations and seven named signal connections disappear.</CODE_REDUCTION>
      <PPA_HYPOTHESIS>Normally no implemented-PPA change because synthesis prunes unused output cones at the hierarchy boundary; it does improve code auditability.</PPA_HYPOTHESIS>
      <RISK>Public behavior is unchanged. Only hierarchical debug visibility of those otherwise unused internal nets is removed.</RISK>
    </CANDIDATE>
    <CANDIDATE rank="4" confidence="MEDIUM" behavior="LEGAL_STATE_EQUIVALENT">
      <NAME>Replace eight explicit block slices with one variable indexed part-select</NAME>
      <EXACT_CHANGE>`lane*_block_raw = lane*_window[(16 + {block_end_offset,4'b0}) +: 256]` is legal Verilog-2001 and matches every binary offset 0..7.</EXACT_CHANGE>
      <PPA_HYPOTHESIS>Likely the same 8:1 wide mux as the current case; code shrinks substantially but PPA probably does not.</PPA_HYPOTHESIS>
      <RISK>This is not eligible for the next behavior-only batch: design v1.3 explicitly requires eight explicit slices, manual inspection is arguably clearer with the case, and X/Z offset simulation behavior differs from the current default-to-offset-7 branch. It requires a design/style decision first.</RISK>
    </CANDIDATE>
    <CANDIDATE rank="5" confidence="LOW_VALUE" behavior="EQUIVALENT_IF_CAREFUL">
      <NAME>Factor repeated unpack clear conditions or merge DDC eligibility expressions</NAME>
      <DETAIL>A short derived synchronous-clear wire could replace repeated `!upk_vld || !map_vld || fifo_clr`; DDC write eligibility could be flattened into one expression. These are synthesis-neutral and make the semantic boundaries less explicit. Keep the current separate validity and DDC names for reviewability.</DETAIL>
      <RECOMMENDATION>Do not include in the next batch.</RECOMMENDATION>
    </CANDIDATE>
  </RANKED_CANDIDATES>
  <RETAIN_WITHOUT_CHANGE>
    <ITEM>`lane0_history_r/lane1_history_r`, 384-bit windows, and offset-dependent extraction are required because legal block ends occur at offsets 0..7.</ITEM>
    <ITEM>Keep the two-stage `mapped_raw` permutation then explicit `mapped_data` sign extension. `mapped_raw` is wiring after synthesis; merging the stages does not predictably reduce PPA and makes 32-channel manual mapping review harder. Functions/generate/business loops are forbidden, so explicit per-sample extension remains appropriate.</ITEM>
    <ITEM>Keep `sample_fmt={frame_fmt,smp_prec}`. It gives one visible six-case truth table per sample. A staged shift/sign architecture may alter mux depth and is not a high-confidence source-only cleanup without synthesis comparison.</ITEM>
    <ITEM>Keep `epoch_valid_r`, `payload_active_r`, `epoch_active`, `upk_vld`, `map_vld`, marker detection, and the separate sequential blocks. They carry distinct epoch, payload, current-beat and configuration semantics. Merging blocks reduces no state and increases review coupling.</ITEM>
    <ITEM>Keep `ddc_i_accepted_r`, `fifo_wlevel&gt;=2`, I-only capacity decision, Q-only accepted-I decision, `ddc_abort_afe`, `ddc_epoch_live`, `ddc_abort_set_evt`, and `data_drop_evt`. These are the minimum state/logic that preserves pair admission, fail-closed software recovery and one-shot abort reporting.</ITEM>
    <ITEM>Keep all 64-bit lifetime counters. No bounded epoch duration or mandatory periodic reset is in the contract. Narrowing them needs a new modulo-width/maximum-live-time contract and is not recommended in a behavior-equivalent batch.</ITEM>
    <ITEM>Keep packed `gap_lut`, named gap slices, and `term_gap/term_phase_next`. They make the frozen per-mode scheduler table auditable; further algebraic compression risks obscuring mapping errors for negligible assured PPA benefit.</ITEM>
  </RETAIN_WITHOUT_CHANGE>
  <CHANGES_REQUIRING_NEW_DESIGN_DECISION>
    <ITEM>Dynamic indexed block slicing instead of the v1.3 mandated eight explicit slices.</ITEM>
    <ITEM>Any counter-width reduction, modulo scheduler, bounded epoch lifetime, or periodic forced epoch restart.</ITEM>
    <ITEM>Any value-based padding filter, reduced legal configuration set, altered DDC buffering/admission, removed abort/software recovery, different FIFO output latency, or public interface change.</ITEM>
    <ITEM>Any function, generate, or business-data loop introduced to shorten the 32-sample map/extension text.</ITEM>
  </CHANGES_REQUIRING_NEW_DESIGN_DECISION>
  <BOUNDED_NEXT_RTL_BATCH>
    <ITEM>Implement only Candidates 1, 2 and 3 in ADC_RXD.</ITEM>
    <ITEM>Do not combine this batch with slice style, mapped-data restructuring, DDC state merging, counter-width changes, or adjacent-module edits.</ITEM>
    <EXPECTED_RESULT>Largest safe readability/PPA opportunity is Candidate 1; Candidate 2 aligns units and removes one wide intermediate; Candidate 3 is declaration cleanup. No register, latency, interface, legal mode, FIFO or recovery behavior changes.</EXPECTED_RESULT>
  </BOUNDED_NEXT_RTL_BATCH>
  <VERIFICATION_FOCUS>
    <ITEM>Structural/lint check for Verilog-2001, no forbidden generate/function/business loop, and no undeclared ADI diagnostic nets.</ITEM>
    <ITEM>Equivalence-oriented comparison of old/new `block_complete` and `block_end_offset` over all legal scheduler states; explicitly cover every offset 0..7 and first offset 7.</ITEM>
    <ITEM>All legal DEC_M 32..96, DEC_DEL_MODE 0..2 and sample modes 0..2: identical payload first-beat timing and complete mapped FIFO sequence.</ITEM>
    <ITEM>Zero payload, history-spanning blocks, DDC I/Q alternation, wlevel 0/1/2 boundaries, link/valid loss at each scheduler phase, clear-wins abort, relink/new epoch, and long uninterrupted runs.</ITEM>
    <ITEM>Regression of all existing ADC_TOP public scoreboards and sticky/event behavior. PPA claims remain hypotheses until later synthesis.</ITEM>
  </VERIFICATION_FOCUS>
  <RECOMMENDATION>Proceed with the bounded Candidates 1+2+3 batch. It is the strongest behavior-equivalent reduction supported by current invariants and frozen v1.3. Retain the explicit slice case and mapping/sign-extension structure for manual review.</RECOMMENDATION>
  <OPEN_QUESTIONS>None for Candidates 1+2+3. Candidate 4 or counter/data-map restructuring requires a separate user/design decision.</OPEN_QUESTIONS>
  <RESIDUAL_RISKS>Actual LUT/timing benefit is unmeasured until synthesis. The scheduler proof depends on the frozen legal-gap table and no future gap below 16 words; any future configuration expansion must re-audit the one-terminal-per-beat invariant.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
