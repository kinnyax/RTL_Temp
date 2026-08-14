---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-07-30
verification_status: READY_FOR_VCS
---

# ADC_TOP v0.3 RTL Handoff

## Outcome

ADC_TOP was rebuilt against the rewritten v0.3 design rather than patched from
the old architecture. Delivery contains nine self-written Verilog files,
ordered filelists, and the provenance-preserving consolidated ADI source under
`rtl\ADI_JESD204`. The JESD204 PHY/GTH remains outside ADC_TOP. No local Git
tracking or commit was created, as requested.

The old `adc_ctl.v`, reset-sync/timeout/retry/tail/snapshot architecture,
delivery `.vlt`, unused ADC_RXD byte-alignment return, helper ADC_RXD_EXT module,
v0.2 handoffs, old mapping extract, simulation build/cache and passing waveform
were removed. Active code now uses ADC_PKT, fixed-eight centralized ADC_TGC,
three-stage-style ADC_REG, PUB-only CDC wrappers and PUB FWFT FIFO.

## Evidence

The final `rtl-vibe-design` VMware run returned `VMWARE_MODULE_CHECK_PASS` with
PUB comparison and Verilator lint PASS and cocotb `6/6 PASS`, seed
`1785381573`, `75572.01 ns`. Detailed coverage and evidence hashes are in
`ADC_TOP_Verification_Plan.md`; file hashes are in
`ADC_TOP_Current_State.md`.

The verification runner was intentionally updated, under the user's earlier
authorization, so Verilator uses `-Wno-fatal`: PUB/ADI warnings remain visible
in the log, while warnings alone do not abort lint. Runner SHA256 is
`1DF1DE599D46759C398C6B56AE0BF902F9BBC012EAA430FDA528F17E91B3C613`.

## Boundary and Next Step

Status is `READY_FOR_VCS`, not VCS-verified or Vivado-integrated. Module XDC is
`DEFERRED_TO_TOP`, PHY/GTH is `DEFERRED_TO_VENDOR_IP`, model equivalence is
`NON_VENDOR_EQUIVALENT`, and PPA remains a hypothesis. The next authorized phase
is the non-UVM VCS/Verdi campaign described in `ADC_TOP_VCS_SOC_HANDOFF.md`.

Knowledge writeback candidate: fixed-packet/no-tail admission, module-owned ADI
TPL16 marker deviation, direct held FWFT reset software protocol, centralized
TGC and software-managed relink. Wiki writeback is not authorized.
