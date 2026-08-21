<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_rework_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_ARCHITECTURE_handoff_05.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <ITEM>User intent: introduce ADC_JESD204 as the wrapper of immutable ADI jesd204_rx; move full ADC_CTL/FRAME_CFG and ADC_TGC register decoding into their downstream owners; ADC_RXD is the primary functional rewrite.</ITEM>
    <ITEM>Current working tree versus RTL_Temp Git baseline a2d303b, current v1.26 design/state and ADI provenance.</ITEM>
    <ITEM>User clarification: ADC_TGC direct full-register ownership is intentionally incomplete; classify it as a structural placeholder, not a final behavior change.</ITEM>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>NONE; this is a direct read-only current-tree and a2d303b comparison.</EVIDENCE_HANDOFF_HASH>
  <OPTIONS>
    <OPTION id="A">
      <BOUNDARY>ADC_JESD204 owns one ADI core instance, all JESD-domain PHY pins/control/status derivation, JESD and AFE enable synchronization, core/device reset construction, JESD-to-AFE link_ready synchronization, and exposes only an AFE-domain decoded tuple (rx_data[255:0], rx_valid, rx_somf) plus documented JESD-domain status/events. ADC_RXD owns only AFE-domain unpack/region/FIFO-write/DDC-abort behavior. CHN_SYNC remains the status/event transport to ADC; ADC_SYNC remains SYS-to-ADC enable and SYS/ADC/AFE status/TGC transport.</BOUNDARY>
      <CDC_RESET>CHN enable becomes ADC-domain first, then two single-bit synchronizers inside ADC_JESD204 to AFE/JESD. ADI reset is asserted from local reset, synchronized enable, PHY reset-done and PLL lock. Device reset is AFE-local. SYSREF is sampled in the ADI device_clk (AFE) domain; its source-domain contract must be explicit. No multi-bit encoded ADI status crosses independently.</CDC_RESET>
      <DATA_RECOVERY>ADI emits AFE-domain data/valid/SOMF; RXD consumes the pre-edge tuple exactly as the v1.26 contract states. Link/disparity/not-in-table/frame events remain sourced once in JESD or AFE and CHN_SYNC pulse-synchronizes them. FIFO/DDC ownership remains solely in RXD/ADC_CHN.</DATA_RECOVERY>
      <MAINTENANCE>Recommended conditional boundary: it is the cleanest one-way vendor adapter and permits isolated surrogate verification of ADI-facing behavior. It keeps downstream FIFO/DDC policy independent of the third-party core.</MAINTENANCE>
    </OPTION>
    <OPTION id="B">
      <BOUNDARY>ADC_JESD204 is only a thin named ADI instantiation. CHN_SYNC or ADC_CHN retains both enable synchronizers, local reset construction, link-ready synchronization, and JESD event derivation; ADC_RXD consumes the ADI tuple.</BOUNDARY>
      <CDC_RESET>Requires the ADI core's JESD and device lifecycle to be split among three modules. Both the wrapper and its caller must expose raw core status/control ports.</CDC_RESET>
      <DATA_RECOVERY>Can preserve legacy code mechanically but leaves third-party reset/configuration and event semantics outside the wrapper.</DATA_RECOVERY>
      <MAINTENANCE>Feasible only if the explicit goal is a very thin adapter. It has more ports, weaker ownership, and reintroduces the ownership split that the proposed refactor is trying to remove.</MAINTENANCE>
    </OPTION>
  </OPTIONS>
  <REJECTED_OPTIONS>
    <ITEM>Do not place FIFO, region FSM, DDC I/Q admission, packetization, or AXIS in ADC_JESD204. Those are ADC product policy, not ADI/JESD adaptation; moving them would couple recovery and packet behavior to the vendor boundary without an identified benefit.</ITEM>
  </REJECTED_OPTIONS>
  <RECOMMENDATION>INFERENCE: Option A is the coherent wrapper boundary if the user wants ADC_JESD204 to be a real ADC-owned IP boundary. It requires completing the wrapper interface first, then making ADC_RXD a pure AFE-domain consumer. This is a conditional recommendation, not an option selection. Option B remains available if the user instead explicitly wants only an ADI module rename.</RECOMMENDATION>
  <ASSUMPTIONS>
    <ITEM>ADI jesd204_rx configuration remains the frozen N'=16, 2-lane, 8B/10B configuration from the prior v1.26 baseline; source provenance identifies frozen ADI commit 9d5de2fc21b6069675104567c9041bcdbfbe9baa.</ITEM>
    <ITEM>ADC_REG remains the SYS-domain owner of AXI readback, safe-write policy, sticky diagnostics, ADC_TGC request acceptance, pending-bit auto-clear on completion, and W1C handling unless the user intentionally changes that software ABI.</ITEM>
  </ASSUMPTIONS>
  <FACTS>
    <FACT severity="P0" category="structural">ADC_JESD204.v is 112 lines of an extracted body with no module declaration, port declarations, or endmodule. It begins with an instance using undeclared names. It is not listed in rtl/filelist.f, so even a completed ADC_CHN reference would not compile from the current declared source list.</FACT>
    <FACT severity="P0" category="structural">ADC_CHN.v contains the literal placeholder ADC_JESD204 adc_jesd( ..... );. Its ADC_RXD instance names ports absent from the current ADC_RXD declaration, while ADC_PKT still references removed/undeclared smp_prec, smp_mode and dec_m. ADC_CHN declares adc_ctl as [1:0] although ADC_TOP passes a 32-bit register.</FACT>
    <FACT severity="P0" category="structural">ADC_RXD.v has a standalone 'assign' at line 128, duplicate declarations of rxd_sta_valid/rxd_sta_zero, and a hybrid of removed JESD-side names (chn_en_afe, link_ready_afe, adi_rx_data, adi_rx_valid, adi_rx_somf, en_adc/en_afe) with no corresponding ports or wrapper instance. It cannot presently elaborate as a pure AFE consumer.</FACT>
    <FACT severity="P0" category="RXD">pair_pha is declared but has no sequential or continuous driver, including no reset value. rxd_pair_complete = rxd_sta_valid &amp; pair_pha; FIFO write eligibility and DDC I/Q admission consequently depend on an undriven state. This alone prevents a defined FIFO/DDC function.</FACT>
    <FACT severity="P0" category="RXD">FIFO_CLR is included in rxd_clr but rxd_fsm, pref_cnt, region_cnt and rxd_buff0/1 clear only on !upk_vld, not rxd_clr. Thus a FIFO clear while link/valid remains true does not clear partial prefix/region/buffer context, contrary to the retained clear/relink contract.</FACT>
    <FACT severity="P0" category="RXD">RXD_VALID unconditionally enters RXD_ZERO on region_clr. For ADC mode and any selected zero length of zero, zero_max is 0 but RXD_ZERO still consumes one beat before returning to VALID. The a2d303b behavior explicitly bypassed RXD_ZERO when selected_zero_beats was zero. This is a material data-drop change, not a refactor-only difference.</FACT>
    <FACT severity="P1" category="RXD">Current buffering captures only when update_data = region_clr &amp; rxd_sta_valid. The a2d303b design captured the first valid beat when rxd_valid_beat &amp; !rxd_pair_phase and formed a candidate on the second. With the missing pair_pha transition, the new timing cannot presently demonstrate the former two-beat 512-bit candidate ordering.</FACT>
    <FACT severity="P1" category="RXD">INFERENCE from pre-edge FSM evaluation: the new PREF-&gt;VALID transition occurs at pref_cnt==pref_max but no transitional beat is counted as valid/captured; the baseline counted payl_hit on that transition. Unless this was intentional, the first payload beat is delayed one accepted AFE beat. It needs an explicit cycle table before implementation.</FACT>
    <FACT severity="P1" category="CDC">ADC_REG produces adc_ctl/frame_cfg in SYS. ADC_TOP now passes raw 32-bit values directly into every ADC_CHN/AFE-side decoder and raw ADC_CTL[0..15] provides enable/clear. This has no declared bundle-coherency or local pulse/level CDC rule. The former ADC_SYNC ADC-domain enable output is now unused, and CHN_SYNC's per-channel enable synchronizers were removed.</FACT>
    <FACT severity="P1" category="event_status">The extracted ADC_JESD204 body contains the correct legacy ownership candidates: ADI status decoded in JESD, link_ready synchronized to AFE, JESD edge events, and AFE SYSREF events. These must not simultaneously remain in ADC_RXD, otherwise duplicate sources or split reset/event ownership result. CHN_SYNC can continue to be the only JESD/AFE-to-ADC event transport.</FACT>
    <FACT severity="P1" category="TGC">The current ADC_TGC and ADC_REG code remain behaviorally equivalent to a2d303b; Git shows no ADC_TGC diff. ADC_TOP/ADC_SYNC still decode adc_tgc[12:1] outside ADC_TGC. Per user clarification this is an acknowledged temporary placeholder, not a finding against the intended final boundary.</FACT>
    <FACT severity="P1" category="TGC_CDC">The retained design sends tgc_req by pulse synchronizer while the TGC fields are level wires. Moving full adc_tgc into ADC_TGC must retain a coherent snapshot rule: ADC_REG owns write acceptance/pending auto-clear and exports an accepted request; the AFE side captures a stable decoded bundle when that request arrives. Direct independent sampling of a live 32-bit SYS register is not a complete CDC contract.</FACT>
    <FACT severity="P2" category="hygiene">git diff --check reports trailing whitespace in ADC_RXD. This is nonfunctional but should be removed as part of a later correction batch.</FACT>
  </FACTS>
  <OPEN_QUESTIONS>
    <QUESTION priority="1">Please confirm Option A intent: should ADC_JESD204 own both enable crossings and ADI reset creation, and expose the AFE-domain rx_data/rx_valid/rx_somf tuple to ADC_RXD, while CHN_SYNC retains only status/event CDC?</QUESTION>
    <QUESTION priority="1">For the primary ADC_RXD rewrite, is the intended functional schedule still exactly the v1.26 one: payload beat is captured on the PREF-to-VALID transition, pairs are first-valid then second-valid, and zero-length regions do not consume a beat? The current equations/states implement a different schedule.</QUESTION>
    <QUESTION priority="1">What is SYSREF's guaranteed source clock/relationship? ADI jesd204_rx samples SYSREF in device_clk (AFE) logic. The wrapper must either receive an AFE-synchronous SYSREF or own the defined synchronization/edge-width rule.</QUESTION>
    <QUESTION priority="2">For full ADC_CTL/FRAME_CFG ownership, do you want a static-bundle protocol (software writes only disabled/idle, then local consumers sample after synchronized enable) or an explicit SYS-to-ADC/AFE configuration mailbox/acknowledgement? The answer determines how full-register decoding remains CDC-safe.</QUESTION>
    <QUESTION priority="2">For final ADC_TGC, should ADC_REG preserve its present command bit0/pending/readback/auto-clear semantics and deliver a separate accepted tgc_req pulse plus coherent adc_tgc configuration to ADC_TGC? This is the smallest change consistent with internal ADC_TGC bit decode.</QUESTION>
    <QUESTION priority="2">Should FIFO_CLR retain the legacy asynchronous FIFO-reset assertion path, or become a locally synchronized clear request with an acknowledgement? Either is viable, but reset release and same-edge pending-write priority differ and must be frozen before RXD repair.</QUESTION>
  </OPEN_QUESTIONS>
  <RESIDUAL_RISKS>
    <ITEM>No compilation, lint, VMware, VCS/Verdi, XSIM, synthesis, implementation, timing or board test was performed by this architecture worker.</ITEM>
    <ITEM>Current files are intentionally incomplete, so the findings identify source-level blockers and manually inspectable semantic divergences; execution evidence is required after the user selects the boundary and the RTL is completed.</ITEM>
    <ITEM>The ADI wrapper/source is GPLv2 unless a commercial license applies; the existing provenance records that a project-level distribution compliance decision remains necessary.</ITEM>
  </RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
