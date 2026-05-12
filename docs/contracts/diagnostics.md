<!-- CONTEXT:BEGIN -->
Registry id: `section_20_diagnostics_hub`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/diagnostics.md`
Owns:
- 20. DiagnosticsHub
Must read before editing:
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_19_codec_boundary` -> `docs/contracts/codec_boundary.md`
Feeds phases:
- `P3`
- `P14`
Related donors:
- `foundation_error_contract`
- `dto_scene_value_validation`
Related diagrams:
- `dfd_diagnostics_error_projection`
Required tests:
- `test.diagnostics.sanitizer_and_public_projection`
Guardrails:
- `diagnostics.disabled_no_alloc_hot_path`
- `diagnostics.sanitized_public_projection`
Do not assume:
- no diagnostic allocations on successful hot path
<!-- CONTEXT:END -->

## 20. DiagnosticsHub

`DiagnosticsHub` is internal.

Disabled policy:

```text
- no DiagnosticRecord allocation on successful pointer move;
- no DiagnosticRecord allocation on successful paint;
- no string interpolation of details before enabled check;
- branch-only overhead;
- public CanvasDataException may allocate details on error path.
```

Diagnostic record:

```text
DiagnosticRecord
  code
  severity
  source: codec | edit | interaction | frame | spatial | resource | diagnostics
  path?
  details sanitized map
  revision?
  sessionId?
  correlationId?
```

Sanitizer permits only JSON-like primitives and bounded previews. It forbids runtime objects, handles, paths, canvases, images, closures and full scene dumps.

---
