# Change Contract

## Goal

Make `docs/contracts/diagnostics.md` the single durable source of truth for
DiagnosticsHub message routing, with one table that classifies implemented,
planned, forbidden, drifted, and non-hub diagnostic/probe claims. Align the
dependent contracts, phase docs, architecture graph, registries, diagrams, and
generated documentation so future phase work can find who writes what to
DiagnosticsHub, how, when, and what must prove it.

## Evidence

- `.design/2026-05-28-diagnostics-hub-ssot-routing-table.md` / disposition and selected form: the design is `READY_FOR_CONTRACT` and selects Candidate A, a canonical routing table in `docs/contracts/diagnostics.md` with graph, registries, diagrams, and generated docs as projections -> this step must implement the docs source-of-truth migration rather than duplicate route tables per producer, make the graph the only route table, or rely on tests alone.
- `.design/2026-05-28-diagnostics-hub-ssot-routing-table.md` / target classification: the required profile is `SOURCE_OF_TRUTH_DOCS` with `SEAM_MIGRATION` obligation -> this step changes durable documentation and structural projections, not production diagnostics behavior.
- `.design/2026-05-28-diagnostics-hub-ssot-routing-table.md` / lock-required facts: `docs/contracts/diagnostics.md` owns the routing table, resource/session and eraser budget probes are not DiagnosticsHub writes, interaction reliability diagnostics use `DiagnosticSource.interaction`, geometry corrupted-row diagnostics use `DiagnosticSource.spatial`, observer failures are post-acceptance `DiagnosticSource.diagnostics` writes, and v1 has no public diagnostics stream -> the contract must preserve these decisions without reopening routing posture.
- `.design/2026-05-28-diagnostics-hub-ssot-routing-table.md` / source-of-truth impact: the future work must update the canonical table first, then dependent contract and phase references, then architecture graph and registries, then durable diagrams, then generated docs and checks -> execution units must follow this order to avoid making projections into competing sources of truth.
- `docs/contracts/diagnostics.md` / `section_20_diagnostics_hub`: `DiagnosticsHub` is internal, owns `DiagnosticRecord` shape and source provenance values, defines disabled-policy no-allocation rules, sanitizer behavior, and the no public diagnostics stream classification -> the routing table belongs in this contract rather than producer docs or public API registry metadata.
- `docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml` / diagnostics public surface: public API v1 exposes diagnostics policy and exception types but no public diagnostics stream, while `diagnostics_public_surface` is registry metadata for guardrail proof -> routing-table work must not create new public exports or imply public access to internal records.
- `docs/architecture/architecture_graph.yaml` / diagnostics route model: the graph already defines `diagnostics.hub`, the implemented codec diagnostic route, and `diagnostic_route` edges with required/future status support -> graph edits should project only graph-checkable table rows and keep non-hub probe rows out of `diagnostic_route`.
- `lib/src/diagnostics/diagnostics_hub.dart` and `lib/src/codec/schema_v1_diagnostics.dart` / current implementation: production `DiagnosticSource` values match the documented source set and current writes route schema v1 failures through `recordSchemaV1FailureDiagnostic` with `DiagnosticSource.codec` -> the implemented table row must start from this route and must not claim non-codec writers are implemented.
- `lib/src/runtime/runtime_root.dart` / observer failure comments: commit, load, and resource dirty observer failure containment currently names a future diagnostics seam -> docs may classify this route as planned/deferred post-acceptance diagnostics but must not present it as implemented.
- `docs/diagrams/c4_component_runtime.mmd`, `docs/diagrams/c4_code_edit_kernel.mmd`, and `.research/2026-05-28-diagnostics-hub-message-routing.md` / drift evidence: durable diagrams currently imply non-codec DiagnosticsHub relationships that research found are not implemented -> diagram work must classify each edge as implemented, planned/future, removed drift, or non-hub probe.
- `docs/contracts/spatial_kernel.md`, `docs/contracts/geometry.md`, `docs/contracts/resources.md`, and `docs/diagrams/seq_resource_resolution.mmd` / probe wording: spatial, geometry, resource, and eraser flows use diagnostic/probe/counter language with mixed hub and non-hub meaning -> dependent docs and diagrams must point to table rows or explicitly say "not a DiagnosticsHub write".
- `docs/tool/sync_generated_docs.dart` and `docs/tool/check_docs.dart` / docs tooling: generated navigation, diagram catalog, graph views, section references, and registry symmetry are mechanically checked -> generated docs must be regenerated or checked through tooling instead of hand-edited.
- `PLAN.md` / roadmap: Step 39 is complete and no later step exists -> this Step 40 is the next roadmap step and its closure state is owned by `PLAN.md` plus this linked step file.

## Boundaries

Owner:

`docs/contracts/diagnostics.md` / `section_20_diagnostics_hub` owns the
canonical DiagnosticsHub routing table and row status vocabulary. Producer
contracts, implementation phase docs, architecture docs, architecture graph
data, registries, durable diagrams, donor/verification docs, and generated docs
are projections or references. `PLAN.md` and this step file own roadmap closure
state.

In Scope:

- Add a canonical DiagnosticsHub routing table to
  `docs/contracts/diagnostics.md` after the `DiagnosticRecord` shape and
  source-provenance rules, with columns for writer/owner, trigger, diagnostic
  source, severity and code family, path and details, timing and policy gate,
  phase/status, and proof surface.
- Populate the table with the design-locked row groups: implemented
  codec/schema v1 failures, staged load validation through the codec bridge,
  edit/commit diagram drift or planned route posture, planned interaction
  reliability diagnostics, planned geometry corrupted-row diagnostics,
  non-hub resource/session probes, non-hub eraser exact-budget probes,
  planned/deferred runtime observer failures, planned/internal diagnostics
  self-protection, and forbidden v1 public diagnostics stream.
- Update dependent durable docs so every DiagnosticsHub, diagnostic, probe, or
  counter claim either points to a routing-table row, is explicitly classified
  as "not a DiagnosticsHub write", or is unrelated and does not imply a hub
  writer.
- Update architecture graph data only for graph-checkable routing rows:
  preserve the implemented codec `diagnostic_route`; add future routes for
  interaction reliability, geometry corrupted rows, and runtime observer
  failures only with future status and the design-selected phase ownership;
  do not add `diagnostic_route` edges for resource/session or eraser budget
  probes.
- Update section, diagram, donor, and public API registries only where they are
  required to keep routing-table references, diagnostics public surface
  metadata, generated navigation, donor evidence, and diagram relationships
  consistent.
- Reconcile durable diagrams that depict DiagnosticsHub routing or diagnostic
  probe/counter behavior so their labels and edges project the routing table
  and do not claim unimplemented writers.
- Regenerate generated docs and architecture graph views through repository
  tooling after registry or graph changes.
- Run documentation checks, architecture graph checks when graph-owned surfaces
  change, generated-view checks, and a bounded semantic search proving every
  durable diagnostics/probe/counter claim is table-backed, explicitly non-hub,
  generated from reviewed sources, donor evidence context, or unrelated.
- After implementation and verification pass, mark Step 40 complete in
  `PLAN.md` and mark this step document's execution-unit checkboxes complete
  in the same change.

Out of Scope:

- Do not change Dart production code, public API exports, DTO shapes, schema
  formats, runtime diagnostics policy behavior, `DiagnosticRecord` runtime
  storage behavior, sanitizer implementation, exception projection behavior, or
  diagnostics tests unless a later user request explicitly expands this step.
- Do not implement non-codec diagnostics writers, observer failure recording,
  interaction reliability recording, geometry corrupted-row recording,
  diagnostics self-protection, resource/session probe counters, eraser probe
  counters, or a public diagnostics stream.
- Do not mark non-codec writers as implemented unless existing code and tests
  already prove them.
- Do not create duplicate per-producer routing tables or make
  `docs/architecture/architecture_graph.yaml` the only routing source of truth.
- Do not hand-edit generated docs such as `docs/diagrams/catalog.md`,
  `docs/indexes/*.md`, or `docs/diagrams/generated/*.mmd`.
- Do not add required graph edges for already-closed phases without
  implementation and proof in the same expanded contract.
- Do not change DCM, analyzer, architecture, or docs-check thresholds to make
  this documentation migration pass.

Source of Truth:

The design input for this step is
`.design/2026-05-28-diagnostics-hub-ssot-routing-table.md`. The canonical
routing table will live in `docs/contracts/diagnostics.md` under
`section_20_diagnostics_hub`. Public diagnostics compatibility remains owned by
`docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml`.
Architecture ownership and graph-checkable routes remain owned by
`docs/architecture/01_runtime_ownership.md`,
`docs/architecture/02_package_boundaries.md`, and
`docs/architecture/architecture_graph.yaml`. Generated navigation and diagram
catalog state remain owned by `docs/_registry/**`, `docs/tool/**`, and the
generated outputs those tools produce. Roadmap closure state remains owned by
`PLAN.md` and this linked step file.

Compatibility:

Public consumers must see no public API, schema, runtime behavior, exception
payload, or diagnostics stream change. Existing `CanvasDataException`,
`CanvasDataErrorCode`, `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`,
`CanvasDiagnosticsSummary`, and `CanvasDiagnosticsVerbose` compatibility must
be preserved. Internal documentation must continue to classify
`DiagnosticRecord.source` as internal provenance only. Disabled diagnostics
policy must remain branch-only on disabled hot paths with no new documented
allocation or detail interpolation requirement. Existing implemented codec
diagnostics proof remains valid, while future and non-hub rows are explicitly
classified as not yet implemented or not hub writes.

Order Constraints:

Update `docs/contracts/diagnostics.md` first so dependent edits can reference
the table instead of creating competing route definitions. Then update
dependent contracts, phase docs, donor docs, architecture docs, and verification
docs to point at the table or classify non-hub/unrelated wording. Then update
architecture graph data and registries for graph-checkable route rows and
diagram/source relationships. Then reconcile durable diagrams as projections of
the table. Then regenerate generated docs and graph views through tooling.
Finally run docs checks, graph checks when graph-owned surfaces changed,
generated-view checks, and the semantic search proof before marking roadmap
closure. Graph edges for future rows must stay `status: future` until a later
implementation contract activates and proves the corresponding writer.

## Execution Units

### [x] Unit 1: Canonical routing table

Owner:

`docs/contracts/diagnostics.md` / `section_20_diagnostics_hub`.

Boundary:

Only the diagnostics contract section that owns `DiagnosticRecord`, source
provenance, disabled policy, sanitizer rules, public projection notes, and the
new routing table. This unit must not edit producer contracts, graph data,
registries, diagrams, generated docs, or Dart code.

Change:

Add the canonical DiagnosticsHub routing table after the `DiagnosticRecord`
shape and source-provenance rules. Include the required columns from the design
and start the table with the implemented codec/schema v1 route row before the
non-codec status buckets. Include the locked row groups for staged load through
the codec bridge, edit/commit diagram drift or planned route posture, planned
interaction reliability, planned geometry corrupted rows, non-hub
resource/session probes, non-hub eraser exact-budget probes, planned/deferred
runtime observer failures, planned/internal diagnostics self-protection, and
forbidden v1 public diagnostics stream. Define the row status vocabulary used
by the table.

The table must spell out these row decisions, not leave them for the
implementer to infer:

- Codec/schema v1 failures: writer `CodecBoundary` through
  `recordSchemaV1FailureDiagnostic`; trigger raw decode failure, schema
  validation failure, or encode DTO rejection; source `codec`; status
  `implemented`; severity/code family is `DiagnosticSeverity.error` plus the
  existing `CanvasDataErrorCode` supplied by the codec/schema failure; path is
  the codec/schema failure path when available; details are sanitized JSON-like
  values and must include current codec `message` placement in `details`;
  timing is pre-throw/error projection with disabled policy checked before
  record allocation or detail-string interpolation; proof is codec diagnostics
  routing tests, disabled no-allocation tests, and
  `codec.schema_v1.failures.report_to_diagnostics`.
- Runtime staged load validation failures: writer is staged load through the
  codec bridge, not a separate runtime route; trigger is load-time schema or
  DTO validation failure; source remains `codec`; status `implemented through
  codec bridge`; severity/code family is `DiagnosticSeverity.error` plus the
  same existing `CanvasDataErrorCode` emitted by the codec/validated-import
  failure; path/details follow the codec row; timing is before failed load is
  projected or thrown, with no accepted document mutation; proof is staged-load
  diagnostics tests plus the codec routing proof.
- Edit/commit validation or runtime failure diagrams: status is `diagram drift
  to reconcile` unless a later approved contract adds a route; source, path,
  details, severity/code family, and timing are `not applicable` for current
  implementation; proof is semantic diagram search showing no durable diagram
  claims an implemented edit-owned DiagnosticsHub writer.
- Spatial query budget/fallback counters: writer is `SpatialKernel` or
  geometry/spatial budget proof code; trigger is pure spatial query tile or
  fallback candidate budget exhaustion outside an interaction-observed
  reliability event; status `planned P8 classification row` and `not a
  DiagnosticsHub write`; diagnostic source, severity/code family, path, and
  details are `not applicable`; timing is bounded spatial query/budget path
  with no `DiagnosticRecord`; proof is spatial docs, diagrams, future P8
  budget tests, and semantic search showing no hub route or graph edge.
- Interaction query reliability events: writer is `InteractionEngine` through
  the interaction/query boundary; trigger is interaction-observed hit-test
  fallback, query budget, or stale candidate rejection that affects
  user-facing selection reliability; source `interaction`; status
  `planned P10`; severity/code family is `DiagnosticSeverity.warning` plus a
  future internal diagnostics reliability code seam with no public API export;
  path/details are bounded interaction/query facts only and no runtime objects;
  timing is budget/reliability path only and must not mutate committed state;
  proof is future graph edge
  `interaction.selection_move.reliability_events.report_to_diagnostics`,
  future focused interaction tests, and semantic diagram search.
- Geometry corrupted committed rows: writer is geometry policy or a
  geometry-owned bridge; trigger is corrupted committed spatial/hit-test row
  such as a non-invertible element transform; source `spatial`; status
  `planned P8`; severity/code family is `DiagnosticSeverity.error` plus a
  future internal diagnostics corruption code seam with no public API export;
  path/details include sanitized field path, element id, and bounded source
  facts only; timing records only under policy, returns miss, and must not
  mutate state; proof is future graph edge
  `geometry.spatial_index.corrupted_rows.report_to_diagnostics`, future
  geometry tests, and semantic diagram search.
- Resource resolver budget/session probes: status `not a DiagnosticsHub write`;
  writer is `SurfaceResourceSession` or resource-owned budget/probe code;
  trigger is resolver budget/session protection; diagnostic source, path, and
  details are `not applicable`; severity/code family is `not applicable`;
  timing is bounded resource/session or paint budget path with no
  `DiagnosticRecord`, no cache write for budget placeholder, and at most one
  pending throttled follow-up repaint where the resource contract says so;
  proof is resources docs, diagrams, future resource tests, and semantic search
  showing no hub route or graph edge.
- Eraser exact-budget probes: status `not a DiagnosticsHub write`; writer is
  eraser/geometry budget proof code; trigger is preview or terminal eraser
  budget exhaustion; diagnostic source, path, and details are `not
  applicable`; severity/code family is `not applicable`; timing is
  preview/terminal budget or cleanup/no-op path and must preserve
  no-partial-erase behavior; proof is eraser/geometry docs, diagrams, future
  eraser tests, and semantic search showing no hub route or graph edge.
- Runtime observer failure seams: writer is `RuntimeRoot`; trigger is
  failure-contained observer delivery after accepted commit, accepted load, or
  accepted resource-dirty publication; source `diagnostics`; status
  `planned P14` or `deferred`; severity/code family is
  `DiagnosticSeverity.error` plus a future internal diagnostics observer code
  seam with no public API export; path/details are sanitized observer surface
  name plus bounded error summary only; timing is post-acceptance and must not
  roll back or alter the accepted commit, load, dirty result, public state
  publication, action delivery, or repaint acceptance; proof is future graph
  edge `runtime.root.observer_failures.report_to_diagnostics`, runtime
  observer containment tests, and semantic diagram search.
- Diagnostics self-protection: writer is `DiagnosticsHub` or a diagnostics-owned
  fallback boundary; trigger is diagnostics sanitizer/formatting failure or
  internal self-protection; source `diagnostics`; status `planned/internal`;
  severity/code family is `DiagnosticSeverity.error` plus a future internal
  diagnostics self-protection code seam with no public API export; path/details
  are sanitized fallback facts only, with no runtime objects, handles, scene
  dumps, recursive public exposure, or unsanitized original payload; timing is
  inside diagnostics failure containment and must not create recursive records;
  proof is diagnostics sanitizer/self-protection tests or a documented future
  test seam plus semantic search.
- Public API diagnostics stream: status `forbidden in v1`; no writer, trigger,
  source, severity/code family, path, details, or timing; proof is public API
  contract wording, `diagnostics_public_surface` registry metadata, and public
  API guardrails.

Completion Check:

`rg -n "DiagnosticsHub routing table|implemented|planned P8|planned P10|planned P14|not a DiagnosticsHub write|forbidden in v1" docs/contracts/diagnostics.md`
shows one canonical table in `section_20_diagnostics_hub` with every
design-locked row group present. Manual review of
`docs/contracts/diagnostics.md` confirms the table appears after the
`DiagnosticRecord` field/source rules, keeps `DiagnosticRecord.source` internal
provenance only, keeps disabled-policy no-allocation wording, and does not add
producer-local duplicate routing tables. Manual review also confirms every row
names its writer/owner, trigger, source or `not applicable`, severity/code
family or `not applicable`, path policy, sanitized detail keys or `not
applicable`, timing/policy gate, phase/status, and proof surface. The codec row
must explicitly state `message` placement in `details`. The load row must
explicitly state codec-bridge/pre-throw behavior with no accepted document
mutation. The geometry row must explicitly state return-miss-without-mutation
behavior. The spatial budget row must explicitly state P8 non-hub
classification for pure `SpatialKernel` query-budget/fallback counters, while
the interaction reliability row must explicitly state P10 `interaction` routing
only for interaction-observed user-facing reliability events. The
resource/session and eraser rows must explicitly state non-hub probe behavior
and no `DiagnosticRecord`. The eraser row must explicitly state no partial
erase. The observer row must explicitly name commit, load, and resource-dirty
observer delivery and state post-acceptance failure containment with no rollback
or accepted-result mutation.

Depends On:

None.

### [x] Unit 2: Dependent docs route classification

Owner:

Producer contracts, implementation phase docs, architecture prose, donor docs,
and verification docs under `docs/**`.

Boundary:

Only durable non-generated Markdown documentation that contains
DiagnosticsHub, diagnostic, diagnostics, probe, or counter wording. This unit
must not edit architecture graph YAML, registries, durable diagrams, generated
docs, or Dart code.

Change:

Search-review all non-generated durable Markdown docs for
DiagnosticsHub/diagnostic/probe/counter claims. Update only the hits whose
meaning changes or whose wording could imply a DiagnosticsHub writer outside
the canonical table. Each remaining durable claim must either reference the
table, explicitly state "not a DiagnosticsHub write", be clearly donor evidence
context, or be unrelated to hub routing. Preserve public API no-stream wording
and keep `diagnostics_public_surface` as guardrail metadata rather than stream
ownership.

The evidence-backed Markdown perimeter for this step is fixed to the current
direct-hit list below. If implementation discovers a new direct hit because
earlier units add or regenerate wording, classify it under the same rules and
record why the list changed.

Must-edit Markdown files:

- `docs/contracts/spatial_kernel.md` - classify spatial fallback/budget
  diagnostic-counter wording with the Unit 1 split: pure SpatialKernel
  query-budget/fallback counters are P8 non-hub classification rows, while only
  interaction-observed user-facing reliability events become the P10
  `interaction` diagnostics route.
- `docs/contracts/geometry.md` - classify corrupted-row diagnostics and eraser
  budget diagnostic/probe counters.
- `docs/contracts/resources.md` - classify missing-placeholder diagnostics and
  resolver budget/session diagnostic/probe counters as table-backed or non-hub.

Classification-only Markdown files from the current direct-hit search:

- `docs/contracts/diagnostics.md`
- `docs/contracts/cache_policy.md`
- `docs/contracts/frame_rendering.md`
- `docs/contracts/interaction_engine.md`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/validation_limits.md`
- `docs/architecture/README.md`
- `docs/architecture/00_architecture_overview.md`
- `docs/architecture/01_runtime_ownership.md`
- `docs/architecture/02_package_boundaries.md`
- `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md`
- `docs/implementation/p2_public_api_v1_freeze.md`
- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
- `docs/implementation/p4_runtime_spine.md`
- `docs/implementation/p13_flutter_surface.md`
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md`
- `docs/donors/01_summary_by_decision.md`
- `docs/donors/02_geometry_hit_test_eraser.md`
- `docs/donors/03_spatial_frame_render_cache.md`
- `docs/donors/04_dto_model_validation_structure.md`
- `docs/donors/05_codec.md`
- `docs/verification/benchmarks.md`
- `docs/verification/guardrail_design_patterns.md`
- `docs/verification/guardrails.md`
- `docs/verification/release_gates.md`
- `docs/verification/tests.md`

Design-required manual-review Markdown files without current direct
DiagnosticsHub/diagnostic/probe/counter hits:

- `docs/contracts/codec_boundary.md`
- `docs/contracts/edit_kernel.md` - classify post-commit observer-failure
  containment against the planned runtime-owned
  `runtime.root.observer_failures.report_to_diagnostics` route; do not imply a
  separate edit-owned DiagnosticsHub writer.
- `docs/contracts/load_document.md`
- `docs/contracts/operation_matrix.md`
- `docs/contracts/schema_v1.md`
- `docs/implementation/p0_package_skeleton_and_hard_boundaries.md`
- `docs/implementation/p5_edit_core.md`
- `docs/implementation/p6_load_document.md`
- `docs/implementation/p7_resources_and_images.md`
- `docs/implementation/p8_geometry_and_spatial.md`
- `docs/implementation/p9_frame_rendering_and_caches.md`
- `docs/implementation/p10_selection_and_move.md`
- `docs/implementation/p11_draw_tools.md`
- `docs/implementation/p12_eraser_and_context_action_request.md`

These classification-only files may remain textually unchanged only when manual
review confirms their hits are already table-backed, explicitly non-hub, donor
evidence context, verification/guardrail metadata, public-surface metadata, or
unrelated to DiagnosticsHub routing. The design-required manual-review files
may remain textually unchanged only when manual review confirms they have no
DiagnosticsHub routing implication through their referenced sections,
registries, diagrams, phase obligations, or graph edges.

Completion Check:

`rg -n -i "DiagnosticsHub|diagnostic|diagnostics|probe|counter" docs --glob "*.md" --glob "!docs/indexes/**" --glob "!docs/diagrams/catalog.md"`
has been reviewed, and every durable Markdown hit is table-backed, explicitly
non-hub, donor evidence context, verification/guardrail metadata, or unrelated
without implying a writer. Manual review confirms every file in the must-edit
and classification-only Markdown lists above has no duplicate routing table and
no unclassified DiagnosticsHub writer claim. Manual review confirms every
design-required manual-review Markdown file above has no unclassified
DiagnosticsHub routing implication through referenced sections, registries,
diagrams, phase obligations, or graph edges. Manual review specifically
confirms `docs/contracts/edit_kernel.md` classifies observer-failure
containment as runtime-owned planned diagnostics through
`runtime.root.observer_failures.report_to_diagnostics`, with no separate
edit-owned hub writer.

Depends On:

Unit 1.

### [x] Unit 3: Graph and registry projections

Owner:

`docs/architecture/architecture_graph.yaml`, `docs/_registry/sections.yaml`,
`docs/_registry/diagrams.yaml`, `docs/_registry/donors.yaml`, and
`docs/_registry/public_api_v1.yaml`.

Boundary:

Only graph-checkable route projections and registry relationships needed to
make the routing table discoverable and generated docs consistent. This unit
must not edit durable diagrams, generated docs, Dart code, or generated
Markdown.

Change:

Preserve `diagnostics.hub` and the implemented codec diagnostic route. Add
future `diagnostic_route` graph edges only for the table rows selected by the
design: `interaction.selection_move.reliability_events.report_to_diagnostics`
from `interaction.selection_move` to `diagnostics.hub` with
`phaseRequiredBy: P10` and `status: future`,
`geometry.spatial_index.corrupted_rows.report_to_diagnostics` from
`geometry.spatial_index` to `diagnostics.hub` with `phaseRequiredBy: P8` and
`status: future`, and
`runtime.root.observer_failures.report_to_diagnostics` from `runtime.root` to
`diagnostics.hub` with `phaseRequiredBy: P14` and `status: future`. Keep
resource/session budget probes and eraser exact-budget probes out of
`diagnostic_route`. Update section, diagram, donor, and public API registries
only where needed so `section_20_diagnostics_hub`, diagnostics-related
diagrams, donor evidence, and `diagnostics_public_surface` metadata remain
consistent with the table.

The graph/registry file perimeter for this unit is fixed to:

- `docs/architecture/architecture_graph.yaml`
- `docs/_registry/sections.yaml`
- `docs/_registry/diagrams.yaml`
- `docs/_registry/donors.yaml`
- `docs/_registry/public_api_v1.yaml`

The `docs/architecture/architecture_graph.yaml` change is exact:

- Preserve node `diagnostics.hub`.
- Preserve edge `codec.schema_v1.failures.report_to_diagnostics` unchanged.
- Add this future edge in the graph edge list:

```yaml
  - id: interaction.selection_move.reliability_events.report_to_diagnostics
    from: interaction.selection_move
    to: diagnostics.hub
    kind: diagnostic_route
    phaseRequiredBy: P10
    status: future
    sourceDocs:
      - path: docs/contracts/diagnostics.md
      - path: docs/contracts/interaction_engine.md
      - path: docs/implementation/p10_selection_and_move.md
    evidence:
      - Interaction-observed hit-test fallback, query budget, and stale candidate reliability events are planned internal diagnostics with source interaction.
    actual:
      delegationTargets:
        - InteractionEngine
```

- Add this future edge in the graph edge list:

```yaml
  - id: geometry.spatial_index.corrupted_rows.report_to_diagnostics
    from: geometry.spatial_index
    to: diagnostics.hub
    kind: diagnostic_route
    phaseRequiredBy: P8
    status: future
    sourceDocs:
      - path: docs/contracts/diagnostics.md
      - path: docs/contracts/geometry.md
      - path: docs/implementation/p8_geometry_and_spatial.md
    evidence:
      - Corrupted committed geometry or spatial rows are planned policy-gated internal diagnostics with source spatial and return-miss-without-mutation behavior.
    actual:
      delegationTargets:
        - GeometryPolicy
```

- Add this future edge in the graph edge list:

```yaml
  - id: runtime.root.observer_failures.report_to_diagnostics
    from: runtime.root
    to: diagnostics.hub
    kind: diagnostic_route
    phaseRequiredBy: P14
    status: future
    sourceDocs:
      - path: docs/contracts/diagnostics.md
      - path: docs/contracts/edit_kernel.md
      - path: docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md
    evidence:
      - Commit, load, and resource-dirty observer delivery failures are planned post-acceptance diagnostics owned by RuntimeRoot and must not roll back accepted results.
    actual:
      delegationTargets:
        - RuntimeRoot
```

- Add the three new edge IDs to the existing
  `sourceCoverage` entry for `section_20_diagnostics_hub`:

```yaml
  - sectionId: section_20_diagnostics_hub
    disposition: graph_obligation
    graphIds:
      - diagnostics.hub
      - codec.schema_v1.failures.report_to_diagnostics
      - interaction.selection_move.reliability_events.report_to_diagnostics
      - geometry.spatial_index.corrupted_rows.report_to_diagnostics
      - runtime.root.observer_failures.report_to_diagnostics
```

- Do not add any `diagnostic_route` graph edge for resource resolver
  budget/session probes, eraser exact-budget probes, pure SpatialKernel
  query-budget/fallback counters, edit-owned commit failures, load-owned
  failures, public API diagnostics streams, or diagnostics public-surface
  registry metadata.

Completion Check:

`rg -n "diagnostic_route|diagnostics.hub|section_20_diagnostics_hub|diagnostics_public_surface" docs/architecture/architecture_graph.yaml docs/_registry`
shows the codec route preserved, only the approved future graph routes added
for graph-checkable planned rows, no resource/session or eraser budget
`diagnostic_route`, and registry relationships pointing diagnostics diagrams
and donor evidence back to `section_20_diagnostics_hub` where material. Manual
review confirms `docs/_registry/public_api_v1.yaml` still treats
`diagnostics_public_surface` as public-surface guardrail metadata, not a public
diagnostics stream. Manual review also confirms new DiagnosticsHub route graph
IDs are added to architecture graph source coverage for
`section_20_diagnostics_hub`, unless the implemented change documents a more
specific source section and keeps `section_20_diagnostics_hub` coverage for the
hub route semantics.

Depends On:

Unit 1 and Unit 2.

### [x] Unit 4: Durable diagram reconciliation

Owner:

Durable Mermaid diagrams under `docs/diagrams/*.mmd`.

Boundary:

Only non-generated diagrams that depict DiagnosticsHub routing, diagnostics
projection, diagnostic/probe/counter behavior, resource/session probes,
eraser-budget probes, geometry/spatial corruption, interaction reliability, or
observer-failure containment. This unit must not edit generated diagrams,
registries, graph YAML, docs tooling, or Dart code.

Change:

Reconcile durable diagrams against the routing table. Keep implemented codec
routing as implemented, show staged load validation as codec-bridge routing,
mark planned/future routes without implying implementation, remove or reword
diagram drift that claims non-existent edit/runtime writers, and label
resource/session and eraser budget probes as non-hub metrics/probes where those
flows remain in diagrams.

Must-edit durable diagrams:

- `docs/diagrams/c4_component_runtime.mmd`
- `docs/diagrams/c4_code_edit_kernel.mmd`
- `docs/diagrams/dfd_cache_invalidation.mmd`
- `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `docs/diagrams/dfd_load_document_success_failure.mmd`
- `docs/diagrams/dfd_main_paint_frame.mmd`
- `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `docs/diagrams/dfd_public_edit.mmd`
- `docs/diagrams/dfd_resource_resolution.mmd`
- `docs/diagrams/dfd_spatial_query_budget.mmd`
- `docs/diagrams/seq_eraser_exact_budget.mmd`
- `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
- `docs/diagrams/seq_load_document_failure.mmd`
- `docs/diagrams/seq_resource_resolution.mmd`
- `docs/diagrams/seq_spatial_touched_update.mmd`
- `docs/diagrams/state_resource_resolution.mmd`

Classification-only durable diagrams from the current direct-hit search:

- `docs/diagrams/c4_container.mmd`
- `docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- `docs/diagrams/seq_schema_v1_decode_encode_order.mmd`

Current durable diagrams without direct DiagnosticsHub/diagnostic/probe/counter
hits are outside the diagram edit perimeter for this step unless a prior unit
changes their referenced section, registry, or diagram meaning:
`docs/diagrams/c4_context.mmd`, `docs/diagrams/dfd_overlay_frame.mmd`,
`docs/diagrams/seq_context_action_request.mmd`,
`docs/diagrams/seq_dispose_during_gesture.mmd`,
`docs/diagrams/seq_edit_rollback.mmd`, `docs/diagrams/seq_edit_success.mmd`,
`docs/diagrams/seq_eraser_commit.mmd`,
`docs/diagrams/seq_line_two_tap_commit.mmd`,
`docs/diagrams/seq_load_document_success.mmd`,
`docs/diagrams/seq_main_paint.mmd`, `docs/diagrams/seq_marquee_select.mmd`,
`docs/diagrams/seq_overlay_paint.mmd`,
`docs/diagrams/seq_pencil_marker_commit.mmd`,
`docs/diagrams/seq_selected_move_cancel.mmd`,
`docs/diagrams/seq_selected_move_preview_commit.mmd`,
`docs/diagrams/seq_single_active_surface.mmd`,
`docs/diagrams/state_edit_session.mmd`, `docs/diagrams/state_eraser.mmd`,
`docs/diagrams/state_pencil_marker_draw.mmd`,
`docs/diagrams/state_pending_context_action_request.mmd`,
`docs/diagrams/state_pointer_session.mmd`,
`docs/diagrams/state_runtime_lifecycle.mmd`,
`docs/diagrams/state_select_marquee.mmd`,
`docs/diagrams/state_selected_move.mmd`, and
`docs/diagrams/state_two_tap_line.mmd`.

Completion Check:

`rg -n -i "DiagnosticsHub|DiagnosticRecord|diagnostic|diagnostics|probe|counter" docs/diagrams --glob "*.mmd" --glob "!docs/diagrams/generated/**"`
has been reviewed, and every durable diagram hit is consistent with a routing
table row or explicitly non-hub/unrelated. Manual review confirms the minimum
must-edit and classification-only durable diagram lists above do not claim
unimplemented DiagnosticsHub writers as implemented. Manual review also
confirms diagrams that remain in scope preserve the table's timing/no-op
semantics: staged load does not imply a separate runtime source, geometry
corruption returns miss without mutation, resource/session and eraser probes
are non-hub, eraser budget paths do not imply partial erase, and observer
failure diagrams do not imply rollback of accepted commit, load, or dirty
publication.

Depends On:

Unit 1, Unit 2, and Unit 3.

### [x] Unit 5: Generated docs, checks, and roadmap closure

Owner:

Docs tooling outputs, architecture graph generated views, docs verification,
and roadmap closure state.

Boundary:

Only generated docs affected by registry or graph changes, verification
commands, semantic-search proof, `PLAN.md`, and this step file. This unit must
not hand-edit generated outputs or change production/test code.

Change:

Regenerate generated docs and architecture graph views through repository
tooling after registry, graph, or diagram changes. Run the docs checks,
architecture graph checks for the latest completed phase baseline when
architecture graph routes/source coverage changed, generated-view checks, and
the semantic search proof. Review generated diffs for consistency with the
canonical routing table. After all checks pass, mark this step complete in
`PLAN.md` and mark all execution units in this step document complete in the
same change. `PLAN.md` is edited only as repository-required roadmap closure
state; that closure update does not expand this docs SSOT contract into
production code or broader roadmap restructuring.

Generated outputs affected by this step must be touched only through tooling:

- `docs/diagrams/catalog.md`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/by_phase.md`
- `docs/indexes/by_subsystem.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/donor_to_phase.md`
- `docs/diagrams/generated/actual_vs_expected_diff.mmd`
- `docs/diagrams/generated/current_phase.mmd`
- `docs/diagrams/generated/full_architecture.mmd`
- `docs/diagrams/generated/future_target.mmd`
- `docs/diagrams/generated/release_verification.mmd`

Completion Check:

`dart run docs/tool/sync_generated_docs.dart --check` passes.
`dart run docs/tool/check_docs.dart` passes. If
`docs/architecture/architecture_graph.yaml` or generated graph views changed,
`dart run tool/architecture_graph/check.dart --phase P7` and
`dart run tool/architecture_graph/generate_views.dart --phase P6 --check`
pass. The final semantic search
`rg -n -i "DiagnosticsHub|diagnostic|diagnostics|probe|counter" docs`
has no unreviewed durable claim that implies a DiagnosticsHub writer outside
the routing table or omits the table's required timing, path/details, non-hub,
or post-acceptance containment classification. `PLAN.md` shows Step 40 checked,
and this step file shows all execution-unit checkboxes checked only after
verification passes.

Depends On:

Unit 1, Unit 2, Unit 3, and Unit 4.
