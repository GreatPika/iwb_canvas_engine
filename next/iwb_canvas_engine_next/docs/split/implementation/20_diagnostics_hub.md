<!-- CONTEXT:BEGIN -->
Registry id: `section_20_diagnostics_hub`
Source: `iwb_canvas_engine_next_full_implementation_plan_v2.md / section 20`
Canonical original: `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`
Owns:
- 20. DiagnosticsHub
Must read before editing:
- `section_06_validation_limits`
- `section_19_codec_boundary`
- `section_22_guardrails_machine_checks`
Depends on:
- `section_06_validation_limits`
- `section_19_codec_boundary`
- `section_22_guardrails_machine_checks`
Feeds phases:
- `P3`
- `P12`
Related donors:
- `foundation_error_contract`
- `dto_scene_value_validation`
Related diagrams:
- docs/split/diagrams/README.md#dfd_diagnostics_error_projection -> tool/diagrams/dfd_diagnostics_error_projection.mmd
Required tests:
- `none`
Guardrails:
- `diagnostics.disabled_no_alloc_hot_path`
Do not infer:
- no diagnostic allocations on successful hot path
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
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

<!-- ORIGINAL-SECTION:END -->
