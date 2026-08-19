---
type: rtl_diagnosis_handoff
module_name: ADC_TOP
date: 2026-08-18
run_id: ADC_TOP_66dd4e9f5c2f427d909a5c33130a107d
author_agent_id: /root/adc_accum_rtl
tags: [FPGA/Handoff, RTL, Diagnosis]
---

# ADC_TOP RTL Source-Timing Diagnosis

## Scope And Evidence Boundary

- Immutable read-only diagnosis for the v1.15 `ADC_TOP_66dd4e9f5c2f427d909a5c33130a107d` VMware return.
- Evidence: JUnit SHA256 `27f96ebc1d236beb6b55d35173a5f5f5a5ebee54eaef9e9c4b6d654e22b9eb6d`; verification input fingerprint `247eba2a3ef9f73172767184d5c8b58643c97c93770818aee88067feda07a392`; toolchain fingerprint `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`.
- Current observed RTL: `D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v`, SHA256 `18a3a30dca02d1b31d897e4c567d9b8d8a1f8f6f495775ee70b97e67cae8b45a`.
- No RTL, design, TB, XDC, ADI, or PUB file was changed by this diagnosis. This handoff neither advances verification status nor authorizes an RTL/TB/XDC/design change.

## Terminal-15 Local Generation Proof

The legal-matrix JUnit failure at 39328 ns reports payload beat 0 as scheduler positions 16 through 31, while its expected payload is positions 0 through 15. `0x0264` is exactly scheduler lane-0 position 16; all reported words retain the expected interleave, so this is not a mapping or precision permutation failure.

For the first valid pair received by `ADC_RXD`:

1. On `RXD_PREF` with `payl_hit=1`, pre-edge `rxd_pair_phase=0`; the AFE edge captures P0 into `rxd_buff0/1` and updates the phase to 1.
2. On the following `RXD_VALID` AFE edge, P1 has `rxd_pair_complete=1`. The registered FIFO request is scheduled with `fifo_wr_data` derived from `{P1,rxd_buff(P0)}` and `fifo_wr_valid=1`.
3. The following AFE edge presents that registered request to the PUB FIFO. Its candidate is terminal 15, exactly P0..P15.

Therefore the local `ADC_RXD` source timing generates terminal 15. The observed terminal-31 first packet beat establishes a two-accepted-beat displacement at or upstream of the ADI-to-`adi_rx_data`/marker boundary, or in a downstream observation boundary; it does not identify an `ADC_RXD` concat or mapping edit as a valid correction.

## ADI Boundary Follow-Up

The remaining required integrated analysis is to align, at two accepted AFE beats of resolution, the public JESD driver word index, ADI marker timing, `adi_rx_valid`/`adi_rx_data`, and the first `ADC_RXD` payload beat. The JUnit/log prove the displacement but do not themselves establish which side owns it. The FST was returned, but no supported local decoder was available during this read-only diagnosis; do not claim an FST-observed internal cycle from this handoff.

The minimal next owner is the verification/integration diagnosis owner with an ADI-boundary waveform or equivalent sampled trace. Do not change ADI/PUB source, ADC_RXD mapping, or the RegionScoreboard solely from the terminal-15 symptom.

## DDC Abort Recovery

At 812298.01 ns the failed recovery poll observes `ADC_STA=0xfe00ff01`. The packing is `{AFE_IDLE,FIFO_FULL,FIFO_EMPTY,LINK_READY}`; thus AFE0 link-ready is 1, FIFO empty is `8'hff`, and only AFE0 is active. The test mask `0x00000101` correctly expects link-ready with FIFO_EMPTY[0]=0. This is not an address or whole-register-mask defect.

Source inspection confirms `ddc_abort_afe` clears only on `fifo_clr`, then `upk_vld` reopens; DDC I accepts only at `fifo_wlevel>=2`, while Q requires the prior accepted-I. The observed empty FIFO after recovery is a real post-relink admission symptom, but JUnit/log do not distinguish abort reassertion, link/valid discontinuity, I-capacity rejection, or a downstream FIFO boundary. No uniquely safe RTL change is established.

## Ancillary Manifest Finding

The returned evidence records 16 executed tests and 14 testcase-map entries. `pure_adc_fixed_prefix` and `static_cfg_non_idle_only_gate` are absent from `testcase_map`. This is a Simulation Worker manifest-only correction, not an RTL finding.

## Status And Next Owner

- RTL correction status: `NOT_AUTHORIZED_BY_THIS_DIAGNOSIS`.
- Verification result: 16 tests, 14 pass, 2 failures, 0 errors, 0 skipped; it is not a passing baseline.
- Next owner: Lead routes ADI-boundary and DDC-recovery waveform diagnosis; Simulation Worker owns the manifest binding correction.
