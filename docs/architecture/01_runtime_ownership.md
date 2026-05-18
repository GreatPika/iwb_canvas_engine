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
| SelectionKernel | runtime selected ids, selectionRevision, selection normalization, content-only filtering | хранить committed document content, selected-order cache или быть public API type |
| EditKernel | synchronous edit sessions, draft, touched sets, cross-owner commit/rollback coordination | выполнять paint или pointer routing |
| InteractionEngine | pointer sessions, tools, preview state, terminal commit requests, interaction request guard facts | читать или менять DocumentStoreKernel напрямую; хранить Flutter text editor session state |
| FrameEngine | captured main/overlay frames, ordinary paint plans, selection decoration/staging, repaint buses | экспортировать public document или владеть selection |
| ResourceKernel | resource API, dirty resource ids, resource visual state publication, session invalidation events | владеть app domain assets, resolved image references или committed descriptors |
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
`InteractionEngine` only through narrow read-only interaction query boundaries
owned by the runtime/document boundary. Selection facts enter through
intent-specific selection query boundaries owned by the runtime/selection
boundary. Query boundaries return immutable, batched, intent-specific facts and
never expose store tables, selection internals, or mutation methods. Committed
mutations requested by interaction still go through `EditKernel`.

`InteractionRequestRegistry` is the interaction-owned registry for issued
request guard facts, such as the `CanvasInteractionRequestId`, target element
id, controllerEpoch, element generation, elementRevision, element family, and
retired request status. `RuntimeRoot` owns the registry instance lifetime,
`InteractionEngine` records issued request facts, and guarded command-port
operations consume those facts through a narrow boundary before delegating
accepted mutations to `EditKernel`. The registry is not an active text-input
session, not app overlay state, and not `CanvasPreviewState`.

Composition root:

```text
RuntimeRoot
  ├─ DocumentStoreKernel
  ├─ SelectionKernel
  ├─ EditKernel
  ├─ InteractionEngine
  ├─ InteractionRequestRegistry
  ├─ FrameEngine
  ├─ SpatialKernel
  ├─ ResourceKernel
  ├─ SurfaceResourceSession (owned by active CanvasSurface)
  ├─ CodecBoundary
  └─ DiagnosticsHub
```

---
