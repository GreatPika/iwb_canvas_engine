<!-- CONTEXT:BEGIN -->
Registry id: `section_00_status_and_scope`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/architecture/00_architecture_overview.md`
Owns:
- 0. Статус и обязательное архитектурное решение
Must read before editing:
- `section_01_legacy_oracle` -> `docs/split/planning/legacy_oracle.md`
- `section_03_package_layout` -> `docs/split/architecture/02_package_boundaries.md`
- `section_22_guardrails_machine_checks` -> `docs/split/verification/guardrails.md`
Depends on:
- `section_01_legacy_oracle` -> `docs/split/planning/legacy_oracle.md`
- `section_03_package_layout` -> `docs/split/architecture/02_package_boundaries.md`
- `section_22_guardrails_machine_checks` -> `docs/split/verification/guardrails.md`
Feeds phases:
- `P0`
- `P1.5`
Related donors:
- `none`
Related diagrams:
- `docs/split/diagrams/README.md#c4_context` -> `docs/split/diagrams/generated/c4_context.mmd`
- `docs/split/diagrams/README.md#c4_container` -> `docs/split/diagrams/generated/c4_container.mmd`
Required tests:
- `test.api_contract.v1_scope_gate`
Guardrails:
- `new_core.no_legacy_imports`
- `new_core.no_scene_controller_shape_dependency`
- `new_core.no_node_spec_patch_shape_dependency`
Do not assume:
- no legacy facade
- no SceneController
- no old public API shape
- no old runtime fallback
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
# `iwb_canvas_engine_next`: полный implementation plan без legacy-фасада внутри нового движка

## 0. Статус и обязательное архитектурное решение

Документ является целевой спецификацией реализации для переписывания библиотеки с нуля.
Он заменяет прежнюю модель, где новый runtime должен был сохранять старую форму публичного API.

Фиксированное решение:

```text
iwb_canvas_engine_next
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
old iwb_canvas_engine
  -> показывает, какие сценарии, edge cases, события, проверки и performance probes нельзя потерять;
  -> не задаёт форму нового публичного API;
  -> не импортируется новым package;
  -> не используется как fallback;
  -> не оборачивается новым runtime.
```

### 0.1 Scope lock для v1

v1 scope additions over old functional behavior:

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
- реализовывать legacy facade старого API;
- экспортировать SceneController;
- экспортировать SceneSnapshot;
- экспортировать NodeSpec;
- экспортировать NodePatch;
- экспортировать PatchField;
- экспортировать SceneWriteTxn;
- экспортировать старые schema v7 public entrypoints как API нового package;
- размещать AppCanvasPort внутри нового package;
- размещать OldEngineAdapter внутри нового package;
- размещать NewEngineAdapter внутри нового package;
- использовать старый runtime в production path;
- доказывать полноту нового API прохождением старого public API ledger.
```

Приложение может иметь собственный слой миграции, но он находится **вне** `iwb_canvas_engine_next`:

```text
app/
  canvas_port/
    AppCanvasPort
    OldEngineAdapter -> old iwb_canvas_engine
    NewEngineAdapter -> iwb_canvas_engine_next
    adapter_contract_tests
```

Этот слой не является deliverable движка. Движок обязан предоставить чистый новый API и собственные contract tests. Приложение само решает, как адаптировать его к `AppCanvasPort`.

---

<!-- ORIGINAL-SECTION:END -->
