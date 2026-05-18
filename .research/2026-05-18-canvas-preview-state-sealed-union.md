---
date: 2026-05-18
researcher: Codex
commit: 9936a51
branch: new-architecture
research_question: "Current codebase facts for converting CanvasPreviewState to a sealed union."
---

# Research: CanvasPreviewState Sealed Union

## Summary

The active root documentation currently describes `CanvasPreviewState` as a read-only immutable public preview snapshot exposed separately from the atomic `CanvasRuntimeState` revision snapshot. `CanvasRuntimeState` contains `CanvasRuntimeRevisions` and `CanvasRuntimeSummary`, while `CanvasRuntime` separately exposes `CanvasPreviewState get preview`; the public revision domain includes `preview` as `state.revisions.preview` (`docs/contracts/public_api_v1.md:307`, `docs/contracts/public_api_v1.md:317`, `docs/contracts/public_api_v1.md:365`, `docs/contracts/public_api_v1.md:388`).

The current documented public shape is one `final class CanvasPreviewState` with required `kind` plus optional or nullable facts for pointer/session, selected move delta, marquee, stroke, line, and eraser preview data (`docs/contracts/public_api_v1.md:1504`, `docs/contracts/public_api_v1.md:1524`, `docs/contracts/public_api_v1.md:1539`). `redesign.md` contains a separate section that represents the same area as a sealed hierarchy with variant classes for no preview, marquee, selected move, stroke, pending line, line, and eraser (`redesign.md:1`, `redesign.md:8`, `redesign.md:14`, `redesign.md:102`).

Preview state is produced by interaction flows from pointer/session/candidate facts, published through the public preview revision when it changes, and consumed by frame capture. Overlay preview kinds are admitted into overlay primitives, while selected move preview is consumed by the main-scene selected supplement path and excluded from ordinary `PaintPlanCache` keys and values (`docs/diagrams/dfd_pointer_preview_commit.mmd:80`, `docs/diagrams/dfd_pointer_preview_commit.mmd:85`, `docs/diagrams/seq_overlay_paint.mmd:21`, `docs/contracts/cache_policy.md:65`).

## Detailed Findings

### 1. Public Preview API Shape

- **Location**: primary `docs/contracts/public_api_v1.md:1488`; additional `docs/contracts/public_api_v1.md:1493`, `docs/contracts/public_api_v1.md:1504`
- **Description**: The public API contract has a "Preview state" section and says the next API exposes read-only preview state because the legacy example reads pending line and stroke preview state (`docs/contracts/public_api_v1.md:1488`, `docs/contracts/public_api_v1.md:1490`). `CanvasPreviewKind` is currently documented as an enum with `none`, `marquee`, `selectedMove`, `pencilStroke`, `markerStroke`, `pendingLineStart`, `linePreview`, and `eraser` (`docs/contracts/public_api_v1.md:1493`, `docs/contracts/public_api_v1.md:1501`). `CanvasPreviewState` is currently documented as a single `final class` (`docs/contracts/public_api_v1.md:1504`).
- **Dependencies**: The public export registry includes `CanvasPreviewState` and `CanvasPreviewKind` in `public_exports` (`docs/_registry/public_api_v1.yaml:62`, `docs/_registry/public_api_v1.yaml:63`). The public API contract states that `lib/iwb_canvas_engine.dart` exports exactly the names in that registry, while the contract document owns public semantics and declarations (`docs/contracts/public_api_v1.md:75`, `docs/contracts/public_api_v1.md:79`).
- **Data flow**: Applications observe public runtime revisions through `ValueListenable<CanvasRuntimeState> get state` and can read preview through `CanvasPreviewState get preview` (`docs/contracts/public_api_v1.md:307`, `docs/contracts/public_api_v1.md:317`).

### 2. Current Single-Class Fields And Rules

- **Location**: primary `docs/contracts/public_api_v1.md:1505`; additional `docs/contracts/public_api_v1.md:1524`, `docs/contracts/public_api_v1.md:1539`
- **Description**: The documented constructor requires only `kind`; the rest of the constructor parameters represent optional pointer/session ids, selected move delta, marquee rect, stroke facts, line facts, and eraser facts (`docs/contracts/public_api_v1.md:1505`, `docs/contracts/public_api_v1.md:1521`). The class fields include nullable `activePointerId`, `sessionId`, `marqueeRect`, stroke color/thickness/opacity, line start/end/timestamp/color/thickness, and eraser thickness, plus `selectedMoveDelta` defaulted through the constructor and list getters for stroke points and eraser corridor (`docs/contracts/public_api_v1.md:1524`, `docs/contracts/public_api_v1.md:1539`).
- **Dependencies**: `CanvasPreviewState` is listed under default identity equality, while `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and `CanvasRuntimeSummary` are listed under required value equality (`docs/contracts/public_api_v1.md:133`, `docs/contracts/public_api_v1.md:142`, `docs/contracts/public_api_v1.md:168`, `docs/contracts/public_api_v1.md:180`).
- **Data flow**: The public rules state that preview state is immutable, pointer preview updates create a small new snapshot or reuse the previous unchanged snapshot, preview getters do not materialize `CanvasDocument`, pending line start is epoch-bound, successful `loadDocument` clears preview, failed `loadDocument` preserves preview, and selected move preview is main-scene preview (`docs/contracts/public_api_v1.md:1543`, `docs/contracts/public_api_v1.md:1552`).

### 3. Runtime State And Revision Publication

- **Location**: primary `docs/contracts/public_api_v1.md:365`; additional `docs/contracts/public_api_v1.md:375`, `docs/contracts/public_api_v1.md:388`
- **Description**: The documented `CanvasRuntimeState` contains only `CanvasRuntimeRevisions revisions` and `CanvasRuntimeSummary summary` (`docs/contracts/public_api_v1.md:365`, `docs/contracts/public_api_v1.md:372`). `CanvasRuntimeRevisions` contains the public `preview` revision domain along with document, selection, viewCamera, resourceVisual, interaction, and epoch (`docs/contracts/public_api_v1.md:375`, `docs/contracts/public_api_v1.md:392`). `CanvasRuntimeSummary` contains element, layer, resource, and selected counts (`docs/contracts/public_api_v1.md:395`, `docs/contracts/public_api_v1.md:406`).
- **Dependencies**: The step 6 plan also defines public `CanvasRuntimeState` as the atomic snapshot with revisions and summary, and defines preview as one stable public revision domain (`plan/step_6_public_runtime_state_and_view_camera_ownership.md:21`, `plan/step_6_public_runtime_state_and_view_camera_ownership.md:25`).
- **Data flow**: Step 6 describes runtime publication as one new `CanvasRuntimeState` after each accepted runtime state change or atomic commit/install, with selection-only, preview-only, resource-dirty, interaction-setting, and view-camera changes publishing state without incrementing document revision (`plan/step_6_public_runtime_state_and_view_camera_ownership.md:390`, `plan/step_6_public_runtime_state_and_view_camera_ownership.md:394`).

### 4. Interaction Production And Cleanup

- **Location**: primary `docs/contracts/interaction_engine.md:76`; additional `docs/contracts/interaction_engine.md:112`, `docs/contracts/interaction_engine.md:115`
- **Description**: The interaction lifecycle state diagram routes active pointers to terminal commit, cancellation, invalid terminal cleanup, and dispose, with active pointer dispose clearing preview before stream close (`docs/contracts/interaction_engine.md:76`, `docs/contracts/interaction_engine.md:90`). Interaction rules state that public interaction setting changes publish `state.revisions.interaction`, preview changes publish `state.revisions.preview`, and no-op cleanup publishes no new public state snapshot (`docs/contracts/interaction_engine.md:112`, `docs/contracts/interaction_engine.md:115`).
- **Dependencies**: The pointer preview data-flow diagram routes normalized finite down/move samples and cleanup terminal data through the pointer session gate to session preview or candidate preview facts, then into immutable `CanvasPreviewState` (`docs/diagrams/dfd_pointer_preview_commit.mmd:64`, `docs/diagrams/dfd_pointer_preview_commit.mmd:82`). It also shows preview snapshots publishing `CanvasRuntimeState` with `state.revisions.preview` when changed (`docs/diagrams/dfd_pointer_preview_commit.mmd:83`, `docs/diagrams/dfd_pointer_preview_commit.mmd:85`).
- **Data flow**: Valid pointer/candidate/session facts become preview state; overlay preview snapshots route to overlay repaint, selected move preview delta routes to main repaint, and terminal cleanup clears active preview/session with `previewRevision` if an active preview existed (`docs/diagrams/dfd_pointer_preview_commit.mmd:83`, `docs/diagrams/dfd_pointer_preview_commit.mmd:92`, `docs/diagrams/dfd_pointer_preview_commit.mmd:95`).

### 5. Documented Preview Kinds By Interaction Flow

- **Location**: primary `docs/contracts/interaction_engine.md:134`; additional `docs/contracts/interaction_engine.md:138`, `docs/contracts/interaction_engine.md:144`
- **Description**: Repaint targets are documented as overlay-only for marquee, pencil stroke, marker stroke, pending line start, line preview, and eraser corridor, while selected move preview targets main scene only (`docs/contracts/interaction_engine.md:134`, `docs/contracts/interaction_engine.md:144`). Marquee starts by publishing kind `marquee` with a zero-area `marqueeRect` and then replaces the immutable marquee preview snapshot on move (`docs/diagrams/seq_marquee_select.mmd:44`, `docs/diagrams/seq_marquee_select.mmd:58`). Selected move starts by publishing kind `selectedMove` with `selectedMoveDelta Offset.zero` and replaces the immutable selected move snapshot when delta changes (`docs/diagrams/seq_selected_move_preview_commit.mmd:44`, `docs/diagrams/seq_selected_move_preview_commit.mmd:58`).
- **Dependencies**: Pencil and marker start by publishing kind `pencilStroke` or `markerStroke` with the first point, and move samples replace the immutable stroke preview snapshot (`docs/diagrams/seq_pencil_marker_commit.mmd:30`, `docs/diagrams/seq_pencil_marker_commit.mmd:45`). The first line tap publishes kind `pendingLineStart` with start, timestamp, color, and thickness, while movement replaces it with kind `linePreview` (`docs/diagrams/seq_line_two_tap_commit.mmd:36`, `docs/diagrams/seq_line_two_tap_commit.mmd:51`). Eraser starts by publishing kind `eraser` with the first corridor point and move samples replace the immutable eraser corridor preview snapshot (`docs/diagrams/seq_eraser_commit.mmd:32`, `docs/diagrams/seq_eraser_commit.mmd:57`).
- **Data flow**: For these flows, preview updates publish `state.revisions.preview` and request either overlay repaint or main repaint according to preview kind (`docs/diagrams/seq_marquee_select.mmd:60`, `docs/diagrams/seq_selected_move_preview_commit.mmd:62`, `docs/diagrams/seq_pencil_marker_commit.mmd:48`, `docs/diagrams/seq_line_two_tap_commit.mmd:55`, `docs/diagrams/seq_eraser_commit.mmd:60`).

### 6. Load, Dispose, And `interactive=false` Behavior

- **Location**: primary `docs/implementation/p6_load_document.md:14`; additional `docs/implementation/p6_load_document.md:23`
- **Description**: Successful `loadDocument` validates/materializes before interaction interruption, clears preview, installs replacement document plus selection clear atomically, increments document/selection/view camera/epoch revisions plus preview when cleanup changes it, clears pointer normalization hooks, invalidates caches, and publishes one `CanvasRuntimeState` after install (`docs/implementation/p6_load_document.md:14`, `docs/implementation/p6_load_document.md:20`). The failure path leaves committed document, selection owner, preview, pointer normalization, repaint, events, and active gesture state unchanged (`docs/implementation/p6_load_document.md:21`, `docs/implementation/p6_load_document.md:23`).
- **Dependencies**: The operation matrix has rows for dispose with active preview and without active preview; active preview dispose touches preview cleanup and publishes `state.revisions.preview` before dispose returns, while dispose without active preview has no revision changes (`docs/contracts/operation_matrix.md:80`, `docs/contracts/operation_matrix.md:81`). The dispose sequence routes selected move cleanup to main-scene repaint and overlay preview cleanup to overlay repaint (`docs/diagrams/seq_dispose_during_gesture.mmd:42`, `docs/diagrams/seq_dispose_during_gesture.mmd:65`).
- **Data flow**: `interactive=false` cancels only an active routed pointer session; pending line start or line preview not owned by an active routed pointer session is preserved until line-owned cleanup, mode/tool change, successful load, dispose, or terminal line decision (`docs/contracts/interaction_engine.md:126`, `docs/contracts/interaction_engine.md:129`).

### 7. Frame Capture And Cache Consumption

- **Location**: primary `docs/contracts/frame_rendering.md:56`; additional `docs/contracts/frame_rendering.md:77`
- **Description**: `CapturedMainFrame` includes `selectedMoveDelta`, while `CapturedOverlayFrame` includes `previewRevision` and `previewState` (`docs/contracts/frame_rendering.md:56`, `docs/contracts/frame_rendering.md:85`). Frame rules state that main and overlay paint each capture once, painters do not live-read runtime, and painters do not materialize `CanvasDocument` (`docs/contracts/frame_rendering.md:91`, `docs/contracts/frame_rendering.md:94`).
- **Dependencies**: The overlay paint sequence captures `previewRevision` and immutable `previewState` once, admits overlay preview kinds from the captured preview state, rejects selected move from overlay admission, and notes that selected move preview is rendered by the main scene selected supplement path (`docs/diagrams/seq_overlay_paint.mmd:16`, `docs/diagrams/seq_overlay_paint.mmd:35`). The main paint DFD reads an immutable selected move preview snapshot once and passes `selectedMoveDelta or none` into the captured main frame (`docs/diagrams/dfd_main_paint_frame.mmd:74`, `docs/diagrams/dfd_main_paint_frame.mmd:75`).
- **Data flow**: `PaintPlanCache` stores ordinary committed records only and excludes selected-move supplement records, `selectedMoveDelta`, and `previewDelta`; it also excludes selected ids, selection flags, and `selectionRevision` from ordinary keys or cached ordinary records (`docs/contracts/cache_policy.md:65`, `docs/contracts/cache_policy.md:73`). The cache ledger also lists `PreviewStateSnapshot` as Interaction-owned, keyed by `previewRevision`, invalidated by pointer/tool/load/mode/dispose, with one preview snapshot capacity (`docs/contracts/cache_policy.md:52`).

### 8. Redesign Document Shape

- **Location**: primary `redesign.md:1`; additional `redesign.md:8`, `redesign.md:116`
- **Description**: `redesign.md` has a section titled `CanvasPreviewState` sealed-union conversion and describes the current problem as one class with nullable fields allowing impossible states (`redesign.md:1`, `redesign.md:3`). It presents `CanvasPreviewState` as a `sealed class` with `CanvasPreviewKind get kind` (`redesign.md:8`, `redesign.md:11`). Its listed variants are `CanvasNoPreview`, `CanvasMarqueePreview`, `CanvasSelectedMovePreview`, `CanvasStrokePreview`, `CanvasPendingLinePreview`, `CanvasLinePreview`, and `CanvasEraserPreview` (`redesign.md:14`, `redesign.md:21`, `redesign.md:32`, `redesign.md:49`, `redesign.md:68`, `redesign.md:85`, `redesign.md:102`).
- **Dependencies**: The redesign's selected move variant contains `activePointerId`, `sessionId`, `delta`, and `selectedIds` (`redesign.md:32`, `redesign.md:43`). The redesign's stroke variant contains one `CanvasDrawTool tool`, point list, color, thickness, and opacity (`redesign.md:49`, `redesign.md:65`). The redesign's pending line and line variants use kind names `pendingLine` and `line`, while the current public enum uses `pendingLineStart` and `linePreview` (`redesign.md:82`, `redesign.md:99`, `docs/contracts/public_api_v1.md:1499`, `docs/contracts/public_api_v1.md:1500`).
- **Data flow**: The redesign section states its outcome as making invalid preview state impossible at the type level (`redesign.md:116`).

### 9. Plan And Verification References

- **Location**: primary `plan/step_6_public_runtime_state_and_view_camera_ownership.md:48`; additional `plan/step_6_public_runtime_state_and_view_camera_ownership.md:64`
- **Description**: Step 6 explicitly lists `No conversion of CanvasPreviewState to a sealed union` under "Not Included in the Change" (`plan/step_6_public_runtime_state_and_view_camera_ownership.md:48`, `plan/step_6_public_runtime_state_and_view_camera_ownership.md:64`). The same step also says its scope has no production Dart implementation under `lib/**` and no Dart test implementation under `test/**` (`plan/step_6_public_runtime_state_and_view_camera_ownership.md:50`, `plan/step_6_public_runtime_state_and_view_camera_ownership.md:51`).
- **Dependencies**: The documented package layout places the future public API under root `lib/`, including `lib/iwb_canvas_engine.dart` and `lib/src/api/canvas_preview.dart`, and states the barrel exports only `src/api/**` (`docs/architecture/02_package_boundaries.md:33`, `docs/architecture/02_package_boundaries.md:51`, `docs/architecture/02_package_boundaries.md:148`).
- **Data flow**: Required verification includes `test.interaction.preview_public_state`, whose description says preview-only pointer changes publish `state.revisions.preview` without changing document, selection, resourceVisual, interaction, or viewCamera revisions and without emitting action events; it also proves cleanup against already-empty preview state is public-state silent (`docs/verification/tests.md:162`, `docs/verification/tests.md:375`).

## Code References

- `docs/contracts/public_api_v1.md:307` - `CanvasRuntime` exposes `ValueListenable<CanvasRuntimeState> get state`.
- `docs/contracts/public_api_v1.md:317` - `CanvasRuntime` exposes `CanvasPreviewState get preview`.
- `docs/contracts/public_api_v1.md:365` - `CanvasRuntimeState` is documented as a final class.
- `docs/contracts/public_api_v1.md:388` - `CanvasRuntimeRevisions` exposes the public `preview` revision.
- `docs/contracts/public_api_v1.md:1493` - current `CanvasPreviewKind` enum declaration starts.
- `docs/contracts/public_api_v1.md:1504` - current `CanvasPreviewState` single-class declaration starts.
- `docs/contracts/public_api_v1.md:1524` - current `CanvasPreviewState` field list starts.
- `docs/contracts/public_api_v1.md:1546` - preview state immutability rule.
- `docs/contracts/interaction_engine.md:112` - preview changes publish `state.revisions.preview`.
- `docs/contracts/interaction_engine.md:136` - preview repaint target table starts.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:21` - `CanvasPreviewState` is shown as immutable pointer-owned preview snapshot with `previewRevision`.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:85` - changed preview publishes `CanvasRuntimeState` with preview revision.
- `docs/diagrams/seq_overlay_paint.mmd:16` - overlay capture reads preview revision and immutable preview state once.
- `docs/diagrams/dfd_main_paint_frame.mmd:74` - main frame reads immutable selected move preview once.
- `docs/contracts/cache_policy.md:52` - `PreviewStateSnapshot` cache row.
- `docs/contracts/cache_policy.md:65` - ordinary `PaintPlanCache` excludes selected move and preview deltas.
- `redesign.md:8` - redesign sealed `CanvasPreviewState` declaration.
- `redesign.md:14` - redesign `CanvasNoPreview` variant.
- `redesign.md:32` - redesign `CanvasSelectedMovePreview` variant.
- `redesign.md:49` - redesign `CanvasStrokePreview` variant.
- `redesign.md:116` - redesign stated outcome.
- `plan/step_6_public_runtime_state_and_view_camera_ownership.md:64` - step 6 excludes sealed-union conversion.
- `docs/verification/tests.md:371` - `test/interaction/preview_public_state_test.dart` proof description starts.
- `docs/verification/guardrails.md:166` - selected move preview main repaint guardrail.
- `docs/indexes/by_guardrail.md:301` - paint-plan preview delta exclusion rule.

## Observed Architecture Facts

- Pattern observed: public observation separates the atomic runtime revision snapshot from direct preview-state reading; `CanvasRuntimeState` carries revisions/summary, while `CanvasRuntime.preview` carries current preview details (`docs/contracts/public_api_v1.md:317`, `docs/contracts/public_api_v1.md:371`, `docs/contracts/public_api_v1.md:372`).
- Pattern observed: preview is Interaction-owned and revisioned independently from document state; preview-only changes publish `state.revisions.preview` without document revision changes (`docs/contracts/interaction_engine.md:113`, `plan/step_6_public_runtime_state_and_view_camera_ownership.md:393`, `plan/step_6_public_runtime_state_and_view_camera_ownership.md:394`).
- Pattern observed: selected move preview is the only documented preview kind that repaints the main scene; marquee, pencil, marker, pending line, line, and eraser previews repaint the overlay (`docs/contracts/interaction_engine.md:136`, `docs/contracts/interaction_engine.md:144`).
- Data flow observed: normalized pointer/sample input -> session or candidate preview facts -> immutable `CanvasPreviewState` -> `state.revisions.preview` publication -> main or overlay repaint, depending on preview kind (`docs/diagrams/dfd_pointer_preview_commit.mmd:69`, `docs/diagrams/dfd_pointer_preview_commit.mmd:80`, `docs/diagrams/dfd_pointer_preview_commit.mmd:87`).
- Data flow observed: runtime preview snapshot -> captured overlay or main frame -> overlay primitive building or selected supplement staging -> painter, with no live runtime reads by painters (`docs/diagrams/seq_overlay_paint.mmd:16`, `docs/diagrams/dfd_main_paint_frame.mmd:74`, `docs/contracts/frame_rendering.md:93`).
- Verification fact: `test.interaction.preview_public_state` is the named future test for preview-only publication and no-op cleanup silence (`docs/verification/tests.md:371`, `docs/verification/tests.md:375`).
- Guardrail fact: `preview.selected_move_main_repaint` states selected move preview increments main repaint, not overlay (`docs/verification/guardrails.md:166`, `docs/indexes/by_guardrail.md:175`).
- Guardrail fact: `frame.paint_plan_excludes_preview_delta` states `PaintPlanCache` excludes `selectedMoveDelta/previewDelta` from keys and values (`docs/verification/guardrails.md:177`, `docs/indexes/by_guardrail.md:301`).

## Open Questions

- The researched files contain both the current public enum names `pencilStroke`, `markerStroke`, `pendingLineStart`, and `linePreview` and the redesign sketch names `stroke`, `pendingLine`, and `line`; the researched files do not contain a resolved mapping between those spellings (`docs/contracts/public_api_v1.md:1497`, `docs/contracts/public_api_v1.md:1500`, `redesign.md:65`, `redesign.md:99`).
- The current public `CanvasPreviewState` field list does not include `selectedIds`, while the redesign `CanvasSelectedMovePreview` variant includes `selectedIds`; the researched files do not contain a resolved public-field decision for that difference (`docs/contracts/public_api_v1.md:1524`, `docs/contracts/public_api_v1.md:1539`, `redesign.md:32`, `redesign.md:43`).
- Step 6 explicitly excludes sealed-union conversion, while `redesign.md` contains the sealed-union section; the researched files do not identify a plan step that owns this conversion after step 6 (`plan/step_6_public_runtime_state_and_view_camera_ownership.md:64`, `redesign.md:1`).
