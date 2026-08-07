<!-- CONTEXT:BEGIN -->
Registry id: `section_20_diagnostics_hub`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/diagnostics.md`
Owns:
- 20. DiagnosticsHub
Must read before editing:
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_19_codec_boundary` -> `docs/contracts/codec_boundary.md`
Current owners:
- `contract`
Related diagrams:
- `dfd_diagnostics_error_projection`
Required tests:
- `test.diagnostics.sanitizer_and_public_projection`
- `test.diagnostics.disabled_no_alloc_hot_path`
- `test.diagnostics.diagnostics_public_surface`
Guardrails:
- `diagnostics.disabled_no_alloc_hot_path`
- `diagnostics.sanitized_public_projection`
Do not assume:
- full pointer/paint no-allocation proof exists before runtime owners exist
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

DiagnosticsHub routing table status vocabulary:

- `implemented`: production code writes this row today and focused tests prove
  the route.
- `implemented through codec bridge`: production load or runtime behavior
  reaches DiagnosticsHub only through the codec/schema v1 bridge, with no
  separate runtime diagnostics source.
- `planned/internal`: the row is the approved future routing posture, but no
  implementation is claimed until a later contract adds code and tests.
- `deferred`: the approved posture is known, but the repository has not yet
  assigned a required implementation contract.
- `not a DiagnosticsHub write`: the named probe, metric, or counter is outside
  DiagnosticsHub and must not allocate a `DiagnosticRecord`.
- `forbidden in v1`: the route or public surface is intentionally absent from
  public API v1.

DiagnosticsHub routing table:

| Writer / owner | Trigger | Diagnostic source | Severity and code family | Path and details | Timing and policy gate | Status | Proof surface |
|---|---|---|---|---|---|---|---|
| `CodecBoundary` through `recordSchemaV1FailureDiagnostic` | Raw decode failure, schema validation failure, or encode DTO rejection | `codec` | `DiagnosticSeverity.error` plus the existing `CanvasDataErrorCode` supplied by the codec/schema failure | Uses the codec/schema failure path when available. Details are sanitized JSON-like values and include the current codec `message` placement inside `details`. | Records the existing `CanvasDataException` before it is thrown or returned; the helper returns that same exception unchanged. The disabled policy is checked before `DiagnosticRecord` allocation or detail-string interpolation. | `implemented` | Codec diagnostics routing tests, disabled no-allocation tests, and graph edge `codec.schema_v1.failures.report_to_diagnostics`. |
| Staged load through the codec bridge | Load-time schema or validated-import failure, including store preparation rejection | `codec` | `DiagnosticSeverity.error` plus the same existing `CanvasDataErrorCode` emitted by the codec or validated-import failure | Follows the codec row path and details policy, including sanitized JSON-like detail values. | The load pipeline passes the existing exception through the codec-owned recording helper before rethrow and before any accepted document mutation. There is no store-owned or separate runtime diagnostic source. | `implemented through codec bridge` | Staged-load diagnostics tests plus the codec diagnostics routing proof. |
| No edit/commit writer | Ordinary edit/commit validation or runtime failure without a separately approved route | `not applicable` | `not applicable` | `not applicable` | The owning error boundary may reject or throw, but allocates no `DiagnosticRecord`. | `not a DiagnosticsHub write` | Public-edit and pointer/commit diagrams explicitly state that no edit-owned writer exists; semantic search must preserve that absence. |
| `SpatialKernel` or geometry/spatial budget proof code | Pure spatial query tile budget exhaustion or fallback candidate budget exhaustion outside an interaction-observed reliability event | `not applicable` | `not applicable` | `not applicable` | Bounded spatial query or budget path only. No `DiagnosticRecord` is allocated. | implemented as `not a DiagnosticsHub write` | Spatial docs, diagrams, geometry/spatial budget tests, and semantic search showing no hub route or graph edge. |
| `InteractionEngine` through the interaction/query boundary | Interaction-observed hit-test fallback, query budget, stale candidate rejection, stale terminal rejection, invalid terminal cleanup, selected-move start denial for non-movable content, or resolver reentrant mutation rejection that affects user-facing selection reliability | `interaction` | `DiagnosticSeverity.warning` plus internal `DiagnosticCode.interaction(InteractionDiagnosticCode)` values with no public API export | Bounded interaction/query facts only. Details must not contain runtime objects, document content, text values, resource bytes, resolver payloads, or full scene dumps. | Records only on the budget/reliability path and must not mutate committed state, publish public state, emit actions, or resolve timestamps. | implemented | Graph edge `interaction.engine.reliability_events.report_to_diagnostics`, focused interaction diagnostics tests, public barrel non-export proof, and semantic diagram search. |
| Geometry policy or a geometry-owned bridge | Corrupted committed spatial or hit-test row, such as a non-invertible element transform | `spatial` | `DiagnosticSeverity.error` plus a future internal diagnostics corruption code seam with no public API export | Sanitized field path, element id, and bounded source facts only. | Records only under policy, returns miss, and must not mutate state. | `deferred` | Future contract-owned graph edge, future geometry tests, and semantic diagram search. |
| `SurfaceResourceSession` or resource-owned budget/probe code | Resolver budget or session protection, including resource/session budget probes | `not applicable` | `not applicable` | `not applicable` | Bounded resource/session or paint budget path with no `DiagnosticRecord`, no cache write for a budget placeholder, and at most one pending throttled follow-up repaint where the resource contract says so. | `not a DiagnosticsHub write` | Resources docs, diagrams, future resource tests, and semantic search showing no hub route or graph edge. |
| Eraser/geometry budget proof code | Preview or terminal eraser budget exhaustion | `not applicable` | `not applicable` | `not applicable` | Preview/terminal budget or cleanup/no-op path. Must preserve no-partial-erase behavior and allocate no `DiagnosticRecord`. | `not a DiagnosticsHub write` | Eraser/geometry docs, diagrams, future eraser tests, and semantic search showing no hub route or graph edge. |
| `RuntimeRoot` | Failure-contained observer delivery after accepted commit, accepted load, or accepted resource-dirty publication | `diagnostics` | `DiagnosticSeverity.error` plus a future internal diagnostics observer code seam with no public API export | Sanitized observer surface name plus bounded error summary only. | Records post-acceptance and must not roll back or alter the accepted commit, load, dirty result, public state publication, action delivery, or repaint acceptance. | `deferred` | Future contract-owned graph edge, runtime observer containment tests, and semantic diagram search. |
| `DiagnosticsHub` or diagnostics-owned fallback boundary | Diagnostics sanitizer/formatting failure or internal self-protection | `diagnostics` | `DiagnosticSeverity.error` plus a future internal diagnostics self-protection code seam with no public API export | Sanitized fallback facts only. No runtime objects, handles, scene dumps, recursive public exposure, or unsanitized original payload. | Inside diagnostics failure containment. Must not create recursive records. | `planned/internal` | Diagnostics sanitizer/self-protection tests or a documented future test seam plus semantic search. |
| No writer | Public diagnostics stream | `not applicable` | `not applicable` | `not applicable` | No public stream route exists in v1. | `forbidden in v1` | Public API contract wording, `diagnostics_public_surface` registry metadata, and public API guardrails. |

Diagnostics-facing Public API v1 declarations are classified by
`diagnostics_public_surface` inside `docs/_registry/public_api_v1.yaml`. That
membership group initially contains `CanvasDiagnosticPolicy`,
`CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`,
`CanvasDiagnosticsVerbose`, `CanvasDataException`, and `CanvasDataErrorCode`,
and it must remain a subset of `public_exports`. The classification is
inventory metadata for guardrail proof; it does not create a public diagnostics
stream or add public API names.

The geometry corrupted-row routing table row remains deferred and is not a
current graph obligation. Current spatial and interaction behavior returns
sanitized misses for corrupted geometry rows without allocating DiagnosticsHub
records. When a later contract
implements that policy-gated internal record, diagnostics-disabled hot paths
must remain branch-only with no `DiagnosticRecord` allocation and no
detail-string interpolation. Enabled details may include sanitized field path,
element id, and source facts, but must not include runtime objects, handles,
full scene dumps, or unsanitized field values.

Sanitizer permits only JSON-like primitives and bounded previews. Public
exception details are deeply immutable snapshots: caller-owned maps and lists
are copied at `CanvasDataException` construction, later caller mutation is not
observable, and unsupported objects are replaced by bounded type previews.
Diagnostic details are intentionally map-shaped public data, but they are not
schema metadata and must not be represented as `CanvasMetadata`.
`diagnostics.sanitized_public_projection` uses the registry-owned
`diagnostics_public_surface` membership plus analyzer-resolved public signature
traversal to prove explicitly classified diagnostics declarations do not expose
the runtime-like public types matched by the guard classifier.
`CanvasDiagnosticPolicy` exposes public readable policy variants:
`CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, and
`CanvasDiagnosticsVerbose`. `CanvasDiagnosticsVerbose.maxPreviewLength` caps
string/object previews and `CanvasDiagnosticsVerbose.maxListEntries` caps list,
set, iterable, and map preview entries. Both values are validated against
`section_06_validation_limits` at policy construction and runtime config
materialization. The sanitizer forbids runtime objects, handles, paths,
canvases, images, closures and full scene dumps.

---
