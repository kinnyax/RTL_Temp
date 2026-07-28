# RTL_Temp Module Subtree Rules

Inherit `D:\Codex\AGENTS.md`. This subtree contains project-independent RTL/IP
modules, never FPGA project namespaces.

## Canonical Module Layout

Use an existing exact module path when supplied. For a new module, derive
`D:\Codex\RTL_Temp\<module_name>` only after the module name is fixed by the
design contract.

```text
<module_name>/
  rtl/
    <module_name>.v
    filelist.f             # optional; only for deterministic source order
  xdc/
    <module_name>.xdc      # only when constraint review returns REQUIRED
  .work/
    docs/
      handoffs/
    state/
    verification/
      tb/
      sim/
      waves/
```

## Delivery And Ownership

- `rtl/` contains active synthesizable module RTL and local synthesizable
  dependencies. Keep `filelist.f` only when explicit source order is needed.
- `xdc/` contains a non-empty module XDC only for `REQUIRED`; an empty directory
  is valid for other constraint classifications.
- Only `rtl/` and `xdc/` are retained delivery directories.
- `.work/docs` owns temporary design documents, handoffs, and downstream plans.
- `.work/state` owns compact continuation state.
- `.work/verification` owns disposable TB/models, logs, result XML, builds, and
  waves. It must not contain a copied RTL tree.
- Do not create module-root `tb`, `sim`, `waves`, `docs`, `tmp`, a Makefile,
  `MODULE_STATUS.md`, `docs/common`, or another workflow-state layout.
- Do not maintain a second guest or legacy source tree. When importing selected
  legacy material, extract only the owned module RTL/XDC into this layout and
  leave the original as unmaintained provenance.
- Promotion into `D:\Codex\RTL` remains user-owned.

## Verification And Cleanup

- The explicitly invoked `rtl-vibe-design` skill owns VMware preflight,
  transfer, lint, simulation, review, and evidence commands.
- Windows files in this module root are canonical; remote jobs are disposable.
- Retain failed verification evidence during active diagnosis.
- Delete `.work/verification` only after corrected PASS, independent Review,
  concise docs/state evidence, and completion of active debug needs.
- Keep `.work/docs` and `.work/state` until user validation and knowledge
  disposition are complete.
- Delete the complete `.work` only after authorized knowledge writeback/
  publication or explicit discard. Never delete RTL/XDC as part of that cleanup.

