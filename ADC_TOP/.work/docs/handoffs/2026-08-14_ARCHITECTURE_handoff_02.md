<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_upk_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <ITEM>Assess the proposal to avoid a persistent FIFO-invalid indication by requiring the ADC-side FIFO read level to be at least two in DDC mode before packet start and/or read.</ITEM>
    <ITEM>Preserve the current fixed 256-payload-beat packet admission/completion contract, FWFT asynchronous FIFO boundary, all DDC I/Q ordering rules, old/new epoch isolation, and PPA preference.</ITEM>
    <ITEM>Assess link interruption after an I write, automatic relink/new-epoch writes, and whether existing count/status signals prove pair identity.</ITEM>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>0b307ab571771b150566ee75369111fecee7a1dc9c43b7df72f6b1ca540a88ac</EVIDENCE_HANDOFF_HASH>
  <SOURCES>
    <SOURCE>ADC_PKT.v, local active RTL, read 2026-08-14: packet_start requires fifo_level &gt;= 256; payload reads one FIFO entry per AXIS handshake until exactly 256 entries are emitted.</SOURCE>
    <SOURCE>async_fifo_rctrl.v, D:\Codex\RTL\PUB\async_fifo_fwft, read 2026-08-14: rlevel is an rclk-domain count derived from the synchronized write pointer; it identifies visible quantity, not write epoch or I/Q identity.</SOURCE>
    <SOURCE>ADC_RXD.v, local active RTL, read 2026-08-14: DDC presently writes I before Q and only keeps ddc_i_accepted_r at the writer; neither FIFO entry carries a pair/epoch tag.</SOURCE>
    <SOURCE>2026-08-13_ARCHITECTURE_handoff.md, SHA256 0b307ab571771b150566ee75369111fecee7a1dc9c43b7df72f6b1ca540a88ac: fixed transport facts and prior DDC two-slot-reservation analysis.</SOURCE>
  </SOURCES>
  <FACTS>
    <FACT>At packet admission, the present ADC_PKT condition fifo_level &gt;= 256 already implies fifo_level/rlevel &gt;= 2. Adding only a second &gt;=2 test to packet_start is therefore logically redundant and has no functional effect.</FACT>
    <FACT>rlevel is a delayed read-clock-domain view of FIFO occupancy. It does not encode whether its first two entries are I then Q, belong to the same epoch, or even are both valid DDC entries.</FACT>
    <FACT>The current FIFO interface has one write port and one 512-bit FIFO entry per write. It cannot atomically commit an I/Q pair as one storage transaction. ADC_PKT also has one AXIS beat per FIFO read and may be stalled by m_axis_tready between two emitted beats.</FACT>
    <FACT>ADC_PKT's 256-beat admission prevents underflow only for the raw count at admission. It does not prove that the 256 stored beats form complete DDC pairs or a single JESD epoch.</FACT>
    <FACT>Current link_ready only describes the current link state. After automatic relink it may return high while an old committed I remains in FIFO; a level/count signal has no memory of that historical fault.</FACT>
  </FACTS>
  <PROPOSAL_ANALYSIS>
    <CASE id="packet-start-rlevel-ge-2">No added protection. Existing fifo_level &gt;=256 makes the additional test redundant.</CASE>
    <CASE id="per-read-rlevel-ge-2">Can avoid reading when only one raw entry is visible, but cannot prove the two visible entries are an I/Q pair. It also changes a started packet from the current guaranteed 256-beat completion into a potentially indefinite mid-packet stall after an error.</CASE>
    <CASE id="even-rlevel">Not a proof. Under the narrow initial-empty, no-fault, complete-pair-only invariant, parity happens to track pair alignment at packet boundaries because a full packet consumes 256 (even) entries. A single committed I makes the count odd. But two interrupted epochs each leaving one I make it even again; so do other untagged loss/restart sequences. Even count says only that the number is even.</CASE>
    <CASE id="stable-even-rlevel">Still not a proof. A stable delayed count can describe a static sequence old-I,new-I or two incomplete epochs. It adds time observation but no origin/pair information.</CASE>
    <CASE id="link-ready-gating">Already partially present at packet_start. It prevents new admission while the link is currently low, but after relink it cannot distinguish residual old FIFO entries from current-epoch entries. It does not repair an already admitted packet.</CASE>
  </PROPOSAL_ANALYSIS>
  <FAILURE_TRACES>
    <TRACE>Packet-boundary partial: 255 valid old entries followed by I0 make rlevel=256. ADC_PKT may admit the packet; I0 is its last payload beat. If the link fails before Q0, a &gt;=2 start test was true and the emitted packet nevertheless ends with an unpaired I.</TRACE>
    <TRACE>Automatic-relink mix: an old I0 remains at FIFO head/tail after a link failure. Link relinks and writes I1,Q1. Once two entries are visible, a per-read &gt;=2 gate may read I0 then I1. The FIFO count is sufficient but the pair is cross-epoch and wrong.</TRACE>
    <TRACE>Parity false acceptance: two separate link interruptions can leave I0 and I1 without their Q partners. The raw count is even and can remain stable, yet the next apparent pair is invalid.</TRACE>
    <TRACE>Started-packet limitation: once the 256-beat packet has been admitted, new source data are ordered behind the admitted contents, but no current output field can mark a subsequently discovered partial DDC pair as invalid. Resetting or withholding reads can either truncate or indefinitely stall that packet.</TRACE>
  </FAILURE_TRACES>
  <OPTIONS>
    <OPTION id="1">
      <NAME>One-bit DDC abort latch, ADC packet-start gate, then existing software FIFO clear</NAME>
      <MECHANISM>In the AFE writer domain, latch a DDC-abort condition when a link/epoch loss occurs after I was committed and before Q was committed. Cross it as a level to ADC, block every subsequent packet_start, preserve an already admitted packet's existing 256-beat completion, and require the established disable/idle/FIFO_CLR/stable-empty/relink sequence before allowing a new packet. Clear the latch only with the same intentional recovery boundary.</MECHANISM>
      <WHAT_IT_GUARANTEES>It prevents automatic relink data from being consumed after a known committed-half-pair until the FIFO is deliberately purged. It preserves the current packet-completion policy for packets admitted before the abort becomes observable.</WHAT_IT_GUARANTEES>
      <LIMITATION>It cannot retract or label an I that was already part of an admitted packet when the later link loss is discovered. If that is unacceptable, no post-write flag can solve it; commit-after-Q buffering is required.</LIMITATION>
      <STATE_CDC_PPA>One writer-domain bit plus an existing-style level CDC and one ADC-side gate; no FIFO-width change. This is the smallest reliable mechanism for preventing old/new automatic-relink mixing, but it is semantically a persistent invalid/abort state even if given another name.</STATE_CDC_PPA>
      <VERIFICATION>Cover I-then-link-loss before packet admission, after admission, recovery clear, no next packet before stable empty, and relink with no old/new pair. Check that an already admitted packet follows the explicitly selected policy.</VERIFICATION>
    </OPTION>
    <OPTION id="2">
      <NAME>Automatic FIFO reset on link loss/relink</NAME>
      <MECHANISM>Assert whole-FIFO reset/clear when a DDC link loss is observed, preventing any old entry from surviving into a new epoch.</MECHANISM>
      <WHAT_IT_GUARANTEES>After reset convergence, no old I can pair with a new I/Q because no old FIFO content remains.</WHAT_IT_GUARANTEES>
      <CONFLICT_WITH_CURRENT_CONTRACT>The present ADC_PKT can be in PKT_PAYLOAD and waits for nonempty FIFO to finish its fixed 256 beats. Immediate FIFO reset makes it empty, causing a mid-packet stall rather than a valid completed packet. It also changes the documented FIFO reset ownership and requires asynchronous-reset assertion/release proof across both FIFO clocks.</CONFLICT_WITH_CURRENT_CONTRACT>
      <STATE_CDC_PPA>A direct reset term looks small, but a safe version must coordinate AFE link event, ADC packet state, FIFO reset protocol, and release. Deferring reset until packet idle requires control/CDC state comparable to or greater than Option 1.</STATE_CDC_PPA>
      <VERIFICATION>Would require revised packet-abort semantics or a drain-before-reset handshake, plus reset convergence, no stale FIFO data, and all clock-running cases.</VERIFICATION>
    </OPTION>
    <OPTION id="3">
      <NAME>Commit-after-Q buffering in ADC_RXD</NAME>
      <MECHANISM>Do not write I into the async FIFO immediately. Hold its 512-bit mapped result in AFE logic until the matching Q is available. On Q, reserve two FIFO slots and emit I then Q as one ordered pair; on link/epoch loss, discard only the uncommitted local I.</MECHANISM>
      <WHAT_IT_GUARANTEES>This is the only listed mechanism that prevents a lone I from ever entering FIFO. Therefore it protects pair identity even for future automatic relink without a FIFO purge, while preserving already committed complete pairs.</WHAT_IT_GUARANTEES>
      <COST_AND_RISK>Requires at least a 512-bit holding register, pair state, two-write scheduling, and a throughput proof that the next I/Q event cannot overrun the drain schedule. If source timing can present another pair before both writes commit, additional buffering is required. This is materially worse for FF area and control complexity than Option 1.</COST_AND_RISK>
      <VERIFICATION>Requires pair-atomic scoreboard checks, Q-side arrival timing, m_axis backpressure interaction, consecutive pair-rate stress, link loss in every hold/write phase, and automatic relink with retained old complete pairs.</VERIFICATION>
    </OPTION>
  </OPTIONS>
  <REJECTED_OPTIONS>Raw rlevel&gt;=2, even rlevel, stable-even rlevel, and current-link-ready-only gating are rejected as pair-identity mechanisms: none record epoch or I/Q ownership. A direct automatic FIFO reset is rejected for the current contract unless the user separately accepts packet abort/recovery semantic changes.</REJECTED_OPTIONS>
  <RECOMMENDATION>Conditional recommendation: for the existing PPA-first module contract, choose Option 1 and retain the existing explicit FIFO clear recovery. It is the minimum state needed to prevent a known half-pair from being followed by a new epoch, and is much smaller than buffering. The user proposal may be kept only as a harmless redundant assertion/check at packet start, not as correctness logic. If the requirement instead is autonomous relink with no software FIFO clear and no possibility of a lone I entering any packet, choose Option 3; there is no count-only substitute. Do not rename an abort latch and claim that this removes state—the necessary historical information is exactly one persistent state bit.</RECOMMENDATION>
  <ASSUMPTIONS>
    <ASSUMPTION>Existing 256-beat packet admission remains a required external contract and an already admitted packet is intended to complete unless the user explicitly changes that contract.</ASSUMPTION>
    <ASSUMPTION>AFE link/epoch loss can be detected in time to clear local unpack state, but no existing signal tags prior FIFO entries with that epoch.</ASSUMPTION>
    <ASSUMPTION>Official FIFO integration must later provide equivalent FWFT, level, reset, and clear behavior; this analysis is limited to the selected PUB FIFO evidence.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>
    <OPEN_QUESTION>Should a packet that was already admitted before a DDC I-to-Q link loss be completed and declared externally invalid, or should the interface gain an explicit packet-abort semantic? The current interface contains neither a payload invalid marker nor a packet abort mechanism.</OPEN_QUESTION>
    <OPEN_QUESTION>Does the user require automatic relink without the existing software FIFO clear? If yes, commit-after-Q buffering (or a larger tagged/transactional FIFO redesign) is required; the one-bit abort/clear recovery is not autonomous.</OPEN_QUESTION>
  </OPEN_QUESTIONS>
  <RESIDUAL_RISKS>All state/area claims are hypotheses until synthesis. The present model/TB may not exercise every exact concurrency race between packet admission and writer-side link-loss observation. VCS-level assertions should explicitly prove that no DDC pair crossing an epoch reaches a packet payload under the selected policy.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
