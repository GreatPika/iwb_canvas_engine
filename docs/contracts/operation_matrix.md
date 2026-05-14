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
| addElement content | layer membership, registry, family row | document, structural, bounds, elementVisual, projection | add id | evict | main | none |
| addBackgroundElement | background layer, registry, family row | document, structural, bounds, elementVisual, projection | add paint only | evict | main | none |
| update visual only | family visual row | document, elementVisual, projection | no | evict | main | none |
| update geometry/transform | family geometry/common transform | document, bounds, elementVisual, projection | touched update | evict | main | none |
| CanvasEdit.removeElement | registry, layer membership, selection when removed id was selected | document, structural, bounds, elementVisual, projection, selection if selected | remove id | evict | main | none |
| command removeElement | registry, layer membership, selection when removed id was selected | document, structural, bounds, elementVisual, projection, selection if selected | remove id | evict | main | deleteElements if removed |
| ensureLayer no-op | none | none | none | none | none | none |
| ensureLayer changed | layer table/order | document, structural, projection | no | evict | main | none |
| setSelection | selection | selection | none | no | main | none |
| marquee commit | selection | selection, previewRevision if active preview cleared | none | no | main + overlay cleanup | selectMarquee if changed |
| selected move preview | preview only | previewRevision | none | no | main only | none |
| selected move commit | transforms | document, bounds, elementVisual, projection, previewRevision if active preview cleared | touched update | evict | main + preview cleanup | moveSelection |
| rotate/flip selection | transforms | document, bounds, elementVisual, projection | touched update | evict | main | transformSelection |
| deleteSelection | elements/layers/selection | document, structural, bounds, elementVisual, projection, selection | remove ids | evict | main | deleteElements |
| CanvasEdit.clearContent | elements, selection, resources when removeUnusedResources removes descriptors | document, structural, bounds, elementVisual, projection, selection, resource if descriptors removed | rebuild empty | evict | main | none |
| command clearContent | elements, selection, resources when removeUnusedResources removes descriptors | document, structural, bounds, elementVisual, projection, selection, resource if descriptors removed | rebuild empty | evict | main | clearContent if removed |
| setCameraOffset | meta | document, frameMeta, projection | no | evict | main + overlay | none |
| setBackgroundColor | meta | document, frameMeta, projection | no | evict | main | none |
| setGrid | meta | document, frameMeta, projection | no | evict | main | none |
| setPalette | meta | document, projection | no | evict | none unless UI observes doc | none |
| upsertResource new/changed | resource table | document, resource, projection | no | evict | main if used | none |
| markResourceDirty | cache only | resourceVisualRevision | no | no | main | none |
| loadDocument success | whole document | all document-level + epoch, previewRevision if active preview cleared | rebuild | evict | main + overlay | none |
| loadDocument failure | none | none | none | none | none | none |
| pencil/marker preview | preview only | previewRevision | none | no | overlay | none |
| pencil/marker commit | add stroke | document, structural, bounds, elementVisual, projection, previewRevision if active preview cleared | add id | evict | main + overlay cleanup | drawPencil/drawMarker |
| line first tap | preview pending | previewRevision | none | no | overlay | none |
| line preview | preview line | previewRevision | none | no | overlay | none |
| line commit | add line | document, structural, bounds, elementVisual, projection, previewRevision if active preview cleared | add id | evict | main + overlay cleanup | drawLine |
| eraser preview | preview corridor | previewRevision | none | no | overlay | none |
| eraser commit | removed elements | document, structural, bounds, elementVisual, projection, selection if erased ids intersect selection, previewRevision if active preview cleared | remove ids | evict | main + overlay cleanup | erase if removed |
| no-op edit | none | none | none | none | none | none |

---
