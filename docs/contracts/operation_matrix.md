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
Related diagrams:
- `seq_edit_success`
- `seq_edit_rollback`
Required tests:
- `test.edit.sync_non_nested_async_stale`
- `test.edit.edit_matrix_effects`
- `test.edit.net_no_op_edit_commit`
- `test.store.store_commit_finalization`
- `test.api.runtime_timestamp_order`
- `test.interaction.runtime_created_timestamps_monotonic`
- `test.interaction.context_action_request`
- `test.interaction.text_edit_stale_commit_guard`
- `test.resources.application_vector_freshness_lifecycle`
Guardrails:
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `events.commands_emit_user_actions`
- `events.runtime_created_timestamps_monotonic`
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
| CanvasEdit.removeEmptyLayer | only an existing ordinary layer that is currently empty at the `removeEmptyLayer` call; absent/nonempty are no-ops and do not delete elements, background, or resources | state.revisions.document; internal structural, projection only when removed | no | evict only when removed | main only when removed | none |
| CanvasEdit.setSelection | callback-local desired ids filtered by Store final-candidate membership, then Selection equality/revision/install | state.revisions.selection only when normalized membership changes; state.revisions.document is unchanged for selection-only edits | none | no | main | none |
| setSelection/toggleSelection/clearSelection/selectAll | selection owner | state.revisions.selection | none | no | main | none |
| marquee commit | selection owner | state.revisions.selection, state.revisions.preview if active preview cleared | none | no | RuntimeRoot closes the edit result, suppresses cleanup publication, merges main + overlay repaint, then common delivery | selectMarquee after public state if changed; `runtime_created_timestamps_monotonic` |
| selected move preview | immutable gesture participant basis plus delta-only preview | state.revisions.preview | none | no | main only; Frame shifts only captured participants | none |
| selected move commit | retained participant transforms | state.revisions.document, state.revisions.preview if active preview cleared; internal bounds, elementVisual, projection | touched update | evict | Accepted participant touches, same-ID replacement, document replacement, or external selection outcome clear the session before public delivery; unrelated/no-op edits retain it. RuntimeRoot resolves configured move callbacks before the shared Runtime-local transform/action preparation; after closed apply it performs publish-false main cleanup before common delivery | moveSelection after public state; `runtime_created_timestamps_monotonic` |
| rotate/flip selection | immutable current command participants, final pivoted world transform | state.revisions.document; internal bounds, elementVisual, projection | touched update | evict | RuntimeRoot sends command facts directly through the same Runtime-local transform/action preparation as selected Move; commands remain resolver-exempt | transformSelection; `runtime_created_timestamps_monotonic` |
| deleteSelection | eligible selected elements/layers plus selection-owner prune after guarded resolver acceptance | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection | remove canonical Store entry ids | evict | prepare full sparse/selection/revision/action state before required resolver; accept installs bound Store then owned Selection once; cancel/error discard without commit | deleteElements after accepted state; `runtime_created_timestamps_monotonic` |
| CanvasEdit.clearContent | every ordinary-layer element; selection-owner prunes removed content; only actually unused descriptors when requested; layers, background/grid, and ordered background elements remain | actual element/resource/selection changes only: state.revisions.document and selection when changed; internal structural, bounds, elementVisual, projection, resource only for their actual domains; background/grid unchanged | zero post-clear frame -> empty reset; otherwise normal committed-frame touched rebuild/update retains background paint entries | evict when accepted state changes | actual accepted clear repaint | none |
| command clearContent | same layer-only clear scope and actual selection/resource effects as CanvasEdit.clearContent | same actual revision domains as CanvasEdit.clearContent | zero post-clear frame -> empty reset; otherwise normal committed-frame touched rebuild/update retains background paint entries | evict when accepted state changes | actual accepted clear repaint | clearContent only for actual removed elements, with accepted removal ids; resource-only cleanup and background-only no-op emit none; `runtime_created_timestamps_monotonic` |
| CanvasEdit.setCameraOffset | persisted document camera | state.revisions.document; internal projection | no | evict | no immediate view-camera repaint unless current view is explicitly reinitialized by load | none |
| CanvasCameraPort.setOffset/panBy | runtime view camera | state.revisions.viewCamera | no | no | main + overlay | none |
| setBackgroundColor | persisted background metadata | state.revisions.document; internal backgroundRevision, projection | no | evict | main | none |
| setGrid | persisted grid metadata | state.revisions.document; internal gridRevision, projection | no | evict | main | none |
| CanvasEdit.updateGrid | supplied non-null fields replace the latest callback-local complete grid fields; null fields remain | same as `setGrid` when the final grid differs; none for all-null, locally equal, or compensating final equality | no | evict only for an accepted changed final grid | main | none |
| setPalette | meta | state.revisions.document; internal projection | no | evict | no canvas repaint | none |
| CanvasEdit.updatePalette | supplied fields replace the latest callback-local complete palette fields; omitted fields remain | same as `setPalette` when the final palette differs; none for all-absent, locally equal, or compensating final equality | no | evict only for an accepted changed final palette | no canvas repaint | none |
| upsertResource new/changed | resource table | state.revisions.document; internal resource, projection | no | evict | main if used | none |
| removeUnusedResource removed | resource table | state.revisions.document; internal resource, projection | no | evict | main if used by stale resource visuals only | none |
| markResourceDirty/markAllResourcesDirty | active session/output resource borrows only | state.revisions.resourceVisual | no | no | main | none |
| setMode/setDrawStyle/setDrawTool/setDrawColor/setPointerPolicy | interaction settings | state.revisions.interaction, state.revisions.selection if draw-mode entry clears selection, state.revisions.preview if active preview cleared | none | no | main/overlay only for changed affected state | none |
| CanvasToolPort.handlePointer dispatcher | validates/routes pointer input to selection, move, draw, line, eraser, context-tap, or cleanup rows | none by itself | none by itself | none by itself | none by itself | none by itself |
| loadDocumentFromJson success | whole document plus selection-owner clear, prepared interaction cleanup outcome, runtime view camera initialized from persisted document camera | state.revisions.document, state.revisions.selection, state.revisions.preview if active preview cleared, state.revisions.viewCamera, state.revisions.epoch; internal document-level revisions | rebuild | evict | main + overlay | none |
| loadDocumentFromJson failure | none | none | none | none | none | none |
| CanvasEdit.replaceDraftDocument | whole draft document plus implicit selection-owner validity behavior, or an explicit staged CanvasEdit.setSelection intent normalized against the replacement | state.revisions.document, state.revisions.selection if the resulting membership changes, state.revisions.epoch; internal document-level revisions | rebuild | evict | main | none |
| pencil/marker preview | preview only | state.revisions.preview | none | no | overlay | none |
| pencil/marker commit | add stroke | state.revisions.document, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | accepted Store-ledger admission reserves the RuntimeRoot-read candidate; failed/no-op preparation leaves it next | evict | closed apply -> publish-false cleanup/effect merge -> common delivery, main + overlay | drawPencil/drawMarker after public state; `runtime_created_timestamps_monotonic` |
| line first tap | preview pending | state.revisions.preview | none | no | overlay | none; timestamped preview `runtime_created_timestamps_monotonic` |
| line first drag | preview line, then terminal add line on up | state.revisions.preview during preview; state.revisions.document and state.revisions.preview cleanup on commit | accepted Store-ledger admission reserves the RuntimeRoot-read candidate; failed/no-op preparation leaves it next | evict on commit | overlay while previewing; main + overlay cleanup on commit | drawLine on commit; `runtime_created_timestamps_monotonic` |
| line preview | preview line | state.revisions.preview | none | no | overlay | none |
| line commit | add line | state.revisions.document, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | accepted Store-ledger admission reserves the RuntimeRoot-read candidate; failed/no-op preparation leaves it next | evict | closed apply -> publish-false cleanup/effect merge -> common delivery, main + overlay | drawLine after public state; `runtime_created_timestamps_monotonic` |
| eraser preview | preview corridor | state.revisions.preview | none | no | overlay | none |
| eraser commit | Unit-2 filtered canonical Store entries plus selection-owner prune after guarded resolver acceptance | state.revisions.document, state.revisions.selection if pruned, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | remove canonical entry ids | evict | prepare before resolver; accept installs bound Store then owned Selection once, completes eraser cleanup, then common delivery; cancel/error discard and clean without commit | erase after accepted state; `runtime_created_timestamps_monotonic` |
| context-action double-tap request | direct `handleDoubleTap` clears pending context tap history before current-target resolution; target admission requires a candidate spatial result with no unresolved/skipped handles; InteractionRequestRegistry stores live context request target kind and guard facts; pending delivery is suppressed by load/dispose cleanup | none for context-action request delivery | none | no | none | asynchronous CanvasContextActionRequested with `runtime_created_timestamps_monotonic` unless suppressed before scheduled delivery |
| commitTextEdit stale rejection | consume/remove live request facts only when the request id is known and rejected; otherwise none | none | none | no | none | none |
| commitTextEdit no-op accepted | consume/remove live request facts | none | none | no | none | none |
| commitTextEdit changed accepted | text element content through EditKernel; after successful prepare and EditKernel closure RuntimeRoot consumes/removes the live request, silently clears only a matching active text session and its owned suppression/candidate state, and records an interaction revision before capture; it completes guarded common delivery, releases the guard, then notifies matching-session closure before true return | state.revisions.document and, only for a matching active session, state.revisions.interaction; internal bounds when layout bounds change, elementVisual, projection | touched update when text layout bounds change; none otherwise | evict | main common delivery, then matching-session close notification; a listener may start another session without losing it | editText; `runtime_created_timestamps_monotonic` |
| no-op edit, including compensating final fact no-op | none | none | none | none | none | none |
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
  through explicit materialized fallback after `readDraftDocument`. Both routes
  finalize accepted committed facts in the store before edit plan compilation,
  so provisional operation journals cannot publish extra revision or touched
  families. Their row outcomes do not change: both implementations must compile
  the same revision families, touched-set categories, selection effects,
  projection invalidation, repaint intent, and action/no-action behavior.
- `replaceDraftDocument` is a separate forced-replacement route. It compiles
  from session replacement facts rather than store final equality and retains
  document-replacement effects even when the replacement has equal public
  content.
- Runtime view camera rows do not mutate persisted document camera and do not
  invalidate public document projection. Persisted camera edits remain document
  edits through `CanvasEdit.setCameraOffset`.
- No-op operations publish no current public state snapshot.
- `CanvasToolPort.handlePointer` is the public pointer dispatcher boundary. It
  validates and routes pointer input, but has no standalone document,
  selection, preview, spatial, projection, repaint, or event effect. Finite
  samples may reach selection, move, draw, line, eraser, or context-tap rows;
  terminal cleanup input reaches cleanup/no-op rows without normalized
  geometry. Terminal effects are defined only by the selected tool row:
  marquee, selected move, pencil/marker, line, eraser, context-action tap, or
  cleanup/no-op.
- `CanvasElementUpdate.isSelectable` changes spatial hit/selectable membership,
  so it is a spatial touched update even when selection normalization and repaint
  effects are otherwise no-ops.
- Context-action double-tap request emits `CanvasContextActionRequested` with
  `CanvasInteractionRequestId`, `CanvasContextActionTrigger.doubleTap`,
  controller epoch, document revision, timestamp, view/world positions, and
  either a content-element target or empty-canvas target. Direct
  `CanvasToolPort.handleDoubleTap` is a host-recognized input that is admitted
  independently from engine-owned pointer-sample context taps: it does not
  require pending first-tap history, move mode, or absence of an active pointer
  preview/session. Emitting the direct request does not clear active pointer
  preview/session state. Pointer-sample context taps remain a separate two-tap
  path guarded by move-mode and pointer-session policy. Content targets carry
  an immutable public
  `CanvasElement` snapshot and boundsWorld; empty-canvas targets carry no
  element snapshot. Delivery is asynchronous through the context request stream.
  Rejected invalid-index, stale-index, budget-exceeded, and unresolved/skipped
  candidate target reads emit no request. Stale, budget, and unresolved/skipped
  rejected reads record bounded interaction diagnostics, while invalid-index
  rejected reads record none. Accepted request delivery is suppressed if
  load/dispose cleanup runs before the scheduled stream emission. Request
  delivery itself has no document, selection, preview, repaint, spatial,
  projection, resource, or action effect.
- `commitTextEdit` rejects stale request ids by request id, controller epoch,
  target kind, element generation, elementRevision, missing element,
  empty-canvas target, vector/non-text target, and current text-kind mismatch.
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
  EditKernel prepare and closure, silently clear only a matching active session
  and its owned suppression/candidate state, and record the outer interaction
  revision before frame capture. Common delivery completes and releases its
  guard before that closure is notified. The listener observes the accepted
  document, consumed request, and null session; it may read final state,
  complete a separate accepted mutation, or start another session without the
  old closure clearing it. Listener errors follow Flutter notifier reporting and
  do not roll back or stop the outer delivery. A direct live-request commit
  without an active session still completes common delivery but has no close
  notification or interaction revision; rejected, failed, and equal-text
  branches do not enter this listener window. The outer route then emits
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
  timestamped action, request, or preview output. Preview rows remain
  non-user-action outputs.
- Action rows emit only after the accepted state for the same operation has
  been installed and published. No-op, stale, invalid, cancel, resolver cancel,
  resolver zero delta, resolver exception, selected-move edit-preparation
  failure, rollback, load cleanup, dispose cleanup, unknown text request ids,
  and invalid direct double tap do not resolve action/request timestamps and
  emit no action or context request.
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

For an accepted resource effect with an attached surface, RuntimeRoot invokes
the generic target/all release after spatial delivery and before root-frame,
bridged-frame, public-state, action, commit-effect, or listener notification.
The active session removes matching cache/suppression
borrows, then its identity-aware surface callback removes the matching retained
main-output borrow; a stale session proves absence and does not mutate current
output. Target release preserves unrelated bindings and overlay output, and
release neither calls the resolver nor disposes application-owned assets. A
later notification failure is contained after removal: accepted state,
revisions, repaint intent, operation return, and the no-borrow postcondition
still publish. Rejected and successful no-op rows mutate neither retention
owner.

Repaint target: the row's `Repaint` cell.

User-action notification: the row's `Events` cell.

No-op behavior: successful no-op paths publish no public state snapshot and
produce no spatial, projection, resource, repaint, or event effects unless the
row explicitly names state touched for that no-op, such as request consumption.
This includes compensating edit callbacks that temporarily change background,
camera, palette, elements, or resources and then restore the final committed
facts before acceptance. Rows with no successful no-op path treat validation
failure, stale handle, nested/async edit rejection, and callback failure as
rollback rather than no-op.

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

Resource effect: remove the unused descriptor and release matching target
session/output borrows for that id.

Repaint target: main only if an attached surface still has stale visual cache
state for the removed descriptor.

User-action notification: none.

No-op behavior: returns false and publishes no state when the id is missing or
still referenced.

Rollback behavior: descriptor table, document revision, projection, resource
cache, repaint, and notifications remain unchanged.

#### clearContent

Touched state: only actual ordinary-layer element removals, selection pruning
for removed content ids, and descriptors actually released by requested unused
resource cleanup. Background/grid values, their revision/touched domains,
ordered background elements, layer rows, and descriptors still referenced by
preserved background image/vector elements remain unchanged.

Public state revisions: `state.revisions.document` for an accepted element or
descriptor removal; `state.revisions.selection` only when selection loses a
removed content id.

Internal revisions: structural, bounds, elementVisual, projection, and resource
advance only for their accepted element/resource differences. Background and
grid revisions do not advance for clear.

Spatial effect: a genuinely zero-element committed post-clear frame may reset
the spatial index. A frame retaining background elements follows normal touched
rebuild/update from committed frame facts and keeps those elements available to
paint queries; this does not change hit or context eligibility.

Projection effect: evict public document projection when the accepted candidate
changes persisted elements or descriptors.

Resource effect: release only descriptors actually removed by requested unused
resource cleanup.

Repaint target: main for accepted clear effects.

User-action notification: low-level clear emits none. Command clear emits one
`clearContent` action only when its accepted result removes elements, and its
payload uses those accepted element/resource removal ids. A resource-only clear
emits no action.

No-op behavior: a background-only retained frame with no unused descriptors is
a no-op; it advances no revisions and emits no repaint, spatial, resource, or
action effect.

Rollback behavior: all candidate element/resource/selection decisions remain
atomic; no partial removal, revision, touched, repaint, or action effect is
published.

#### replaceDraftDocument

Owner coverage: staged load owns this executable edit-session replacement row.
`CanvasEdit.replaceDraftDocument` replaces the whole draft document through the
edit commit path.

Touched state: whole draft document; selection owner when replacement makes the
current selection invalid, unless the callback stages an explicit desired
selection which replaces that implicit result after final-document normalization.

Public state revisions: `state.revisions.document`; `state.revisions.selection`
if the resulting normalized membership changes; `state.revisions.epoch`.

Internal revisions: document-level revisions including controllerEpoch,
structural, resource, bounds, elementVisual, backgroundRevision, gridRevision,
and projectionRevision.

Spatial effect: rebuild from the replacement document.

Projection effect: evict public document projection.

Resource effect: replace descriptor table with the replacement document's
resource descriptors and release all previous session/output borrows.

Repaint target: main.

User-action notification: none.

No-op behavior: replacing with an equivalent document is still a forced
document replacement inside the edit session and publishes the replacement
effects. This exception applies only to explicit `replaceDraftDocument`, not to
ordinary sparse/materialized candidates that merely compensate back to the base
committed facts.

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
descriptors and release all previous session/output borrows before publication.

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
release to the active surface resource session if attached.

Repaint target: main.

User-action notification: none.

No-op behavior: no catalog hit means no `resourceVisualRevision`, no public
state publication, no repaint/effect delivery, and no action event.

Rollback behavior: resource visual state, session/output borrows, repaint, and
notifications remain unchanged.

#### markAllResourcesDirty

Touched state: resource visual state only.

Public state revisions: `state.revisions.resourceVisual` when dirty-resource
state changes.

Internal revisions: resourceVisualRevision.

Spatial effect: none.

Projection effect: none.

Resource effect: mark all registered resources dirty and send all-resource
release to the active surface resource session if attached.

Repaint target: main.

User-action notification: none.

No-op behavior: no publication when there is no registered resource visual
state to dirty.

Rollback behavior: resource visual state, session/output borrows, repaint, and
notifications remain unchanged.

---
