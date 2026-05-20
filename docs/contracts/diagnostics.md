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

`DiagnosticRecord.source` is internal provenance only. It is not projected as a
public `CanvasDataException` field; public exceptions expose only code, message,
path, and sanitized bounded details.

Runtime corruption diagnostics, such as a committed hit-test row with a
non-invertible element transform, are policy-gated internal records. When
diagnostics are disabled, the hot path remains branch-only with no
`DiagnosticRecord` allocation and no detail-string interpolation. When enabled,
details may include sanitized field path, element id, and source facts, but
must not include runtime objects, handles, full scene dumps, or unsanitized
field values.

Sanitizer permits only JSON-like primitives and bounded previews. Public
exception details are deeply immutable snapshots: caller-owned maps and lists
are copied at `CanvasDataException` construction, later caller mutation is not
observable, and unsupported objects are replaced by bounded type previews.
Diagnostic details are intentionally map-shaped public data, but they are not
schema metadata and must not be represented as `CanvasMetadata`.
`CanvasDiagnosticPolicy` exposes public readable policy variants:
`CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, and
`CanvasDiagnosticsVerbose`. `CanvasDiagnosticsVerbose.maxPreviewLength` caps
string/object previews and `CanvasDiagnosticsVerbose.maxListEntries` caps list,
set, iterable, and map preview entries. Both values are validated against
`section_06_validation_limits` at policy construction and runtime config
materialization. The sanitizer forbids runtime objects, handles, paths,
canvases, images, closures and full scene dumps.

---
