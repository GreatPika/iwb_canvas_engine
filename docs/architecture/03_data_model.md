<!-- CONTEXT:BEGIN -->
Registry id: `section_10_runtime_data_model`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/03_data_model.md`
Owns:
- 10. Runtime data model
Must read before editing:
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
Feeds phases:
- `P4`
- `P5`
- `P6`
- `P7`
- `P8`
- `P9`
Related donors:
- `dto_document_helpers`
- `store_scene_controller_read_paths`
- `dto_node_boundary_mapping`
Related diagrams:
- `c4_component_runtime`
- `dfd_cache_invalidation`
Required tests:
- `test.runtime.dispose_lifecycle`
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
Guardrails:
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `projection.only_explicit_read_paths`
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
elementVisualRevision   -> element visual fields, element style fields, and transform-affecting paint changes
frameMetaRevision       -> camera, background, and grid changes that affect frame capture/static frame caches
projectionRevision      -> public CanvasDocument projection invalidated
previewRevision         -> preview state changed
```

`frameMetaRevision` is the v1 aggregate for frame-affecting document meta. It may
later be split into `cameraRevision`, `backgroundRevision`, and `gridRevision`
without changing the public API. Paint-plan cache keys must depend on
`elementVisualRevision`, not `frameMetaRevision`; camera/background/grid changes
repaint frame surfaces but must not invalidate ordinary committed element paint
plans.
In short: v1 aggregate, may split later without public API changes.

No-op edit does not change revisions. Preview cleanup increments
`previewRevision` only when it clears or replaces existing preview state; a
cleanup request against already-empty preview state is a no-op. Effects-only
action without state change is not used in v1.

After `CanvasRuntime.dispose()` returns, public revision listenables are
terminal read handles. `documentRevisionListenable.value` and
`previewRevisionListenable.value` remain readable and expose the final revisions.
Dispose does not increment the committed document revision or notify
`documentRevisionListenable` listeners. `previewRevisionListenable` may notify
during the first dispose call only if active preview cleanup advances
`previewRevision`; no revision listenable may notify after dispose returns.
Listener owners remain responsible for removing listeners they registered.

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
