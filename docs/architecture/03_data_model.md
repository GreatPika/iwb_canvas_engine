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
- `test.runtime.runtime_state_publication`
- `test.runtime.load_document_state_publication`
- `test.runtime.interaction_settings_state`
- `test.store.read_document_projection`
- `test.selection.runtime_owner_separation`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
Guardrails:
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
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
  admission: AdmissionState
  revisions: RevisionState
  projectionCache: DocumentProjectionCache
```

Selection is runtime view state owned by `SelectionKernel`, not committed
document content. `CommittedDocument` stores no selected ids, selected order, or
selection revision.

`DocumentMetaRecord` stores persisted document facts:

```text
persistedCameraOffset
backgroundColor
gridEnabled
gridCellSize
gridColor
palettePenColors
paletteBackgroundColors
paletteGridSizes
metadata (`CanvasMetadata` projection facts)
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

Runtime view camera is not stored in `CommittedDocument`. It is runtime state
owned by `RuntimeRoot` through the camera boundary. Runtime construction with an
initial document and `loadDocument` both initialize the runtime view camera from
`persistedCameraOffset`; `readDocument` projects the persisted camera, not the
current runtime view camera.

### 10.2 Revisions

```text
documentRevision        -> any committed document state change
controllerEpoch         -> loadDocument success or full document replacement
structuralRevision      -> element/layer/resource membership/order/family changes
resourceRevision        -> resource descriptor changes
resourceVisualRevision  -> markResourceDirty / resolver visual invalidation
boundsRevision          -> geometry/transform/hit/paint bounds changed
elementVisualRevision   -> element visual fields, element style fields, and transform-affecting paint changes
frameMetaRevision       -> persisted document background and grid changes, plus other document meta changes that affect frame capture/static frame caches
projectionRevision      -> public CanvasDocument projection invalidated
previewRevision         -> preview state changed
```

Public runtime observation is one immutable `CanvasRuntimeState` snapshot. The
runtime root publishes a new snapshot only after an accepted runtime-visible
change has reached its owning boundary. `state.revisions` exposes the stable
public domains `document`, `selection`, `preview`, `viewCamera`,
`resourceVisual`, `interaction`, and `epoch`; internal cache/projection
revisions remain private. `state.summary` exposes runtime counts from the same
moment and does not duplicate revision or epoch fields.

`SelectionKernel` owns `selectionRevision`. Selection-only changes increment
`selectionRevision`, schedule the selection UI repaint needed by the runtime,
and do not increment `documentRevision`, evict `DocumentProjectionCache`, or
update `SpatialKernel`. Operations that remove or replace document content may
also produce a selection-prune or selection-clear effect, but the document and
selection effects are published as one atomic `CanvasRuntimeState`.

Runtime view camera changes increment the public `state.revisions.viewCamera`,
schedule the affected surface repaint, and do not increment `documentRevision`,
evict `DocumentProjectionCache`, or change persisted document camera state.
Persisted document camera changes are ordinary document edits through
`CanvasEdit.setCameraOffset`; they increment `documentRevision`, invalidate the
public document projection, and are visible through `readDocument`.

`frameMetaRevision` is the v1 aggregate for frame-affecting persisted document
meta such as background and grid. It may later be split into background and grid
revision families without changing the public API. Paint-plan cache keys must
depend on `elementVisualRevision`, not `frameMetaRevision`; background/grid and
runtime view-camera changes repaint frame surfaces but must not invalidate
ordinary committed element paint plans.
In short: v1 aggregate, may split later without public API changes.

No-op edit does not change revisions. Preview cleanup increments
`previewRevision` only when it clears or replaces existing preview state; a
cleanup request against already-empty preview state is a no-op. Effects-only
action without state change is not used in v1. No-op runtime operations do not
publish a new `CanvasRuntimeState`.

Interaction setting changes such as mode, draw style, active draw tool, draw
color, and pointer policy increment the public `state.revisions.interaction`
without changing document revision. Preview-producing pointer changes increment
`state.revisions.preview`. Resource dirty operations increment
`state.revisions.resourceVisual`.

After `CanvasRuntime.dispose()` returns, `state` is a terminal read handle.
`state.value` remains readable and exposes the final runtime snapshot. Dispose
does not increment the committed document revision. During the first dispose
call, `state` may notify only if active preview cleanup advances
`state.revisions.preview`; no state notifications may be delivered after
dispose returns. Listener owners remain responsible for removing listeners they
registered.

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

Projection DTOs must deep-copy all public collections and materialize frozen
`CanvasMetadata` values. Runtime tables may store compact metadata facts, but
raw metadata maps are not exposed as ordinary public DTO metadata.

---
