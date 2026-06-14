# Change Contract

## Goal

Consolidate schema v1 JSON/map reading into one codec-owned canonical reader seam so public decode and runtime import share wire-format navigation and field admission, while runtime JSON load stays on the fast dependency-neutral event path into store-owned row preparation with no public `CanvasDocument`, public `CanvasImageResource`, retained event graph, retained fact graph, or first public projection.

## Source Inputs

- Design: `.design/2026-06-14-schema-v1-reader-consolidation.md`
- Research: `.research/2026-06-14-schema-v1-load-read-paths.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/README.md`, `docs/contracts/codec_boundary.md`, `docs/contracts/load_document.md`, `docs/architecture/03_data_model.md`, `lib/src/codec/schema_v1_decoder.dart`, `lib/src/codec/schema_v1_import_emitter.dart`, `lib/src/edit/staged_document_load.dart`, `lib/src/store/schema_v1_store_import.dart`, `test/codec/schema_v1_import_emitter_test.dart`, `test/store/fixtures/schema_v1_store_import_fixture.dart`, `docs/_registry/benchmarks.yaml`, `test/benchmarks/benchmark_probe_flutter.dart`, `tool/bench/manual/reference_decisions.json`, `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json`, `tool/bench/src/benchmark_diff.dart`, `test/benchmarks/benchmark_diff_test.dart`, `docs/_registry/sections.yaml`, `docs/diagrams/dfd_schema_v1_import_encode.mmd`, `docs/diagrams/seq_schema_v1_import_encode_order.mmd`

## Classification

Profile: REFACTOR

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| D1: Schema v1 wire-format navigation and field admission get one codec-owned canonical reader seam. | `Boundaries.Owner`, `Boundaries.Source of Truth`, `Unit 1`, `Unit 2` | Unit 1 establishes the seam from the import-emitter path; Unit 2 proves decoder traversal retirement with structural no-duplicate-reader checks and decode/import parity fixtures. |
| D2: Runtime load continues through isolated import events into `StoreSchemaV1ImportBuilder` with no public DTO/projection or retained event graph. | `Boundaries.In Scope`, `Boundaries.Out of Scope`, `Boundaries.Order Constraints`, `Unit 1`, `Unit 3`, `Unit 5` | Unit 1 keeps import wrappers behaviorally equivalent; Unit 3 proves no retained graph/no eager projection and all-or-nothing runtime failure; Unit 5 measures the public load route. |
| D3: Public decoder becomes a codec-local builder sink over the canonical reader and keeps public DTO assembly plus public decode reference validation. | `Boundaries.Owner`, `Boundaries.Compatibility`, `Unit 2` | Unit 2 migrates `decodeSchemaV1Document` and `decodeSchemaV1DocumentFromJson`, keeps public signatures/schema shape stable, and verifies public decode results and diagnostics. |
| D4: Public non-isolated sink prevalidation and isolated sink abort semantics remain distinct. | `Boundaries.Order Constraints`, `Unit 1`, `Unit 3` | Unit 1 preserves sink modes in the canonical reader API; Unit 3 proves no partial non-isolated sink delivery and isolated abort/no-mutation behavior on failure. |
| D5: Duplicate id admission and missing-reference rejection remain store-owned for runtime import, while public decoder keeps decode-output reference validation. | `Boundaries.Owner`, `Boundaries.Out of Scope`, `Unit 2`, `Unit 3` | Unit 2 keeps decoder post-materialization reference validation; Unit 3 proves duplicate/missing-reference streams reach store import and are rejected during store preparation without projection or partial install. |
| D6: Performance proof requires the existing fresh Xiaomi baseline as input evidence and a final Xiaomi measurement after implementation. | `Boundaries.Order Constraints`, `Unit 5` | Unit 5 reconciles the benchmark gate/source of truth, proves `schema_import_load_us` measures `runtime.edits.loadDocumentFromJson`, and requires a final Xiaomi `load_document.success/50k` measurement with no regression against the accepted reference. |
| D7: Docs and guardrails must name the canonical reader owner and prevent a second schema v1 traversal from returning silently. | `Boundaries.Source of Truth`, `Unit 4` | Unit 4 updates authoritative docs and structural guardrails/tests so the canonical reader seam is mechanically enforced instead of only described. |
| D8: Durable schema v1 import/encode diagrams and section registry links must be reviewed and either updated or explicitly preserved with evidence. | `Boundaries.Source of Truth`, `Unit 4` | Unit 4 reviews `dfd_schema_v1_import_encode` and `seq_schema_v1_import_encode_order`, updates diagrams/registry/generated docs when needed, and runs docs checks. |

## Evidence

- `.design/2026-06-14-schema-v1-reader-consolidation.md:13` / design disposition: design is `READY_FOR_CONTRACT` -> this plan step can be a full Change Contract rather than a blocker.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:17` / product outcome: schema v1 reading needs one codec-owned source of truth without public DTO/resource/projection work on runtime load -> fixes the source-of-truth and performance boundary.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:30` / classification: design selects `REFACTOR` with `SEAM_MIGRATION` -> preserves the required contract profile and obligation.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:239` / selected form: Candidate A is the canonical codec-owned schema v1 event reader with decoder sink migration -> rejects leaf-helper-only, retained-graph, and generator alternatives.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:252` / seam ownership: current import emitter is the starting point and the architecture fixes one reader core for document envelope, resources, layers, element dispatch, metadata budget, transform/color/value admission, and diagnostics -> Unit 1 must establish the canonical reader before consumers migrate.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:260` / runtime route: runtime load remains `loadDocumentFromJson` -> `LoadDocumentPipeline.prepareFromJson` -> canonical isolated reader -> `StoreSchemaV1ImportBuilder` -> store prepare -> runtime install -> Unit 1 and Unit 3 must preserve runtime ordering.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:271` / retained payload constraint: runtime route must not add public DTOs, retained event lists, retained fact graphs, or first projection -> Unit 3 needs structural and behavioral negative proof.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:278` / decoder route: public decoder becomes a target builder over the canonical reader and keeps public DTO reference validation -> Unit 2 owns decoder migration and compatibility proof.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:293` / policy boundary: codec owns field navigation/admission, public decoder owns DTO assembly/reference validation, store owns runtime duplicate/reference admission and install -> owner boundaries cannot be re-decided during implementation.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:305` / migration order: seam first, structural tests, decoder migration, parity tests, store policy proof, source-of-truth updates, Xiaomi proof -> contract execution order follows the design handoff.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:320` / benchmark acceptance: contract must cite existing fresh Xiaomi baseline and implementation must capture the same metric after migration with no regression or weaker contradictory gate -> Unit 5 must repair benchmark source-of-truth and require manual proof.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:506` / source-of-truth impact: codec/load/data-model docs, durable diagrams, section registry links, structural tests, and benchmark source-of-truth may need updates -> Unit 4 and Unit 5 own durable source-of-truth work.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:542` / verification impact: required proof includes structural no-duplicate-reader/no-retained-graph, public decoder characterization, sink failure modes, store import policy, runtime all-or-nothing, diagrams/docs checks, benchmark probe checks, and Xiaomi final measurement -> each execution unit has direct completion signals.
- `.design/2026-06-14-schema-v1-reader-consolidation.md:628` / open decisions: no unresolved owner, boundary, source-of-truth, proof, or user decisions remain; exact file names are local implementation planning details -> no Contract Blocker is needed.
- `.research/2026-06-14-schema-v1-load-read-paths.md:13` / duplicated read paths: public decoder and runtime import both read schema v1 production JSON -> supports owner-level seam consolidation rather than caller-local cleanup.
- `.research/2026-06-14-schema-v1-load-read-paths.md:37` / duplicated surface: both paths duplicate root sections, resources, layers, element fields, metadata, transforms, colors, and values -> Unit 2 must retire traversal/dispatch duplication, not only scalar helpers.
- `.research/2026-06-14-schema-v1-load-read-paths.md:523` / policy split: decoder validates duplicates/missing image resources after materialization while import events reach the store for row admission -> Unit 3 must preserve store-owned runtime admission.
- `.research/2026-06-14-schema-v1-load-read-paths.md:556` / benchmark mismatch: prior Xiaomi gate and current diff cap disagree -> Unit 5 must reconcile the benchmark gate/source of truth before acceptance.
- `docs/README.md:22` / documentation source of truth: architecture, contracts, verification policy, registries, generated navigation, `.design`, and `.research` are routed source inputs -> Unit 4 must update owning docs/registries rather than leaving decisions only in plan prose.
- `docs/contracts/codec_boundary.md:35` / codec owner: `CodecBoundary` owns schema v1 encode and internal import validation -> canonical reader belongs in codec, not store/runtime.
- `docs/contracts/codec_boundary.md:65` / runtime load boundary: public decode helpers are not runtime load routes and codec must not materialize `CanvasDocument`, `CanvasImageResource`, store rows/sinks, or retained document-sized payloads -> Unit 3 must prove runtime load stays import-event based.
- `docs/contracts/codec_boundary.md:73` / sink modes: public non-isolated sinks receive events only after validation succeeds while isolated import may stream and abort -> Unit 1 and Unit 3 must preserve both callback/delivery modes.
- `docs/contracts/load_document.md:63` / load success order: load streams codec validation/import events into an isolated sink, store prepares rows, runtime atomically installs, and then publishes one state -> Unit 3 must keep the all-or-nothing boundary at install.
- `docs/contracts/load_document.md:122` / failure projection: failed load must not materialize public projection/resources, install partial rows, clear selection, change camera/revisions, publish effects/actions, or notify listeners -> Unit 3 completion must include failure no-mutation proof.
- `docs/architecture/03_data_model.md:61` / data model source of truth: schema v1 load uses dependency-neutral import events into store-owned prepared rows, not public `CanvasDocument` -> runtime data-flow compatibility must be preserved.
- `docs/architecture/03_data_model.md:127` / public DTOs: public DTOs are projections -> decoder DTO assembly is allowed only on public decode/read output paths.
- `docs/architecture/03_data_model.md:216` / projection cache: public document projection cache is lazy -> Unit 3 must prove no first projection during runtime load.
- `lib/src/codec/schema_v1_decoder.dart:24` / decoder traversal: `decodeSchemaV1Document` currently reads schema sections directly -> Unit 2 must migrate decoder consumption to the canonical reader.
- `lib/src/codec/schema_v1_decoder.dart:65` / public materialization: decoder currently materializes a public `CanvasDocument` -> decoder builder sink may retain DTO lists only for public decode output.
- `lib/src/codec/schema_v1_decoder.dart:78` / decoder reference validation: decoder validates document references after materialization -> Unit 2 must keep public decode reference validation outside store import.
- `lib/src/codec/schema_v1_decoder.dart:821` / local decoder helpers: decoder owns local map readers -> Unit 2 needs structural retirement proof for duplicate reader helpers.
- `lib/src/codec/schema_v1_import_emitter.dart:1` / import emitter role: emitter is already codec-owned and avoids public DTOs and store row types -> Unit 1 should start from this seam.
- `lib/src/codec/schema_v1_import_emitter.dart:32` / isolated entry: import emitter has the JSON-to-isolated-sink runtime route -> Unit 1 must preserve fast import entry points.
- `lib/src/codec/schema_v1_import_emitter.dart:50` / non-isolated validation: public import validates before delivery -> Unit 3 must prove no partial public sink notification.
- `lib/src/codec/schema_v1_import_emitter.dart:190` / ordered event emission: emitter reads document/resources/layers/elements in one pass -> Unit 1 should preserve one-pass event emission semantics.
- `lib/src/codec/schema_v1_import_emitter.dart:1099` / emitter helpers: emitter has local map readers parallel to decoder readers -> Unit 1 can own successor reader helpers while Unit 2 removes decoder duplicates.
- `lib/src/edit/staged_document_load.dart:123` / runtime prepare: load preparation creates `StoreSchemaV1ImportBuilder`, imports JSON into isolated sink, and asks store to prepare rows -> Unit 1 and Unit 3 must keep runtime load one-pass and sink-based.
- `lib/src/store/schema_v1_store_import.dart:12` / store import builder: builder is the single handoff from import events to committed store tables and splitting it would create another retained import graph -> retained intermediate graph is out of scope.
- `lib/src/store/schema_v1_store_import.dart:87` / store preparation: store consumes pending import state into `PreparedStoreDocumentImport` -> runtime row admission remains store-owned.
- `test/codec/schema_v1_import_emitter_test.dart:22` / structural guard: current guard keeps import emitter codec-owned and non-retained -> Unit 4 must migrate this guard to the successor reader seam.
- `test/codec/schema_v1_import_emitter_test.dart:356` / codec policy test: duplicate ids and missing resource references are not codec-owned policy -> Unit 3 must preserve store-owned runtime rejection.
- `test/store/fixtures/schema_v1_store_import_fixture.dart:29` / projection proof: valid import prepares and installs rows without projection -> Unit 3 must keep runtime load projection-free.
- `test/store/fixtures/schema_v1_store_import_fixture.dart:48` / store admission proof: store preparation owns duplicate/reference rejection -> Unit 3 must keep row admission in store.
- `docs/_registry/benchmarks.yaml:680` / registered benchmark: `load_document.success` is registered -> Unit 5 must use registered benchmark source-of-truth.
- `docs/_registry/benchmarks.yaml:694` / required metric: `schema_import_load_us` is required -> Unit 5 must use this metric for no-regression.
- `test/benchmarks/benchmark_probe_flutter.dart:2051` / benchmark split: load and first projection are timed separately -> Unit 5 must preserve first projection exclusion.
- `test/benchmarks/benchmark_probe_flutter.dart:2086` / benchmark route: `_timedLoadDocument` measures `runtime.edits.loadDocumentFromJson(encodedJson)` -> Unit 5 must keep performance proof on the public runtime route.
- `tool/bench/manual/reference_decisions.json:6` / accepted Xiaomi reference: current accepted reference path is the Xiaomi 22081283G report -> Unit 5 must cite this accepted baseline.
- `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json:4125` / 50k case: accepted Xiaomi reference contains `load_document.success` scale `50k` -> Unit 5 must compare the matching case.
- `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json:4170` / baseline metric: accepted Xiaomi 50k `schema_import_load_us` is `342101` -> final implementation measurement must not regress against this metric.
- `tool/bench/src/benchmark_diff.dart:23` / current absolute cap: current cap is `1500000` -> this is weaker than the accepted Xiaomi baseline and must be reconciled.
- `test/benchmarks/benchmark_diff_test.dart:952` / current failure text: benchmark diff test expects the `1500000` cap -> Unit 5 must update tests with the reconciled no-regression source of truth.
- `docs/_registry/sections.yaml:175` / schema v1 diagrams: schema v1 registry links `dfd_schema_v1_import_encode` and `seq_schema_v1_import_encode_order` -> Unit 4 must review/update durable diagram references.
- `docs/_registry/sections.yaml:660` / codec boundary diagrams: `CodecBoundary` registry links the same diagrams -> Unit 4 must keep registry links accurate after diagram review.
- `docs/diagrams/dfd_schema_v1_import_encode.mmd:26` / data-flow diagram: current diagram names the import event stream -> Unit 4 must decide whether to show the canonical reader and decoder sink handoff.
- `docs/diagrams/seq_schema_v1_import_encode_order.mmd:16` / sequence diagram: current sequence routes runtime load through `importSchemaV1DocumentFromJson(json, sink)` -> Unit 4 must keep ordering documentation truthful after seam migration.

## Boundaries

Owner: `CodecBoundary` owns the canonical schema v1 reader seam and wire-format field admission; public decoder code in codec owns `CanvasDocument` builder-sink materialization and public decode reference validation; store import owns runtime duplicate id admission, missing-reference rejection, row placement, revision facts, prepared committed tables, and final store preparation; runtime/edit owns load orchestration, atomic install, and public observation.

In Scope:

- Establish one codec-internal canonical schema v1 reader core from the current import-emitter reader shape.
- Preserve existing import/decode/load public entry points, signatures, schema v1 JSON shape, diagnostics semantics, and sink delivery modes.
- Migrate public decoder to consume the canonical reader through a codec-local builder sink and retire decoder-owned schema traversal/dispatch/read helpers that duplicate the canonical reader.
- Keep runtime JSON load on isolated import events into `StoreSchemaV1ImportBuilder` and `DocumentStoreKernel.prepareSchemaV1Import`.
- Preserve store-owned runtime duplicate/reference admission and decoder-owned public decode reference validation.
- Add or migrate structural, parity, sink failure-mode, store admission/projection, runtime all-or-nothing, docs/diagram, benchmark route, and Xiaomi performance proof.
- Update authoritative docs, registries, diagrams, guardrails/tests, and benchmark source-of-truth only where needed to reflect the canonical reader seam and no-regression gate.

Out of Scope:

- Public API renames or new public decode/load/import entry points.
- Schema v1 JSON shape changes, fixture scale policy changes, or schema-reader code generation.
- Moving store row admission, duplicate id rejection, missing-reference rejection, or runtime install policy into codec.
- Introducing a retained validated schema fact graph, retained import event list, public `CanvasDocument` runtime load route, public `CanvasImageResource` runtime load allocation route, or first public projection during load success.
- Changing resource resolver behavior, runtime load atomicity, selection/camera cleanup policy, or public observation ordering except for preserving the existing contracts.
- Treating the current `1500000` us cap as sufficient proof if it allows regression against the accepted Xiaomi reference.

Source of Truth: Canonical schema v1 wire-format navigation and field admission live in one codec reader seam. Runtime committed document truth remains store-owned committed tables prepared from dependency-neutral import events. Public `CanvasDocument` remains a projection/output object for explicit decode/read paths. Authoritative behavior and verification meaning live in `docs/contracts/`, `docs/architecture/`, `docs/_registry/`, diagram sources, structural tests/guardrails, benchmark manifest/diff/reference files, and focused tests; `.design/` and `.research/` remain source inputs and evidence, not active behavior owners.

Compatibility: Existing public APIs, internal import entry points, schema v1 wire format, diagnostics codes/paths for covered behavior, public decode output, runtime load success/failure ordering, store admission outcomes, and benchmark measurement boundary must remain compatible. Implementation may choose exact private file names for the reader core and decoder builder sink, but must preserve the design's owner, boundary, source-of-truth, order, and proof requirements.

Order Constraints:

1. Establish the canonical reader seam and migrate/wrap existing import entry points before changing public decoder traversal.
2. Add or migrate structural guards for the successor seam before retiring duplicate decoder traversal.
3. Migrate public decoder to a codec-local builder sink over the canonical reader, then retire decoder-owned duplicate JSON section readers, element dispatch, and map/list helpers.
4. Add parity/characterization tests and sink-mode failure tests before relying on the new shared seam as complete.
5. Preserve and prove store-owned runtime admission, runtime all-or-nothing failure, and no-projection/no-retained-graph constraints before final source-of-truth cleanup.
6. Review/update source-of-truth docs, guardrails, diagrams, registries, and generated docs after the seam behavior is settled.
7. Reconcile benchmark source-of-truth and route tests before final acceptance, then capture the final Xiaomi 22081283G `load_document.success/50k schema_import_load_us` implementation measurement; acceptance requires no regression against the accepted reference metric `342101`.

## Execution Units

### [ ] Unit 1: Establish canonical reader seam

Owner: `CodecBoundary` production code under `lib/src/codec/`.

Boundary: Schema v1 JSON/map root admission, section navigation, field admission, diagnostics wrapping, event ordering, and non-isolated/isolated sink delivery modes. Store row admission and public DTO assembly remain outside this unit.

Change: Extract or reorganize the current import-emitter reader core into a single codec-internal canonical reader seam. Existing `importSchemaV1Document`, `importSchemaV1DocumentFromJson`, `importSchemaV1DocumentIntoIsolatedSink`, and `importSchemaV1DocumentFromJsonIntoIsolatedSink` continue to delegate to that seam with behaviorally equivalent event order, diagnostics, and failure behavior.

Completion Check: Focused codec import tests pass for current valid and invalid schema v1 import cases, including raw JSON length/root/schema admission, known/unknown field policy, metadata budget, transform/color/value admission, document/resource/layer/element event ordering, non-isolated prevalidation before sink delivery, and isolated `abortDocument()` on reader or sink failure. A structural source test names the canonical reader seam and fails if it imports store/runtime/edit/frame/Flutter widget dependencies, materializes `CanvasDocument` or `CanvasImageResource`, or retains a document-sized event/fact list in the runtime import path.

Depends On: none.

### [ ] Unit 2: Migrate public decoder to builder sink

Owner: `CodecBoundary` production code under `lib/src/codec/`.

Boundary: Public `decodeSchemaV1Document` and `decodeSchemaV1DocumentFromJson` output assembly and decoder-owned public DTO reference validation. Runtime load and store row admission remain outside this unit.

Change: Move public decoder section traversal, element-kind dispatch, map/list helpers, and field-shape admission onto the canonical reader by adding a codec-local, non-exported `CanvasDocument` builder sink. Keep public decode signatures and schema v1 JSON compatibility stable. Keep decoder-specific `CanvasDocument` materialization and post-materialization reference validation after the builder sink completes.

Completion Check: Public decoder characterization tests prove that `decodeSchemaV1Document` and `decodeSchemaV1DocumentFromJson` still return equivalent `CanvasDocument` results and equivalent `CanvasDataException` codes/paths for valid documents, defaults, diagnostics routing, colors, metadata, transforms, resources, layers, and every element family covered by schema v1 fixtures. Structural source tests cover decoder-owned codec files, including `schema_v1_decoder.dart` and any new decoder builder-sink file, and fail if they reintroduce independent schema section traversal, element-kind dispatch, or local map/list/typed reader helpers that duplicate the canonical reader. Decoder reference-validation tests still prove duplicate layer/element ids and missing image resource references are rejected after public DTO materialization.

Depends On: Unit 1.

### [ ] Unit 3: Preserve runtime admission and failure semantics

Owner: Store import under `lib/src/store/`, runtime/edit load orchestration under `lib/src/edit/` and runtime install boundaries, with codec sink-mode proof from `lib/src/codec/`.

Boundary: Runtime JSON load from `runtime.edits.loadDocumentFromJson(json)` through isolated import, store preparation, atomic install, projection invalidation, and failure projection. Public decoder materialization remains outside this unit except as an explicitly forbidden runtime dependency.

Change: Ensure the canonical reader migration does not move duplicate id admission, missing-reference rejection, row placement, revision facts, prepared committed tables, or install policy out of store/runtime. Preserve all-or-nothing failure behavior: fallible raw length, parse, schema reading, event delivery, store preparation, and prepared cleanup complete before the irreversible runtime install; post-install publication remains the first public observation.

Completion Check: Store import tests prove duplicate ids and missing resource/reference event streams reach store preparation and are rejected there without public projection or partial install. Runtime load failure tests cover raw length, parse, schema read, event delivery, store preparation, and prepared cleanup failures before install; each case throws the expected public error type and leaves previous committed document, selection, view camera, revisions, preview, effects/actions, repaints, projection build count, and state listeners unchanged. Runtime load success tests prove exactly one post-install public state publication and no first `CanvasDocument` projection until explicit read. Sink-mode tests prove invalid non-isolated import does not notify external sinks, isolated import calls `abortDocument()` on reader/sink/store-preparation failure, and no aborted pending sink state can be prepared or installed.

Depends On: Unit 1 and Unit 2.

### [ ] Unit 4: Update source-of-truth docs, diagrams, and guardrails

Owner: Documentation, registry, diagram, and guardrail/test surfaces under `docs/`, `docs/_registry/`, `docs/diagrams/`, and focused codec structural tests.

Boundary: Authoritative descriptions and mechanical enforcement for schema v1 reader ownership, runtime load no-retained-graph/no-projection constraints, decoder sink handoff, and durable diagram truth. Production behavior remains owned by Units 1-3.

Change: Update `docs/contracts/codec_boundary.md` to name the canonical reader owner and preserve the no public DTO/no retained graph runtime load constraint. Update `docs/contracts/load_document.md` and `docs/architecture/03_data_model.md` only where needed to keep runtime import-event flow and projection language accurate. Review `docs/diagrams/dfd_schema_v1_import_encode.mmd` and `docs/diagrams/seq_schema_v1_import_encode_order.mmd`; either update them for the canonical reader plus decoder sink handoff or record in the owning source-of-truth surface why their current abstraction remains accurate. Keep `docs/_registry/sections.yaml` links accurate after diagram decisions. Migrate structural guardrails/tests away from the old emitter file-name-only assumption to the canonical reader seam.

Completion Check: `docs/diagrams/dfd_schema_v1_import_encode.mmd` and `docs/diagrams/seq_schema_v1_import_encode_order.mmd` are each either updated to show the canonical reader plus decoder sink handoff, or the owning source-of-truth surface records a preservation rationale explaining why that diagram remains accurate at its current abstraction level after the seam migration. Documentation checks `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after any required generated-doc refresh. If architecture-owned graph or generated diagram closure changes, `dart run tool/architecture_graph/check.dart` and `dart run tool/architecture_graph/generate_views.dart --check` pass. Structural guardrail tests fail when a second schema v1 traversal is added to the decoder or when the canonical reader imports store/runtime/edit/frame/Flutter widget dependencies or materializes runtime public DTO/projection payloads.

Depends On: Unit 1, Unit 2, and Unit 3.

### [ ] Unit 5: Reconcile benchmark gate and prove Xiaomi no-regression

Owner: Benchmark source-of-truth and tests under `docs/_registry/benchmarks.yaml`, `tool/bench/`, `test/benchmarks/`, and manual benchmark reference records under `tool/bench/manual/`.

Boundary: `load_document.success/50k schema_import_load_us` performance proof for the public runtime load route. This unit does not change fixture scale policy or measure private helper routes.

Change: Reconcile benchmark source-of-truth so the implementation cannot pass by staying below the current `1500000` us cap while regressing against the accepted Xiaomi reference. Preserve or update benchmark manifest/diff/reference tests so `schema_import_load_us` for `load_document.success/50k` is compared against the accepted Xiaomi 22081283G `342101` metric or a stricter no-regression policy derived from that accepted reference. Preserve benchmark probe coverage proving `schema_import_load_us` times `runtime.edits.loadDocumentFromJson(encodedJson)` and excludes first projection.

Completion Check: Benchmark unit tests pass for manifest, probe route, manual reference selection, and diff failure messages showing `load_document.success/50k schema_import_load_us` fails on regression against the accepted Xiaomi reference/no-regression policy rather than only the weaker `1500000` cap. A final post-implementation Xiaomi 22081283G Android 14 Flutter 3.44.0 release measurement for `load_document.success/50k` is captured in the manual benchmark workflow and reports `schema_import_load_us <= 342101` or otherwise fails the step; the measurement must use `runtime.edits.loadDocumentFromJson(encodedJson)` and keep first projection reported separately.

Depends On: Unit 1, Unit 2, Unit 3, and Unit 4.
