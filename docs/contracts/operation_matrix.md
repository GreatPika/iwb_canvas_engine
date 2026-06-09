<!-- CONTEXT:BEGIN -->
Registry id: `section_13_operation_matrix`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/operation_matrix.md`
Owns:
- 13. Operation matrix
Must read before editing:
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
Current owners:
- `contract`
Benchmarks:
- `none`
Related diagrams:
- `seq_edit_success`
- `seq_edit_rollback`
Required tests:
- `test.edit.sync_non_nested_async_stale`
- `test.edit.edit_matrix_effects`
- `test.api.runtime_timestamp_order`
- `test.interaction.runtime_created_timestamps_monotonic`
- `test.interaction.context_action_request`
- `test.interaction.text_edit_stale_commit_guard`
Guardrails:
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
- `events.commands_emit_user_actions`
- `events.runtime_created_timestamps_monotonic`
- `interaction.text_edit_stale_commit_guard`
Do not assume:
- no implicit mutation path outside EditKernel
<!-- CONTEXT:END -->

## 13. Operation matrix

Owner coverage:

```text
Edit owns edit rows and the generic executable effect shape.
Staged load owns loadDocumentFromJson success/failure rows.
Staged load also owns CanvasEdit.replaceDraftDocument success/failure behavior
and load-driven draft replacement execution.
Resource and interaction owners own their resource and interaction rows.
```

| Operation | State touched | Revisions | Spatial | Projection | Repaint | Events |
|---|---|---|---|---|---|---|
| addElement content | layer membership, registry, family row | state.revisions.document; internal structural, bounds, elementVisual, projection | add id | evict | main | none |
| addBackgroundElement | background layer, registry, family row | state.revisions.document; internal structural, bounds, elementVisual, projection | add paint only | evict | main | none |
| CanvasEdit.updateElement | changed element fields plus selection-owner prune when the Element update field-effect taxonomy requires normalization | state.revisions.document, state.revisions.selection if pruned; internal revisions from the Element update field-effect taxonomy | taxonomy-defined touched update or none | evict when any persisted field changes | taxonomy-defined main or none | none |
| CanvasEdit.removeElement | registry/layer membership, plus selection-owner prune when removed id was selected | state.revisions.document, state.revisions.selection if pruned; internal structural, bounds, elementVisual, projection | remove id | evict | main | none |
| command removeElement | registry/layer membership, plus selection-owner prune when removed id was selected | state.revisions.document, state.revisions.selection if pruned; internal structural, bounds, elementVisual, projection | remove id | evict | main | deleteElements if removed; `runtime_created_timestamps_monotonic` |
| ensureLayer no-op | none | none | none | none | none | none |
| ensureLayer changed | layer table/order | state.revisions.document; internal structural, projection | no | evict | main | none |
| setSelection/toggleSelection/clearSelection/selectAll | selection owner | state.revisions.selection | none | no | main | none |
| marquee commit | selection owner | state.revisions.selection, state.revisions.preview if active preview cleared | none | no | main + overlay cleanup | selectMarquee if changed; `runtime_created_timestamps_monotonic` |
| selected move preview | preview only | state.revisions.preview | none | no | main only | none |
| selected move commit | transforms | state.revisions.document, state.revisions.preview if active preview cleared; internal bounds, elementVisual, projection | touched update | evict | main + preview cleanup | moveSelection; resolver request timestamp proof `runtime_created_timestamps_monotonic` |
| rotate/flip selection | transforms | state.revisions.document; internal bounds, elementVisual, projection | touched update | evict | main | transformSelection; `runtime_created_timestamps_monotonic` |
| deleteSelection | elements/layers plus selection-owner prune | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection | remove ids | evict | main | deleteElements; `runtime_created_timestamps_monotonic` |
| CanvasEdit.clearContent | elements, selection-owner clear, resources when removeUnusedResources removes descriptors | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection, resource | rebuild empty | evict | main | none |
| command clearContent | elements, selection-owner clear, resources when removeUnusedResources removes descriptors | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection, resource | rebuild empty | evict | main | clearContent if removed; `runtime_created_timestamps_monotonic` |
| CanvasEdit.setCameraOffset | persisted document camera | state.revisions.document; internal projection | no | evict | no immediate view-camera repaint unless current view is explicitly reinitialized by load | none |
| CanvasCameraPort.setOffset/panBy | runtime view camera | state.revisions.viewCamera | no | no | main + overlay | none |
| setBackgroundColor | persisted background metadata | state.revisions.document; internal backgroundRevision, projection | no | evict | main | none |
| setGrid | persisted grid metadata | state.revisions.document; internal gridRevision, projection | no | evict | main | none |
| setPalette | meta | state.revisions.document; internal projection | no | evict | no canvas repaint | none |
| upsertResource new/changed | resource table | state.revisions.document; internal resource, projection | no | evict | main if used | none |
| removeUnusedResource removed | resource table | state.revisions.document; internal resource, projection | no | evict | main if used by stale resource visuals only | none |
| markResourceDirty/markAllResourcesDirty | cache only | state.revisions.resourceVisual | no | no | main | none |
| setMode/setDrawStyle/setDrawTool/setDrawColor/setPointerPolicy | interaction settings | state.revisions.interaction, state.revisions.selection if draw-mode entry clears selection, state.revisions.preview if active preview cleared | none | no | main/overlay only for changed affected state | none |
| CanvasToolPort.handlePointer dispatcher | validates/routes pointer sample to selection, move, draw, line, eraser, context-tap, or cleanup rows | none by itself | none by itself | none by itself | none by itself | none by itself |
| loadDocumentFromJson success | whole document plus selection-owner clear, prepared interaction cleanup outcome, runtime view camera initialized from persisted document camera | state.revisions.document, state.revisions.selection, state.revisions.preview if active preview cleared, state.revisions.viewCamera, state.revisions.epoch; internal document-level revisions | rebuild | evict | main + overlay | none |
| loadDocumentFromJson failure | none | none | none | none | none | none |
| CanvasEdit.replaceDraftDocument | whole draft document plus selection-owner clear if current selection references replaced content | state.revisions.document, state.revisions.selection if cleared, state.revisions.epoch; internal document-level revisions | rebuild | evict | main | none |
| pencil/marker preview | preview only | state.revisions.preview | none | no | overlay | none |
| pencil/marker commit | add stroke | state.revisions.document, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | add id | evict | main + overlay cleanup | drawPencil/drawMarker; `runtime_created_timestamps_monotonic` |
| line first tap | preview pending | state.revisions.preview | none | no | overlay | none; timestamped preview `runtime_created_timestamps_monotonic` |
| line first drag | preview line, then terminal add line on up | state.revisions.preview during preview; state.revisions.document and state.revisions.preview cleanup on commit | add id on commit | evict on commit | overlay while previewing; main + overlay cleanup on commit | drawLine on commit; `runtime_created_timestamps_monotonic` |
| line preview | preview line | state.revisions.preview | none | no | overlay | none |
| line commit | add line | state.revisions.document, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | add id | evict | main + overlay cleanup | drawLine; `runtime_created_timestamps_monotonic` |
| eraser preview | preview corridor | state.revisions.preview | none | no | overlay | none |
| eraser commit | removed elements plus selection-owner prune when erased ids intersect selection | state.revisions.document, state.revisions.selection if pruned, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | remove ids | evict | main + overlay cleanup | erase if removed; `runtime_created_timestamps_monotonic` |
| context-action double-tap request | unsupported direct double tap has no touched state; direct `handleDoubleTap` clears pending context tap history before candidate-admitted current-target resolution; InteractionRequestRegistry stores live context request target kind and guard facts | none for unsupported direct double tap; none for context-action request delivery | none | no | none | asynchronous CanvasContextActionRequested with `runtime_created_timestamps_monotonic` |
| commitTextEdit stale rejection | consume/remove live request facts only when the request id is known and rejected; otherwise none | none | none | no | none | none |
| commitTextEdit no-op accepted | consume/remove live request facts | none | none | no | none | none |
| commitTextEdit changed accepted | text element content through EditKernel plus consume/remove live request facts after successful prepare | state.revisions.document; internal bounds when layout bounds change, elementVisual, projection | touched update when text layout bounds change; none otherwise | evict | main | editText; `runtime_created_timestamps_monotonic` |
| no-op edit | none | none | none | none | none | none |
| dispose with active preview | preview cleanup and terminal runtime state | state.revisions.preview before dispose returns | none | no | overlay cleanup | stream close only |
| dispose without active preview | terminal runtime state only | none | none | no | none | stream close only |

Notes:

```text
- Any row that changes a public revision publishes one coherent
  `CanvasRuntimeState` after the owning operation succeeds.
- setPalette changes document state and projection, so `state.revisions.document`
  advances after atomic install.
- Palette UI repaint outside the canvas is the application's responsibility.
- markResourceDirty uses main to mean main repaint intent; an attached
  CanvasSurface observes that intent if present.
- Selection-only rows affect the internal selection owner and do not increment
  `state.revisions.document`, evict projection, or update spatial indexes.
- Rows that touch both document content and selection publish one atomic
  `CanvasRuntimeState` through the runtime/applier boundary.
- Edit-backed document rows may execute through the ordinary sparse route or
  through explicit materialized fallback after `readDraftDocument` or
  `replaceDraftDocument`. The row outcomes do not change: both implementations
  must compile the same revision families, touched-set categories, selection
  effects, projection invalidation, repaint intent, and action/no-action
  behavior.
- Runtime view camera rows do not mutate persisted document camera and do not
  invalidate public document projection. Persisted camera edits remain document
  edits through `CanvasEdit.setCameraOffset`.
- No-op operations publish no current public state snapshot.
- `CanvasToolPort.handlePointer` is the public pointer dispatcher boundary. It
  validates and routes the pointer sample, but has no standalone document,
  selection, preview, spatial, projection, repaint, or event effect. Terminal
  effects are defined only by the selected tool row: marquee, selected move,
  pencil/marker, line, eraser, context-action tap, or cleanup/no-op.
- Context-action double-tap request emits `CanvasContextActionRequested` with
  `CanvasInteractionRequestId`, `CanvasContextActionTrigger.doubleTap`,
  controller epoch, document revision, timestamp, view/world positions, and
  either a content-element target or empty-canvas target. Direct
  `CanvasToolPort.handleDoubleTap` is a host-recognized input that does not
  require pending first-tap history; pointer-sample recognition remains a
  separate two-tap path. Content targets carry an immutable public
  `CanvasElement` snapshot and boundsWorld; empty-canvas targets carry no
  element snapshot. Delivery is asynchronous through the context request stream.
  Rejected invalid-index, stale-index, and budget-exceeded target reads emit no
  request; stale and budget rejected reads record bounded interaction
  diagnostics, while invalid-index rejected reads record none. Request delivery
  itself has no document, selection, preview, repaint, spatial, projection,
  resource, or action effect.
- `commitTextEdit` rejects stale request ids by request id, controller epoch,
  target kind, element generation, elementRevision, missing element,
  empty-canvas target, non-text target, and current text-family mismatch.
  `documentRevision` is observation-only; unrelated document edits do not
  reject a still-current text edit.
- For `commitTextEdit` stale rejection, known live rejected request ids are
  consumed and removed from InteractionRequestRegistry, while unknown or
  already-consumed ids do nothing. That private registry consumption does not
  publish public
  `CanvasRuntimeState` and has no document, selection, preview, spatial,
  projection, resource, repaint, or action effect.
- `commitTextEdit` validates `newText` before request consumption and before
  draft mutation. Changed text commits consume the request only after successful
  EditKernel prepare and before public delivery, then emit
  `CanvasActionType.editText` with
  `CanvasTextEditActionPayload`; the payload contains text lengths and never
  raw text.
- Changed text commits may update the target text element transform to preserve
  the resolved horizontal text anchor and top edit edge when measured text
  bounds change.
- Bounds-affecting text layout changes must compile `boundsRevision` and touched
  spatial updates just like other geometry/bounds edits.
- Rows that name `runtime_created_timestamps_monotonic` resolve timestampMs
  through the public runtime timestamp contract before publishing the
  timestamped action, request, preview, or resolver request output. Preview and
  resolver request rows remain non-user-action outputs.
- Action rows emit only after the accepted state for the same operation has
  been installed and published. No-op, stale, invalid, cancel, resolver cancel,
  rollback, load cleanup, dispose cleanup, unknown text request ids, and
  unsupported double tap do not resolve action/request timestamps and emit no
  action or context request.
```

### Compact row expanded dimensions

Every row in the main operation table that does not have its own heading under
`Operation row details` is machine-checked by combining the row cells with the
defaults below. A row-detail block overrides these defaults only for the named
operation or alias.

Touched state: the row's `State touched` cell.

Public state revisions: every `state.revisions.*` token in the row's
`Revisions` cell, or `none` when that cell is `none`.

Internal revisions: every internal revision token in the row's `Revisions`
cell, or `none` when that cell is `none`. If the cell points to a named owner
such as the `Element update field-effect taxonomy` or document-level revisions,
the executable check must resolve that owner and assert the internal revisions
enumerated there.

Spatial effect: the row's `Spatial` cell.

Projection effect: the row's `Projection` cell.

Resource effect: `none` unless the row's touched state or revision cells name
resource table, resource descriptor, resource cache, resourceVisual, dirty
resource, resolver, or surface resource session effects. When they do, the
resource effect is limited to the named resource state and does not imply a
document resource descriptor mutation unless the row says `resource table` or
`resource descriptor`. If the row points to a named owner such as the
`Element update field-effect taxonomy`, the executable check must resolve that
owner and assert the resource effects enumerated there.

Repaint target: the row's `Repaint` cell.

User-action notification: the row's `Events` cell.

No-op behavior: successful no-op paths publish no public state snapshot and
produce no spatial, projection, resource, repaint, or event effects unless the
row explicitly names state touched for that no-op, such as request consumption.
Rows with no successful no-op path treat validation failure, stale handle,
nested/async edit rejection, and callback failure as rollback rather than no-op.

Rollback behavior: the edit rollback contract applies to edit-backed rows. For
runtime rows outside an edit callback, failed validation or rejection leaves the
row's touched state, revisions, spatial state, projection, resource state,
repaint, user-action notifications, and public state publication unchanged.

### Operation row details

The row-detail blocks below are the machine-checkable operation aliases for
public operations that otherwise share a grouped row. Edit-backed aliases use
the edit rollback contract. Runtime aliases outside an edit callback use the
runtime rejection and validation behavior stated in their own
`Rollback behavior:` label.

#### removeUnusedResource

Touched state: resource descriptor table when the resource exists and no
background or content element references it.

Public state revisions: `state.revisions.document` when removed.

Internal revisions: `resourceRevision`, `projectionRevision`.

Spatial effect: none.

Projection effect: evict public document projection when removed.

Resource effect: remove the unused descriptor and invalidate descriptor cache
state for that id.

Repaint target: main only if an attached surface still has stale visual cache
state for the removed descriptor.

User-action notification: none.

No-op behavior: returns false and publishes no state when the id is missing or
still referenced.

Rollback behavior: descriptor table, document revision, projection, resource
cache, repaint, and notifications remain unchanged.

#### replaceDraftDocument

Owner coverage: staged load owns this executable edit-session replacement row.
`CanvasEdit.replaceDraftDocument` replaces the whole draft document through the
edit commit path.

Touched state: whole draft document; selection owner when replacement makes the
current selection invalid.

Public state revisions: `state.revisions.document`; `state.revisions.selection`
if selection is cleared; `state.revisions.epoch`.

Internal revisions: document-level revisions including controllerEpoch,
structural, resource, bounds, elementVisual, backgroundRevision, gridRevision,
and projectionRevision.

Spatial effect: rebuild from the replacement document.

Projection effect: evict public document projection.

Resource effect: replace descriptor table with the replacement document's
resource descriptors.

Repaint target: main.

User-action notification: none.

No-op behavior: replacing with an equivalent document is still a document
replacement inside the edit session and publishes the replacement effects.

Rollback behavior: original committed document, selection owner, epoch,
resources, spatial index, projection, repaint, and notifications remain
unchanged.

#### loadDocumentFromJson success

Touched state: whole document; selection owner clear; prepared interaction
cleanup outcome for preview cleanup when an active preview exists, pointer
normalization, and pending tap history; runtime view camera initialized from
persisted document camera.

Public state revisions: `state.revisions.document`, `state.revisions.selection`,
`state.revisions.viewCamera`, `state.revisions.epoch`, and
`state.revisions.preview` if active preview cleanup changed preview state.

Internal revisions: document-level revisions including controllerEpoch,
structural, resource, bounds, elementVisual, backgroundRevision, gridRevision,
projectionRevision, and previewRevision when preview cleanup changed preview
state.

Spatial effect: rebuild from the replacement document.

Projection effect: evict public document projection.

Resource effect: replace descriptor table with the loaded document's resource
descriptors, invalidate resource caches for the replacement, and clear
surface-session resource state that depends on the previous document.

Repaint target: main plus overlay.

User-action notification: none.

No-op behavior: no successful no-op path; validation/materialization failure is
covered by the `loadDocumentFromJson failure` row.

Rollback behavior: validation/materialization failure leaves active gesture,
preview, pending line, pointer normalization, committed document, selection,
runtime view camera, spatial state, projection, resources, repaint,
notifications, and public state publication unchanged.
After successful document install, runtime load publication consumes the already
prepared interaction cleanup outcome and does not call an interaction owner
boundary to finish cleanup.

#### toggleSelection

Touched state: selection owner.

Public state revisions: `state.revisions.selection` when normalized selected
ids change.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: main selection repaint.

User-action notification: none.

No-op behavior: no publication when the target id normalizes out and selection
does not change.

Rollback behavior: selection owner, repaint, and notifications remain
unchanged.

#### clearSelection

Touched state: selection owner.

Public state revisions: `state.revisions.selection` when a non-empty selection
is cleared.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: main selection repaint.

User-action notification: none.

No-op behavior: no publication when selection is already empty.

Rollback behavior: selection owner, repaint, and notifications remain
unchanged.

#### selectAll

Touched state: selection owner.

Public state revisions: `state.revisions.selection` when normalized selected
ids change.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: main selection repaint.

User-action notification: none.

No-op behavior: no publication when the parameter-dependent normalized target
selection equals the current selection; with default `onlySelectable=true`, the
target contains only eligible visible/selectable content elements.

Rollback behavior: selection owner, repaint, and notifications remain
unchanged.

#### setMode

Touched state: interaction settings; selection owner if entering draw mode
clears selection and `CanvasRuntimeConfig.clearSelectionOnDrawModeEnter` is
true; preview state if active preview is cleared.

Public state revisions: `state.revisions.interaction`;
`state.revisions.selection` if selection is cleared; `state.revisions.preview`
if preview is cleared.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: main and overlay only for affected changed state.

User-action notification: none.

No-op behavior: no publication when requested mode and cleanup result is
unchanged. Entering draw mode with `clearSelectionOnDrawModeEnter` false does
not clear selection; entering draw mode with the flag true clears selection
through the selection owner in the same public state as the mode change.

Rollback behavior: interaction settings, selection, preview, repaint, and
notifications remain unchanged.

#### setDrawStyle

Touched state: interaction settings.

Public state revisions: `state.revisions.interaction` when style changes.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: overlay only if a pending draw preview must reflect the changed
style; otherwise none.

User-action notification: none.

No-op behavior: no publication when style is unchanged.

Rollback behavior: interaction settings, repaint, and notifications remain
unchanged.

#### setDrawTool

Touched state: interaction settings; preview state if changing tool clears an
active tool preview.

Public state revisions: `state.revisions.interaction`;
`state.revisions.preview` if preview is cleared.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: overlay cleanup only when preview is cleared.

User-action notification: none.

No-op behavior: no publication when the tool is unchanged and no preview
cleanup is needed.

Rollback behavior: interaction settings, preview, repaint, and notifications
remain unchanged.

#### setDrawColor

Touched state: interaction settings.

Public state revisions: `state.revisions.interaction` when color changes.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: overlay only if a pending draw preview must reflect the changed
color; otherwise none.

User-action notification: none.

No-op behavior: no publication when color is unchanged.

Rollback behavior: interaction settings, repaint, and notifications remain
unchanged.

#### setPointerPolicy

Touched state: interaction settings.

Public state revisions: `state.revisions.interaction` when policy changes.

Internal revisions: none.

Spatial effect: none.

Projection effect: none.

Resource effect: none.

Repaint target: none.

User-action notification: none.

No-op behavior: no publication when policy is unchanged.

Rollback behavior: interaction settings, repaint, and notifications remain
unchanged.

#### markResourceDirty

Touched state: resource visual state for the requested resource id only.

Public state revisions: `state.revisions.resourceVisual` when target dirty
state changes.

Internal revisions: resourceVisualRevision.

Spatial effect: none.

Projection effect: none.

Resource effect: mark the requested resource id dirty and send target
invalidation to the active surface resource session if attached.

Repaint target: main.

User-action notification: none.

No-op behavior: no catalog hit means no `resourceVisualRevision`, no public
state publication, no repaint/effect delivery, and no action event.

Rollback behavior: resource visual state, session cache, repaint, and
notifications remain unchanged.

#### markAllResourcesDirty

Touched state: resource visual state only.

Public state revisions: `state.revisions.resourceVisual` when dirty-resource
state changes.

Internal revisions: resourceVisualRevision.

Spatial effect: none.

Projection effect: none.

Resource effect: mark all registered resources dirty and send all-resource
invalidation to the active surface resource session if attached.

Repaint target: main.

User-action notification: none.

No-op behavior: no publication when there is no registered resource visual
state to dirty.

Rollback behavior: resource visual state, session cache, repaint, and
notifications remain unchanged.

---
