---
date: 2026-05-26
researcher: Codex
commit: 3738e250
branch: new-architecture
research_question: "Map the current loadDocument ordering around staged preparation, interaction cleanup, document replacement, state publication, and guardrail coverage."
---

# Research: loadDocument interaction cleanup

## Summary

The current public `loadDocument` path enters through `CanvasEditPort`, is routed by `EditKernel`, and reaches `RuntimeRoot._loadDocument` only after the runtime-active and no-open-edit-session checks pass (`lib/src/edit/edit_kernel.dart:83`, `lib/src/edit/edit_kernel.dart:90`, `lib/src/runtime/runtime_root.dart:112`). Inside `RuntimeRoot`, the code prepares a `PreparedDocumentLoad`, interrupts the load interaction boundary, consumes the prepared replacement into the store, clears selection, initializes runtime camera and epoch facts, calls `clearPostInstallFacts`, and then publishes state plus effects (`lib/src/runtime/runtime_root.dart:373`, `lib/src/runtime/runtime_root.dart:383`).

The staged load pipeline validates and materializes the incoming `CanvasDocument` before store mutation. `LoadDocumentPipeline.prepare` builds a `ValidatedImportDraft`, returns prepared document/id/revision facts, and `consume` enforces pipeline ownership plus one-shot consumption before calling `DocumentStoreKernel.replaceDocument` (`lib/src/edit/staged_document_load.dart:54`, `lib/src/edit/staged_document_load.dart:81`). Store replacement advances the replacement revision delta and resets id admission for element, layer, and resource ids (`lib/src/store/document_store_kernel.dart:138`, `lib/src/store/document_store_kernel.dart:154`).

The docs and tests both describe success/failure ordering around preparation and public publication, while naming interaction cleanup at different levels of detail. The contract says success includes prepared-load interaction cleanup, install plus selection clear, pointer normalization and pending tap history cleanup, and one post-install state publication (`docs/contracts/load_document.md:61`, `docs/contracts/load_document.md:78`). The runtime ordering fixture currently records the concrete injected boundary order as `interrupt`, `post-install-cleanup`, `state`, `observer`, with interrupt seeing the old document and post-install cleanup seeing the replacement (`test/runtime/fixtures/load_document_ordering_fixture.dart:57`, `test/runtime/fixtures/load_document_ordering_fixture.dart:68`).

## Detailed Findings

### 1. Public Entry and Runtime Orchestration

- **Location**: primary `lib/src/runtime/runtime_root.dart:373`; additional references `lib/src/edit/edit_kernel.dart:83`, `lib/src/edit/edit_kernel.dart:90`, `lib/src/runtime/runtime_root.dart:102`, `lib/src/runtime/runtime_root.dart:112`.
- **Description**: `EditKernel.loadDocument` checks runtime activity, rejects calls while an edit session is open, and then invokes the document-load installer callback (`lib/src/edit/edit_kernel.dart:83`, `lib/src/edit/edit_kernel.dart:90`). `RuntimeRoot` wires that installer to `_loadDocument` when it constructs `EditKernel` (`lib/src/runtime/runtime_root.dart:102`, `lib/src/runtime/runtime_root.dart:112`).
- **Dependencies**: The entry path uses `CanvasEditPort`, `EditKernel`, `LoadDocumentPipeline`, `LoadInteractionBoundary`, `SelectionKernel`, `DocumentStoreKernel`, and the commit-effect observer (`lib/src/edit/edit_kernel.dart:3`, `lib/src/edit/edit_kernel.dart:5`, `lib/src/runtime/runtime_root.dart:18`, `lib/src/runtime/runtime_root.dart:20`, `lib/src/runtime/runtime_root.dart:21`, `lib/src/runtime/runtime_root.dart:89`).
- **Data flow**: `CanvasDocument` input -> `EditKernel.loadDocument` precondition checks -> `RuntimeRoot._loadDocument` orchestration -> store/selection/camera/revision updates plus state/effect delivery (`lib/src/edit/edit_kernel.dart:83`, `lib/src/runtime/runtime_root.dart:373`, `lib/src/runtime/runtime_root.dart:383`).

### 2. Current Runtime Success Order

- **Location**: primary `lib/src/runtime/runtime_root.dart:373`; additional references `lib/src/runtime/runtime_root.dart:376`, `lib/src/runtime/runtime_root.dart:377`, `lib/src/runtime/runtime_root.dart:382`, `lib/src/runtime/runtime_root.dart:418`.
- **Description**: `_loadDocument` calls `_loadPipeline.prepare(document)` first, then `_loadInteractionBoundary.interruptPreparedLoad()`, then `_loadPipeline.consume(preparedLoad)`, then `_selection.clearForDocumentReplacement()`, then assigns `_viewCamera` from the prepared document, increments `_viewCameraRevision`, increments `_epochRevision`, calls `_loadInteractionBoundary.clearPostInstallFacts()`, and finally calls `_deliverLoadResult(...)` (`lib/src/runtime/runtime_root.dart:373`, `lib/src/runtime/runtime_root.dart:383`).
- **Dependencies**: The interaction seam is `LoadInteractionBoundary` with `interruptPreparedLoad` and `clearPostInstallFacts`; the production boundary is `_NoopLoadInteractionBoundary`, while `RuntimeRoot.test` accepts an injected boundary (`lib/src/runtime/runtime_root.dart:49`, `lib/src/runtime/runtime_root.dart:53`, `lib/src/runtime/runtime_root.dart:487`, `lib/src/runtime/runtime_root.dart:499`).
- **Data flow**: prepared load -> interaction interrupt -> store replacement -> selection clear -> camera/epoch facts -> post-install facts cleanup -> state publication and observer effects (`lib/src/runtime/runtime_root.dart:374`, `lib/src/runtime/runtime_root.dart:376`, `lib/src/runtime/runtime_root.dart:377`, `lib/src/runtime/runtime_root.dart:378`, `lib/src/runtime/runtime_root.dart:379`, `lib/src/runtime/runtime_root.dart:381`, `lib/src/runtime/runtime_root.dart:382`, `lib/src/runtime/runtime_root.dart:383`).

### 3. Staged Preparation and Store Replacement

- **Location**: primary `lib/src/edit/staged_document_load.dart:54`; additional references `lib/src/edit/staged_document_load.dart:70`, `lib/src/edit/staged_document_load.dart:98`, `lib/src/store/document_store_kernel.dart:138`.
- **Description**: `LoadDocumentPipeline.prepare` converts the input document through `ValidatedImportDraft.fromDocument`, then creates `PreparedDocumentLoad` with the validated document, resource ids, layer ids, element ids, replacement revision delta, and the pipeline owner token (`lib/src/edit/staged_document_load.dart:54`, `lib/src/edit/staged_document_load.dart:66`). `consume` rejects loads from another pipeline, rejects an already consumed load, marks the load consumed, and calls `_store.replaceDocument(load.document, load.revisionDelta)` (`lib/src/edit/staged_document_load.dart:70`, `lib/src/edit/staged_document_load.dart:81`).
- **Dependencies**: The pipeline depends on `ValidatedImportDraft`, optional diagnostics, `DocumentStoreKernel`, and `StoreRevisionDelta` (`lib/src/edit/staged_document_load.dart:4`, `lib/src/edit/staged_document_load.dart:5`, `lib/src/edit/staged_document_load.dart:6`, `lib/src/edit/staged_document_load.dart:7`).
- **Data flow**: public DTO -> validated import draft -> prepared replacement payload -> owner/one-shot checks -> `DocumentStoreKernel.replaceDocument` (`lib/src/edit/staged_document_load.dart:55`, `lib/src/edit/staged_document_load.dart:60`, `lib/src/edit/staged_document_load.dart:70`, `lib/src/edit/staged_document_load.dart:81`).

### 4. Selection, Camera, Revisions, and Load Effects

- **Location**: primary `lib/src/runtime/runtime_root.dart:378`; additional references `lib/src/selection/selection_kernel.dart:54`, `lib/src/runtime/runtime_root.dart:436`, `lib/src/runtime/runtime_root.dart:456`.
- **Description**: `RuntimeRoot._loadDocument` clears selection after store consumption and before state publication (`lib/src/runtime/runtime_root.dart:377`, `lib/src/runtime/runtime_root.dart:378`). `SelectionKernel.clearForDocumentReplacement` clears selected ids, increments `_selectionRevision`, and returns `true` (`lib/src/selection/selection_kernel.dart:54`, `lib/src/selection/selection_kernel.dart:58`). Runtime state publication includes store document revision, selection revision, preview revision, view camera revision, and epoch revision (`lib/src/runtime/runtime_root.dart:456`, `lib/src/runtime/runtime_root.dart:464`).
- **Dependencies**: `_loadEffects` creates an unmodifiable list with projection, spatial, resource, repaint, conditional selection, and public-state effects (`lib/src/runtime/runtime_root.dart:436`, `lib/src/runtime/runtime_root.dart:444`).
- **Data flow**: replacement store facts and selection facts -> `_runtimeState` snapshot -> `ValueNotifier` state update -> optional commit-effect observer delivery (`lib/src/runtime/runtime_root.dart:361`, `lib/src/runtime/runtime_root.dart:421`, `lib/src/runtime/runtime_root.dart:423`).

### 5. Failure Behavior Verified by Tests

- **Location**: primary `test/runtime/fixtures/load_document_ordering_fixture.dart:18`; additional references `test/runtime/fixtures/load_document_state_publication_fixture.dart:49`, `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:73`.
- **Description**: The ordering fixture verifies a duplicate-element load throws `CanvasDataException.duplicateElementId`, produces no load-boundary events, keeps the old document id, and leaves runtime state equal to the captured state (`test/runtime/fixtures/load_document_ordering_fixture.dart:23`, `test/runtime/fixtures/load_document_ordering_fixture.dart:36`). The state-publication fixture verifies failed duplicate-element load publishes no snapshots, records no effect batches, preserves captured state/document/selection facts, preserves camera offset, and leaves generated element id at `e0` (`test/runtime/fixtures/load_document_state_publication_fixture.dart:61`, `test/runtime/fixtures/load_document_state_publication_fixture.dart:67`).
- **Dependencies**: Staged-load tests cover duplicate resources, duplicate layers, duplicate elements, missing resource references, invalid metadata, and non-invertible transforms before store changes (`test/edit/fixtures/staged_document_load_success_failure_fixture.dart:73`, `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:161`).
- **Data flow**: invalid document input -> staged validation exception -> no interaction event/store replacement/state publication/effect batch in the tested paths (`test/runtime/fixtures/load_document_ordering_fixture.dart:34`, `test/runtime/fixtures/load_document_state_publication_fixture.dart:63`, `test/runtime/fixtures/load_document_state_publication_fixture.dart:64`).

### 6. Documentation and Guardrail Coverage

- **Location**: primary `docs/contracts/load_document.md:34`; additional references `docs/diagrams/seq_load_document_success.mmd:43`, `docs/diagrams/dfd_load_document_success_failure.mmd:70`, `docs/verification/guardrails.md:194`.
- **Description**: The `loadDocument` contract states that `RuntimeRoot` owns atomic cross-owner replacement once validation/materialization succeeds, including document installation and selection clearing before public state notification (`docs/contracts/load_document.md:36`, `docs/contracts/load_document.md:43`). Its success list places validation and materialization before success-only interaction interrupt, then preview clear, document install plus selection clear, camera initialization, revision increments, pointer normalization and pending tap history clear, cache invalidation, repaint, and one state publication (`docs/contracts/load_document.md:64`, `docs/contracts/load_document.md:78`).
- **Dependencies**: The sequence diagram shows prepared-load interaction cleanup before install, post-install pending input cleanup, cache/resource/frame effects, repaint scheduling, and one state publication (`docs/diagrams/seq_load_document_success.mmd:43`, `docs/diagrams/seq_load_document_success.mmd:72`). The DFD labels `Post-install input cleanup` after `AtomicRuntimeResult` and pending input clear after atomic install (`docs/diagrams/dfd_load_document_success_failure.mmd:81`, `docs/diagrams/dfd_load_document_success_failure.mmd:82`).
- **Data flow**: documented success path is public API -> staged validation/materialization -> interaction cleanup -> atomic install/selection clear -> runtime result/effects -> public state (`docs/diagrams/dfd_load_document_success_failure.mmd:53`, `docs/diagrams/dfd_load_document_success_failure.mmd:93`).

## Code References

- `lib/src/edit/edit_kernel.dart:83` - `EditKernel.loadDocument` starts the public load precondition path.
- `lib/src/edit/edit_kernel.dart:90` - `EditKernel.loadDocument` delegates to the installed document-load callback.
- `lib/src/runtime/runtime_root.dart:112` - `RuntimeRoot` wires `installLoadedDocument` to `_loadDocument`.
- `lib/src/runtime/runtime_root.dart:373` - `_loadDocument` begins runtime orchestration.
- `lib/src/runtime/runtime_root.dart:376` - success path calls `interruptPreparedLoad`.
- `lib/src/runtime/runtime_root.dart:377` - success path consumes the prepared replacement into the store.
- `lib/src/runtime/runtime_root.dart:378` - success path clears selection for document replacement.
- `lib/src/runtime/runtime_root.dart:382` - success path calls `clearPostInstallFacts`.
- `lib/src/runtime/runtime_root.dart:383` - success path delivers load result after cleanup.
- `lib/src/runtime/runtime_root.dart:418` - `_deliverLoadResult` starts state/effect delivery.
- `lib/src/runtime/runtime_root.dart:421` - load delivery publishes runtime state.
- `lib/src/runtime/runtime_root.dart:423` - load delivery invokes the commit-effect observer when effects exist.
- `lib/src/runtime/runtime_root.dart:436` - `_loadEffects` constructs load effects.
- `lib/src/runtime/runtime_root.dart:487` - `LoadInteractionBoundary` declares the interaction seam.
- `lib/src/edit/staged_document_load.dart:54` - `LoadDocumentPipeline.prepare` starts staged validation/materialization.
- `lib/src/edit/staged_document_load.dart:70` - `LoadDocumentPipeline.consume` starts owner/one-shot checks.
- `lib/src/edit/staged_document_load.dart:81` - successful consume calls store replacement.
- `lib/src/edit/staged_document_load.dart:98` - replacement revision delta turns on all document-level replacement flags.
- `lib/src/store/document_store_kernel.dart:138` - `replaceDocument` starts store replacement.
- `lib/src/selection/selection_kernel.dart:54` - `clearForDocumentReplacement` clears selection and increments revision.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:57` - ordering fixture expects `interrupt`, `post-install-cleanup`, `state`, `observer`.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:63` - interrupt callback observes the old document.
- `test/runtime/fixtures/load_document_ordering_fixture.dart:68` - post-install cleanup callback observes the replacement document.
- `test/runtime/fixtures/load_document_state_publication_fixture.dart:33` - state-publication fixture expects one load snapshot.
- `test/runtime/fixtures/load_document_state_publication_fixture.dart:63` - failure fixture expects no snapshots.
- `docs/contracts/load_document.md:64` - contract success ordering begins with validation.
- `docs/contracts/load_document.md:75` - contract success ordering includes pointer normalization and pending tap history cleanup.
- `docs/diagrams/seq_load_document_success.mmd:49` - sequence diagram says public state waits until committed replacement is installed.
- `docs/diagrams/dfd_load_document_success_failure.mmd:81` - DFD places post-install input cleanup after atomic runtime result.

## Observed Architecture Facts

- Pattern observed: staged public load separates validation/materialization from store consumption; `prepare` returns a `PreparedDocumentLoad`, and `consume` performs owner and one-shot checks before replacing the store (`lib/src/edit/staged_document_load.dart:54`, `lib/src/edit/staged_document_load.dart:81`).
- Pattern observed: public load failure before prepared-load success is tested as no interaction-boundary event, no document replacement, and no state publication (`test/runtime/fixtures/load_document_ordering_fixture.dart:34`, `test/runtime/fixtures/load_document_state_publication_fixture.dart:63`).
- Pattern observed: runtime load success publishes state through `_deliverLoadResult`, and `_deliverLoadResult` sets `_isDeliveringCommitEffects` while publishing state and invoking the observer (`lib/src/runtime/runtime_root.dart:418`, `lib/src/runtime/runtime_root.dart:429`).
- Data flow: public `loadDocument` -> `EditKernel.loadDocument` -> `RuntimeRoot._loadDocument` -> `LoadDocumentPipeline.prepare` -> `LoadInteractionBoundary.interruptPreparedLoad` -> `LoadDocumentPipeline.consume` -> selection/camera/epoch updates -> `LoadInteractionBoundary.clearPostInstallFacts` -> state/effect delivery (`lib/src/edit/edit_kernel.dart:83`, `lib/src/runtime/runtime_root.dart:373`, `lib/src/runtime/runtime_root.dart:383`).
- Data flow: invalid public document -> `ValidatedImportDraft.fromDocument` failure -> exception path before runtime interaction or store replacement in the tested load path (`lib/src/edit/staged_document_load.dart:55`, `test/runtime/fixtures/load_document_ordering_fixture.dart:34`).
- Key dependencies: load orchestration depends on `LoadDocumentPipeline`, `LoadInteractionBoundary`, `SelectionKernel`, `DocumentStoreKernel`, and `CommitEffectObserver` at `RuntimeRoot` (`lib/src/runtime/runtime_root.dart:78`, `lib/src/runtime/runtime_root.dart:89`).
- Documentation fact: the contract and diagrams describe prepared-load interaction cleanup before public state publication, and the DFD also names a `Post-install input cleanup` node after `AtomicRuntimeResult` (`docs/contracts/load_document.md:49`, `docs/contracts/load_document.md:78`, `docs/diagrams/dfd_load_document_success_failure.mmd:81`).

## Open Questions

- The current research identified the `LoadInteractionBoundary` seam and tests that inject it, but did not identify a production implementation beyond `_NoopLoadInteractionBoundary` in `RuntimeRoot` (`lib/src/runtime/runtime_root.dart:44`, `lib/src/runtime/runtime_root.dart:492`).
- The docs mention `PointerCleanupOutcome` and `InteractionEngine` load cleanup behavior (`docs/diagrams/seq_load_document_success.mmd:45`, `docs/contracts/load_document.md:50`), while the current runtime seam exposes `void interruptPreparedLoad()` and `void clearPostInstallFacts()` (`lib/src/runtime/runtime_root.dart:487`, `lib/src/runtime/runtime_root.dart:489`).
- The DFD names failure-preserved pending input as pointer normalization plus pending tap history, while the contract failure list separately names pending line and pointer normalization (`docs/diagrams/dfd_load_document_success_failure.mmd:21`, `docs/contracts/load_document.md:96`, `docs/contracts/load_document.md:97`).
