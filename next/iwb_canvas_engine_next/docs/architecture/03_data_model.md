<!-- CONTEXT:BEGIN -->
Registry id: `section_10_runtime_data_model`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/03_data_model.md`
Owns:
- 10. Runtime data model
Must read before editing:
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
Feeds phases:
- `P5`
- `P6`
- `P8`
Related donors:
- `dto_document_helpers`
- `store_scene_controller_read_paths`
- `dto_node_boundary_mapping`
Related diagrams:
- `c4_component_runtime`
- `dfd_cache_invalidation`
Required tests:
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
Guardrails:
- `core.single_runtime_root`
Do not assume:
- no legacy mutable runtime graph
- no SceneController shape dependency
<!-- CONTEXT:END -->

## 10. Runtime data model

### 10.1 Committed document

`DocumentStoreKernel` does not store public `CanvasDocument` as live mutable state. It stores compact committed tables.

```text
CommittedDocument
  meta: DocumentMetaRecord
  resources: ResourceTable
  backgroundLayer: ElementOrderList
  layerTable: LayerTable
  elementRegistry: ElementRegistry
  familyTables: FamilyTables
  selection: SelectionStore
  admission: AdmissionState
  revisions: RevisionState
  projectionCache: DocumentProjectionCache
```

`DocumentMetaRecord`:

```text
cameraOffset
backgroundColor
gridEnabled
gridCellSize
gridColor
palettePenColors
paletteBackgroundColors
paletteGridSizes
metadata
```

`ElementRegistry`:

```text
CanvasElementId -> ElementHandle
ElementHandle:
  id
  generation
  family
  locationKind: background | content
  layerId?
  orderToken
  rowIndex
  elementRevision
  structuralRevision
  boundsRevision
```

`FamilyTables`:

```text
ImageRows
PathRows
TextRows
StrokeRows
LineRows
RectRows
```

Each row table stores only family-specific fields plus common packed fields needed by render/hit/update. Public DTOs are projections.

### 10.2 Revisions

```text
documentRevision        -> any committed document state change
controllerEpoch         -> loadDocument success or full document replacement
structuralRevision      -> element/layer/resource membership/order/family changes
resourceRevision        -> resource descriptor changes
resourceVisualRevision  -> markResourceDirty / resolver visual invalidation
selectionRevision       -> selected ids changed
boundsRevision          -> geometry/transform/hit/paint bounds changed
visualRevision          -> visual fields/camera/background/grid/style changed
projectionRevision      -> public CanvasDocument projection invalidated
overlayRevision         -> preview state changed
```

No-op edit does not change revisions. Preview cleanup increments
`overlayRevision` only when it clears or replaces existing preview state; a
cleanup request against already-empty preview state is a no-op. Effects-only
action without state change is not used in v1.

### 10.3 Public document projection

`DocumentProjectionCache` policy:

```text
- lazy;
- one retained CanvasDocument per projectionRevision;
- never built in pointer move;
- never built in hit-test;
- never built in main paint;
- never built in overlay paint;
- built only by readDocument, encodeCanvasDocument, tests/tools, or explicit edit.readDraftDocument.
```

Projection DTOs must deep-copy all public collections and metadata.

---
