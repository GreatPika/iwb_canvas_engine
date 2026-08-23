<!-- CONTEXT:BEGIN -->
Registry id: `section_10_runtime_data_model`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/03_data_model.md`
Owns:
- 10. Runtime data model
Must read before editing:
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
Current owners:
- `architecture`
Related diagrams:
- `c4_component_runtime`
- `dfd_cache_invalidation`
Required tests:
- `test.runtime.dispose_lifecycle`
- `test.runtime.runtime_state_publication`
- `test.runtime.load_document_state_publication`
- `test.resources.application_vector_freshness_lifecycle`
- `test.api.tool_port_settings`
- `test.store.read_document_projection`
- `test.selection.runtime_owner_separation`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
- `test.guardrails.store_projection_checks`
- `test.guardrails.selection_boundary_checks`
Guardrails:
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
- `projection.only_explicit_read_paths`
Do not assume:
- no mutable runtime graph bypass
- no implementation-owner dependency bypass
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

Sparse public edits prepare and install against these committed tables. Schema
v1 JSON load prepares replacement committed tables through the same store-owned
source of truth, but its input is dependency-neutral schema import events from
the codec-owned canonical schema v1 reader rather than public `CanvasDocument`.
The codec reader validates JSON/map wire format and emits import events;
`DocumentStoreKernel` consumes those events into prepared rows/tables, resource
descriptor rows, admitted-id facts, reference facts, revision facts, camera
facts, and projection invalidation facts before runtime install.

Sparse edit sessions record every successful pre-materialization operation once
as an unchanged `StoreSparseMutation` and ask `DocumentStoreKernel` to build
the accepted `CommittedDocument` snapshot before the irreversible swap. The
same ordered DTO list is the sole promotion input: explicit Draft
materialization traverses it once through Draft's exhaustive mutation consumer,
then discards it. Promotion does not build a committed public projection or
retain a closure/listener replay mirror. Sparse sessions now own separate lazy
indexed orders for layers, background elements, and each content layer, plus
one current `ElementLocationFacts` view seeded directly from the committed
store on first lookup. Local structural transitions replace that seed, so no
order list or placement override mirror remains. Sparse resource decisions read
the Store-owned committed image/vector summaries directly and combine each with
only the session's affected-id delta. Every accepted image/vector row
transition, including clear removal, updates that delta before the next
resource decision; descriptor edits do not. `removeUnusedResource` and clear
cleanup therefore query the current logical count without an accepted-element
scan, count-map clone, or mutation-history walk. Draft now owns direct layer
and element maps, one current placement view, and separate owner-local indexed
orders for layers, background elements, and every content layer. Materialized
Draft operations read and mutate those facts directly; an explicit Draft
document projection traverses each current order once and creates only public
output lists. Draft keyed resource descriptors and split image/vector counts
remain pending for Unit 5. Atomic whole-backing construction and replacement
swap remain pending for Unit 6; this structural backing is not yet a completed
replacement boundary. The journal receives only Draft's write-only DTO consumer
during promotion, not a readable Draft state; Draft's promotion target opens
and releases the document around that replay.
One Store-private transaction candidate opens the existing family, resource,
and structural working owners once and holds only current scalar facts
(`camera`, `background`, and `palette`). It does not mirror rows, descriptors,
or order. Replay and every subsequent decision read those live owners. Its
finalization order is relationship handling, provided-delta validation,
deferred validation in journal order, base-versus-final acceptance, coverage,
normalization, owner freeze/publication, one immutable aggregate construction,
and accepted touched facts. A rejected or final-no-op candidate constructs no
aggregate; an accepted candidate constructs exactly one. Sparse preparation is
projection-free and has bounded aggregate work `O(S + K log M + R)` for opened
owners `S`, mutations `K`, maximum order `M`, and changed descriptors `R`.
Intermediate aggregate snapshots are retired.
The store validates id admission, layer/resource membership, sealed image/vector
descriptor relationships against the completed candidate, row placement,
revision-family alignment, and projection invalidation in that prepare step.
The descriptor subtype, never nullable MIME data, is the current relationship
discriminator. A successful sparse install swaps committed tables and revision
state directly; it does not create or retain a public `CanvasDocument`.
Materialized fallback remains available only for explicit draft projection
requests such as `CanvasEdit.readDraftDocument` and whole-draft replacement.

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
  orderToken
  rowIndex
  elementRevision
  structuralRevision
  boundsRevision
```

geometry/spatial committed spatial reads expose a narrower immutable
`FrameElementHandle` across `FrameFactsPort`: id, structuralRevision,
generation, and committed orderToken. `locationKind` and nullable `layerId`
are facts-only values resolved from the current committed row by
`resolveElement`; callers cannot supply them as handle identity fields. Stale
structural revisions, generation mismatches, and order-token mismatches are
rejected before those facts are returned.

`FamilyTables`:

```text
ImageRows
VectorRows
PathRows
TextRows
StrokeRows
LineRows
RectRows
```

Each row table stores only family-specific fields plus common packed fields needed by render/hit/update. Public DTOs are projections.

`FamilyTables` keeps element membership directly in those seven maps: a
membership lookup probes the maps and does not construct a document-wide ID
union. Its sparse working owner is the consume-once `FamilyTablesEditor`.
Each affected family opens one lazy copy-on-write buffer; all current-row
decisions and final-equality normalization read that editor rather than a
successive immutable table. After accepted normalization it freezes one
`FamilyTables` value. Untouched family maps retain their base identity.

The same owner keeps the two derived resource-reference summaries: image
`resourceId -> count` and vector `resourceId -> count`. The editor records
only affected-ID deltas while it changes rows, then materializes a changed
summary once at its accepted freeze. Untouched summaries retain their base
identity. These counts are row-derived facts, not descriptor ownership or a
general element index.

`LayerTable` keeps ordered layer rows as the ordering truth and publishes an
immutable `layerId -> {row, index}` fact in the same construction or update.
Targeted layer membership, row/index, placement, and per-layer element reads
use that fact. `ElementRegistry` continues to own its distinct element
location facts and frame-order tokens; the layer fact does not replace them.

`ResourceTable` stores sealed descriptor facts. The image fact variant carries
its optional MIME field; the vector variant contains no MIME kind inference. A
resource reference is checked once by `DocumentStoreKernel` against the final
live sparse candidate or materialized candidate, rather than against a
resource-id set while family rows are being assembled. Missing ids and existing
wrong descriptor kinds remain distinct typed relationship failures.

For a complete committed document, `DocumentStoreKernel` seeds generated-ID
admission by immediately enumerating the authoritative `FamilyTables`,
`LayerTable`, and `ResourceTable` owners. Construction, reset, replacement,
prepared load, and Schema v1 import use this owner enumeration; sparse accepted
work instead admits its existing ordered ledger. Committed membership mirrors
and their append overlays are retired.

The admission owner maintains each generated prefix cursor at its first free
ID. Its private element candidate read is non-mutating; current explicit
element generation reads that candidate and synchronously reserves it, then
advances the same cursor as needed. No candidate, ticket, or separate
reservation history is retained outside admission.

Prepared Schema v1 import and staged document load retain one immutable
`CanvasDocumentSummary` captured from the completed payload's element, layer,
and resource scalar counts. Its read view retains no membership inventory and
does not enumerate committed owners when the summary is read.

Runtime view camera is not stored in `CommittedDocument`. It is runtime state
owned by `RuntimeRoot` through the camera boundary. Runtime construction creates
the default empty document and initializes the runtime view camera from that
document's `persistedCameraOffset`; successful schema v1 JSON load initializes
the runtime view camera from the loaded document's `persistedCameraOffset`.
`readDocument` projects the persisted camera, not the current runtime view
camera.

### 10.2 Revisions

```text
documentRevision        -> any committed document state change
controllerEpoch         -> loadDocumentFromJson success or full document replacement
structuralRevision      -> element/layer/resource membership/order/family changes
resourceRevision        -> resource descriptor changes
resourceVisualRevision  -> ResourceKernel/RuntimeRoot markResourceDirty visual invalidation
boundsRevision          -> geometry/transform/hit/paint bounds changed
elementVisualRevision   -> element visual fields, element style fields, and transform-affecting paint changes
backgroundRevision      -> persisted document background color changes
gridRevision            -> persisted CanvasGrid enabled/cellSize/color changes
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

`backgroundRevision` and `gridRevision` are internal persisted-document metadata
facts. `CanvasSurface.gridStyle` and `CanvasSurface.selectionStyle` are captured
paint inputs, not document revision families and not public runtime revisions.
Paint-plan cache keys must depend on `elementVisualRevision`, not background,
grid, style-only, or runtime view-camera facts; background/grid and runtime
view-camera changes repaint frame surfaces but must not invalidate ordinary
committed element paint plans.

Frame-facing committed revision facts enter `FrameEngine` through the
`contracts/internal/**` `FrameFactsPort`. `DocumentStoreKernel` remains the
owner of revision state, resource descriptors, compact row tables, and
projection policy; the port only returns immutable committed facts needed for
frame capture, stale row rejection, and descriptor snapshot lookup.

No-op edit does not change revisions. Preview cleanup increments
`previewRevision` only when it clears or replaces existing preview state; a
cleanup request against already-empty preview state is a no-op. Effects-only
action without state change is not used in v1. No-op runtime operations do not
publish a new `CanvasRuntimeState`.

Interaction setting changes such as mode, draw style, active draw tool, draw
color, and pointer policy increment the public `state.revisions.interaction`
without changing document revision. Preview-producing pointer changes increment
`state.revisions.preview`. Resource dirty operations increment
`state.revisions.resourceVisual`. That public dirty-resource domain is a repaint
observation signal; per-surface resource-asset resolution uses explicit
target/all resource release instead of deriving cache identity from the public
revision.
Active release clears matching session cache/suppression and retained main-output
borrows before publication, while stale identities leave current output intact.
`resourceVisualRevision` is runtime resource state coordinated by
`ResourceKernel` and `RuntimeRoot` through contract-owned dirty-resource
outcomes, not committed document store state.

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

Ordinary sparse edits increment the internal projection revision when their
accepted operation affects public document projection, but they must not build
the projection cache. Projection materialization happens only at the explicit
read paths listed above. This keeps `DocumentStoreKernel` as the committed
source of truth and `CanvasDocument` as a read DTO.

Projection DTOs must deep-copy all public collections and materialize frozen
`CanvasMetadata` values. Runtime tables may store compact metadata facts, but
raw metadata maps are not exposed as ordinary public DTO metadata.

Schema v1 JSON load preserves this lazy projection policy. Valid load installs
prepared store-owned committed tables and invalidates projection facts, but it
must not build `DocumentProjectionCache` or retain a public `CanvasDocument` as
the loaded state. Resource JSON is imported as committed descriptor rows; public
image/vector public resources are materialized only by explicit read/resource
projection or resolver-facing surfaces.

---
