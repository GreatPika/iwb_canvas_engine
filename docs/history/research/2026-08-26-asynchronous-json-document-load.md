---
date: 2026-08-26
researcher: agent
commit: cf34391d
branch: main
research_question: "What does the current codebase establish about asynchronous schema v1 JSON document loading, the staged-load ownership check, and the prepared import data boundary?"
---

# Research: Asynchronous JSON Document Load

## Summary

The current public JSON document-load surface is synchronous. `CanvasEditPort.loadDocumentFromJson` returns `void`, and the public runtime facade exposes that port through `CanvasRuntime.edits` (`lib/src/contracts/public/canvas_runtime.dart:147-151`, `lib/src/api/canvas_runtime.dart:37-46`). The port delegates to `RuntimeRoot._loadDocumentFromJson`, which invokes `_loadPipeline.prepareFromJson(json)` before any runtime cleanup, then performs prepared interaction cleanup, store consumption, selection clearing, view-camera initialization, and result delivery (`lib/src/edit/edit_kernel.dart:372-390`, `lib/src/runtime/runtime_root.dart:2239-2258`). No public async/Future JSON-load variant was found in the inspected public, API, edit, or runtime production paths.

`LoadDocumentPipeline.prepareFromJson` currently combines codec import into `StoreSchemaV1ImportBuilder` with store preparation, then packages the result in `PreparedDocumentLoad` (`lib/src/edit/staged_document_load.dart:72-103`). Both the pipeline and prepared load store an `Object` owner token, and `consume` uses `identical` to reject a prepared load from a different pipeline (`lib/src/edit/staged_document_load.dart:41`, `lib/src/edit/staged_document_load.dart:64`, `lib/src/edit/staged_document_load.dart:105-114`). Existing tests exercise rejection by a different local pipeline and rejection of a second consumption (`test/edit/fixtures/staged_document_load_success_failure_fixture.dart:53-77`, `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:95-108`). No test was found that sends a prepared load across an isolate boundary.

`PreparedStoreDocumentImport` holds a revision snapshot, `CommittedDocument`, revision delta, scalar summary, and a mutable consumption flag; it does not declare a `DocumentStoreKernel`, diagnostics, or callback field (`lib/src/store/schema_v1_store_import.dart:225-258`). The store kernel owns the mutable current committed document and uses the prepared import's revision check during installation (`lib/src/store/document_store_kernel.dart:177-181`, `lib/src/store/document_store_kernel.dart:728-741`, `lib/src/store/document_store_kernel.dart:794-801`). A repository-wide search found no `Isolate.run` use and no `dart:isolate` import under `lib/`; the only `dart:isolate` import is a VM-retention test fixture (`test/api/fixtures/vm_retention_connection.dart:2`, `test/api/fixtures/vm_retention_connection.dart:16-17`). The repository does not contain an execution test or a documented transferability classification for this prepared object graph.

## Detailed Findings

### 1. Public JSON-load contract and delegation

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:147-151`.
- **Description**: `CanvasEditPort` declares `void loadDocumentFromJson(String json)`.
- **Dependencies**: `CanvasRuntime.edits` returns the runtime root's edit port (`lib/src/api/canvas_runtime.dart:37-46`); `RuntimeRoot.edits` returns `_editPort` (`lib/src/runtime/runtime_root.dart:420-424`); and `_editPort` is supplied from `EditKernel.port` during root construction (`lib/src/runtime/runtime_root.dart:353-364`, `lib/src/edit/edit_kernel.dart:81-84`).
- **Data flow**: application call -> `CanvasRuntime.edits` -> `_EditKernelPort.loadDocumentFromJson` -> `DocumentLoadInstaller` -> `RuntimeRoot._loadDocumentFromJson` (`lib/src/api/canvas_runtime.dart:37-46`, `lib/src/edit/edit_kernel.dart:372-390`, `lib/src/runtime/runtime_root.dart:353-364`).
- **Evidence consequence**: the present public operation completes without a `Future` return value; no public async/Future JSON-load declaration was found in `lib/src/contracts/public`, `lib/src/api`, `lib/src/edit`, or `lib/src/runtime`.

### 2. Runtime staging, installation, and publication order

- **Location**: `lib/src/runtime/runtime_root.dart:2239-2258`.
- **Description**: `_loadDocumentFromJson` first calls `_loadPipeline.prepareFromJson(json)`. After successful preparation, it enters an installation guard, prepares interaction cleanup, consumes the prepared load, clears selection, copies the prepared camera to `_viewCamera`, advances revisions, leaves the guard in `finally`, and delivers the load result.
- **Dependencies**: `_prepareLoadInteractionCleanup` includes the optional boundary callback, text-edit transient-state clearing, `interactionEngine.prepareLoadCleanup`, request clearing, and pending-context suppression (`lib/src/runtime/runtime_root.dart:2261-2275`). Runtime mutations are rejected while a document load is in progress (`lib/src/runtime/runtime_root.dart:1935-1946`, `lib/src/runtime/runtime_root.dart:1972-1978`).
- **Data flow**: prepared load -> prepared interaction cleanup -> pipeline consume -> selection/view-camera/revision state -> delivery effects -> published runtime state and repaint targets (`lib/src/runtime/runtime_root.dart:2242-2258`, `lib/src/runtime/runtime_root.dart:2473-2491`, `lib/src/runtime/runtime_root.dart:3732-3741`).
- **Evidence consequence**: a preparation failure occurs before the runtime cleanup boundary. The ordering fixture expects no boundary events, unchanged document/state, and no actions after an unsuccessful preparation (`test/runtime/fixtures/load_document_ordering_fixture.dart:41-66`). The same fixture observes cleanup before the published state and observes the replacement only after publication (`test/runtime/fixtures/load_document_ordering_fixture.dart:322-368`, `test/runtime/fixtures/load_document_ordering_fixture.dart:400-425`).

### 3. Staged-load owner and consumption state

- **Location**: `lib/src/edit/staged_document_load.dart:18-48`.
- **Description**: `PreparedDocumentLoad` stores camera, background, palette, metadata, revision delta, optional committed-document/store-import payloads, an `Object` owner token, and `_isConsumed`. Its `document` getter always throws rather than materializing a public document projection.
- **Dependencies**: `LoadDocumentPipeline` owns a `DocumentStoreKernel`, optional `DiagnosticsHub`, and a newly allocated `Object` owner token (`lib/src/edit/staged_document_load.dart:55-70`). `prepareFromJson` creates a `StoreSchemaV1ImportBuilder`, imports schema v1 JSON into it, invokes kernel preparation, and creates `PreparedDocumentLoad` with the pipeline's owner token (`lib/src/edit/staged_document_load.dart:72-103`).
- **Data flow**: JSON -> schema v1 import sink -> `DocumentStoreKernel.prepareSchemaV1Import` -> `PreparedStoreDocumentImport` -> `PreparedDocumentLoad` -> `LoadDocumentPipeline.consume` (`lib/src/edit/staged_document_load.dart:72-103`, `lib/src/store/document_store_kernel.dart:728-741`, `lib/src/edit/staged_document_load.dart:105-127`).
- **Evidence consequence**: `consume` compares owner tokens with `identical`, checks `_isConsumed`, then either installs the prepared schema-v1 import or replaces the prepared committed document (`lib/src/edit/staged_document_load.dart:105-127`). The existing fixture proves that a different pipeline is rejected and that a second consume is rejected (`test/edit/fixtures/staged_document_load_success_failure_fixture.dart:53-77`, `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:95-108`).

### 4. Schema import accumulation and prepared import payload

- **Location**: `lib/src/store/schema_v1_store_import.dart:80-222`.
- **Description**: `StoreSchemaV1ImportBuilder` accumulates document, resource, family, layer, and order import state, along with started/ended/aborted flags. Its `prepare` consumes its subordinate builders, creates an `ElementRegistry` and `CommittedDocument`, and returns a prepared store import (`lib/src/store/schema_v1_store_import.dart:81-92`, `lib/src/store/schema_v1_store_import.dart:152-195`).
- **Dependencies**: resource, family, layer, and order builders retain mutable accumulators until their `consume` operations produce store tables/facts (`lib/src/store/resource_table.dart:734-760`, `lib/src/store/family_tables.dart:1564-1585`, `lib/src/store/layer_table.dart:277-325`, `lib/src/store/element_registry.dart:1088-1165`). The schema-v1 event contract supplies values such as `Offset`, `Size`, `Color`, `CanvasMetadata`, identifiers, and lists of stroke points (`lib/src/contracts/internal/schema_v1_import_events.dart:25-37`, `lib/src/contracts/internal/schema_v1_import_events.dart:93-208`, `lib/src/contracts/internal/schema_v1_import_events.dart:210-237`).
- **Data flow**: schema reader -> `IsolatedSchemaV1ImportSink` event methods -> `StoreSchemaV1ImportBuilder` accumulators -> store tables/registry -> `CommittedDocument` -> `PreparedStoreDocumentImport` (`lib/src/contracts/internal/schema_v1_import_events.dart:10-23`, `lib/src/edit/staged_document_load.dart:72-84`, `lib/src/store/schema_v1_store_import.dart:152-195`).
- **Evidence consequence**: the builder's event wrapper accepts an operation closure only as a call argument and does not store it as a builder field (`lib/src/store/schema_v1_store_import.dart:214-222`). The repository's use of the word "isolated" in `IsolatedSchemaV1ImportSink` identifies an abortable partial-import protocol; it does not import `dart:isolate` (`lib/src/contracts/internal/schema_v1_import_events.dart:19-23`).

### 5. Prepared store import and store-owned mutable state

- **Location**: `lib/src/store/schema_v1_store_import.dart:225-258`.
- **Description**: `PreparedStoreDocumentImport` stores `baseRevisions`, `document`, `revisionDelta`, and `_isConsumed`; `consume` checks single consumption and equality with the current revisions before setting `_isConsumed`.
- **Dependencies**: `CommittedDocument.fromStoreTables` receives camera, background, palette, element registry, metadata, resource table, and accepted revisions; `CommittedDocument` retains these as final fields (`lib/src/store/committed_document.dart:116-134`, `lib/src/store/committed_document.dart:174-180`). `RevisionState` contains eight final integer revision values, while `StoreRevisionDelta` contains eight final boolean flags and produces a new revision state in `advance` (`lib/src/store/revision_state.dart:1-20`, `lib/src/store/store_revision_delta.dart:7-17`, `lib/src/store/store_revision_delta.dart:73-111`).
- **Data flow**: current store revisions + builder + replacement delta -> prepared import -> `prepared.consume(current revisions)` -> store's `_document` replacement and ID-admission reset (`lib/src/store/document_store_kernel.dart:728-741`, `lib/src/store/document_store_kernel.dart:794-801`, `lib/src/store/document_store_kernel.dart:154-167`).
- **Evidence consequence**: `DocumentStoreKernel` owns mutable `_document` state (`lib/src/store/document_store_kernel.dart:177-181`); `PreparedStoreDocumentImport` does not declare a kernel, diagnostics, or callback field (`lib/src/store/schema_v1_store_import.dart:225-258`). Summary and sparse-candidate observers are Zone-scoped for the duration of observer operations rather than retained prepared-object fields (`lib/src/store/schema_v1_store_import.dart:18-23`, `lib/src/store/schema_v1_store_import.dart:238-244`, `lib/src/store/committed_document.dart:158-172`).

### 6. Existing isolate usage and coverage

- **Location**: `test/api/fixtures/vm_retention_connection.dart:2-17`.
- **Description**: the VM-retention test fixture imports `dart:isolate` as `dart_isolate` and passes `dart_isolate.Isolate.current` to the VM service.
- **Dependencies**: a guardrail test contains a string fixture with `import 'dart:isolate';`; it is test source content rather than a production import (`test/guardrails/import_boundaries_test.dart:496`).
- **Data flow**: VM service information -> current isolate identifier -> retention service connection (`test/api/fixtures/vm_retention_connection.dart:12-28`).
- **Evidence consequence**: repository-wide searches found no `Isolate.run` occurrence and no `dart:isolate` import under `lib/`. No inspected test sends `PreparedDocumentLoad`, `PreparedStoreDocumentImport`, or `CommittedDocument` across an isolate boundary.

### 7. Public API and external consumer compilation

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:147-151`.
- **Description**: `CanvasEditPort` owns the public interface declaration; `docs/contracts/public_api_v1.md:45-65` owns public member signatures and semantics.
- **Dependencies**: Root-barrel access reaches the existing type through `lib/iwb_canvas_engine.dart:15` and `lib/src/api/canvas_runtime.dart:21`. The public YAML registry inventories exported type names, not members (`docs/_registry/public_api_v1.yaml:47-52`, `tool/guardrails/src/public_api_registry.dart:17-36`).
- **Evidence consequence**: the external compile fixture has a concrete `CanvasEditPort` implementer at `test/api_contract/public_api_v1_compiles_as_written_test.dart:1056-1065`. No member-level registry or root-barrel export location exists for an additional member (`lib/iwb_canvas_engine.dart:1-19`, `docs/_registry/public_api_v1.yaml:3-130`).
- **Evidence consequence**: the public API contract and its guardrail reject `FutureOr` and nullable asynchronous/container return forms but do not reject `Future<T>` (`docs/contracts/public_api_v1.md:150-163`, `tool/guardrails/src/public_api_contract_checks.dart:93-160`). The existing external integration fixture calls only the synchronous load route (`test/api_contract/fixtures/public_integration_compile_fixture.dart:57-104`, `test/api_contract/public_integration_compile_fixture_test.dart:41-68`).

### 8. Diagnostics, runtime lifecycle, and final candidate validation

- **Location**: `lib/src/runtime/runtime_root.dart:216-266`.
- **Description**: Runtime construction retains one policy-derived `DiagnosticsHub?` and supplies it to `LoadDocumentPipeline`. The pipeline forwards it to the emitter and records/rethrows store-preparation `CanvasDataException`s (`lib/src/edit/staged_document_load.dart:55-90`, `lib/src/codec/schema_v1_import_emitter.dart:8-42`).
- **Dependencies**: the diagnostic helper records the existing error code and returns the same exception (`lib/src/codec/schema_v1_diagnostics.dart:5-35`); the reader maps raw JSON failures to `CanvasDataException` before recording (`lib/src/codec/schema_v1_reader.dart:359-403`).
- **Data flow**: reader/store failure -> codec diagnostic record -> unchanged `CanvasDataException` -> caller (`lib/src/codec/schema_v1_diagnostics.dart:19-35`, `lib/src/contracts/public/canvas_errors.dart:5-55`).
- **Evidence consequence**: `RuntimeRoot` has separate disposed, delivery, installation, and resolver flags, and the mutation guard rejects an active installation (`lib/src/runtime/runtime_root.dart:333-336`, `lib/src/runtime/runtime_root.dart:1935-1978`). Current tests exercise reentrant operations while cleanup/delivery runs, but no load method has an await point and no test covers overlapping async loads, disposal during a pending load, cancellation, or completion timing (`test/runtime/fixtures/load_document_ordering_fixture.dart:98-170`, `test/runtime/fixtures/load_document_ordering_fixture.dart:338-425`).
- **Evidence consequence**: edit callbacks reject `Future<Object?>` results, and the synchronous external load route is rejected while an edit session is open (`lib/src/edit/edit_kernel.dart:86-119`, `lib/src/edit/edit_kernel.dart:372-390`, `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart:24-27`, `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart:247-272`). `dispose` explicitly rejects execution during document-load installation (`lib/src/runtime/runtime_root.dart:1701-1732`).
- **Location**: `lib/src/store/document_store_kernel.dart:728-741`.
- **Description**: kernel preparation supplies current revisions to the builder, then validates final resource relationships. The validator classifies absent and wrong-kind resources (`lib/src/store/document_store_kernel.dart:2897-2996`); the same validation is used by other full-document routes (`lib/src/store/document_store_kernel.dart:140`, `lib/src/store/document_store_kernel.dart:693-748`).
- **Evidence consequence**: installation performs the prepared import's stale-revision and single-consume checks before document replacement (`lib/src/store/document_store_kernel.dart:794-801`, `lib/src/store/schema_v1_store_import.dart:248-258`). Direct fixtures cover stale preparation, repeat installation, resource relationship errors, and failure-without-store-change (`test/store/fixtures/schema_v1_store_import_fixture.dart:352-391`, `test/store/fixtures/schema_v1_store_import_fixture.dart:464-573`).

### 9. Test, guardrail, documentation, and diagram owners

- **Location**: `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:15-36`.
- **Description**: the staged-load test owner covers direct preparation/consume, foreign-pipeline rejection, failure preservation, resource errors, and diagnostics. Runtime ordering, publication, and interaction cleanup have distinct owners at `test/runtime/fixtures/load_document_ordering_fixture.dart:13-36`, `test/runtime/fixtures/load_document_state_publication_fixture.dart:14-37`, and `test/runtime/fixtures/load_interaction_cleanup_fixture.dart:12-78`.
- **Dependencies**: public root-barrel compilation invokes the existing load route at `test/api_contract/fixtures/public_integration_compile_fixture.dart:57-104`; public API declaration compilation is exercised by `test/api_contract/public_api_v1_compiles_as_written_test.dart:248-275`.
- **Evidence consequence**: guardrails prohibit public `CanvasDocument` load input and public internal load types (`test/api_contract/no_unapproved_document_load_inputs_test.dart:1-212`, `test/api_contract/no_public_internal_load_types_test.dart:8-48`, `tool/guardrails/src/public_api_checks.dart:65-116`, `tool/guardrails/src/guardrail_registry.dart:45-51`). No current test transfers any prepared graph through an isolate.
- **Location**: `docs/contracts/load_document.md:27-134`.
- **Description**: the active load contract owns load ordering and failure semantics. Schema/codec contracts own wire and reader/import facts (`docs/contracts/schema_v1.md:31-35`, `docs/contracts/schema_v1.md:85-91`, `docs/contracts/codec_boundary.md:31-94`); the operation matrix owns load rows (`docs/contracts/operation_matrix.md:40-45`, `docs/contracts/operation_matrix.md:75-76`); the diagnostics contract specifies unchanged codec exceptions and no separate staged-load store/runtime diagnostic writer (`docs/contracts/diagnostics.md:77-78`).
- **Dependencies**: active semantic diagrams encode the same flow (`docs/diagrams/dfd_load_document_success_failure.mmd:6-74`, `docs/diagrams/seq_load_document_success.mmd:21-61`, `docs/diagrams/seq_load_document_failure.mmd:19-54`, `docs/diagrams/dfd_schema_v1_import_encode.mmd:9-102`, `docs/diagrams/seq_schema_v1_import_encode_order.mmd:16-99`) and are registered in `docs/_registry/diagrams.yaml:61-69`, `docs/_registry/diagrams.yaml:107-126`, and `docs/_registry/diagrams.yaml:207-224`.
- **Dependencies**: architecture assigns codec, store, runtime, and public API ownership (`docs/architecture/01_runtime_ownership.md:53-73`), and the graph records the load-pipeline owner and required pipeline-to-store boundary (`docs/architecture/architecture_graph.yaml:219-224`, `docs/architecture/architecture_graph.yaml:613-624`).
- **Evidence consequence**: verification documentation names staged, state-publication, public smoke, load guardrail, and release-gate owners (`docs/verification/tests.md:446-449`, `docs/verification/tests.md:662-667`, `docs/verification/tests.md:732-736`, `docs/verification/guardrails.md:169-175`, `docs/verification/guardrails.md:205-206`, `docs/verification/release_gates.md:19-32`, `docs/verification/release_gates.md:54-55`, `docs/verification/release_gates.md:115-138`). Generated documentation catalog/index output is managed by `docs/tool/sync_generated_docs.dart:5-20`; structural documentation checks invoke its check mode (`docs/tool/check_docs.dart:376-389`).

### 10. Isolate infrastructure

- **Location**: `pubspec.yaml:6-26`.
- **Description**: package constraints are Dart `^3.10.4` and Flutter `>=3.38.0`; test dependencies include `flutter_test`, `test`, and `vm_service`. CI runs Flutter tests serially and has separate VM-service evidence commands (`.github/workflows/root_package.yml:41-48`).
- **Dependencies**: executable `dart:isolate` use is limited to the VM-service fixture reading `Isolate.current` (`test/api/fixtures/vm_retention_connection.dart:1-28`); widget tests have existing `WidgetTester.runAsync` usage (`test/api/vector_preparation_context_test.dart:21-123`).
- **Evidence consequence**: searches found no `Isolate.run`, spawn, port, transferable-data, `compute`, or multiprocess implementation.

### 11. Confirmed implementation-owner map for the stated deliverables

The following production owners are the exact source files that contain the seams named in the stated deliverables:

- `lib/src/contracts/public/canvas_runtime.dart:147-151` — the public `CanvasEditPort` member declaration.
- `lib/src/edit/edit_kernel.dart:43` and `lib/src/edit/edit_kernel.dart:372-390` — `DocumentLoadInstaller` and the sole production implementation of the edit port's JSON-load method.
- `lib/src/runtime/runtime_root.dart:353-364` and `lib/src/runtime/runtime_root.dart:2239-2258` — installer wiring and runtime load orchestration, including the existing prepare/cleanup/consume/delivery order.
- `lib/src/edit/staged_document_load.dart:18-42`, `lib/src/edit/staged_document_load.dart:55-127` — prepared-load payload, owner-token check, codec-to-builder preparation, and consume entry.
- `lib/src/store/document_store_kernel.dart:728-741` and `lib/src/store/document_store_kernel.dart:794-801` — the current coupling of builder preparation to revision capture and final relationship validation, followed by prepared installation.

The following existing source files are consumed by that route but do not contain a required new seam for the stated deliverables: the codec reader/emitter already accepts a sink (`lib/src/codec/schema_v1_import_emitter.dart:16-26`, `lib/src/codec/schema_v1_reader.dart:32-70`); the store builder already accepts supplied base revisions and a replacement delta (`lib/src/store/schema_v1_store_import.dart:152-195`); and the diagnostics helper already records an existing `CanvasDataException` without translating it (`lib/src/codec/schema_v1_diagnostics.dart:5-35`).

The direct test owners for the stated public method, background preparation, store preparation, and runtime behavior are:

- `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:15-36` — prepared-load token, consume-once, preparation failure, and diagnostics.
- `test/store/fixtures/schema_v1_store_import_fixture.dart:19-29`, `test/store/fixtures/schema_v1_store_import_fixture.dart:352-573` — stale prepared imports, final relationship validation, and store non-mutation on failure.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:13-36`, `test/runtime/fixtures/load_document_ordering_fixture.dart:98-425` — ordering, reentrancy, and delivery guards.
- `test/runtime/fixtures/load_document_state_publication_fixture.dart:14-37`, `test/runtime/fixtures/load_document_state_publication_fixture.dart:273-419` — state, revision, camera, effect, and failure facts.
- `test/runtime/fixtures/load_interaction_cleanup_fixture.dart:12-78`, `test/runtime/fixtures/load_interaction_cleanup_fixture.dart:84-217` — prepared cleanup and unchanged failed-load interaction state.
- `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart:24-27`, `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart:247-272` — rejected asynchronous edit callbacks and rejected load inside an edit session.
- `test/runtime/dispose_lifecycle_test.dart:31` — runtime disposal lifecycle.
- `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart:192-251` — runtime load diagnostics and action ordering.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:550`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:1056-1065` — root-barrel call and external interface implementer.
- `test/api_contract/fixtures/public_integration_compile_fixture.dart:57-104`, `test/api_contract/public_integration_compile_fixture_test.dart:41-68`, and `test/smoke/public_incremental_smoke_test.dart:37` — external integration compile and public runtime smoke coverage.

No separate new test file is structurally required: the existing staged-load fixture is the nearest owner for an isolate transfer witness, and the existing runtime fixtures are the nearest owners for asynchronous public behavior.

## Code References

- `lib/src/contracts/public/canvas_runtime.dart:147` - public synchronous JSON-load declaration.
- `lib/src/edit/edit_kernel.dart:372` - edit port runtime-mutation/session checks and installer call.
- `lib/src/runtime/runtime_root.dart:2239` - runtime staged-load orchestration.
- `lib/src/edit/staged_document_load.dart:72` - JSON preparation pipeline.
- `lib/src/edit/staged_document_load.dart:105` - owner and consume-once checks.
- `lib/src/store/schema_v1_store_import.dart:152` - prepared store-import construction.
- `lib/src/store/schema_v1_store_import.dart:225` - prepared store-import fields and revision check.
- `lib/src/store/document_store_kernel.dart:728` - store preparation boundary.
- `lib/src/store/document_store_kernel.dart:794` - store installation boundary.
- `docs/contracts/load_document.md:60` - documented success ordering for schema-v1 load.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:41` - preparation-failure ordering witness.

## Search Coverage

- **Inspected**: public contracts/facade/root barrel; EditKernel, RuntimeRoot, staged load, codec diagnostics/emitter/reader, store preparation/install/relationship validation and transitive prepared-import owners; active load/schema/codec/operation documentation, architecture graph, registered diagrams, registries, documentation tools, package/test/CI configuration; all named staged-load, runtime lifecycle, direct store, public compile, and guardrail fixtures.
- **Searched**: repository-wide `loadDocumentFromJson`, `loadDocumentFromJsonAsync`, `prepareFromJson`, `PreparedDocumentLoad`, `PreparedStoreDocumentImport`, `StoreSchemaV1ImportBuilder`, owner-token symbols, `Isolate.run`, `dart:isolate`, spawning/port/transfer APIs, and public API registry/guardrail contracts. Active documentation was searched separately from `docs/history/**`.
- **Not found**: a public async/Future JSON-load declaration; production `lib/` use of `dart:isolate`; `Isolate.run`, spawn, port, transferable-data, `compute`, or multiprocess code; an isolate transfer witness for the prepared load graph; an existing async load ordering/concurrency/disposal/cancellation contract or fixture; a member-level public-export registry entry.
- **Not inspected**: unrelated rendering or resource-resolution code beyond types reached from the prepared document graph. This research did not execute a secondary-isolate experiment or inspect external Dart/Flutter runtime implementation documentation.

## Observed Architecture Facts

- **Pattern observed**: staged JSON load separates fallible preparation from runtime installation. Preparation completes before prepared interaction cleanup and store installation (`lib/src/runtime/runtime_root.dart:2239-2258`, `docs/contracts/load_document.md:60-86`).
- **Pattern observed**: the prepared load has two protections: pipeline-owner identity and single consumption (`lib/src/edit/staged_document_load.dart:64`, `lib/src/edit/staged_document_load.dart:105-114`). The prepared store import separately checks its base revisions at installation (`lib/src/store/schema_v1_store_import.dart:248-258`).
- **Data flow**: JSON -> schema-v1 reader/import sink -> store builder -> prepared store import -> prepared document load -> runtime interaction cleanup -> store installation -> state/effect delivery (`lib/src/edit/staged_document_load.dart:72-103`, `lib/src/runtime/runtime_root.dart:2239-2258`, `lib/src/runtime/runtime_root.dart:2473-2491`).
- **Key dependencies**: schema import events use contract/public value types (`lib/src/contracts/internal/schema_v1_import_events.dart:1-8`); store preparation constructs store-owned tables and a committed aggregate (`lib/src/store/schema_v1_store_import.dart:167-195`); installation is performed by `DocumentStoreKernel` (`lib/src/store/document_store_kernel.dart:794-801`).

## Open Questions

None within the inspected repository scope.
