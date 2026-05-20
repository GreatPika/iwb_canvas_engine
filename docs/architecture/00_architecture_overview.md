<!-- CONTEXT:BEGIN -->
Registry id: `section_00_status_and_scope`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/00_architecture_overview.md`
Owns:
- 0. Статус и обязательное архитектурное решение
Must read before editing:
- `none`
Feeds phases:
- `P0`
- `P1`
Related donors:
- `none`
Related diagrams:
- `c4_context`
- `c4_container`
Required tests:
- `test.api_contract.no_legacy_public_symbols`
- `test.api_contract.app_next_engine_adapter_compile_fixture`
Guardrails:
- `core.no_legacy_imports`
- `core.no_scene_controller_shape_dependency`
- `core.no_node_spec_patch_shape_dependency`
Do not assume:
- no legacy facade
- no SceneController
- no legacy public API shape
- no legacy runtime fallback
<!-- CONTEXT:END -->

# `iwb_canvas_engine`: scope and architecture decision

## 0. Статус и обязательное архитектурное решение

Документ фиксирует обязательную границу v1 для новой библиотеки.
Он заменяет прежнюю модель, где новый runtime должен был сохранять старую форму публичного API.

Фиксированное решение:

```text
iwb_canvas_engine
  -> отдельный новый package;
  -> новый публичный API v1;
  -> один новый runtime;
  -> новый core/store/edit/frame/interaction/resource/codec;
  -> functional-compatible со старым движком;
  -> не API-compatible со старым движком;
  -> без legacy facade внутри нового движка;
  -> без старого runtime внутри поставляемого артефакта.
```

Старый движок используется только как **functional oracle**:

```text
legacy iwb_canvas_engine package
  -> показывает, какие сценарии, edge cases, события, проверки и performance probes нельзя потерять;
  -> не задаёт форму нового публичного API;
  -> не импортируется новым package;
  -> не используется как fallback;
  -> не оборачивается новым runtime.
```

### 0.1 Scope lock для v1

v1 scope additions over legacy functional behavior:

```text
- CanvasResourceId;
- CanvasResourceSource.appKey;
- markResourceDirty / markAllResourcesDirty;
- typed action payloads;
- CanvasPreviewState;
- CanvasPalette;
- CanvasGrid.color;
- CanvasSurface(interactive=false).
```

Запрещено в новом package:

```text
Legacy public API:
  - реализовывать legacy facade старого API;
  - экспортировать SceneController;
  - экспортировать SceneSnapshot;
  - экспортировать NodeSpec;
  - экспортировать NodePatch;
  - экспортировать PatchField;
  - экспортировать SceneWriteTxn;
  - экспортировать старые schema v7 public entrypoints как API нового package.

App integration:
  - размещать AppCanvasPort внутри нового package;
  - размещать LegacyEngineAdapter внутри нового package;
  - размещать NextEngineAdapter внутри нового package.

Runtime and proof:
  - использовать старый runtime в production path;
  - доказывать полноту нового API прохождением старого public API ledger.
```

Приложение может иметь собственный слой миграции или adapter contract, но он находится **вне** `iwb_canvas_engine`.
Такой слой не является deliverable движка. Движок обязан предоставить чистый новый API и собственные contract tests; приложение само решает, как адаптировать его к своему integration port.
При этом полнота public API для внешнего app adapter доказывается не наличием
типов в контракте, а external compile fixture, который импортирует только
`package:iwb_canvas_engine/iwb_canvas_engine.dart` и не использует `src/**`,
legacy symbols или internal runtime classes.

---
