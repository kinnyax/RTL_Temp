<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_phase_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_ARCHITECTURE_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <REQUIREMENT>Current user request: improve readability around gap_base/gap_dec/gap_ddc; replace the term_phase next-state combinational maze with an intuitive terminal counter that increments only at a completed block; use compact ternary assigns and clear names; preserve deterministic reset/default recovery; do not add illegal static-configuration datapath handling because software guarantees legal, stable configurations.</REQUIREMENT>
    <REQUIREMENT>Current frozen design ADC_TOP v1.10, SHA256 afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8, and current read-only ADC_RXD.v, SHA256 416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8.</REQUIREMENT>
    <REQUIREMENT>Preserve all legal pure/single/DDC formulas, 64-bit monotonic word_pos_r/next_term_r coordinates, DDC I/Q selection, 12-bit term-gap arithmetic, RXD state/clear behavior, history slicing, FIFO/DDC-abort behavior, clock/reset/CDC boundaries, and the existing user-approved software static-configuration contract.</REQUIREMENT>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c</EVIDENCE_HANDOFF_HASH>
  <CONTEXT_FINGERPRINTS>
    <FINGERPRINT path="D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md" sha256="afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8">Current finalized design reviewed read-only.</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" sha256="416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8">Current RTL reviewed read-only.</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_ARCHITECTURE_handoff_02.md" sha256="2883efc008f77e23759b33e4dc614743beedfb18c09664736eaa6cc880d524b4">Accepted formula background only; it is not reused as a current contributor.</FINGERPRINT>
  </CONTEXT_FINGERPRINTS>
  <EQUIVALENCE_BASIS>
    <FACT>The current RTL initializes term_phase_r to zero on reset, rxd_clr, IDLE, PREF-to-PAYL hit, and invalid FSM recovery. In PAYL, only block_complete changes it; term_gap, block_is_i, and block_is_q read the pre-edge phase. Therefore a replacement counter must initialize to zero at exactly those points, hold on non-terminal PAYL beats, and have its pre-edge value drive both gap choice and DDC I/Q classification.</FACT>
    <FACT>next_term_r is initialized to 15 at the PREF-to-PAYL hit and advances by zero-extended 12-bit term_gap only at PAYL block_complete. word_pos_r remains its distinct 64-bit owner; neither coordinate may be narrowed, rebased, or changed to a downcounter.</FACT>
    <FACT>For legal static configurations, a 3-bit counter with the truth table below has the same pre-terminal values as term_phase_r. No behavior is specified or added for smp_mode=3, unsupported precision/delete settings, single N=0, DDC N&lt;2, or mid-epoch static configuration changes.</FACT>
  </EQUIVALENCE_BASIS>
  <COUNTER_CLEAR_WRAP_TRUTH_TABLE>
    <ROW><MODE>pure ADC, smp_mode=0</MODE><FRACTION>ignored</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16}</TERM_GAPS><DDC_CLASS>N/A</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>always; counter remains 0</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>single decimation, smp_mode=1</MODE><FRACTION>f=0</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16N}</TERM_GAPS><DDC_CLASS>N/A</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>always; counter remains 0</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>single decimation, smp_mode=1</MODE><FRACTION>f=1</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0,1,2,3</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,16,16,64N-32}</TERM_GAPS><DDC_CLASS>N/A</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter==3</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>single decimation, smp_mode=1</MODE><FRACTION>f=2</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0,1,2,3</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,32N+1,16,32N+1}</TERM_GAPS><DDC_CLASS>N/A</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter==3</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>single decimation, smp_mode=1</MODE><FRACTION>f=3</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0,1,2,3</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,16,16,64N}</TERM_GAPS><DDC_CLASS>N/A</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter==3</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>DDC, smp_mode=2</MODE><FRACTION>f=0</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0,1</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,16N-16}</TERM_GAPS><DDC_CLASS>counter[0]=0:I; counter[0]=1:Q</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter[0]==1</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>DDC, smp_mode=2</MODE><FRACTION>f=1</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0..7</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,16,16,16,16,16,16,64N-96}</TERM_GAPS><DDC_CLASS>counter[0]=0:I; counter[0]=1:Q</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter==7</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>DDC, smp_mode=2</MODE><FRACTION>f=2</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0..7</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,16,16,16,16,16,16,32N-32}</TERM_GAPS><DDC_CLASS>counter[0]=0:I; counter[0]=1:Q</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter==7</WRAP_ON_BLOCK_COMPLETE></ROW>
    <ROW><MODE>DDC, smp_mode=2</MODE><FRACTION>f=3</FRACTION><PRE_TERMINAL_COUNTER_VALUES>0..7</PRE_TERMINAL_COUNTER_VALUES><TERM_GAPS>{16,16,16,16,16,16,16,64N-64}</TERM_GAPS><DDC_CLASS>counter[0]=0:I; counter[0]=1:Q</DDC_CLASS><WRAP_ON_BLOCK_COMPLETE>counter==7</WRAP_ON_BLOCK_COMPLETE></ROW>
    <IMPLEMENTATION_SHAPE>term_cnt_wrap is a compact combinational ternary: pure always wraps; single f0 always wraps and f1/f2/f3 wrap at term_cnt_r==3; DDC f0 wraps when term_cnt_r[0] is 1 and f1/f2/f3 wrap at term_cnt_r==7. The sequential term counter changes only under rxd_fsm_payl &amp;&amp; block_complete: if term_cnt_wrap then 0, else term_cnt_r + 3'd1. It is zeroed on the same reset/clear/IDLE/PREF-hit/invalid-FSM paths as the current phase register.</IMPLEMENTATION_SHAPE>
    <PURE_ADC_NOTE>Do not describe pure ADC as a continuously incrementing counter: exact equivalence requires it to remain zero. This may be implemented as an asserted wrap on every completed pure-ADC block, preserving one common counter block and deterministic behavior.</PURE_ADC_NOTE>
  </COUNTER_CLEAR_WRAP_TRUTH_TABLE>
  <NAMING_DIRECTION>
    <FACT>gap_base16/gap_base32/gap_base64 are formula bases, not mode-specific quantities. Preferred compact replacements are gap_16n, gap_32n, and gap_64n.</FACT>
    <FACT>Replace misleading ordinal/mode names with formula-purpose names: gap_tail_64n_m32 for 64N-32; gap_pair_tail_16n_m16 for 16N-16; gap_cycle_tail_64n_m96 for 64N-96; gap_cycle_tail_32n_m32 for 32N-32; and gap_cycle_tail_64n_m64 for 64N-64. Keep the source-required single-f2 expression gap_32n + 12'd1 visibly local to its ternary branch, or name it gap_32n_p1 if a named intermediate is specifically wanted.</FACT>
    <FACT>Use single_term_gap and iq_term_gap for the mode-specific selection wires, then the existing neutral term_gap final selection. term_cnt_r, term_cnt_wrap, and term_cnt_next are clearer than term_phase_r, term_phase_next, phase4_nx, and phase8_nx. A next value wire is optional; the simple sequential increment is clearer when it is written directly.</FACT>
  </NAMING_DIRECTION>
  <OPTIONS>
    <OPTION id="A" name="Rename-only explicit phase-next scheduler">
      <DESCRIPTION>Keep the current 3-bit phase register, phase4/phase8 next-state calculations, and shared next_term_r/phase state block; rename gaps and perhaps phase to count-like names only.</DESCRIPTION>
      <EQUIVALENCE>Cycle-equivalent by construction for all legal configurations.</EQUIVALENCE>
      <BENEFITS>Smallest RTL delta and least disturbance to the already accepted v1.10 ownership layout.</BENEFITS>
      <COSTS>Does not meet the stated goal of replacing the next-state combinational maze. Retains two redundant add/wrap expressions and obscures pure/f0 held-zero behavior.</COSTS>
      <PPA_INTENT>HYPOTHESIS: indistinguishable from the current scheduler after synthesis; no measured benefit.</PPA_INTENT>
    </OPTION>
    <OPTION id="B" name="Unified term_cnt_r with explicit clear/wrap">
      <DESCRIPTION>Replace term_phase_r with one 3-bit terminal counter. Compact ternary assigns compute gap and term_cnt_wrap; a dedicated counter block clears on existing recovery/init paths and, only on block_complete, executes either term_cnt_r &lt;= 3'd0 or term_cnt_r &lt;= term_cnt_r + 3'd1. next_term_r may become a separate single-target block with identical init/recovery guards and existing next_term_r + term_gap terminal update.</DESCRIPTION>
      <EQUIVALENCE>Exact for every legal mode/fraction in the table because the pre-edge counter values, selected gap, I/Q parity, initial coordinate 15, and terminal-edge advance equal the current term_phase_r behavior. The counter must not advance on ordinary PAYL beats, PREF beats, or invalid cycles.</EQUIVALENCE>
      <BENEFITS>Directly communicates the terminal sequence and reset modulus; removes phase4_nx/phase8_nx/term_phase_next; permits a one-register-per-block ownership layout; preserves compact ternary formula style.</BENEFITS>
      <COSTS>The wrap decode remains combinational and must be reviewed alongside the gap decode. Separating next_term_r and the counter creates two sequential blocks that must share exactly the same reset/clear/init/default-recovery priority.</COSTS>
      <PPA_INTENT>HYPOTHESIS: the 3-bit incrementer already exists conceptually in the current phase-next cone, so PPA should be near-neutral. Synthesis could optimize differently, but no area/timing claim is warranted without a fresh build.</PPA_INTENT>
    </OPTION>
    <OPTION id="C" name="Separate mode/fraction-specific modulo counters">
      <DESCRIPTION>Use independent 0/1/2/3-bit counters or counter paths for pure, single, DDC-f0, and DDC-f1..3, then select their state for gap/IQ logic.</DESCRIPTION>
      <EQUIVALENCE>Feasible only with all counters initialized and enabled exactly at the same terminal events; it has no behavioral capability beyond Option B for legal stable configurations.</EQUIVALENCE>
      <BENEFITS>Each modulus can be locally obvious and may isolate a particular mode cone if a future timing report proves it necessary.</BENEFITS>
      <COSTS>More state or muxing, more reset/default-recovery obligations, more mode-transition ambiguity despite the software-stability contract, and a larger verification matrix. It conflicts with the requested compact, intuitive single terminal counter.</COSTS>
      <PPA_INTENT>HYPOTHESIS: likely worse or neutral in FF/control cost; only a post-synthesis critical-path finding could justify reconsideration.</PPA_INTENT>
    </OPTION>
  </OPTIONS>
  <REJECTED_OPTIONS>None is selected by this Worker. Option C is not preferred absent measured scheduler timing pressure because it adds state without changing legal behavior. Option A remains valid only if minimizing source delta outweighs the user's stated counter-readability objective.</REJECTED_OPTIONS>
  <RECOMMENDATION>If the user confirms that a visible modulo/wrap counter is the desired readability model, select Option B: keep term-gap ternary formulas and 64-bit coordinates, replace only phase-next machinery with term_cnt_r/term_cnt_wrap, and split next_term_r into its own single-target block. If the user instead prioritizes the smallest possible change to the accepted v1.10 scheduler, select Option A. Do not select Option C unless later synthesis evidence identifies a mode-decoder timing issue and the user accepts its maintenance/verification cost.</RECOMMENDATION>
  <IMPLEMENTATION_GUARDRAILS>
    <ITEM>Evaluate term_gap, block_is_i, block_is_q, and term_cnt_wrap from pre-edge term_cnt_r. At a terminal edge, next_term_r uses that pre-edge term_gap and the counter wraps/increments afterward through nonblocking assignments; this retains current I/Q and gap order.</ITEM>
    <ITEM>Keep block_complete as the one terminal comparison of word_pos_r[63:3] and next_term_r[63:3]; retain block_end_offset=next_term_r[2:0], all eight history slices, and at-most-one completion per 8-word beat.</ITEM>
    <ITEM>In a separated next_term_r block, preserve priority exactly: asynchronous !afe_rst_n, rxd_clr, RXD_IDLE, RXD_PREF &amp;&amp; payl_hit, RXD_PAYL &amp;&amp; block_complete, then invalid-FSM recovery; preserve implicit hold on PREF miss and PAYL non-terminal cycles. The counter block must use the same priority and recovery outcomes.</ITEM>
    <ITEM>Do not add a mode-3/default datapath branch intended to define illegal software configurations. Deterministic reset/default FSM recovery remains required and distinct from illegal static-configuration handling.</ITEM>
  </IMPLEMENTATION_GUARDRAILS>
  <VERIFICATION_IMPACT>
    <REQUIRED>For every legal single N=1..63, DDC N=2..63, f=0..3, and d=0..2 reference enumeration, compare terminal coordinate, selected gap, counter pre-value, wrap result, offset, and DDC I/Q classification against the truth table. Include pure ADC as counter-held-zero.</REQUIRED>
    <REQUIRED>Directed DUT tests should cover each wrap boundary: single f1/f2/f3 at count 3; DDC f0 at count 1; DDC f1/f2/f3 at count 7; N=63 gap 4032; single f2 32N+1 and cross-period offsets; reset/rxd_clr/IDLE/PREF hit/invalid FSM recovery; and DDC FIFO acceptance/rejection with I/Q parity.</REQUIRED>
    <RISK>Separating next_term_r and term_cnt_r makes a copy/paste priority mismatch possible. A missing invalid-state clear, a counter advance outside block_complete, or a post-increment interpretation of I/Q would be a functional regression even though normal f=0 smoke tests may pass.</RISK>
    <BOUNDARY>No RTL, TB, XDC, verification, VMware, VCS/Verdi, XSIM, synthesis, implementation, timing, bitstream, or board work was performed by this analysis.</BOUNDARY>
  </VERIFICATION_IMPACT>
  <ASSUMPTIONS>
    <ASSUMPTION>Software supplies and holds a legal static configuration while an epoch is active, as frozen in v1.10; equivalence is scoped to that contract.</ASSUMPTION>
    <ASSUMPTION>Current rxd_clr and state predicates retain their present four-state simulation and synthesized semantics; no reset/CDC change is authorized.</ASSUMPTION>
    <ASSUMPTION>Formula-base and tail-gap name changes are internal ADC_RXD readability changes only; DEC_M external compatibility and configuration encoding remain unchanged.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>
    <QUESTION priority="USER_SELECTION">Choose Option A or B. This Worker conditionally favors B only when the requested intuitive explicit terminal-counter presentation outweighs smallest-delta preservation; it does not select on the user's behalf.</QUESTION>
    <QUESTION priority="NONBLOCKING_NAMING">Confirm whether the compact m32/m96/m64 suffixes are acceptable, or prefer fully spelled minus32/minus96/minus64 names. Both preserve formula meaning.</QUESTION>
  </OPEN_QUESTIONS>
  <RESIDUAL_RISKS>
    <RISK>PPA is HYPOTHESIS. The refactor is control-only and must not be claimed as an area/timing improvement until fresh synthesis bound to the changed RTL, target, and constraints.</RISK>
    <RISK>Current v1.10 design/RTL and prior VMware results are not proof of a later selected RTL delta. The downstream RTL workflow must rerun lint/simulation/review against the new exact baseline.</RISK>
    <RISK>The prescribed behavior preserves 64-bit terminal coordinate overflow behavior over an extremely long uninterrupted epoch; this analysis does not add a rebase or wrap policy because that would change the frozen contract.</RISK>
  </RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
