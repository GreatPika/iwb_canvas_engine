---
date: 2026-05-18
researcher: Codex
commit: eb3e245
branch: new-architecture
research_question: "Text edit request stale guard: add request identity, revision facts, and commitTextEdit semantics"
---

# Research: Text Edit Stale Guard

## Summary

The current root-package documentation describes text editing as an app-owned editor flow. The engine emits a `CanvasTextEditRequested` notification when a double-tap on a visible selectable text element is accepted, and the application later commits text changes through the normal `updateElement(CanvasTextElementUpdate)` edit path (`docs/contracts/public_api_v1.md:1857`, `docs/contracts/public_api_v1.md:1882`, `docs/contracts/public_api_v1.md:1886`).

The current public API contract does not include a text edit request id, request-carried epoch/revision facts, or `CanvasCommandPort.commitTextEdit(...)`. `CanvasTextEditRequested` currently carries `elementId`, `timestampMs`, `viewPosition`, `worldPosition`, `boundsWorld`, and `textSnapshot` (`docs/contracts/public_api_v1.md:1860`, `docs/contracts/public_api_v1.md:1875`), while `CanvasCommandPort` currently declares only `removeElement` and `clearContent` (`docs/contracts/public_api_v1.md:1228`, `docs/contracts/public_api_v1.md:1234`).

Existing stale guards are documented before request emission and inside the normal edit machinery. Pending text tap state stores generation and `controllerEpoch` and is revalidated before emitting the request (`docs/diagrams/state_pending_text_edit_request.mmd:39`, `docs/diagrams/state_pending_text_edit_request.mmd:46`, `docs/diagrams/state_pending_text_edit_request.mmd:73`). After emission, the current text model says the engine does not store an active text-input session and that load/dispose/tool-change behavior while editing is application responsibility (`docs/contracts/public_api_v1.md:1887`, `docs/contracts/public_api_v1.md:1889`).

## Detailed Findings

### 1. Public Text Edit API Surface

- **Location**: primary `docs/contracts/public_api_v1.md:1857`; registry at `docs/_registry/public_api_v1.yaml:84`.
- **Description**: `CanvasRuntime` exposes a `Stream<CanvasTextEditRequested>` as `textEditRequests` (`docs/contracts/public_api_v1.md:303`, `docs/contracts/public_api_v1.md:322`). The registry exports `CanvasTextEditRequested` as a public API name (`docs/_registry/public_api_v1.yaml:84`).
- **Dependencies**: The public contract owns API semantics and signatures, while the registry owns the machine-readable export inventory (`docs/contracts/public_api_v1.md:73`, `docs/contracts/public_api_v1.md:77`, `docs/contracts/public_api_v1.md:80`; `docs/_registry/public_api_v1.yaml:1`, `docs/_registry/public_api_v1.yaml:2`).
- **Data flow**: Runtime emits `CanvasTextEditRequested` -> application receives the stream event -> application owns the Flutter text editor overlay -> application commits changed text through `updateElement(CanvasTextElementUpdate)` (`docs/contracts/public_api_v1.md:1882`, `docs/contracts/public_api_v1.md:1884`, `docs/contracts/public_api_v1.md:1886`).

### 2. Current Request Payload and Commit Path

- **Location**: primary `docs/contracts/public_api_v1.md:1860`; commit path at `docs/contracts/public_api_v1.md:1155`.
- **Description**: The current `CanvasTextEditRequested` constructor requires `elementId`, `timestampMs`, `viewPosition`, `worldPosition`, `boundsWorld`, and `textSnapshot` (`docs/contracts/public_api_v1.md:1860`, `docs/contracts/public_api_v1.md:1868`). The current event fields match those constructor arguments (`docs/contracts/public_api_v1.md:1870`, `docs/contracts/public_api_v1.md:1875`).
- **Dependencies**: The text commit path uses `CanvasEdit.updateElement(CanvasElementUpdate update)` (`docs/contracts/public_api_v1.md:1155`, `docs/contracts/public_api_v1.md:1162`). `CanvasTextElementUpdate` contains a `text` field typed as `CanvasFieldUpdate<String>` (`docs/contracts/public_api_v1.md:1022`, `docs/contracts/public_api_v1.md:1034`, `docs/contracts/public_api_v1.md:1047`).
- **Data flow**: Application text change -> `CanvasTextElementUpdate` -> `CanvasEdit.updateElement` inside the normal edit path -> EditKernel compile/install/publication sequence (`docs/diagrams/seq_text_edit_request.mmd:70`, `docs/diagrams/seq_text_edit_request.mmd:71`; `docs/contracts/edit_kernel.md:65`, `docs/contracts/edit_kernel.md:83`).

### 3. Current Command Port Surface

- **Location**: primary `docs/contracts/public_api_v1.md:1220`.
- **Description**: High-level commands are public user-intent operations and use EditKernel for atomic mutation while owning user action event emission (`docs/contracts/public_api_v1.md:1220`, `docs/contracts/public_api_v1.md:1222`, `docs/contracts/public_api_v1.md:1223`). The current `CanvasCommandPort` declares `removeElement` and `clearContent` only (`docs/contracts/public_api_v1.md:1228`, `docs/contracts/public_api_v1.md:1234`).
- **Dependencies**: Command mutations must go through EditKernel and inherit rollback/stale/dispose checks (`docs/contracts/public_api_v1.md:1237`, `docs/contracts/public_api_v1.md:1240`). Command action payloads are emitted after atomic install (`docs/contracts/public_api_v1.md:1245`).
- **Data flow**: Command call -> EditKernel mutation -> atomic install -> optional command action payload after install (`docs/contracts/public_api_v1.md:1240`, `docs/contracts/public_api_v1.md:1245`, `docs/contracts/public_api_v1.md:1246`).

### 4. Text Double-Tap Request Lifecycle

- **Location**: primary `docs/contracts/interaction_engine.md:159`; sequence at `docs/diagrams/seq_text_edit_request.mmd:1`.
- **Description**: Double-tap on a visible selectable text element emits `CanvasTextEditRequested`, does not mutate the document, and does not select or deselect by itself (`docs/contracts/interaction_engine.md:159`, `docs/contracts/interaction_engine.md:161`).
- **Dependencies**: The sequence routes pointer input through `CanvasSurface`, `CanvasToolPort`, `InteractionEngine`, `InteractionReadPort`, `DocumentStoreKernel`, `SpatialKernel`, and `GeometryPolicy` before request emission (`docs/diagrams/seq_text_edit_request.mmd:6`, `docs/diagrams/seq_text_edit_request.mmd:13`).
- **Data flow**: Tap sample -> spatial hit candidates -> exact geometry hit -> immutable text facts -> pending candidate -> second tap revalidation -> stream event (`docs/diagrams/seq_text_edit_request.mmd:21`, `docs/diagrams/seq_text_edit_request.mmd:24`, `docs/diagrams/seq_text_edit_request.mmd:33`, `docs/diagrams/seq_text_edit_request.mmd:56`, `docs/diagrams/seq_text_edit_request.mmd:61`).

### 5. Existing Pre-Emission Stale Guards

- **Location**: primary `docs/diagrams/state_pending_text_edit_request.mmd:35`.
- **Description**: Pending text tap state stores element id, generation, view/world positions, timestamp, and `controllerEpoch`; it is input history only, not `CanvasPreviewState` and not Store state (`docs/diagrams/state_pending_text_edit_request.mmd:35`, `docs/diagrams/state_pending_text_edit_request.mmd:39`, `docs/diagrams/state_pending_text_edit_request.mmd:42`).
- **Dependencies**: Candidate cleanup occurs on delay exceeded, slop exceeded, invalid sample, no hit, mode mismatch, `controllerEpoch` mismatch, mode change, or `interactive=false` (`docs/diagrams/state_pending_text_edit_request.mmd:45`, `docs/diagrams/state_pending_text_edit_request.mmd:46`).
- **Data flow**: Pending candidate -> second tap gate -> current committed hit data -> candidate match gate -> request emission only when the same element remains visible, selectable, text, generation-current, and epoch-current (`docs/diagrams/state_pending_text_edit_request.mmd:51`, `docs/diagrams/state_pending_text_edit_request.mmd:58`, `docs/diagrams/state_pending_text_edit_request.mmd:71`, `docs/diagrams/state_pending_text_edit_request.mmd:73`, `docs/diagrams/state_pending_text_edit_request.mmd:79`).

### 6. Revision and Epoch Facts Relevant to Stale Detection

- **Location**: primary `docs/architecture/03_data_model.md:116`.
- **Description**: `documentRevision` means any committed document state change, and `controllerEpoch` means `loadDocument` success or full document replacement (`docs/architecture/03_data_model.md:119`, `docs/architecture/03_data_model.md:120`). `ElementHandle` stores `elementRevision`, `structuralRevision`, and `boundsRevision` (`docs/architecture/03_data_model.md:80`, `docs/architecture/03_data_model.md:92`, `docs/architecture/03_data_model.md:94`).
- **Dependencies**: Public `CanvasRuntimeRevisions` exposes `document` and `epoch`, but internal structural, bounds, element visual, projection, and resource descriptor revisions are not public API fields (`docs/contracts/public_api_v1.md:377`, `docs/contracts/public_api_v1.md:388`, `docs/contracts/public_api_v1.md:412`, `docs/contracts/public_api_v1.md:416`).
- **Data flow**: `loadDocument` success installs replacement document and clears selection in one runtime result, advances public epoch/document/selection/viewCamera revisions, and may advance preview if cleanup changed preview state (`docs/contracts/load_document.md:59`, `docs/contracts/load_document.md:66`, `docs/contracts/load_document.md:69`, `docs/contracts/load_document.md:76`).

### 7. Normal Edit Transaction Behavior

- **Location**: primary `docs/contracts/edit_kernel.md:50`.
- **Description**: EditKernel opens a synchronous edit session, rejects disposed/nested usage, creates a draft from committed revision, rejects `Future` results, compiles touched sets, installs document and selection effects atomically, commits buffered events/effects, and closes the handle (`docs/contracts/edit_kernel.md:65`, `docs/contracts/edit_kernel.md:68`, `docs/contracts/edit_kernel.md:71`, `docs/contracts/edit_kernel.md:76`, `docs/contracts/edit_kernel.md:83`).
- **Dependencies**: A changed update increments element revision and invalidates only typed touched sets (`docs/contracts/public_api_v1.md:1136`, `docs/contracts/public_api_v1.md:1138`). Programmatic `updateElement` emits no action event (`docs/contracts/public_api_v1.md:1836`, `docs/contracts/public_api_v1.md:1839`).
- **Data flow**: `CanvasEdit` mutations -> draft mutation -> exact touched facts -> CommitCompiler -> CommitApplier -> runtime state publication after atomic install (`docs/diagrams/seq_edit_success.mmd:33`, `docs/diagrams/seq_edit_success.mmd:35`, `docs/diagrams/seq_edit_success.mmd:42`, `docs/diagrams/seq_edit_success.mmd:53`, `docs/diagrams/seq_edit_success.mmd:67`).

### 8. Current Redesign Note

- **Location**: primary `redesign.md:1`.
- **Description**: `redesign.md` contains a planned text edit stale guard note. It describes adding `CanvasTextEditRequestId`, adding `requestId`, `controllerEpoch`, `documentRevision`, and `elementRevision` to `CanvasTextEditRequested`, and adding `CanvasCommandPort.commitTextEdit(...)` (`redesign.md:5`, `redesign.md:8`, `redesign.md:10`, `redesign.md:24`, `redesign.md:40`, `redesign.md:41`).
- **Dependencies**: The note states `commitTextEdit` returns false for unknown request id, changed `controllerEpoch`, deleted element, changed `elementRevision`, or element no longer being text (`redesign.md:51`, `redesign.md:56`). It also states successful `commitTextEdit` performs `updateElement` inside a normal edit transaction (`redesign.md:59`, `redesign.md:62`).
- **Data flow**: Proposed request emission with id/revision facts -> application calls `commitTextEdit(requestId, newText)` -> guard checks request/current facts -> successful path delegates to `updateElement` in normal edit transaction (`redesign.md:37`, `redesign.md:45`, `redesign.md:51`, `redesign.md:62`).

## Code References

- `AGENTS.md:3` - repository root is the canonical architecture rebuild target package.
- `docs/contracts/public_api_v1.md:77` - public barrel exports exactly the registry names.
- `docs/_registry/public_api_v1.yaml:84` - `CanvasTextEditRequested` is listed as a public export.
- `docs/contracts/public_api_v1.md:322` - runtime exposes `Stream<CanvasTextEditRequested>`.
- `docs/contracts/public_api_v1.md:1228` - current `CanvasCommandPort` declaration begins.
- `docs/contracts/public_api_v1.md:1234` - current `CanvasCommandPort` declaration ends with `clearContent`.
- `docs/contracts/public_api_v1.md:1860` - current `CanvasTextEditRequested` declaration begins.
- `docs/contracts/public_api_v1.md:1875` - current `CanvasTextEditRequested` includes `CanvasTextElement textSnapshot`.
- `docs/contracts/public_api_v1.md:1886` - current text model commits changed text through `updateElement(CanvasTextElementUpdate)`.
- `docs/contracts/public_api_v1.md:1887` - current text model says the engine does not store active text-input session.
- `docs/diagrams/seq_text_edit_request.mmd:61` - sequence emits current request payload.
- `docs/diagrams/state_pending_text_edit_request.mmd:40` - pending text candidate stores element id and generation.
- `docs/diagrams/state_pending_text_edit_request.mmd:41` - pending text candidate stores timestamp and `controllerEpoch`.
- `docs/architecture/03_data_model.md:119` - `documentRevision` definition.
- `docs/architecture/03_data_model.md:120` - `controllerEpoch` definition.
- `docs/architecture/03_data_model.md:92` - `ElementHandle` stores `elementRevision`.
- `docs/contracts/edit_kernel.md:159` - accepted edit commit publishes one public runtime state snapshot.
- `docs/contracts/operation_matrix.md:78` - text double-tap request row is stream-only with no revision/spatial/projection/repaint effects.
- `docs/verification/guardrails.md:172` - stale or epoch-mismatched terminal samples cannot create commit intent.
- `audit.md:58` - audit still has an unchecked operation-matrix item for text double-tap/text edit request.
- `redesign.md:8` - redesign note introduces `CanvasTextEditRequestId`.
- `redesign.md:40` - redesign note adds `commitTextEdit` to `CanvasCommandPort`.

## Observed Architecture Facts

- Pattern observed: app-owned text editing is request-only at the engine boundary. The engine emits `CanvasTextEditRequested`, while overlay, IME, focus, accessibility, text selection, hide/show policy, and editor lifetime belong to the application (`docs/diagrams/seq_text_edit_request.mmd:61`, `docs/diagrams/seq_text_edit_request.mmd:65`, `docs/contracts/public_api_v1.md:1884`, `docs/contracts/public_api_v1.md:1889`).
- Data flow: double-tap -> current hit revalidation -> stream notification -> application-owned overlay -> later normal edit update (`docs/diagrams/seq_text_edit_request.mmd:41`, `docs/diagrams/seq_text_edit_request.mmd:56`, `docs/diagrams/seq_text_edit_request.mmd:61`, `docs/diagrams/seq_text_edit_request.mmd:64`, `docs/diagrams/seq_text_edit_request.mmd:71`).
- Pattern observed: stale protection exists for pointer terminal commits before commit intent creation, using active token/session/epoch checks (`docs/contracts/interaction_engine.md:102`, `docs/contracts/interaction_engine.md:104`; `docs/diagrams/state_pointer_session.mmd:53`, `docs/diagrams/state_pointer_session.mmd:60`).
- Pattern observed: normal edit-session staleness is handle-lifetime based. `CanvasEdit` handles become stale after the callback, and later operations throw `StateError` (`docs/contracts/public_api_v1.md:1187`, `docs/contracts/public_api_v1.md:1188`; `docs/diagrams/seq_edit_success.mmd:65`, `docs/diagrams/seq_edit_success.mmd:66`).
- Data flow: `loadDocument` success advances epoch and clears pending tap history after install, while load failure leaves committed document identity, `controllerEpoch`, and document revisions unchanged (`docs/contracts/load_document.md:69`, `docs/contracts/load_document.md:73`; `docs/diagrams/seq_load_document_success.mmd:60`, `docs/diagrams/seq_load_document_success.mmd:61`; `docs/diagrams/seq_load_document_failure.mmd:50`, `docs/diagrams/seq_load_document_failure.mmd:51`).
- Key dependency: `redesign.md` records a different desired text-edit guard surface than the current normative API, including request id, revision facts, and `commitTextEdit` (`redesign.md:5`, `redesign.md:24`, `redesign.md:40`, `redesign.md:51`).

## Open Questions

- The current normative API does not carry request id, `controllerEpoch`, `documentRevision`, or `elementRevision` on `CanvasTextEditRequested`; these fields appear in `redesign.md` only (`docs/contracts/public_api_v1.md:1860`, `docs/contracts/public_api_v1.md:1875`; `redesign.md:10`, `redesign.md:28`).
- The current normative `CanvasCommandPort` does not contain `commitTextEdit`; that helper appears in `redesign.md` only (`docs/contracts/public_api_v1.md:1228`, `docs/contracts/public_api_v1.md:1234`; `redesign.md:37`, `redesign.md:45`).
- The current text request sequence says first-tap candidate facts include `textSnapshot`, `boundsWorld`, and element generation, while the state diagram additionally says pending state stores `controllerEpoch` (`docs/diagrams/seq_text_edit_request.mmd:33`, `docs/diagrams/seq_text_edit_request.mmd:37`; `docs/diagrams/state_pending_text_edit_request.mmd:40`, `docs/diagrams/state_pending_text_edit_request.mmd:41`).
- The current text editing model delegates load/dispose/tool-change behavior while editing to the application; `redesign.md` describes engine-controlled stale commit rejection for already-issued requests (`docs/contracts/public_api_v1.md:1887`, `docs/contracts/public_api_v1.md:1889`; `redesign.md:51`, `redesign.md:62`).
