<!-- CONTEXT:BEGIN -->
Registry id: `section_02_architecture_model`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/architecture/01_runtime_ownership.md`
Owns:
- 2. Несущая модель новой библиотеки
Must read before editing:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/split/architecture/02_package_boundaries.md`
- `section_10_runtime_data_model` -> `docs/split/architecture/03_data_model.md`
Depends on:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/split/architecture/02_package_boundaries.md`
- `section_10_runtime_data_model` -> `docs/split/architecture/03_data_model.md`
Feeds phases:
- `P0`
- `P5`
Related donors:
- `none`
Related diagrams:
- `docs/split/diagrams/README.md#c4_container` -> `docs/split/diagrams/generated/c4_container.mmd`
- `docs/split/diagrams/README.md#c4_component_runtime` -> `docs/split/diagrams/generated/c4_component_runtime.mmd`
Required tests:
- `none`
Guardrails:
- `new_core.single_runtime_root`
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
| DocumentStoreKernel | committed document state, revisions, selection, resources | читать gesture state или Flutter widget |
| EditKernel | synchronous edit sessions, draft, touched sets, commit/rollback | выполнять paint или pointer routing |
| InteractionEngine | pointer sessions, tools, preview state, terminal commit requests | менять committed document в обход EditKernel |
| FrameEngine | captured main/overlay frames, paint plans, repaint buses | экспортировать public document |
| ResourceKernel | resource descriptors, resolver cache, invalidation | владеть app domain assets |
| SpatialKernel | coarse candidate lookup, outlier policy | быть source of truth для сцены |
| CodecBoundary | schema v1 encode/decode, validation, diagnostics | зависеть от Flutter widget или gestures |
| DiagnosticsHub | internal diagnostic records, public error projection | добавлять public stream без API-решения |

Composition root:

```text
RuntimeRoot
  ├─ DocumentStoreKernel
  ├─ EditKernel
  ├─ InteractionEngine
  ├─ FrameEngine
  ├─ SpatialKernel
  ├─ ResourceKernel
  ├─ CodecBoundary
  └─ DiagnosticsHub
```

---

