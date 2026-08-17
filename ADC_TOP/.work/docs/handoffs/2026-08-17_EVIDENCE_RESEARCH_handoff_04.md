<EVIDENCE_HANDOFF>
  <AGENT_ID>/root/adc_decim_evidence</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_EVIDENCE_RESEARCH_handoff_04.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <QUESTION_SCOPE>Complete 2-CML single-decimation r2/F=.5 and r3/F=.75 terminal phase/gap evidence from the primary grouping workbook; current ADC_TOP v1.5 is read-only comparison only. No architecture recommendation or implementation change.</QUESTION_SCOPE>
  <SOURCES>
    <SOURCE><TITLE>AC9810-32 JESD204B grouping scenarios</TITLE><PUBLISHER>AC9810 vendor material</PUBLISHER><PATH>D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx</PATH><ANCHORS>sheet3 “单抽取”, 2-CML rows107-108 (F=.5) and rows124-127 (F=.75); sheet3 B2 defines M=N+F, N=1..63, F={0,.25,.5,.75}.</ANCHORS></SOURCE>
  </SOURCES>
  <FACTS>
    <FACT confidence="HIGH">For r2/F=.5, each 2-CML row107/108 contains two contiguous 16-word indexed output groups `[0]` and `[1]`, followed by one extra repeated terminal word (`IN16[1]` / `IN32[1]`) at AM, then `(32N-16)*0` at AN. It then contains the same two 16-word groups `[2]` and `[3]`, one repeated terminal word at BU, and the same zero run at BV. The visible positional pattern is therefore `16,16,1,(32N-16)`, repeating.</FACT>
    <FACT confidence="HIGH">For r2, the terminal-to-terminal distances are consequently `{16, (1+(32N-16)+16), 16, (1+(32N-16)+16)}` = `{16,32N+1,16,32N+1}`. The phase count is four and the period is `64N+34` words. The exact first terminal is word15; successive terminal coordinates are `15`, `31`, `32N+32`, `32N+48`, and `64N+49` (the next cycle’s phase0 terminal). Their offsets modulo eight are respectively `7,7,0,0,1`; because the period is 2 modulo eight, this offset progression continues across cycles rather than being phase-static.</FACT>
    <FACT confidence="HIGH">For r3/F=.75, each 2-CML row124/125 has four contiguous 16-word indexed output groups `[0]` through `[3]`, then `(64N-16)*0` at BS. Rows126/127 continue with output groups `[4]` through `[7]`, then the same zero run at BS. The visible positional pattern is `16,16,16,(64N-16)` between groups, repeating across the two-row continuation.</FACT>
    <FACT confidence="HIGH">For r3, terminal-to-terminal distances are `{16,16,16,(64N-16)+16}` = `{16,16,16,64N}`. The phase count is four and the period is `64N+48` words. With first terminal word15, the next coordinates are `31,47,63,64N+63`; all are offset7 modulo eight because every gap is a multiple of eight.</FACT>
    <FACT confidence="HIGH">The r2/r3 zero-run expressions are nonnegative for N>=1: `32N-16` gives16 at N=1 and `64N-16` gives48 at N=1. This agrees with the single-decimation lower bound established in the preceding evidence addendum.</FACT>
  </FACTS>
  <INFERENCES>
    <INFERENCE>The current v1.5 r2 terminal schedule `{16,32N+1,16,32N+1}` and period `64N+34` exactly reproduce the full primary-workbook positional layout, including the otherwise easy-to-miss repeated terminal word. The `+1` is source-required; replacing it with the zero-run-plus-output expression `32N` would lose that word.</INFERENCE>
    <INFERENCE>The current v1.5 r3 terminal schedule `{16,16,16,64N}` and period `64N+48` exactly reproduce the primary-workbook layout: unlike r1, the long terminal distance is the zero run plus the following 16-word output group.</INFERENCE>
    <INFERENCE>With the existing scheduler coordinate convention (`next_term_r=15` initially), the terminal-offset facts above validate retained cross-beat history/slicing for r2 because offsets are not permanently 7. r3 may always end at offset7, but this does not authorize a mode-specific RTL redesign.</INFERENCE>
  </INFERENCES>
  <CONFLICTS>
    <CONFLICT><TARGET>ADC_TOP v1.5 r2/r3 forms at lines499-500 and 518; ADC_RXD.v lines260-261</TARGET><DETAIL>NONE. The current r2 and r3 gap sequences, phase counts and periods match the primary-workbook positional layouts. This evidence does not remove the separately identified r1 conflict (`64N-48` is its zero run, whereas its terminal gap is `64N-32`).</DETAIL></CONFLICT>
  </CONFLICTS>
  <GAPS>
    <OPEN_QUESTION>The workbook layout establishes r2/r3 word positions, but system-level lane-rate feasibility for every N still depends on the selected ADC clock/CML configuration and sheet3 B2’s rate ceiling.</OPEN_QUESTION>
  </GAPS>
  <RESIDUAL_RISKS>No RTL/TB/XDC changed and no verification ran. This handoff proves the workbook positional derivation only; it does not claim board-capture or vendor-IP equivalence.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</EVIDENCE_HANDOFF>
