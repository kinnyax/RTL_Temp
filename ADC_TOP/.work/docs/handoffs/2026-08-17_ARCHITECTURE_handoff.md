<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_decim_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_ARCHITECTURE_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <REQUIREMENT>Analyze only ADC_TOP / ADC_RXD as project-independent, read-only architecture context; do not modify design, RTL, TB, XDC, or run verification.</REQUIREMENT>
    <REQUIREMENT>User direction: derive internal dec_int=N[5:0] and dec_frac=f[1:0] from compact E={N,f}; favor clear names, fewer signals, positive counters, and exactly the three modes pure ADC, single decimation, and decimation plus DDC.</REQUIREMENT>
    <REQUIREMENT>Preserve frozen JESD parameters, fixed valid-SOMF recovery model, 384-bit per-lane history / eight slice semantics, and existing DDC I/Q, capacity-admission, abort, and fail-closed packet-admission semantics unless evidence explicitly changes them.</REQUIREMENT>
    <REQUIREMENT>Compare feasible unpack structures without selecting an option for the user. Identify formula, range, width, PPA, and verification consequences of extending to the documented factor range.</REQUIREMENT>
  </REQUIREMENTS_USED>
  <CONTEXT_FINGERPRINTS>
    <FINGERPRINT path="D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md" sha256="62bc9f85b66f7a17f7796d26986a0b2fb475747e0d1650413ae93e84990cca7c">Current v1.5 design, read-only</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" sha256="a2203f25f6ecf3c2cc568d6c912db3510543cdee08f98e71ac03dd1ef380a217">Current implementation context, read-only</FINGERPRINT>
  </CONTEXT_FINGERPRINTS>
  <EVIDENCE_HANDOFF_HASH>65899ac4c0f7eebbbfe1f8749dfe92390bf02e753f5808f3faaf839e0058ea6b</EVIDENCE_HANDOFF_HASH>
  <OPTIONS>
    <OPTION id="A" name="Explicit three-state receive/unpack FSM">
      <BOUNDARY_AND_OWNERSHIP>Inside ADC_RXD's existing AFE-domain unpack partition, replace epoch_valid_r plus payload_active_r with RXD_WAIT_SOMF, RXD_SKIP_PREFIX, and RXD_PAYLOAD. The FSM owns epoch existence and payload activity; an independent 3-bit term_phase_r owns only the output-group phase. The ADI adapter, external ports, CDC, FIFO interface, and ADC_PKT admission boundary do not move.</BOUNDARY_AND_OWNERSHIP>
      <CONTROL>RXD_WAIT_SOMF accepts only upk_vld &amp;&amp; adi_rx_somf[0] &amp;&amp; map_vld, clears per-epoch coordinates, stores marker-inclusive prefix_beat_r=0, and enters RXD_SKIP_PREFIX. RXD_SKIP_PREFIX increments only on each later upk_vld; it enters RXD_PAYLOAD precisely when prefix_beat_r+1 equals payload_start_beat. RXD_PAYLOAD advances word_pos_r by +8 and advances next_term_r only by positive term_gap when the sole terminal comparison hits. Any !upk_vld, !map_vld, fifo_clr, or AFE reset clears context and returns to WAIT; a SOMF while not in WAIT is not an alternate alignment path.</CONTROL>
      <COUNTERS>Use a 12-bit positive prefix_beat_r, a 12-bit payload_start_beat, 64-bit positive lifetime word_pos_r and next_term_r, 12-bit term_gap, and 3-bit term_phase_r. No sequential downcounter, subtraction-based hit detector, or implicit period rebase is needed.</COUNTERS>
      <INTERFACES_CDC_BUFFERING>Unchanged. The existing JESD-to-AFE link_ready level CDC stays private to ADC_RXD. The stored two 128-bit beats per lane plus current 128-bit beat still form the required 384-bit per-lane window; the eight explicit end-offset slices remain. DDC uses the existing immediate I then Q FIFO writes after I reserves two slots, and the existing ddc_abort_afe -> inverted level CDC -> ADC_PKT new-packet gate stays intact.</INTERFACES_CDC_BUFFERING>
      <THROUGHPUT_LATENCY_ORDERING_RECOVERY>Equivalent target: one accepted input beat per upk_vld, no normal-path stall, marker-inclusive prefix convention, original payload ordering, and one 512-bit output at each terminal. The first payload beat must be inserted into history at the SKIP-to-PAYLOAD transition so the following beat completes the first 16-word block at terminal 15. Existing loss/clear recovery remains fail-closed for DDC and discards incomplete local context.</THROUGHPUT_LATENCY_ORDERING_RECOVERY>
      <VERIFICATION_REUSE_MAINTENANCE>State names expose the three recovery phases to assertions and debug without adding behavior. Compared with the current two flags, invalid state combinations are unrepresentable. It remains compatible with explicit Verilog-2001 coding and no function/generate/procedural datapath loop policy.</VERIFICATION_REUSE_MAINTENANCE>
      <PPA_INTENT>HYPOTHESIS: one 2-bit FSM can replace two 1-bit state flops and associated mutually dependent conditions; area/timing change is likely negligible versus 512-bit mapping and slice muxes. Its principal gain is auditability and lower control-risk, not a promised resource reduction.</PPA_INTENT>
      <VENDOR_BOUNDARY>No change to ADI JESD204 RX, PUB FIFO, or eventual Vivado PHY/IP boundaries.</VENDOR_BOUNDARY>
    </OPTION>
    <OPTION id="B" name="Implicit flags with compact factor decode">
      <BOUNDARY_AND_OWNERSHIP>Keep epoch_valid_r and payload_active_r, but replace dec_m-derived naming/range logic with dec_factor=E, dec_int=E[7:2], and dec_frac=E[1:0]. Keep the existing positive prefix/word/terminal counters and phase sequencer.</BOUNDARY_AND_OWNERSHIP>
      <CONTROL>Formula selection is compact, but state remains represented by two flags. Recovery must continue to clear both flags atomically; reviewers must prove epoch_valid_r=0/payload_active_r=1 never occurs and DDC epoch-live meaning follows the intended flag.</CONTROL>
      <INTERFACES_CDC_BUFFERING>Identical to A, including history, slices, DDC write/abort behavior, and all CDCs.</INTERFACES_CDC_BUFFERING>
      <THROUGHPUT_LATENCY_ORDERING_RECOVERY>Can be behaviorally equivalent to A, including positive counters and no downcount. It has no inherent latency or throughput advantage.</THROUGHPUT_LATENCY_ORDERING_RECOVERY>
      <VERIFICATION_REUSE_MAINTENANCE>Smaller source delta and strongest local continuity with ADC_RXD.v, but names such as epoch_active remain derived and the two-flag invariants need explicit assertions. It does not meet the stated 'fewer signals/clear state' preference as directly as A.</VERIFICATION_REUSE_MAINTENANCE>
      <PPA_INTENT>HYPOTHESIS: nearly identical FF/LUT result to A; syntactic minimization is not evidence of lower PPA after synthesis.</PPA_INTENT>
      <VENDOR_BOUNDARY>No vendor boundary change.</VENDOR_BOUNDARY>
    </OPTION>
    <OPTION id="C" name="Table or microcode scheduler">
      <BOUNDARY_AND_OWNERSHIP>A per-mode/fraction table would emit initial prefix, phase count, and gaps; the existing flags or an FSM would still be required for receive state.</BOUNDARY_AND_OWNERSHIP>
      <CONTROL>It can centralize schedules, but requires a table encoding for mode/fraction/delay and still needs phase/terminal counters. A ROM/case table cannot supply missing positional proof for single-decimation r2/r3.</CONTROL>
      <INTERFACES_CDC_BUFFERING>Unchanged externally, but the table expands control verification and introduces another representation of the source layout.</INTERFACES_CDC_BUFFERING>
      <THROUGHPUT_LATENCY_ORDERING_RECOVERY>Potentially equivalent only if every table entry and phase transition is independently proven. No throughput gain is expected.</THROUGHPUT_LATENCY_ORDERING_RECOVERY>
      <VERIFICATION_REUSE_MAINTENANCE>Rejected for this direction: it conflicts with the preference for simple formula selection, repeats the v1.4/v1.5 packed-LUT complexity that was intentionally removed, and obscures arithmetic/range review.</VERIFICATION_REUSE_MAINTENANCE>
      <PPA_INTENT>HYPOTHESIS: a constant table may synthesize acceptably, but no measured PPA benefit exists and selector fan-in could worsen relative to formulas.</PPA_INTENT>
      <VENDOR_BOUNDARY>No vendor boundary change.</VENDOR_BOUNDARY>
    </OPTION>
  </OPTIONS>
  <FORMULA_AND_RANGE_ANALYSIS>
    <COMPACT_ENCODING status="FACT">Let E={N[5:0],f[1:0]} = 4N+f. Derive dec_int=E[7:2] and dec_frac=E[1:0] once; do not retain redundant dec_n. The documented physical E range is 8'h04 through 8'hff.</COMPACT_ENCODING>
    <MODE_VALIDITY>
      <PURE_ADC status="FACT">smp_mode=0: precision legality remains required; E and DEC_DEL_MODE have no framing effect and need not reject pure ADC.</PURE_ADC>
      <SINGLE_DECIMATION status="FACT">smp_mode=1: dec_int in [1,63], dec_frac in [0,3], and the existing allowed delete-mode d in [0,2]. The 2-CML workbook zero runs are nonnegative at N=1 for all fractions.</SINGLE_DECIMATION>
      <DDC status="FACT">smp_mode=2: dec_int in [2,63], dec_frac in [0,3], and d in [0,2]. DDC N=1 is unsupported by the supplied 2-CML layouts because every listed fraction requires negative trailing padding.</DDC>
      <INVALID status="FACT">smp_mode=3, smp_prec=3, d=3, single N=0, and DDC N=0/1 are map_vld=0; they establish neither epoch nor FIFO write.</INVALID>
    </MODE_VALIDITY>
    <PREFIX_FORMULAS status="FACT">With B(0)=0, B(1)=4E, and B(2)=8E in beats: pure=16; f0=2N+23+B(d); f1=8N+25+B(d); f2=4N+25+B(d); f3=8N+29+B(d). These are direct marker-inclusive beat formulas. At E=255 and d=2, the maximum is f3: 8*63+29+8*255=2573, requiring 12 bits (not 64) for prefix target/count.</PREFIX_FORMULAS>
    <GAP_FORMULAS>
      <SINGLE_F0 status="FACT">gaps {16N,16N}; cycle 32N.</SINGLE_F0>
      <SINGLE_F1 status="FACT">gaps {16,16,16,64N-32}; cycle 64N+16. The long term is trailing zero run (64N-48) plus the subsequent 16-word output group; 64N-48 is incorrect as a terminal distance.</SINGLE_F1>
      <SINGLE_F2 status="OPEN_QUESTION">Current v1.5 uses {16,32N+1,16,32N+1}; its claimed cycle is 64N+34. The accepted evidence records only zero run 32N-16, not the full phase/terminal positions. Do not carry this exact schedule into a revised frozen contract without workbook positional derivation.</SINGLE_F2>
      <SINGLE_F3 status="OPEN_QUESTION">Current v1.5 uses {16,16,16,64N}; its claimed cycle is 64N+48. The zero run 64N-16 and output-group accounting make 64N a plausible long terminal distance, but accepted evidence explicitly withholds the complete fractional phase schedule. It remains unfreezeable without positional derivation.</SINGLE_F3>
      <DDC_F0 status="FACT">I/Q gaps {16,16N-16}; cycle 16N.</DDC_F0>
      <DDC_F1 status="FACT">I,Q,I,Q,I,Q,I,Q gaps: seven 16s then 64N-96; cycle 64N+16.</DDC_F1>
      <DDC_F2 status="FACT">I,Q,I,Q,I,Q,I,Q gaps: seven 16s then 32N-32; cycle 32N+80.</DDC_F2>
      <DDC_F3 status="FACT">I,Q,I,Q,I,Q,I,Q gaps: seven 16s then 64N-64; cycle 64N+48.</DDC_F3>
    </GAP_FORMULAS>
    <WIDTHS status="FACT">At N=63, 16N=1008, 32N=2016, and 64N=4032. Every scheduler gap, including the longest possible 4032, therefore needs unsigned 12 bits; 11 bits truncates it. Extend 12-bit term_gap to 64 bits explicitly before next_term_r addition. 64-bit word_pos_r and next_term_r remain justified only as monotonic lifetime coordinates: they preserve the frozen no-rebase contract for continuous operation. A 64-bit prefix counter is not justified by the bounded per-epoch formulas.</WIDTHS>
  </FORMULA_AND_RANGE_ANALYSIS>
  <ESSENTIAL_VS_REMOVABLE>
    <ESSENTIAL status="FACT">ADI fixed parameters; valid-SOMF[0]-only epoch establishment; link_ready JESD-to-AFE CDC; location-driven handling of zero-valued payload; two prior 128-bit beats per lane plus current beat (384-bit windows); all eight explicit offset slices; 64-bit word/terminal coordinates; positive phase sequence; DDC I/Q immediate pair semantics; two-space I admission; DDC abort latch, one-shot event, recovery rule, and fail-closed level CDC to ADC_PKT.</ESSENTIAL>
    <REMOVABLE_IF_OPTION_A status="INFERENCE">epoch_valid_r and payload_active_r become the explicit RXD state; epoch_active becomes state != WAIT or can disappear at the history-enable site; dec_n is replaced by dec_int; the five named long-gap wires can be folded into a documented mode/fraction formula expression if that improves readability without reintroducing a table. Do not remove term_phase_r, the history/slice network, map_vld distinctions, or ddc_i_accepted_r.</REMOVABLE_IF_OPTION_A>
    <NOT_REMOVABLE status="FACT">The 384-bit windows and eight slice cases are not generic alignment residue: legal terminals can end at any word offset 0..7. Removing them changes the required cross-beat output reconstruction.</NOT_REMOVABLE>
  </ESSENTIAL_VS_REMOVABLE>
  <VERIFICATION_MATRIX>
    <ROW>All modes: reset, fifo_clr, !map_vld, loss of upk_vld, valid SOMF[0], invalid SOMF[15:1], and zero-valued payload; prove WAIT/SKIP/PAYLOAD recovery and no alternative alignment.</ROW>
    <ROW>Pure ADC: E ignored, payload_start=16, positive marker-inclusive prefix capture, first terminal at 15, all end offsets 0..7, no DDC abort creation.</ROW>
    <ROW>Single decimation: for f=0..3 test N=1, N=2, N=63 and d=0..2. Check direct prefix formulas, no negative/premature terminal, f1 corrected {16,16,16,64N-32} period 64N+16, and source-vector ordering. Treat f2/f3 as expected-to-be-specified only after the missing positional derivation; do not falsely score existing v1.5 schedules as accepted.</ROW>
    <ROW>DDC: for f=0..3 test N=2 and N=63 (and reject N=1) with d=0..2. Check all four supported gap schedules, I/Q alternation, 0/1-space whole-pair rejection, >=2-space I/Q writes, and that phase/terminal advance independent of capacity.</ROW>
    <ROW>Width boundaries: assert prefix target/count max 2573 fits 12 bits, N=63 long gap 4032 does not truncate, each gap is positive for its legal mode, and next_term_r uses zero-extended 12-bit gap. Include directed f1 single N=63 (4000 long gap) and DDC f1/f3 N=63 (3936/3968).</ROW>
    <ROW>DDC recovery: inject one-cycle and persistent link_ready_afe/adi_rx_valid loss after a valid epoch, before and after I acceptance and with each fraction; prove one abort/data-drop, no resumed new packet before FIFO_CLR or AFE reset, no mode-switch bypass, and existing packet completes structurally.</ROW>
    <ROW>Equivalence scope: compare unchanged pure, DDC, mapping, history/slices, normal FIFO writes, and recovery to the current verified behavior only where formulas are source-backed. The corrected single-f1 and any newly derived single-f2/f3 schedules are behavior changes requiring source-vector rather than old-RTL equivalence as oracle.</ROW>
  </VERIFICATION_MATRIX>
  <REJECTED_OPTIONS>Option C is rejected as an implementation direction because it recreates the packed/table scheduler complexity deliberately removed in v1.5, duplicates formula knowledge, and cannot resolve absent r2/r3 source evidence. Option B remains feasible but does not directly satisfy the user's explicit state clarity preference.</REJECTED_OPTIONS>
  <RECOMMENDATION>Conditional, not a user selection: if the user confirms the requested readability-oriented refactor after r2/r3 are evidence-complete, Option A is the best fit. It uses one visible three-state control owner, removes two coupled state flags, preserves all proven datapath/CDC/DDC contracts, and makes validity/range checks auditable. Before a revised design can be frozen, the user/Lead must decide whether to (a) obtain and adopt complete source positional schedules for single f2/f3 or (b) deliberately limit single-decimation support to f0/f1; it is not safe to claim full f=0..3 support while their schedules remain open.</RECOMMENDATION>
  <ASSUMPTIONS>
    <ASSUMPTION>The compact E control replaces the current dec_m naming semantically, with E=4N+f and DEC_DEL_MODE retained because no requirement authorizes removing its prefix effect.</ASSUMPTION>
    <ASSUMPTION>The planned 12-bit prefix count has sufficient range because only the documented E and delete modes are supported; it is not a lifetime coordinate.</ASSUMPTION>
    <ASSUMPTION>The requested N range concerns framing-layout validity, not selected lane-rate/electrical feasibility. A system-level rate check remains separate.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>
    <QUESTION priority="BLOCKING_DESIGN_FREEZE">Derive and preserve primary-source positional proof (not just zero runs) for the full single-decimation f2 and f3 terminal sequences, first terminal/cycle, and their relation to the direct prefix formula. Current v1.5 r2/r3 schedules cannot be accepted merely by continuity.</QUESTION>
    <QUESTION priority="BLOCKING_DESIGN_FREEZE">Confirm the user’s disposition for f2/f3 while that evidence is absent: scope them out, provide source vectors, or approve a separately documented assumption. No worker may choose this behavior silently.</QUESTION>
    <QUESTION priority="NONBLOCKING_ARCHITECTURE">Evaluate lane-rate feasibility for N=1..63 against the selected ADC clock/CML configuration; nonnegative workbook padding does not prove electrical operation.</QUESTION>
    <QUESTION priority="IMPLEMENTATION_DETAIL">Confirm whether E is already the named register field/port or only an internal refactor of dec_m. This handoff assumes no top-level interface change until the design author specifies it.</QUESTION>
  </OPEN_QUESTIONS>
  <RESIDUAL_RISKS>
    <RISK>The current v1.5 design and RTL are internally inconsistent for single r1: its table period says 64N+16 while its formula/RTL use 64N-48 and sum to 64N. Implementing either unchanged is unsafe.</RISK>
    <RISK>Extending valid N beyond 31 necessarily changes gap arithmetic from 11 to 12 bits. A partial-width change that leaves an 11-bit selector, constants, or extension path will fail at high factors.</RISK>
    <RISK>A FSM refactor can introduce first-payload/history or abort-order off-by-one defects unless the directed matrix above verifies the transition beat and loss-before-state-clear ordering.</RISK>
    <RISK>All PPA conclusions are HYPOTHESIS; no synthesis, implementation, timing, or power measurement was performed.</RISK>
  </RESIDUAL_RISKS>
  <PHASE_BOUNDARY>No RTL/TB/XDC/design document was changed. No VMware, VCS/Verdi, XSIM, synthesis, implementation, bitstream, or board validation was run.</PHASE_BOUNDARY>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
