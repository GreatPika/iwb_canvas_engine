<!-- CONTEXT:BEGIN -->
Registry id: `section_13_operation_matrix`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/operation_matrix.md`
Owns:
- 13. Operation matrix
Must read before editing:
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
Feeds phases:
- `P5`
- `P6`
- `P7`
- `P10`
- `P11`
- `P12`
Related donors:
- `interaction_mutation_boundary`
Related diagrams:
- `seq_edit_success`
- `seq_edit_rollback`
Required tests:
- `test.edit.sync_non_nested_async_stale`
- `test.edit.operation_matrix_effects`
Guardrails:
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
Do not assume:
- no implicit mutation path outside EditKernel
<!-- CONTEXT:END -->

## 13. Operation matrix

Phase ownership:

```text
P5 closes edit-owned rows and the generic executable effect shape.
P6 closes the loadDocument success/failure rows after the staged load contract.
P7 and P10-P12 close their resource and interaction rows when those owners land.
```

| Operation | State touched | Revisions | Spatial | Projection | Repaint | Events |
|---|---|---|---|---|---|---|
| addElement content | layer membership, registry, family row | state.revisions.document; internal structural, bounds, elementVisual, projection | add id | evict | main | none |
| addBackgroundElement | background layer, registry, family row | state.revisions.document; internal structural, bounds, elementVisual, projection | add paint only | evict | main | none |
| update visual only | family visual row | state.revisions.document; internal elementVisual, projection | no | evict | main | none |
| update geometry/transform | family geometry/common transform | state.revisions.document; internal bounds, elementVisual, projection | touched update | evict | main | none |
| CanvasEdit.removeElement | registry/layer membership, plus selection-owner prune when removed id was selected | state.revisions.document, state.revisions.selection if pruned; internal structural, bounds, elementVisual, projection | remove id | evict | main | none |
| command removeElement | registry/layer membership, plus selection-owner prune when removed id was selected | state.revisions.document, state.revisions.selection if pruned; internal structural, bounds, elementVisual, projection | remove id | evict | main | deleteElements if removed |
| ensureLayer no-op | none | none | none | none | none | none |
| ensureLayer changed | layer table/order | state.revisions.document; internal structural, projection | no | evict | main | none |
| setSelection/toggleSelection/clearSelection/selectAll | selection owner | state.revisions.selection | none | no | main | none |
| marquee commit | selection owner | state.revisions.selection, state.revisions.preview if active preview cleared | none | no | main + overlay cleanup | selectMarquee if changed |
| selected move preview | preview only | state.revisions.preview | none | no | main only | none |
| selected move commit | transforms | state.revisions.document, state.revisions.preview if active preview cleared; internal bounds, elementVisual, projection | touched update | evict | main + preview cleanup | moveSelection |
| rotate/flip selection | transforms | state.revisions.document; internal bounds, elementVisual, projection | touched update | evict | main | transformSelection |
| deleteSelection | elements/layers plus selection-owner prune | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection | remove ids | evict | main | deleteElements |
| CanvasEdit.clearContent | elements, selection-owner clear, resources when removeUnusedResources removes descriptors | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection, resource | rebuild empty | evict | main | none |
| command clearContent | elements, selection-owner clear, resources when removeUnusedResources removes descriptors | state.revisions.document, state.revisions.selection; internal structural, bounds, elementVisual, projection, resource | rebuild empty | evict | main | clearContent if removed |
| CanvasEdit.setCameraOffset | persisted document camera | state.revisions.document; internal projection | no | evict | no immediate view-camera repaint unless current view is explicitly reinitialized by load | none |
| CanvasCameraPort.setOffset/panBy | runtime view camera | state.revisions.viewCamera | no | no | main + overlay | none |
| setBackgroundColor | persisted background metadata | state.revisions.document; internal backgroundRevision, projection | no | evict | main | none |
| setGrid | persisted grid metadata | state.revisions.document; internal gridRevision, projection | no | evict | main | none |
| setPalette | meta | state.revisions.document; internal projection | no | evict | no canvas repaint | none |
| upsertResource new/changed | resource table | state.revisions.document; internal resource, projection | no | evict | main if used | none |
| markResourceDirty/markAllResourcesDirty | cache only | state.revisions.resourceVisual | no | no | main | none |
| setMode/setDrawStyle/setDrawTool/setDrawColor/setPointerPolicy | interaction settings | state.revisions.interaction, state.revisions.selection if draw-mode entry clears selection, state.revisions.preview if active preview cleared | none | no | main/overlay only for changed affected state | none |
| loadDocument success | whole document plus selection-owner clear, preview cleanup, runtime view camera initialized from persisted document camera | state.revisions.document, state.revisions.selection, state.revisions.preview if active preview cleared, state.revisions.viewCamera, state.revisions.epoch; internal document-level revisions | rebuild | evict | main + overlay | none |
| loadDocument failure | none | none | none | none | none | none |
| pencil/marker preview | preview only | state.revisions.preview | none | no | overlay | none |
| pencil/marker commit | add stroke | state.revisions.document, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | add id | evict | main + overlay cleanup | drawPencil/drawMarker |
| line first tap | preview pending | state.revisions.preview | none | no | overlay | none |
| line preview | preview line | state.revisions.preview | none | no | overlay | none |
| line commit | add line | state.revisions.document, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | add id | evict | main + overlay cleanup | drawLine |
| eraser preview | preview corridor | state.revisions.preview | none | no | overlay | none |
| eraser commit | removed elements plus selection-owner prune when erased ids intersect selection | state.revisions.document, state.revisions.selection if pruned, state.revisions.preview if active preview cleared; internal structural, bounds, elementVisual, projection | remove ids | evict | main + overlay cleanup | erase if removed |
| text double-tap request | text edit request stream only | none | none | no | none | textEditRequested |
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
- Runtime view camera rows do not mutate persisted document camera and do not
  invalidate public document projection. Persisted camera edits remain document
  edits through `CanvasEdit.setCameraOffset`.
- No-op operations publish no new public state snapshot.
```

---
