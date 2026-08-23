---
date: 2026-08-23
researcher: agent
commit: 29d10eaa
branch: main
research_question: "Determine the change surface and active-design intersection for pre-commit deletion interception, configurable eraser element kinds, and all-selection deletion eligibility."
---

# Research: Delete, Eraser, and Selection Change Scope

## Summary

This research examines the requested implementation baseline at commit `391410862c12676090f263d3ed8f26a6f7bed3ea` and the current active-design status at the repository `HEAD` recorded above. At the requested implementation baseline, deletion of a selection and terminal eraser deletion carry only element IDs into the same sparse interaction-commit route. The public document retains the complete ordered element data needed to reconstruct a deletion snapshot, but the current deletion facts, action payloads, intent objects, and sparse remove mutation do not carry an element, a layer position, or an intra-layer index.

The eraser kind filter is confined to the eraser read path before terminal commit: resolved spatial candidates are budgeted before they are exact-hit tested, and their frame facts already contain `CanvasElementKind`. Selection deletion eligibility is computed at the runtime command-facts boundary from current selection and frame facts; the command then removes only deletable selected IDs, which is the established partial-deletion behavior.

The requested three capabilities are a separate design. Their confirmed overlap with the active sparse-commit design is at shared runtime routes, atomic installation, and delivery seams, rather than at a shared design scope. The current historical Contract 2 handoff records Contracts 3 and 4 as pending; the store-transaction candidate itself is completed. The interaction is therefore concentrated in the runtime route and delivery seam, while the completed store transaction remains an indirect consumer of removal mutations.

## Detailed Findings

### 1. Pre-commit deletion interception

- **Location**: `lib/src/runtime/runtime_root.dart:871`; `lib/src/runtime/runtime_root.dart:2406`.
- **Description**: `deleteSelection` reads `SelectionDeleteFacts.deletableIds`, records a sparse `removeElement` for each ID, attaches `DeleteSelectionActionIntent`, and delivers the accepted result. The eraser terminal route accepts `EraserCommitIntent.erasedElementIds`, prepares the same kind of sparse removes, runs success cleanup, and then delivers the result. `EditKernel.prepareInteractionCommit` prepares and installs an accepted commit within the same method before it returns a delivery result (`lib/src/edit/edit_kernel.dart:113`).
- **Dependencies**: The public action payloads contain only removed/erased IDs (`lib/src/contracts/public/canvas_actions.dart:86`; `lib/src/contracts/public/canvas_actions.dart:144`). The existing synchronous resolver pattern is `CanvasMoveCommitResolver` in `CanvasRuntimeConfig` (`lib/src/contracts/public/canvas_actions.dart:220`; `lib/src/contracts/public/canvas_runtime.dart:22`) and is invoked through the runtime resolver guard before move preparation (`lib/src/runtime/runtime_root.dart:2110`).
- **Data flow**: selection or terminal eraser intent -> ID list -> `CanvasEdit.removeElement` -> `StoreSparseRemoveElement(id)` -> prepared sparse commit -> document install -> selection effect -> runtime state/action delivery (`lib/src/runtime/runtime_root.dart:871`; `lib/src/runtime/runtime_root.dart:2431`; `lib/src/edit/edit_session.dart:579`; `lib/src/store/sparse_store_commit.dart:79`; `lib/src/edit/commit_applier.dart:85`; `lib/src/runtime/runtime_root.dart:1872`).
- **Observed change surface**: the requested snapshot data is absent from the delete facts, eraser intent, public action payloads, and sparse remove DTOs. Public `CanvasDocument` instead owns ordered layers and their ordered elements (`lib/src/contracts/public/canvas_document.dart:63`; `lib/src/contracts/public/canvas_document.dart:97`); sparse element location carries a nullable layer ID but no index (`lib/src/store/element_registry.dart:515`). Existing witnesses cover selection-delete action/no-op behavior and eraser success/no-op/failure delivery (`test/api/fixtures/selection_transform_commands_fixture.dart:136`; `test/interaction/fixtures/commands_emit_user_actions_fixture.dart:32`).

### 2. Configurable eraser element kinds

- **Location**: `lib/src/runtime/runtime_interaction_read_adapter.dart:324`; `lib/src/geometry/hit_test_policy.dart:165`.
- **Description**: Preview and terminal eraser reads use distinct budget inputs and a shared `_eraserFacts` implementation (`lib/src/runtime/runtime_interaction_read_adapter.dart:241`; `lib/src/runtime/runtime_interaction_read_adapter.dart:256`). It resolves spatial candidates, applies `candidateLimit` to the resolved-handle count, increments the exact counter for every resolved fact, and calls `exactEraserHit` (`lib/src/runtime/runtime_interaction_read_adapter.dart:340`; `lib/src/runtime/runtime_interaction_read_adapter.dart:345`; `lib/src/runtime/runtime_interaction_read_adapter.dart:359`).
- **Dependencies**: `FrameElementFacts` contains `kind` (`lib/src/contracts/internal/frame_facts_port.dart:46`), while `exactEraserHit` switches across image, vector, rect, text, line, stroke, and path (`lib/src/geometry/hit_test_policy.dart:173`). The public tool configuration contains eraser thickness but no kind set (`lib/src/contracts/public/canvas_tools.dart:17`); neither `EraserReadRequest` nor `EraserReadFacts` carries a kind filter (`lib/src/interaction/interaction_read_port.dart:252`; `lib/src/interaction/interaction_read_port.dart:262`).
- **Data flow**: pointer eraser capture -> `EraserReadRequest` -> corridor/spatial query -> resolved frame facts -> candidate and exact-check budgets -> ordered erased IDs -> terminal intent, if IDs are nonempty and the exact budget was not exceeded (`lib/src/interaction/eraser_machine.dart:64`; `lib/src/interaction/eraser_machine.dart:136`).
- **Observed change surface**: the requested filter concerns the public configuration surface and the read adapter's candidate loop. It is upstream from both exact geometry and the sparse commit route. Existing geometry witnesses define budget inputs and no-partial-commit behavior (`test/geometry/fixtures/eraser_exact_budget_inputs_fixture.dart:65`; `test/geometry/fixtures/eraser_exact_budget_no_partial_commit_fixture.dart:71`).

### 3. All-selection deletion eligibility and all-or-none mode

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:201`; `lib/src/contracts/internal/command_facts_port.dart:27`; `lib/src/runtime/runtime_command_facts_adapter.dart:60`.
- **Description**: `CanvasSelectionPort` exposes selected IDs and `deleteSelection`, but no deletion-eligibility property or deletion mode. `SelectionDeleteFacts` contains an immutable `deletableIds` list only. The facts adapter reads current selected IDs and frame handles in document order, retaining only content elements whose frame facts are deletable (`lib/src/runtime/runtime_command_facts_adapter.dart:61`; `lib/src/runtime/runtime_command_facts_adapter.dart:134`).
- **Dependencies**: `RuntimeRoot.deleteSelection` exits only when `deletableIds` is empty; otherwise it removes every listed ID in one interaction commit (`lib/src/runtime/runtime_root.dart:871`; `lib/src/runtime/runtime_root.dart:874`; `lib/src/runtime/runtime_root.dart:879`). `SelectionKernel` owns selected IDs and a selection revision, not deletion eligibility or policy (`lib/src/selection/selection_kernel.dart:15`; `lib/src/selection/selection_kernel.dart:22`). Sparse `removeElement` verifies existence rather than `isDeletable` (`lib/src/edit/edit_session.dart:579`).
- **Data flow**: selection state plus frame facts -> `SelectionDeleteFacts.deletableIds` -> sparse removals -> prepared selection prune -> document installation and selection-effect installation (`lib/src/runtime/runtime_command_facts_adapter.dart:60`; `lib/src/edit/commit_compiler.dart:15`; `lib/src/edit/commit_applier.dart:95`; `lib/src/runtime/runtime_root.dart:1835`).
- **Observed change surface**: the public port and current facts DTO do not expose the requested all-selected predicate. The partial-deletion branch is a tested current behavior: a deletable selected element is removed while a non-deletable selected element remains (`test/api/fixtures/selection_transform_commands_fixture.dart:139`; `test/api/fixtures/selection_transform_commands_fixture.dart:152`). The command-facts fixture also establishes document ordering and immutable facts output (`test/runtime/fixtures/command_facts_port_fixture.dart:68`; `test/runtime/fixtures/command_facts_port_fixture.dart:74`).

### 4. Separate-design intersection with the active sparse-commit design

- **Location**: `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:248`; `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:555`.
- **Description**: The active design is `READY_FOR_CONTRACT` and partitions its performance work into four contracts (`docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:5`; `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:555`). The historical Contract 2 file is archived and its lifecycle gate states that the design remains active because Contracts 3 and 4 are pending (`docs/history/plans/2026-08-13-store-transaction-candidate.md:549`).
- **Dependencies**: Contract 2 targeted the store transaction candidate; Contract 3 targets indexed edit lifecycle and atomic install closure; Contract 4 targets runtime route and temporal delivery closure (`docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:555`; `docs/history/plans/2026-08-13-store-transaction-candidate.md:545`; `docs/history/plans/2026-08-13-store-transaction-candidate.md:546`). The active design names `RuntimeRoot` interaction routes, sparse preparation, `EditSession`, and store owners as in-scope seams (`docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:248`; `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:557`).
- **Data flow**: interaction route -> sparse edit session -> store preparation -> atomic install -> common guarded delivery is an explicit design temporal surface (`docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:264`; `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:545`).
- **Observed intersection**: eraser is expressly present in Contract 4's cleanup and delivery evidence (`docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:61`; `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:545`). The separate design's deletion interceptor, kind filter, all-selected predicate, and all-or-none mode are not named in the active design's scope. The active design's exclusion of public API changes describes that design's own contract boundary (`docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:250`; `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:254`).

## Code References

- `lib/src/contracts/public/canvas_actions.dart:86` - current delete payload holds IDs only.
- `lib/src/contracts/public/canvas_actions.dart:144` - current erase payload holds IDs and eraser metrics only.
- `lib/src/contracts/public/canvas_runtime.dart:22` - current runtime configuration includes the move resolver.
- `lib/src/contracts/public/canvas_runtime.dart:201` - current public selection surface.
- `lib/src/runtime/runtime_root.dart:871` - selection deletion route.
- `lib/src/runtime/runtime_root.dart:2406` - eraser delivery and cleanup route.
- `lib/src/edit/edit_kernel.dart:113` - interaction preparation installs accepted commits.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:324` - candidate budget and exact-hit loop.
- `lib/src/geometry/hit_test_policy.dart:165` - eraser exact-hit entry point and all-kind dispatch.
- `lib/src/runtime/runtime_command_facts_adapter.dart:60` - selection deletion facts calculation.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:545` - Contract 3 is the next edit/atomic-install boundary.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:546` - Contract 4 is the remaining runtime-route and temporal-delivery boundary.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:549` - Contract 2 is archived and leaves Contracts 3–4 pending.

## Search Coverage

- Inspected: the directly named public contracts, runtime root, edit kernel, document store, hit-test policy, interaction read adapter, command facts port/adapter, and selection kernel at `39141086`; the active design and its completed Contract 2 handoff at repository `HEAD`; dependent interaction, commit, store, document, and test files listed in the detailed findings were read for the traced paths.
- Searched: `deleteSelection`, `EraserCommitIntent`, `CanvasEraseActionPayload`, `CanvasDeleteActionPayload`, `CanvasMoveCommitResolver`, `SelectionDeleteFacts`, `candidateLimit`, `exactCheckCount`, `CanvasElementKind`, `StoreSparseRemoveElement`, and active-plan references across `lib`, `test`, and relevant `docs` paths at `39141086`.
- Not found: a delete/erase resolver; a kind-filter field in the eraser configuration/request/facts/intent surfaces; a public all-selection-deletable state; an all-or-none deletion mode; and a sparse remove DTO carrying element placement.
- Not inspected: implementation feasibility after `39141086`; this research records the requested target commit's behavior and the current planning status only.

## Observed Architecture Facts

- Pattern observed: public command eligibility is assembled by runtime adapters from frame and selection facts, then consumed by `RuntimeRoot` command routes (`lib/src/runtime/runtime_command_facts_adapter.dart:60`; `lib/src/runtime/runtime_root.dart:871`).
- Data flow: terminal eraser read -> `EraserCommitIntent` -> sparse interaction commit -> cleanup -> action delivery (`lib/src/interaction/eraser_machine.dart:64`; `lib/src/runtime/runtime_root.dart:2406`; `lib/src/edit/edit_kernel.dart:113`).
- Key dependencies: public deletion behavior is routed through an internal sparse journal whose remove record is ID-only (`lib/src/edit/edit_session.dart:579`; `lib/src/store/sparse_store_commit.dart:79`), while source layer ordering belongs to the public document/layer structure (`lib/src/contracts/public/canvas_document.dart:63`; `lib/src/contracts/public/canvas_document.dart:97`).

## Open Questions

- The requested implementation baseline is `39141086`, while the active design's Contract 2 completion is recorded in the current repository history (`docs/history/plans/2026-08-13-store-transaction-candidate.md:549`). This document records the baseline behavior and the current planning status separately.
