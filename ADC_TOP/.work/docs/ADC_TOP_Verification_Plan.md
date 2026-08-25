---
type: verification_plan
module_name: ADC_TOP
spec_version: v0.2
verification_status: VERIFICATION_EXECUTION_READY
---

# ADC_TOP v0.2 Verification Plan

This replaces all v1.32 evidence. The execution suite is deterministic (seed
`20260825`, 900 s finite timeout) and starts fresh clocks in every testcase.
All `#UDLY` observations wait `Timer(1, "ns")` before `ReadOnly()`; no driver
is called from a read-only phase.

Coverage is requirement-derived: independent SYS/ADC/AFE/JESD reset and legal
recovery; legal direct/DEC/DDC mode, N, f, delay, format and precision
reference enumeration; valid-loss in each partial UPK state and SOMF restart;
DDC pair atomicity at free levels 0/1/2/512; fifo_sta lifecycle/header snapshot;
exact 64-byte header, CRC-16 vectors/N+8 latency and 256 payload beats; AXIS
arbitrary-stall stability; AXI-Lite split AW/W, B/R stalls, WSTRB ignored,
map/W1C/static gate; per-channel TGC command/done CDC success/cancel/RUN clear;
FIFO clear and event CDC/reset cases.

The temporal verdict for each stateful path is PRE_STATE -> stimulus -> edge ->
post-state -> withdrawal -> stability/no-extra-transfer. Public AXI/AXIS/TGC
outputs are asserted directly; source-model/reference enumeration determines
data-path acceptance and packet scoreboards. ADI JESD behavior and the PUB
FWFT FIFO are trusted boundary dependencies, not internally reviewed.

VMware execution has not occurred for v0.2. `VCS/Verdi`, XSIM, synthesis,
implementation, timing and board evidence are `NOT_RUN`.

## Baseline Evidence Boundary

This baseline intentionally carries no valid RELEASE evidence. Historical
VMware runs were produced by older RTL/TB/tooling and must not be reused for
the current files. The next development task must run the then-installed
`rtl-vibe` WSL1 Icarus/cocotb gate, followed by its independent review and
release-manifest flow.
