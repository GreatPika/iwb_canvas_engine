<!-- CONTEXT:BEGIN -->
Registry id: `section_02_architecture_model`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/01_runtime_ownership.md`
Owns:
- 2. Несущая модель новой библиотеки
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
Feeds phases:
- `P0`
- `P4`
Related donors:
- `none`
Related diagrams:
- `c4_container`
- `c4_component_runtime`
- `generated/actual_vs_expected_diff`
- `generated/current_phase`
- `generated/full_architecture`
- `generated/future_target`
- `generated/release_verification`
- `state_runtime_lifecycle`
Required tests:
- `test.guardrails.blocking_suite`
- `test.selection.runtime_owner_separation`
Guardrails:
- `core.single_runtime_root`
- `selection.owner_separate_from_document`
Do not assume:
- no legacy facade
- no SceneController
<!-- CONTEXT:END -->

## 2. Несущая модель новой библиотеки

Новая библиотека предоставляет графический runtime для холста. Она не хранит предметную модель приложения.

```text
Application domain state
  -> живёт в приложении;
  -> может ссылаться на canvas element ids;
  -> не хранится внутри engine core.

Canvas engine state
  -> документ холста;
  -> элементы;
  -> ресурсы;
  -> выделение;
  -> камера;
  -> режимы и preview;
  -> render/cache/spatial/runtime state.
```

Внутри движка роли разделены так:

| Зона | Хранит | Не должна делать |
|---|---|---|
| Public API | стабильные DTO, операции, события, ошибки | раскрывать таблицы, handles, caches, runtime internals |
| DocumentStoreKernel | committed document state, document revisions, resource descriptors, public document projection cache | читать gesture state, selection state или Flutter widget |
| FrameFactsPort | immutable committed frame facts for capture, row resolution, descriptor snapshots, and resourceRevision | expose store tables, public document projections, drafts, mutations, selection facts, or frame-owned render models |
| SelectionKernel | runtime selected ids, selectionRevision, selection normalization, content-only filtering | хранить committed document content, selected-order cache или быть public API type |
| EditKernel | synchronous edit sessions, draft, touched sets, cross-owner commit/rollback coordination | выполнять paint или pointer routing |
| InteractionEngine | pointer sessions, tools, preview state, terminal commit requests, interaction request guard facts, target pointer cleanup coordinator composition | читать или менять DocumentStoreKernel напрямую; хранить Flutter text editor session state |
| FrameEngine | frame-internal facade for capture, planning, painter input assembly, and repaint buses; target composition owner for frame-private collaborators | read concrete DocumentStoreKernel internals, export public document, own selection, or expose frame collaborators outside `lib/src/frame/**` |
| ResourceKernel | resource API, committed catalog reads through `ResourceCatalogPort`, dirty resource ids, resource visual state publication, dirty outcomes for future session invalidation | владеть app domain assets, resolved image references или committed descriptors |
| SurfaceResourceSession | surface-scoped resolver reference, resolverGeneration, ImageResolveCache, resolver budget, same-frame missing/null suppression | владеть committed descriptors, public runtime state или Flutter widget lifecycle |
| SpatialKernel | coarse candidate lookup, outlier policy | быть source of truth для сцены |
| CodecBoundary | schema v1 encode/decode, validation, diagnostics | зависеть от Flutter widget или gestures |
| DiagnosticsHub | internal diagnostic records, public error projection | добавлять public stream без API-решения |

Public runtime observation is owned by `RuntimeRoot`. It publishes the single
`CanvasRuntime.state` listenable as immutable `CanvasRuntimeState` snapshots
after accepted document, selection, preview, view camera, resource visual,
interaction, or epoch changes. Downstream owners contribute facts through their
own boundaries; they do not own the public snapshot object or depend on Flutter
widget state to publish core runtime state.

Frame, cache, lifecycle, and public edit diagrams use this public runtime state
model: `CanvasRuntime.state` carries runtime-visible revisions, runtime view
camera is distinct from persisted document camera, and retired separate public
listener getters are not diagram seams.

The target `PointerToolCleanupCoordinator` is an internal
`InteractionEngine` collaborator and cleanup policy seam. `InteractionEngine`
owns its composition and is the only caller. Tool machines may return typed
cleanup requests to `InteractionEngine`, but they must not call the coordinator
directly. The coordinator calculates an effect-only `PointerCleanupOutcome`
from interaction-owned state and request ownership context; it does not publish
runtime state, emit actions or context requests, schedule repaints, call
resolvers, open edits, read stores or selection internals, or become a second
state store.

Camera ownership is split deliberately:

```text
Runtime view camera
  -> owned by RuntimeRoot/CanvasCameraPort;
  -> published through state.revisions.viewCamera;
  -> repaints affected surfaces;
  -> does not dirty document state or invalidate CanvasDocument projection.

Persisted document camera
  -> owned by DocumentStoreKernel as committed document content;
  -> stored in CanvasDocument and schema v1;
  -> changed only through CanvasEdit.setCameraOffset or document replacement;
  -> read back through readDocument.
```

Gesture decisions may need committed facts such as controller epoch,
selection ids, movable flags, text snapshots, and bounds. Document facts enter
`InteractionEngine` through `InteractionReadPort`, the target read-only
interaction query boundary owned by the runtime/document interaction boundary.
Selection facts enter through intent-specific selection query boundaries owned
by the runtime/selection boundary and may be batched into `InteractionReadPort`
responses when the interaction intent needs document order plus selected ids.
The port returns only immutable, batched, intent-specific facts: hit/order
facts, immutable element snapshots, `boundsWorld`, element generation,
`elementRevision`, element family, `controllerEpoch`, visibility, and top-hit
status. It must not expose mutation APIs, draft access, `CanvasDocument`
projection, store internals, resource/session internals, selection internals, or
per-property concrete owner probes. Committed mutations requested by interaction
still go through `EditKernel`.

Frame capture also uses a narrow intent-specific document boundary.
`FrameFactsPort` is owned by `lib/src/contracts/internal/**` and is the
accepted committed-state read seam between the frame-internal facade and
`DocumentStoreKernel`:

```text
FrameEngine -> FrameFactsPort -> DocumentStoreKernel
```

The port supplies only immutable frame-facing facts: `documentRevision`,
`structuralRevision`, `boundsRevision`, `elementVisualRevision`,
`backgroundRevision`, `gridRevision`, committed render-row facts resolved
against the captured structural revision and generation, immutable resource
descriptor snapshots, and `resourceRevision`. It does not own mutable document
state and must not return `CanvasDocument`, `CommittedDocument`, raw family
tables, `DocumentProjectionCache`, drafts, mutation APIs, selection facts,
`RenderElementRecord`, `PaintPlan`, selected supplement records, decoration
plans, or frame cache classes.

The selected target frame form keeps `FrameEngine` as the orchestration facade
and splits its internal work across seven frame-private collaborators:
`FrameCaptureService`, `OrdinaryPaintPlanner`,
`SelectedMoveSupplementPlanner`, `SelectionDecorationPlanner`,
`PaintAssetBindingService`, `StaticBackgroundPlanner`, and
`OverlayPreviewPlanner`. The collaborators remain implementation details under
`lib/src/frame/**`; package consumers continue to see only the public API
barrel.

Target ownership boundaries:

| Target collaborator | Owns | Must not own |
|---|---|---|
| `FrameCaptureService` | one-time capture of main/overlay live frame facts into `CapturedMainFrame` and `CapturedOverlayFrame` | record planning, resolver/session calls, cache mutation beyond captured-frame construction |
| `OrdinaryPaintPlanner` | ordinary committed `PaintPlanCache` lookup/build using structure, bounds, element visual, viewport, and DPR | selection revision, selection style, selected move delta, preview state, resource resolver/session, static background identity |
| `SelectedMoveSupplementPlanner` | per-frame selected move filtering, shifted candidate lookup, row resolution, and merge by `orderToken` | ordinary `PaintPlanCache` writes, overlay rendering, global scene sort |
| `SelectionDecorationPlanner` | selection UI decoration and `SelectionDecorationPlan` key including `boundsRevision` | ordinary record cache identity, selected move supplement records, static background identity |
| `PaintAssetBindingService` | descriptor-to-asset binding for records with image resource ids, using immutable descriptor facts and `SurfaceResourceSession` | ordinary paint plan construction, painter resolver calls, app resolver ownership |
| `StaticBackgroundPlanner` | static background/grid plan and cache identity | selection, preview, resource visual, ordinary element visual identity |
| `OverlayPreviewPlanner` | immutable overlay primitives admitted from `CapturedOverlayFrame` | selected move rendering, resource resolver reads, cache invalidation, repaint scheduling |

Committed document facts stay store-owned and enter frame code only through the
contract-owned `FrameFactsPort`. Selection facts stay selection-owned and enter
frame code through contract-owned selection fact seams. Preview and view-camera
facts stay runtime/interaction-owned and are captured at frame boundaries.
Resolver/cache state stays owned by the future `SurfaceResourceSession` under
`lib/src/resources/**`; among the target frame collaborators, only
`PaintAssetBindingService` receives that session. Committed resource catalog
reads for the public resource port go through `ResourceCatalogPort`, while
frame descriptor lookup stays on `FrameFactsPort`.

`InteractionRequestRegistry` is the interaction-owned registry for issued
request guard facts, such as the `CanvasInteractionRequestId`, context request
target kind, controllerEpoch, and retired request status. For content-element
targets, it also stores target element id, element generation, elementRevision,
and element family. `RuntimeRoot` owns the registry instance lifetime,
`InteractionEngine` records issued request facts, and guarded command-port
operations consume those facts through a narrow boundary before delegating
accepted mutations to `EditKernel`. The registry is not an active text-input
session, not a context menu or app overlay state owner, and not
`CanvasPreviewState`.

Composition root:

```text
RuntimeRoot
  ├─ DocumentStoreKernel
  ├─ FrameFactsPort (contracts/internal seam implemented by runtime/store facts)
  ├─ SelectionKernel
  ├─ EditKernel
  ├─ InteractionEngine
  │  └─ PointerToolCleanupCoordinator (internal interaction collaborator)
  ├─ InteractionReadPort
  ├─ InteractionRequestRegistry
  ├─ FrameEngine (frame-internal facade)
  ├─ SpatialKernel
  ├─ ResourceKernel
  ├─ SurfaceResourceSession (owned by active CanvasSurface)
  ├─ CodecBoundary
  └─ DiagnosticsHub
```

---
