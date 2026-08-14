<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_upk_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_03.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <ITEM>User decision, 2026-08-14: select conservative DDC abort. While DDC mode and the effective channel are enabled, a link/epoch validity loss latches abort, pulses existing data_drop_evt, and prevents every new ADC_PKT admission until FIFO_CLR or AFE reset.</ITEM>
    <ITEM>Retain immediate I then Q FIFO writes, WC=0 native overflow, fifo_wlevel&gt;=2 DDC pair reservation, ddc_i_accepted state, fixed 256-payload-beat packet completion, no 512-bit I buffer, and no new software register bit.</ITEM>
    <ITEM>Refine exact event, priority, intentional-disable, CDC, public-software and verification semantics without changing design/RTL/TB.</ITEM>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASHES>
    <HASH role="Evidence Researcher">233e6b4f6dc83cd672646280440e99e3e4d55348b434ff83d1af1ef0aee5c8bb</HASH>
    <HASH role="Prior Architecture">9147bcdd84dabc4a91e06362a9af13983506ab8fcc711bf2c6694e14c0d274b2</HASH>
    <HASH role="Prior Design Author Candidate">7662c9881eb8a94cc51cfe77d25ebab615068db413223bea4b956b8aa5c39c53</HASH>
  </EVIDENCE_HANDOFF_HASHES>
  <SELECTED_ARCHITECTURE_REFINEMENT>
    <DEFINITIONS>
      <ITEM>`effective_channel_enabled` is `chn_en_afe`, the ADC-domain effective enable synchronized into AFE. It is not the raw software AFE_EN request.</ITEM>
      <ITEM>`ddc_epoch_live` is `(smp_mode == 2'd2) &amp;&amp; chn_en_afe &amp;&amp; epoch_valid_r`.</ITEM>
      <ITEM>`ddc_abort_set_evt` is `!ddc_abort_afe &amp;&amp; ddc_epoch_live &amp;&amp; (!link_ready_afe || !adi_rx_valid)`.</ITEM>
      <ITEM>The existing unpack contract already treats any `adi_rx_valid==0` while active as loss of the current epoch and clears epoch/block history. Therefore the event has no new valid-bubble assumption beyond the accepted design.</ITEM>
    </DEFINITIONS>
    <WHY_EPOCH_VALID_ARMS_THE_EVENT>`!epoch_valid_r` must not itself be a set level. Before first legal SOMF, after enable, and during relink acquisition, epoch_valid_r is correctly zero and no prior DDC payload is at risk. Requiring old/current epoch_valid_r=1 makes the first loss cycle a single event without a new previous-value register.</WHY_EPOCH_VALID_ARMS_THE_EVENT>
    <LATCH_PRIORITY>
      <ORDER priority="1">Asynchronous `!afe_rst_n`: clear ddc_abort_afe. AFE reset also clears the whole FIFO through the accepted FIFO reset equation.</ORDER>
      <ORDER priority="2">Synchronous sampled `fifo_clr==1`: clear ddc_abort_afe. Clear dominates a coincident set because FIFO contents are being intentionally discarded.</ORDER>
      <ORDER priority="3">`ddc_abort_set_evt`: set ddc_abort_afe.</ORDER>
      <ORDER priority="4">Otherwise hold.</ORDER>
      <NOTE>ADC reset alone does not clear the AFE-domain latch. This avoids an ADC-to-AFE reset dependency and follows the user's selected clear sources. Since ADC reset clears the FIFO but not abort, software still completes the selected FIFO_CLR/AFE-reset recovery before new packet admission.</NOTE>
    </LATCH_PRIORITY>
    <DATA_DROP_EVENT>`data_drop_evt` emits exactly one AFE-clock pulse on ddc_abort_set_evt. Persistent low link/valid does not retrigger because epoch_valid_r clears and ddc_abort_afe is set. The existing separate pulse for a deliberately rejected DDC I when fifo_wlevel&lt;2 remains; it does not set abort because the matching Q is also suppressed and FIFO pair alignment remains intact.</DATA_DROP_EVENT>
    <PACKET_POLICY>The synchronized abort state gates only the `PKT_IDLE` packet_start equation and applies regardless of the current sample mode until recovery. It must not gate `PKT_HEADER`, `PKT_PAYLOAD`, `fifo_rd_inc`, AXIS valid, or reset the packet FSM. An already admitted packet therefore completes its structural Header+256 Payload contract; software/backend discards that packet when the DATA_DROP recovery context says its data may be invalid. A mode change cannot bypass a stale DDC abort because stale FIFO data is mode-independent.</PACKET_POLICY>
    <WRITER_POLICY>The abort latch does not stop new AFE-side FIFO writes by itself; the user's selected mechanism is an admission gate, not an automatic source stop. Automatic relink may refill the FIFO and may cause native overflow, but none of that data can start a new packet before FIFO_CLR/AFE reset. The supported recovery flow disables the channel before clearing, so all old and relink-era contents are discarded together.</WRITER_POLICY>
  </SELECTED_ARCHITECTURE_REFINEMENT>
  <EDGE_CHOICE_COMPARISON>
    <CHOICE id="event-arm">
      <SELECTED>`epoch_valid_r &amp;&amp; effective_channel_enabled` arms link/valid loss.</SELECTED>
      <REJECTED>Low-level `!epoch_valid_r` sets abort: falsely flags startup, SOMF wait and normal relink acquisition.</REJECTED>
    </CHOICE>
    <CHOICE id="enable-boundary">
      <SELECTED>Use `chn_en_afe`, which remains high while an already-started packet drains and falls only when effective shutdown reaches AFE.</SELECTED>
      <REJECTED>Use raw AFE_EN: it is not AFE-domain synchronized and would disarm protection too early when software requests stop while a packet is still completing.</REJECTED>
      <INTENTIONAL_DISABLE>When the link remains valid, a normal AFE_EN clear eventually lowers chn_en_afe; the guard then prevents the expected device reset/adi_rx_valid drop from creating abort. If link/valid fails before effective enable falls, abort sets conservatively.</INTENTIONAL_DISABLE>
    </CHOICE>
    <CHOICE id="clear-versus-set">
      <SELECTED>FIFO_CLR clear wins over set on the same AFE edge because FIFO reset discards the potentially invalid entry.</SELECTED>
      <REJECTED>Set wins: would leave abort latched after the recovery action that removed the hazard and force a second clear.</REJECTED>
    </CHOICE>
    <CHOICE id="cdc-polarity">
      <PREFERRED>Synchronize `ddc_admit_ok_afe = ~ddc_abort_afe` as a level into ADC with destination reset value zero, then require ddc_admit_ok_adc for every packet_start. This is fail-closed during ADC reset/release and uses the same one-bit level synchronizer resources as direct abort synchronization.</PREFERRED>
      <ALTERNATIVE>Synchronize ddc_abort_afe directly with the existing reset-to-zero level primitive and gate with `!ddc_abort_adc`. It is simpler in naming but transiently fail-open after adc_rst_n release until a pre-existing high abort propagates; relying on FIFO level 256 to provide enough latency couples correctness to clock/fill behavior.</ALTERNATIVE>
      <REJECTED>Add a separate CDC-valid/handshake bit: unnecessary if the inverted admit-ok level is used.</REJECTED>
    </CHOICE>
  </EDGE_CHOICE_COMPARISON>
  <CDC_AND_RESET>
    <ITEM>Source ownership: ddc_abort_afe is an AFE-domain state bit under afe_clk/afe_rst_n.</ITEM>
    <ITEM>Destination use: only ADC_PKT packet admission in adc_clk/adc_rst_n. Use one existing PUB level synchronizer; no pulse CDC is sufficient for the persistent gate.</ITEM>
    <ITEM>Diagnostic path stays the existing AFE-to-ADC data_drop pulse synchronizer followed by ADC-to-SYS pulse synchronization and ADC_REG sticky capture.</ITEM>
    <ITEM>FIFO_CLR must remain asserted long enough to be sampled by afe_clk as already required by the clocks-running FIFO-clear contract; no fixed wall-clock delay is introduced.</ITEM>
    <ITEM>AFE reset asynchronously clears the abort source and whole FIFO. ADC reset clears the whole FIFO and destination synchronizer but preserves the source latch; fail-closed admit-ok CDC prevents a post-reset admission window.</ITEM>
  </CDC_AND_RESET>
  <PUBLIC_SOFTWARE_SEMANTICS>
    <ITEM>No new register/status bit is added. Existing per-channel DATA_DROP_PD is set for either DDC abort or deliberate insufficient-two-space pair rejection.</ITEM>
    <ITEM>W1C of DATA_DROP_PD acknowledges only the SYS sticky diagnostic. It does not clear ddc_abort_afe and must never be treated as permission to restart.</ITEM>
    <ITEM>Because the public bit does not distinguish the two data-drop causes, the conservative software rule is: any DATA_DROP_PD in DDC mode requires AFE_EN clear, completion/AFE_IDLE observation, FIFO_CLR with both clocks running, clear convergence/stable FIFO_EMPTY, then relink/re-enable. This may clear a pair-aligned FIFO after a capacity drop, but preserves simple and safe software semantics.</ITEM>
    <ITEM>Automatic relink without FIFO_CLR cannot reopen packet admission. Clearing DATA_DROP_PD alone leaves packet admission blocked.</ITEM>
  </PUBLIC_SOFTWARE_SEMANTICS>
  <VERIFICATION_ACCEPTANCE>
    <ITEM>DDC enable before the first SOMF and link-ready wait must not set abort or DATA_DROP_PD.</ITEM>
    <ITEM>After a valid DDC epoch, one-cycle or persistent link_ready_afe loss must set abort and produce exactly one data_drop_evt pulse.</ITEM>
    <ITEM>After a valid DDC epoch, one-cycle or persistent adi_rx_valid loss must produce the same one-shot behavior.</ITEM>
    <ITEM>Loss must set abort even when no I is pending; loss after accepted I and before Q must also set it and leave the lone FIFO entry unread by every later packet start.</ITEM>
    <ITEM>Automatic relink/new SOMF without clear may write, but packet_start remains false at fifo_level 256 or above and under all sample modes.</ITEM>
    <ITEM>An already-started packet continues through backpressure and completes exactly one Header plus 256 Payload beats; no abort-driven tail packet, truncation, or FSM reset is allowed.</ITEM>
    <ITEM>Intentional AFE_EN clear with a healthy link must not set abort. Link/valid loss before chn_en_afe actually falls must set abort.</ITEM>
    <ITEM>FIFO_CLR and a coincident loss clear abort with no new abort pulse; after stable empty and clear deassertion, fail-closed CDC opens admission only after the synchronized safe level arrives.</ITEM>
    <ITEM>AFE reset clears abort/FIFO; ADC-only reset preserves source abort and no packet starts during or immediately after destination reset while the abort remains set.</ITEM>
    <ITEM>W1C DATA_DROP_PD without FIFO_CLR does not reopen packet admission. Full recovery clears FIFO and abort, after which only clean new-epoch data reaches the next packet.</ITEM>
    <ITEM>Normal and decimation modes never set a new abort, but a previously latched DDC abort still gates their packet admission until recovery.</ITEM>
  </VERIFICATION_ACCEPTANCE>
  <PPA_HYPOTHESIS>One AFE state bit, one existing-style 1-bit level CDC, one packet_start gate and reuse of the existing data_drop pulse path. Inverted admit-ok CDC has the same state count as direct abort CDC. This remains far smaller than a 512-bit I buffer, pair scheduler, epoch tags, or automatic FIFO-reset handshake; actual PPA is unmeasured until synthesis.</PPA_HYPOTHESIS>
  <REJECTED_OPTIONS>Do not reintroduce rlevel&gt;=2/even/stable-even as pair identity; do not use raw AFE_EN as the AFE loss guard; do not let DATA_DROP_PD W1C clear abort; do not reset/abort an already-started packet; do not allow a sample-mode change to bypass the gate.</REJECTED_OPTIONS>
  <RECOMMENDATION>Freeze the selected conservative scheme using the exact armed-loss event, clear-wins priority, effective-enable boundary, unconditional new-packet gate and conservative public recovery above. Prefer inverted `ddc_admit_ok` level synchronization because it provides fail-closed ADC reset behavior for no additional state or PPA hypothesis cost.</RECOMMENDATION>
  <ASSUMPTIONS>
    <ASSUMPTION>Static sample-mode/configuration remains unchanged while the effective channel is active.</ASSUMPTION>
    <ASSUMPTION>Once established, the selected ADI device stream normally keeps adi_rx_valid asserted continuously; current unpack RTL already treats a low cycle as epoch loss.</ASSUMPTION>
    <ASSUMPTION>The software-controlled FIFO_CLR flow continues to keep AFE_CLK and ADC_CLK running and satisfies the selected FIFO implementation's documented reset/clear assertion and convergence requirements.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>NONE. The user selected the conservative false-positive tradeoff and explicit clear recovery; the remaining packet-data disposition is specified as structural completion plus software/backend discard.</OPEN_QUESTIONS>
  <RESIDUAL_RISKS>A DATA_DROP pulse concurrent with downstream ADC/SYS reset may not reach the sticky register, although the persistent internal gate remains. With no new public live-abort bit, software may observe blocked admission without a newly captured DATA_DROP_PD after such a reset coincidence; system reset/recovery procedure must still perform FIFO clear. The one-bit abort cannot retract a lone I already consumed by an admitted packet; that packet is completed structurally and discarded by recovery context. Official FIFO replacement, VCS and board behavior remain unverified.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
