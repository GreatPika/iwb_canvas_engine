<!-- CONTEXT:BEGIN -->
Registry id: `section_13_operation_matrix`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/contracts/operation_matrix.md`
Owns:
- 13. Operation matrix
Must read before editing:
- `section_11_edit_kernel` -> `docs/split/contracts/edit_kernel.md`
- `section_12_load_document` -> `docs/split/contracts/load_document.md`
- `section_23_tests` -> `docs/split/verification/tests.md`
Feeds phases:
- `P6`
Related donors:
- `interaction_mutation_boundary`
Related diagrams:
- `seq_edit_success`
- `seq_edit_rollback`
Required tests:
- `test.edit_kernel.sync_non_nested_async_stale`
Guardrails:
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
Do not assume:
- no implicit mutation path outside EditKernel
<!-- CONTEXT:END -->

## 13. Operation matrix

| Operation | State touched | Revisions | Spatial | Projection | Repaint | Events |
|---|---|---|---|---|---|---|
| addElement content | layer membership, registry, family row | document, structural, bounds, visual, projection | add id | evict | main | none |
| addBackgroundElement | background layer, registry, family row | document, structural, bounds, visual, projection | add paint only | evict | main | none |
| update visual only | family visual row | document, visual, projection | no | evict | main | none |
| update geometry/transform | family geometry/common transform | document, bounds, visual, projection | touched update | evict | main | none |
| CanvasEdit.removeElement | registry, layer membership, selection maybe | document, structural, bounds, visual, projection, selection if selected | remove id | evict | main | none |
| command removeElement | registry, layer membership, selection maybe | document, structural, bounds, visual, projection, selection if selected | remove id | evict | main | deleteElements if removed |
| ensureLayer no-op | none | none | none | none | none | none |
| ensureLayer changed | layer table/order | document, structural, projection | no | evict | main | none |
| setSelection | selection | selection | none | no | main | none |
| marquee commit | selection | selection | none | no | main | selectMarquee if changed |
| selected move preview | preview only | overlayRevision or movePreviewRevision | none | no | main only | none |
| selected move commit | transforms | document, bounds, visual, projection | touched update | evict | main + preview cleanup | moveSelection |
| rotate/flip selection | transforms | document, bounds, visual, projection | touched update | evict | main | transformSelection |
| deleteSelection | elements/layers/selection | document, structural, bounds, visual, projection, selection | remove ids | evict | main | deleteElements |
| CanvasEdit.clearContent | elements, selection, maybe resources | document, structural, bounds, visual, projection, selection, resource if requested | rebuild empty | evict | main | none |
| command clearContent | elements, selection, maybe resources | document, structural, bounds, visual, projection, selection, resource if requested | rebuild empty | evict | main | clearContent if removed |
| setCameraOffset | meta | document, visual | no | evict | main + overlay | none |
| setBackgroundColor | meta | document, visual, projection | no | evict | main | none |
| setGrid | meta | document, visual, projection | no | evict | main | none |
| setPalette | meta | document, projection | no | evict | none unless UI observes doc | none |
| upsertResource new/changed | resource table | document, resource, projection | no | evict | main if used | none |
| markResourceDirty | cache only | resourceVisualRevision | no | no | main | none |
| loadDocument success | whole document | all document-level + epoch | rebuild | evict | main + overlay | none |
| loadDocument failure | none | none | none | none | none | none |
| pencil/marker preview | preview only | overlayRevision | none | no | overlay | none |
| pencil/marker commit | add stroke | document, structural, bounds, visual, projection | add id | evict | main + overlay cleanup | drawPencil/drawMarker |
| line first tap | preview pending | overlayRevision | none | no | overlay | none |
| line preview | preview line | overlayRevision | none | no | overlay | none |
| line commit | add line | document, structural, bounds, visual, projection | add id | evict | main + overlay cleanup | drawLine |
| eraser preview | preview corridor | overlayRevision | none | no | overlay | none |
| eraser commit | removed elements | document, structural, bounds, visual, projection, selection maybe | remove ids | evict | main + overlay cleanup | erase if removed |
| no-op edit | none | none | none | none | none | none |

---

