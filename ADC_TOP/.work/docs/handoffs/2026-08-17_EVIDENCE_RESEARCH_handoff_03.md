<EVIDENCE_HANDOFF>
  <AGENT_ID>/root/adc_decim_evidence</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_EVIDENCE_RESEARCH_handoff_03.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <QUESTION_SCOPE>Mode-specific AC9810 2-CML zero-run legality and the single-decimation r1 terminal-gap reconciliation. This is a read-only evidence addendum; no RTL architecture is proposed.</QUESTION_SCOPE>
  <SOURCES>
    <SOURCE><TITLE>AC9810-32 JESD204B grouping scenarios</TITLE><PUBLISHER>AC9810 vendor material</PUBLISHER><PATH>D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx</PATH><ANCHORS>single-decimation sheet3 “单抽取”: B2, rows70-71 (r0), 87-90 (r1), 107-108 (r2), 124-127 (r3). DDC sheet4 “抽取+DDC”: rows68-69 (r0), 90-93 (r1), 110-113 (r2), 130-133 (r3).</ANCHORS></SOURCE>
    <SOURCE><TITLE>AC9810-32 Register Manual</TITLE><PUBLISHER>海思技术有限公司</PUBLISHER><VERSION>03</VERSION><DATE>2025-12-08</DATE><PATH>D:\Codex\Vault\RAW\Datasheet\AC9810-32\01-Data Sheet\AC9810-32 寄存器手册.pdf</PATH><ANCHORS>physical pages66-67, printed pages59-60: CFG_DEMOD_FACT_FRAC offset0x09, CFG_DEMOD_FACT_INT offset0x0A.</ANCHORS></SOURCE>
  </SOURCES>
  <FACTS>
    <FACT confidence="HIGH">The workbook defines M=N+F with N=1..63 and F={0,.25,.5,.75} (sheet3 B2). The register manual independently defines FACT_INT[5:0] range[1,63] and FACT_FRAC[1:0] encodings 00/01/10/11 for F=0/.25/.5/.75 (pages66-67).</FACT>
    <FACT confidence="HIGH">For 2-CML single decimation the explicit trailing zero runs are: r0/F0:16N-16 (sheet3 rows70-71); r1/F.25:64N-48 (rows87-90); r2/F.5:32N-16 (rows107-108); r3/F.75:64N-16 (rows124-127). Each is nonnegative for every integer N>=1; r0 at N=1 is exactly zero. Thus these four single-decimation workbook layouts support N>=1 by zero-run nonnegativity.</FACT>
    <FACT confidence="HIGH">For 2-CML DDC the explicit trailing zero runs are: r0/F0:16N-32 (sheet4 rows68-69); r1/F.25:64N-112 (rows90-93); r2/F.5:32N-48 (rows110-113); r3/F.75:64N-80 (rows130-133). For integer N, simultaneous nonnegative legality requires N>=2. At N=2 the four values are respectively 0,16,16,48; therefore zero-length padding is a valid layout boundary, while N=1 would require negative padding in every listed DDC r case.</FACT>
    <FACT confidence="HIGH">Single-decimation r1 rows87-90 show four contiguous 16-word output groups followed by a `(64N-48)*0` run. A terminal-to-terminal gap crosses the subsequent 16-word output group as well as its preceding zero run. The long terminal gap is therefore (64N-48)+16=64N-32; the four-gap cycle is 16,16,16,(64N-32), whose exact sum is 64N+16.</FACT>
    <FACT confidence="HIGH">The same “zero run plus following 16-word output” accounting matches the current DDC long-gap forms: r0 (16N-32)+16=16N-16, r1 (64N-112)+16=64N-96, r2 (32N-48)+16=32N-32, r3 (64N-80)+16=64N-64. These are source-layout-derived terminal distances, not zero-run values themselves.</FACT>
    <FACT confidence="HIGH">The lossless internal compact encoding is E={N[5:0],f[1:0]}=4N+f. If all physical factor combinations are exposed, its exact range is 8'h04..8'hFF inclusive. It is an ADC-side control encoding; the AC9810 instead programs FACT_INT/FACT_FRAC as separate registers, each with an independent profile/direct-select bit [8].</FACT>
    <FACT confidence="HIGH">For N=63, 16N=1008, 32N=2016 and 64N=4032. Source-derived long terminal distances include 4000 for single-dec r1 and 3936/3968 for DDC r1/r3; the largest scheduler gap remains 4032. A full N=63 formula datapath requires unsigned 12-bit gap/term storage (0..4095); 11-bit storage truncates 64N and several long gaps.</FACT>
  </FACTS>
  <INFERENCES>
    <INFERENCE>Use of the documented physical-factor range is mode dependent at the framing scheduler boundary: single decimation can admit N=1 from these layout formulas, while DDC must admit no lower than N=2 unless a different N=1 DDC layout is supplied. This is narrower and evidence-based compared with a blanket N>=8 restriction, but lane-rate feasibility remains separately constrained by sheet3 B2’s rate ceiling.</INFERENCE>
    <INFERENCE>The source-proven r1 single-dec schedule is `{16,16,16,64N-32}` with cycle 64N+16. The current v1.5 RTL/design form `{16,16,16,64N-48}` sums to 64N, so its r1 long gap omits one 16-word output block. The design table’s stated 64N+16 period agrees with the workbook-derived result, while its listed long-gap formula and ADC_RXD formula do not.</INFERENCE>
    <INFERENCE>Exact source-derived terminal-distance formulas established here are: single r0=16N, single r1=64N-32; DDC r0=16N-16, r1=64N-96, r2=32N-32, r3=64N-64. The workbook zero-runs for single r2/r3 are recorded above, but their full fractional terminal phase schedules require a complete positional derivation and are not asserted here beyond the requested r1 reconciliation.</INFERENCE>
  </INFERENCES>
  <CONFLICTS>
    <CONFLICT><TARGET>ADC_TOP v1.5 design lines498,516-518; ADC_RXD.v lines248,256-261</TARGET><DETAIL>For single-dec r1, v1.5 selects long gap 64N-48. That is the workbook’s zero-run only, not its terminal distance. It yields cycle64N, contradicting v1.5’s own table period64N+16 and the positional workbook layout. The source-derived long gap is64N-32.</DETAIL></CONFLICT>
    <CONFLICT><TARGET>ADC_TOP v1.5 legal n=8..24 and 11-bit gap contract; ADC_RXD.v lines54-62,227-229,245-266</TARGET><DETAIL>The primary source factors are N=1..63, with 2-CML layout lower bounds N>=1 for single decimation and N>=2 for DDC. If support is extended to N=63, existing 11-bit gaps are insufficient; 12 bits are required. The current subset can remain a deliberate system limitation, but it is not the raw-device range.</DETAIL></CONFLICT>
  </CONFLICTS>
  <GAPS>
    <OPEN_QUESTION>Sheet3 B2’s lane-rate ceiling has not been evaluated for a concrete ADC clock and CML choice; nonnegative padding alone does not prove each N/F is electrically feasible in a selected system.</OPEN_QUESTION>
    <OPEN_QUESTION>No source in this extraction states an alternative N=1 DDC 2-CML framing layout. Treat DDC N=1 as unsupported by the listed layout until authoritative replacement evidence is supplied.</OPEN_QUESTION>
  </GAPS>
  <RESIDUAL_RISKS>No RTL/TB/XDC changed and no verification ran. The full r2/r3 single-dec terminal phase derivation is intentionally not claimed in this targeted addendum.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</EVIDENCE_HANDOFF>
