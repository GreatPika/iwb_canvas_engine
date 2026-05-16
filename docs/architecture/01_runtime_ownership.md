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
| InteractionEngine | pointer sessions, tools, preview state, terminal commit requests | читать или менять DocumentStoreKernel напрямую |
| FrameEngine | captured main/overlay frames, ordinary paint plans, selection decoration/staging, repaint buses | экспортировать public document или владеть selection |
| ResourceKernel | resolver boundary, image resolve cache, dirty resource ids | владеть app domain assets или committed descriptors |
| SpatialKernel | coarse candidate lookup, outlier policy | быть source of truth для сцены |
| CodecBoundary | schema v1 encode/decode, validation, diagnostics | зависеть от Flutter widget или gestures |
| DiagnosticsHub | internal diagnostic records, public error projection | добавлять public stream без API-решения |

Gesture decisions may need committed facts such as controller epoch,
selection ids, movable flags, text snapshots, and bounds. Document facts enter
`InteractionEngine` only through narrow read-only interaction query boundaries
owned by the runtime/document boundary. Selection facts enter through
intent-specific selection query boundaries owned by the runtime/selection
boundary. Query boundaries return immutable, batched, intent-specific facts and
never expose store tables, selection internals, or mutation methods. Committed
mutations requested by interaction still go through `EditKernel`.

Composition root:

```text
RuntimeRoot
  ├─ DocumentStoreKernel
  ├─ SelectionKernel
  ├─ EditKernel
  ├─ InteractionEngine
  ├─ FrameEngine
  ├─ SpatialKernel
  ├─ ResourceKernel
  ├─ CodecBoundary
  └─ DiagnosticsHub
```

---
