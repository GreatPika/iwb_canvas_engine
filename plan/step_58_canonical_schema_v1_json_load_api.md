# Change Contract

## Goal

Make schema-v1 JSON the only canonical public runtime load input: applications call `runtime.edits.loadDocumentFromJson(json)` on an existing runtime, valid JSON installs committed engine tables atomically, invalid JSON leaves the runtime unchanged, and `CanvasDocument` remains only a read/output projection.

## Source Inputs

- Design: `.design/2026-06-07-canonical-schema-v1-json-load-api.md`
- Research: none
- Phase: none
- PLAN: `PLAN.md`, `plan/step_52_legacy_example_full_parity_port.md`
- Other: `docs/contracts/public_api_v1.md`, `docs/_registry/public_api_v1.yaml`, `docs/contracts/load_document.md`, `docs/contracts/codec_boundary.md`, `docs/contracts/schema_v1.md`, `docs/contracts/resources.md`, `docs/contracts/validation_limits.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/03_data_model.md`, `docs/_registry/benchmarks.yaml`, `docs/verification/benchmarks.md`, `docs/verification/guardrails.md`, `tool/guardrails`, `tool/bench/manual/reference_decisions.json`, `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json`, `lib/src/api/canvas_runtime.dart`, `lib/src/api/canvas_codec.dart`, `lib/src/codec/schema_v1_decoder.dart`, `lib/src/codec/validated_import_draft.dart`, `lib/src/edit/staged_document_load.dart`, `lib/src/store/document_store_kernel.dart`, `lib/src/store/resource_table.dart`, `lib/src/runtime/runtime_root.dart`, `test/benchmarks/benchmark_probe_flutter.dart`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: SEAM_MIGRATION, PUBLIC_API_CHANGE

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Canonical public runtime load is `CanvasEditPort.loadDocumentFromJson(String json)`, not `loadDocument(CanvasDocument)`. | `Boundaries.In Scope`, `Boundaries.Compatibility`, Unit 1, Unit 2, Unit 5 | Public API compile fixture, registry/barrel parity, production route-retirement search, runtime load tests. |
| `D2` `CanvasRuntime(initialDocument: CanvasDocument?)` is retired with no replacement initial-load input. | `Boundaries.Compatibility`, Unit 1, Unit 2 | Public constructor compile-negative fixture and docs/registry proof that runtime construction creates the default empty document only. |
| `D3` `CanvasDocument` is read/output projection only and is not public or internal load input. | `Boundaries.Source of Truth`, Unit 2, Unit 4, Unit 5, Unit 6 | Static signature guardrail and semantic search reject production load/runtime constructor/import/store pipeline methods that accept `CanvasDocument` as load/admission input; allowed exceptions are limited to read/output projection, explicit draft materialization compatibility paths that are not runtime load, and encode/tooling paths. |
| `D4` Public `decodeCanvasDocument` and `decodeCanvasDocumentFromJson` are removed from Public API v1 and cannot be a public runtime load route. | `Boundaries.Compatibility`, Unit 1, Unit 2, Unit 7 | Registry/barrel proof, public compile-negative fixture, example migration, benchmark probe route assertion. |
| `D5` Schema validation remains codec-owned; codec emits dependency-neutral import events, does not import/call store, and does not return a document-sized retained validated fact graph. | `Boundaries.Owner`, `Boundaries.Source of Truth`, Unit 3, Unit 4 | Owner-DAG import tests, importer/store fixtures, retained-payload negative proof. |
| `D6` Internal builder/sink/row/prepared-table types are not public API exports. | `Boundaries.Out of Scope`, Unit 2, Unit 4 | Public export guardrails and internal-export negative fixtures. |
| `D7` Resources import as store-owned descriptor rows without constructing `CanvasImageResource` on the load path. | `Boundaries.Source of Truth`, Unit 4 | Resource import tests and semantic/allocation proof; read/resolver projection tests prove public resource projection still works. |
| `D8` JSON load is all-or-nothing across document, selection, camera, revisions, previews/interactions, effects, observers, actions, and state listeners. | `All-Or-Nothing Failure Boundary`, Unit 5 | Runtime snapshot failure fixtures and ordered listener/effect tests. |
| `D9` Store install preserves id-admission reset and revision behavior without eager projection. | `Boundaries.Order Constraints`, Unit 4, Unit 5 | Store id/revision tests and projection build-count fixtures. |
| `D10` Performance acceptance measures the new public JSON load API at 50k on the Xiaomi 22081283G manual reference contour, excludes first projection, and gates `schema_import_load_us < 820000`. | `Boundaries.Order Constraints`, Unit 7 | Benchmark manifest/probe tests, Xiaomi manual run, and required bridge report comparing old route and new route with no projection. |
| `D11` 100k raw JSON is outside this phase under the current 32 MiB raw JSON limit. | `Boundaries.Out of Scope`, Unit 7 | Manifest scale assertions and validation-limit tests for oversized raw JSON rejection. |
| `D12` Durable docs, diagrams, registries, guardrails, benchmarks, and active Step 52/example workflow must be updated before implementation completion. | `Boundaries.Source of Truth`, Unit 1, Unit 2, Unit 6, Unit 7 | Docs checks, generated-doc checks, diagram architecture checks, Step 52/example tests, guardrail registry/check tests, benchmark registry checks. |
| User P.S. Xiaomi device availability and bridge-report requirement, 2026-06-07. | `Boundaries.Order Constraints`, Unit 7 | Implementer must run the device benchmark with Xiaomi connected and publish a bridge report: `legacy decode_us + legacy load_document_us` vs `new schema_import_load_us` on one Xiaomi contour, one 50k fixture family, and no projection. |

## Evidence

- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract rather than a blocker.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:17` / product outcome: saved documents load by schema-v1 JSON into an existing runtime and invalid JSON leaves the runtime unchanged -> contract must define public JSON load plus atomic failure proof.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:23` / user API decision: initial document construction input and public `decodeCanvasDocument*` helpers are removed -> public API removal is in scope and not an implementer choice.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:28` / non-goals: first projection optimization, 100k raw JSON, public internal rows/sinks, and retained validated payloads are excluded -> contract must block eager projection and public/internal graph shortcuts.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:36` / classification: required profile is `BEHAVIOR_CHANGE` with `SEAM_MIGRATION` and `PUBLIC_API_CHANGE` -> execution order must add and prove successor seams before retiring old routes.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:557` / selected form: locked public load API is `CanvasEditPort.loadDocumentFromJson(String json)` -> public API and runtime units must implement that exact route.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:578` / load input policy: `CanvasDocument` is not public or internal load input -> seam-retirement proof must cover public, runtime, edit, store, benchmarks, and examples.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:585` / owner split: codec owns JSON parse/validation/import-event emission and store owns committed row builders/install -> importer and store work must remain separately owned.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:595` / handoff boundary: the codec/store handoff is an internal event/visitor boundary, not a retained document graph, and codec must not import store -> Unit 3 and Unit 4 need dependency and retained-payload negative proof.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:610` / resource policy: resources import as internal descriptor rows and load does not construct `CanvasImageResource` -> Unit 4 needs direct resource-row proof.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:616` / atomicity: failed JSON load leaves document, selection, camera, revisions, interactions, effects, action streams, and state listeners unchanged -> Unit 5 must prove all public runtime domains.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:624` / irreversible point: runtime install of prepared store tables plus selection, camera, revisions, invalidation, and cleanup is the irreversible point -> all fallible work must complete before install.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:632` / performance boundary: success measures 50k raw JSON on Xiaomi 22081283G, includes parse/validation/import/install, and excludes first projection -> Unit 7 benchmark acceptance cannot use Pixel, old decode/load route, or projection.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:640` / numeric gate: `schema_import_load_us < 820000` on `runtime.edits.loadDocumentFromJson(json)` -> Unit 7 completion must fail when this threshold is missed.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:647` / scale exclusion: 100k raw JSON remains outside this phase under the 32 MiB raw JSON cap -> Unit 7 must not require 100k raw JSON load success.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:657` / decision trace: D1-D12 are lock-required handoff rows -> every decision must map to a boundary, execution unit, or proof surface.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:839` / source-of-truth impact: active Step 52 must be repaired or superseded before removing public decode/load APIs -> Unit 1 must resolve the roadmap conflict.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:845` / source-of-truth impact: public API docs and registry must replace DTO load, remove constructor input, and remove public decode helpers -> Unit 1 owns docs/registry source-of-truth changes.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:863` / source-of-truth impact: `docs/architecture/03_data_model.md` must document prepared row/table load, resource descriptor row import, and lazy projection preservation -> Unit 1 owns this architecture document update.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:871` / source-of-truth impact: benchmark registry, benchmark docs, tools, and tests must measure the new public JSON API with Xiaomi 50k threshold and separate projection -> Unit 7 owns benchmark policy and proof.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:876` / source-of-truth impact: `docs/verification/guardrails.md`, `tool/guardrails`, and guardrail registry must cover old load input retirement, decode-helper route rejection, internal export quarantine, and no eager projection -> Unit 2 and Unit 6 must add mandatory guardrails, not optional semantic-only proof.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:879` / source-of-truth impact: durable load diagrams must be updated because current diagrams show the old DTO/decode/load route -> Unit 6 owns diagram repairs.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:897` / verification impact: public compile fixtures must prove the new public call and absence of old signatures -> Unit 2 proof must be public-barrel based.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:906` / verification impact: codec/import tests must cover raw length, malformed JSON, schema version, unknown kinds, metadata, duplicate ids, references, transforms, and retained-payload absence -> Unit 3 and Unit 4 need focused failure proof.
- `.design/2026-06-07-canonical-schema-v1-json-load-api.md:931` / verification impact: benchmark tests must prove 50k public JSON load, threshold, invalid JSON failure, breakdown split, and 100k exclusion -> Unit 7 must include both runner proof and device proof.
- `PLAN.md:74` / active roadmap: Step 52 remains unchecked -> implementation cannot silently leave its decode-then-load example contract as the active import source of truth.
- `plan/step_52_legacy_example_full_parity_port.md:291` / active contract conflict: Step 52 currently requires `decodeCanvasDocumentFromJson` followed by `runtime.edits.loadDocument` -> Unit 1 or Unit 6 must repair/supersede this before public API removal completes.

## Boundaries

Owner:

`CanvasEditPort` owns the public JSON load command shape. `RuntimeRoot` owns load orchestration, mutation/publication guards, prepared cleanup ordering, and public state/effect publication. `CodecBoundary` owns raw JSON length validation, JSON parse, schema-v1 validation policy, diagnostics, and dependency-neutral import-event emission. `DocumentStoreKernel` owns committed row builders, resource descriptor rows, id admission, reference checks, prepared table payloads, projection invalidation facts, and final table install. Existing docs, registries, diagrams, guardrails, and benchmark owners remain the source-of-truth owners for their surfaces.

In Scope:

Add `CanvasEditPort.loadDocumentFromJson(String json)` as the canonical public load route for schema-v1 JSON on existing runtimes. Remove public `CanvasRuntime(initialDocument: CanvasDocument?)` input with no replacement initial-load constructor route. Remove public `decodeCanvasDocument` and `decodeCanvasDocumentFromJson` exports from Public API v1. Retire `CanvasDocument` as public and internal load input across runtime/edit/store/import pipelines while preserving `CanvasDocument` as read/output projection and encode/tooling input where still public. Add codec-owned dependency-neutral schema import events, store-owned prepared rows/tables, resource descriptor row import, id/revision/camera/selection handling, atomic runtime install, failure rollback/no-publication proof, source-of-truth docs/diagram updates, guardrails, example/Step 52 migration, benchmark manifest/probe migration, and Xiaomi 50k bridge-report proof.

Out of Scope:

Do not optimize first `readDocument()` projection in this step. Do not use eager projection as a load-performance solution. Do not accept 100k raw JSON under the current 32 MiB raw JSON limit. Do not add public row, sink, builder, prepared-table, visitor, importer, or committed-table types. Do not let codec import runtime, store, edit, frame, Flutter widgets, or interaction state. Do not return or retain a second document-sized validated fact/list/tree graph between parsed JSON and store-native rows. Do not move schema-v1 wire policy out of the codec/schema contracts or create a second durable schema.

Source of Truth:

Schema v1 JSON remains the wire source of truth. `DocumentStoreKernel` committed tables remain the runtime state source of truth, with `docs/architecture/03_data_model.md` owning the architecture-level prepared row/table load path, resource descriptor row import, and lazy projection policy. `CanvasDocument` remains a public read/output projection, not load state. Public signature truth lives in `docs/contracts/public_api_v1.md`, `docs/_registry/public_api_v1.yaml`, `lib/iwb_canvas_engine.dart`, and public API guardrails. Load atomicity truth lives in `docs/contracts/load_document.md` and runtime/load tests. Codec validation truth lives in `docs/contracts/codec_boundary.md` and `docs/contracts/schema_v1.md`. Resource import truth lives in `docs/contracts/resources.md` and store/resource tests. Guardrail truth for old load input retirement, decode-helper route rejection, internal export quarantine, and no eager projection lives in `docs/verification/guardrails.md`, `tool/guardrails`, and guardrail registry/tests. Benchmark acceptance truth lives in `docs/_registry/benchmarks.yaml`, `docs/verification/benchmarks.md`, benchmark tools/tests, and the accepted Xiaomi manual reference decision/report surfaces. Active example-import roadmap truth must be repaired in Step 52 or explicitly superseded by this step before old public APIs are removed.

Compatibility:

This is an intentional breaking Public API v1 change for load/constructor/decode surfaces, accepted because there are no external users yet. Public `CanvasDocument` read projection, explicit `readDocument()`, schema-v1 JSON format, encode/tooling behavior that remains exported, public runtime observation semantics, and validation/security limits must remain compatible unless this contract names the change. Internal seams may change, but internal types must remain non-public and package-boundary compliant.

Order Constraints:

First repair or supersede active Step 52 and update public source-of-truth docs/registry so the roadmap no longer requires decode-then-load. Then add the public JSON load signature, migrate the example workflow/tests to it, and retire old public routes only after that consumer migration is complete. Then add guardrails while keeping old routes only as transitional internals where needed. Then add codec-owned import events and store-owned prepared row/table builders with dependency and retained-payload negative proof. Then wire runtime JSON load through the existing edit/runtime guard and retire remaining internal `CanvasDocument` load inputs after successor seams and migration tests exist. Then update durable diagrams, guardrails, and semantic proof. Run benchmark migration and Xiaomi bridge/report proof last, after the real public JSON load route exists. The bridge report must compare `legacy decode_us + legacy load_document_us` with `new schema_import_load_us` on one connected Xiaomi 22081283G contour, one 50k fixture family, and no projection.

Temporal Surface Closure:

The temporal invariant is that no public listener, action stream, effect observer, repaint, revision, preview/interaction state, selection state, runtime view camera, resource visual state, or committed document state observes a partial JSON load. Synchronous callback surfaces are state listeners, action stream listeners, effect observers, prepared cleanup test seams, and any runtime load guard that can reject an interleaved mutation before install. `RuntimeRoot` owns the mutation/publication guard. Allowed public observation order is public JSON command -> raw length check -> parse -> schema validation -> dependency-neutral import events -> store row/reference/id preparation -> prepared cleanup -> irreversible store install plus selection clear, runtime view camera initialization, revision/invalidation facts -> one public state/effect/action publication. Invalid JSON or any pre-install failure throws `CanvasDataException`, mapped `CanvasDataException`, or `StateError` and produces no public mutation or notification.

All-Or-Nothing Failure Boundary:

The irreversible point is accepted runtime install of prepared store tables plus accepted selection, camera, revision, invalidation, and prepared-cleanup effects. Fallible work before that point includes raw length validation, JSON parse, schema validation, metadata/resource/element/enum/transform validation, duplicate id checks, missing resource reference checks, import-event processing, row/reference/id preparation, mutation guard checks, and prepared cleanup. Later work is allowed only when it is infallible, part of the accepted result, or post-commit failure-contained under existing observer-failure policy. Failure projection before the irreversible point is the previous runtime snapshot with unchanged committed document, selected ids, runtime view camera, revisions, projection cache, preview/interaction facts, resource visual state, action/event/effect lists, listener counts, and no first projection.

## Execution Units

### [x] Unit 1: Roadmap and public source-of-truth migration

Owner:

Existing roadmap, public API contract, public API registry, load/codec/schema/resource/validation contracts, architecture data-model docs, and source-of-truth docs under `PLAN.md`, `plan/**`, and `docs/**`.

Boundary:

Repair the durable contract sources before implementation can treat the old decode-then-load route as retired.

Change:

Preserve this step's `PLAN.md` registration. Repair or supersede `plan/step_52_legacy_example_full_parity_port.md` so it no longer requires `decodeCanvasDocumentFromJson` followed by `runtime.edits.loadDocument` and instead requires direct `runtime.edits.loadDocumentFromJson(json)` for valid example import plus unchanged runtime on invalid JSON. Update `docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml` to define `CanvasEditPort.loadDocumentFromJson(String)`, remove constructor `initialDocument: CanvasDocument?`, remove public `decodeCanvasDocument` and `decodeCanvasDocumentFromJson`, and keep `CanvasDocument` only as read/output projection. Update `docs/contracts/load_document.md`, `docs/contracts/codec_boundary.md`, `docs/contracts/schema_v1.md`, `docs/contracts/resources.md`, and `docs/contracts/validation_limits.md` to preserve JSON validation, row import, resource descriptor, atomicity, projection exclusion, and 100k raw JSON exclusion semantics. Update `docs/architecture/03_data_model.md` to describe the internal prepared row/table load path, resource descriptor row import, store-owned committed rows, and preservation of lazy projection.

Completion Check:

Docs and registry checks fail if public API docs, registry, and generated docs disagree about the JSON load signature, old constructor input, public decode helpers, or `CanvasDocument` projection-only role. `docs/contracts/load_document.md` describes JSON schema validation, dependency-neutral import, store-owned row/table preparation, prepared cleanup, atomic install, success publication, and failed-load no-mutation without requiring DTO validation/materialization. `docs/contracts/codec_boundary.md` and `docs/contracts/schema_v1.md` state that runtime JSON load shares schema-v1 validation policy but does not expose public decode helpers as a runtime route and does not materialize `CanvasDocument` or a retained validated graph for load. `docs/contracts/resources.md` states that load imports resource descriptors as store-owned rows and public `CanvasImageResource` appears only on explicit read/resolver-facing projection. `docs/contracts/validation_limits.md` preserves the 32 MiB raw JSON limit and excludes 100k raw JSON acceptance unless a later design changes that limit with memory proof. `docs/architecture/03_data_model.md` states that schema-v1 load prepares store-owned rows/tables, imports resources as descriptor rows, keeps committed tables as runtime source of truth, and preserves lazy `CanvasDocument` projection only on explicit read/projection paths. Step 52/example contract no longer contains a live requirement to decode JSON into `CanvasDocument` before runtime load. Documentation checks pass: `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart`. Architecture graph checks pass for the changed architecture documentation: `dart run tool/architecture_graph/check.dart --phase P14` and `dart run tool/architecture_graph/generate_views.dart --phase P14 --check`. No execution-unit checkbox in this step is marked complete until implementation evidence exists.

Depends On:

None.

### [x] Unit 2: Public API shape and retirement guardrails

Owner:

Public contracts/facades under `lib/src/contracts/public/**`, public API facades under `lib/src/api/**`, root barrel `lib/iwb_canvas_engine.dart`, example workflow/tests, public API tests, and guardrail owners.

Boundary:

Expose only the new public JSON load command while proving old public load/decode/constructor seams and internal row/importer types do not leak.

Change:

Add the public `CanvasEditPort.loadDocumentFromJson(String json)` surface and facade delegation. Migrate the example import workflow to call `runtime.edits.loadDocumentFromJson(json)` directly and handle invalid JSON with no runtime mutation before old public routes are removed. Remove public `CanvasEditPort.loadDocument(CanvasDocument)` as the canonical load route, remove `CanvasRuntime` constructor `initialDocument` input, and remove public `decodeCanvasDocument`/`decodeCanvasDocumentFromJson` exports after the example consumer no longer depends on them. Keep `CanvasDocument`, `readDocument()`, and allowed encode/tooling surfaces only where they remain read/output concerns. Add or update public compile fixtures, export registry tests, mandatory guardrail registry entries/checks for old public load input retirement and internal export quarantine, and internal export negative fixtures for importer/visitor/sink/row/prepared payload types.

Completion Check:

Public compile fixtures prove an external app importing `package:iwb_canvas_engine/iwb_canvas_engine.dart` can call `runtime.edits.loadDocumentFromJson(json)`. Example tests prove export still emits schema-v1 JSON, valid import calls public `loadDocumentFromJson(json)` directly, and invalid import leaves runtime state unchanged before old public routes are removed. Compile-negative fixtures or API shape tests fail if public code can call `CanvasRuntime(initialDocument: CanvasDocument)`, `CanvasRuntime(initialDocument: json)`, `runtime.edits.loadDocument(CanvasDocument)`, `decodeCanvasDocument`, or `decodeCanvasDocumentFromJson`. Public export registry guardrails fail if internal importer, visitor, sink, row, resource descriptor row, prepared payload, or committed-table type is exported. Guardrail registry/tests fail if old public load input retirement or internal export quarantine checks are absent or inactive. Static route-retirement checks fail if production public/runtime load routes still accept `CanvasDocument` as a load input. Structural signature checks fail if production load/runtime constructor/import/store pipeline methods still accept `CanvasDocument` as load/admission input; allowed `CanvasDocument` parameters are limited to read/output projection, explicit draft materialization compatibility paths that are not runtime load, and encode/tooling paths. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/contracts/public lib/src/api example test/api_contract tool/guardrails`, and focused public API/example/guardrail tests pass.

Depends On:

Unit 1.

### [x] Unit 3: Codec-owned schema import events

Owner:

Codec schema-v1 internals under `lib/src/codec/**` and codec/import tests.

Boundary:

Reuse schema-v1 validation policy for runtime load without materializing public DTOs, importing store/runtime/edit, or returning a retained document-sized validated graph.

Change:

Add a non-public schema-v1 import path that performs raw JSON length validation, parse, schema root/field validation, unsupported version/kind/enum rejection, metadata validation, resource and element field validation order, diagnostics, and dependency-neutral import-event emission. Keep duplicate id checks, id admission, missing resource references, and cross-row reference checks out of codec ownership; those invariants belong to the store-owned preparation in Unit 4. Keep exact class names local to implementation, but the seam must be event/visitor-like and non-public. The codec may parse the raw JSON object under the current non-streaming path, but it must not construct `CanvasDocument`, `CanvasImageResource`, store rows, store sinks, or a retained document-sized validated fact/list/tree payload for runtime load.

Completion Check:

Codec/import tests prove malformed JSON, oversized JSON, unsupported `schemaVersion`, unknown resource/element kinds, unknown enum values, metadata limit violations, and non-invertible transform fields fail before runtime mutation while duplicate id, id admission, and cross-row reference policy remain outside codec ownership. Owner-DAG guardrails fail if `lib/src/codec/**` imports runtime, store, edit, frame, Flutter widgets, or interaction owners. Retained-payload negative proof fails if the runtime import API returns a document-sized validated fact/list/tree graph or public DTO. Semantic tests fail if runtime load code calls public `decodeCanvasDocument`/`decodeCanvasDocumentFromJson` as the importer. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/codec test/codec test/guardrails`, and focused codec/guardrail tests pass.

Depends On:

Unit 2.

### [x] Unit 4: Store-owned prepared row install seam

Owner:

Store row builders and prepared payloads under `lib/src/store/**`, non-public shared handoff declarations under `lib/src/contracts/internal/**` only when needed for dependency-neutral codec/store composition, existing load composition adoption under `lib/src/edit/**` without row/prepared-table ownership, and store/resource tests.

Boundary:

Convert dependency-neutral import events into store-owned committed rows and a consume-once prepared load payload without public DTO/resource materialization or eager projection.

Change:

Add store-owned row builders and prepared table payloads for schema-v1 document load: family rows, layer/order rows, background/palette/metadata facts, resource descriptor rows, duplicate id checks, id admission facts, missing resource reference checks, cross-row reference checks, revision facts, projection invalidation facts, and camera facts needed by runtime. Replace load-preparation and full replacement paths that currently require `CanvasDocument` as runtime load/admission input, including store constructors/replacement methods and load pipeline preparation. Preserve consume-once prepared load behavior and id-admission reset semantics. Keep public projection and resolver-facing `CanvasImageResource` creation only on explicit read/resource projection surfaces.

Completion Check:

Store/import tests prove valid JSON events prepare and install committed family tables, layer order, background/palette/metadata, resource descriptor rows, admitted-id facts, revision deltas, runtime camera facts, and projection invalidation without building `CanvasDocument`. Store-owned failure tests prove duplicate ids, id admission failures, missing resource references, and invalid cross-row references fail before install with no runtime mutation. Resource tests prove load-time resource import creates internal descriptor facts and no `CanvasImageResource` before explicit read/resource/resolver projection; explicit projection still exposes public resources correctly. Projection build-count tests fail if successful or failed JSON load calls `readDocument()` or builds `DocumentProjectionCache`. Structural searches or guardrails fail if any production load/runtime constructor/import/store pipeline method still accepts `CanvasDocument` as load/admission input, including `ValidatedImportDraft.fromDocument`, `LoadDocumentPipeline.prepare(CanvasDocument)`, `DocumentStoreKernel(CanvasDocument initialDocument)`, and store replacement from `CanvasDocument`. Allowed `CanvasDocument` parameters remain only on read/output projection, explicit draft materialization compatibility paths that are not runtime load, and encode/tooling paths. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/store lib/src/edit test/store test/resources test/runtime`, and focused store/resource/load tests pass.

Depends On:

Unit 3.

### [x] Unit 5: Runtime JSON load orchestration and atomicity proof

Owner:

`RuntimeRoot`, edit/runtime load composition, interaction cleanup boundaries, runtime/load tests, and observer/effect fixtures.

Boundary:

Wire the public JSON command through the existing edit/runtime mutation guard and install only already-prepared store payloads as one accepted runtime result.

Change:

Route `runtime.edits.loadDocumentFromJson(json)` through runtime load orchestration. Sequence public JSON -> codec validation/import events -> store row preparation -> prepared interaction cleanup -> irreversible install -> selection clear -> runtime view camera initialization from persisted JSON camera -> revision/invalidation facts -> one state/effect/action publication. Retire production runtime/load call sites and signatures that still treat `CanvasDocument` as canonical load/admission input. Preserve existing observer-failure containment after accepted install while ensuring invalid JSON and pre-install failures produce no public mutation or notification.

Completion Check:

Runtime success tests prove one accepted public state publication observes replacement document summary, cleared selection, runtime view camera initialized from persisted JSON camera, revision increments, resource/projection invalidation facts, and prepared cleanup effects together with no intermediate public observation. Runtime failure snapshot tests cover invalid JSON, forced import failure, forced store-preparation failure, and prepared-cleanup failure across committed document summary/projection count, selected ids, runtime view camera, every public revision domain, preview/interaction state, resource visual state, repaint/action/effect batches, state listener counts, and observer counts; expected result is unchanged runtime and thrown `CanvasDataException` or `StateError`. Runtime structural checks fail if `RuntimeRoot`, runtime construction, edit load composition, or load pipeline signatures still accept `CanvasDocument` as runtime load/admission input. Reentrant/interleaved mutation tests cover each synchronous callback surface named in this contract: during state listener delivery, action stream listener delivery, and effect observer delivery, attempts to call `runtime.edits.edit(...)` and `runtime.edits.loadDocumentFromJson(validJson)` are rejected by the `RuntimeRoot` delivery guard with `StateError` whose message contains `post-commit effect delivery`; after each rejected action, committed document summary, selected ids, runtime view camera, revisions, action/effect batches, state listener publication count, and observer count remain unchanged beyond the accepted load already being delivered. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/runtime lib/src/edit test/runtime test/interaction`, focused runtime/load tests, and architecture graph checks for changed architecture-owned load surfaces pass.

Depends On:

Unit 4.

### [x] Unit 6: Durable diagrams and negative-proof hardening

Owner:

Durable load diagrams, docs/diagram registry surfaces, `docs/verification/guardrails.md`, `tool/guardrails`, guardrail registry/tests, and route-retirement proof tests.

Boundary:

Make the new load route the only canonical documented flow and make the old route mechanically hard to reintroduce.

Change:

Update `docs/diagrams/seq_load_document_success.mmd`, `docs/diagrams/seq_load_document_failure.mmd`, and `docs/diagrams/dfd_load_document_success_failure.mmd` to remove decode-to-`CanvasDocument` and `loadDocument(document)` from the load flow. Update diagram catalog or registry entries only if existing metadata changes. Update `docs/verification/guardrails.md`, guardrail registry, and `tool/guardrails` checks so production runtime/load/example surfaces fail on old load input usage, decode-helper route usage, internal export leakage, and eager projection on the load path. Benchmark-specific old-route proof is deferred to Unit 7 after benchmark migration. Add semantic tests only as supporting proof; they do not replace the required guardrail updates.

Completion Check:

Durable diagram checks and docs checks prove registered load diagrams now show JSON -> codec import events -> store rows -> runtime install and failure without public DTO materialization. `docs/verification/guardrails.md` documents the active checks, guardrail registry includes them, and guardrail tests fail when fixture code uses `decodeCanvasDocumentFromJson` plus runtime load, public `loadDocument(CanvasDocument)`, production load/runtime constructor/import/store signatures that accept `CanvasDocument` as load/admission input, exported internal importer/row types, or eager `readDocument()`/projection on the load route. Static route-retirement checks also fail on production/runtime/load/example calls to the old route. `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, `dart run tool/architecture_graph/check.dart --phase P14`, `dart run tool/architecture_graph/generate_views.dart --phase P14 --check`, `dart analyze`, `dcm analyze .`, owner-scoped DCM metrics for changed docs/tool/test owners, and focused guardrail tests pass.

Depends On:

Unit 5.

### [ ] Unit 7: Benchmark migration, Xiaomi bridge report, and acceptance gate

Owner:

Benchmark manifest, benchmark docs, benchmark probe/runner/diff tools, manual benchmark report surfaces, benchmark tests, and release-readiness guardrails.

Boundary:

Measure the actual new public JSON load route, not the old decode/load split, internal importer-only timing, runtime construction, fixture generation, teardown, or first projection.

Change:

Update `docs/_registry/benchmarks.yaml`, `docs/verification/benchmarks.md`, `tool/bench`, and `test/benchmarks/benchmark_probe_flutter.dart` so `load_document.success`, `load_document.failure`, and `load_document.breakdown` use `runtime.edits.loadDocumentFromJson(json)` for accepted schema-v1 load. Define `schema_import_load_us` as raw length validation through atomic runtime install, excluding runtime construction, fixture generation, teardown, and first projection. Preserve `projection.read_document` as the separate projection benchmark and keep first projection only as a diagnostic breakdown metric. Exclude 100k raw JSON load success under the 32 MiB limit. Add benchmark-specific route-retirement proof after benchmark migration so benchmark surfaces fail if they reintroduce `decodeCanvasDocumentFromJson` plus `loadDocument(CanvasDocument)` or time internal importer-only/projection work as load success. With the Xiaomi connected during implementation, produce a bridge report through existing benchmark/manual surfaces: `dart run tool/bench/run.dart` for the device run, `dart run tool/bench/archive_manual_run.dart` for `tool/bench/manual/run_history/**`, and `dart run tool/bench/accept_manual_reference.dart` only if the accepted reference must be refreshed in `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json` and `tool/bench/manual/reference_decisions.json`. The bridge report must compare `legacy decode_us + legacy load_document_us` against new `schema_import_load_us` on the same Xiaomi 22081283G contour, the same 50k fixture family, and no projection. Gate success on `schema_import_load_us < 820000`.

Completion Check:

Benchmark manifest/probe tests fail if success timing calls `decodeCanvasDocumentFromJson`, public `loadDocument(CanvasDocument)`, an internal importer-only helper, `readDocument()`, runtime construction, fixture generation, teardown, or projection as part of `schema_import_load_us`. Required-case tests prove 50k success uses the public JSON API, invalid JSON failure reports committed mutation count zero plus unchanged runtime facts, breakdown separates parse/import/install/projection diagnostics, and 100k raw JSON is not a required acceptance scale. The Xiaomi bridge report exists in the existing manual benchmark/report decision flow and shows, on one Xiaomi contour and one 50k fixture family with no projection, legacy `decode_us + load_document_us`, new `schema_import_load_us`, and pass/fail evaluation against `< 820000`. Manual device run fails the implementation if `schema_import_load_us >= 820000`. `dart run tool/bench/run.dart --profile=dry_run`, focused benchmark tests, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics docs/tool tool/bench test/benchmarks` pass.

Depends On:

Unit 5 and Unit 6.
