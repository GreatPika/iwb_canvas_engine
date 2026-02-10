language: russian

# IWB Canvas Engine v2 — рабочий план (transaction-first)

## 0) Цель релиза (фиксированная)

Сделать major-версию, где:
- внешний код не может мутировать документ напрямую;
- запись в сцену идёт только через транзакцию `SceneControllerV2.write(...)`;
- один `write(...)` даёт один commit, один пересчёт производных структур и один flush уведомлений;
- `replaceScene(...)` внутри того же контроллера не смешивает кэши/индекс/NodeId благодаря `controllerEpoch`;
- сильные стороны текущей реализации (математика, геометрия, инструменты, рендер) переиспользуются.

## 1) Сверка плана с текущей кодовой базой (2026-02-09)

Проверено по `lib/src/**`, `ARCHITECTURE.md`, `README.md`, `tool/invariant_registry.dart`.

- [x] `SceneController.scene` сейчас публично мутабелен.
- [x] `InputSliceContracts` сейчас отдаёт mutable `Scene`.
- [x] Spatial index завязан на `_sceneGeometryRevision`.
- [x] `nodeHitTestCandidateBoundsWorld(...)` использует `_scenePaddingToWorldMax(...)` (риск "раздутого" candidate bounds при анизотропии).
- [x] `SceneView._invalidateRenderCachesOnControllerSwap()` не очищает `SceneStaticLayerCache`.
- [x] `SceneStrokePathCache.getOrBuild(...)` бросает `StateError` при `points.length < 2`.
- [x] Таймер `LineTool` уже корректно отменяется в `reset()`; отдельная реализация отмены не нужна, нужен regression-test.

## 2) Что исправлено в этом плане

Из предыдущей версии плана убрано/исправлено:
- удалён большой статический листинг файлов `lib/src/**` (быстро устаревает, не помогает выполнению);
- удалена избыточная "карта переиспользования" по каждому файлу в деталях;
- убраны устаревшие формулировки про уже решённые части (таймер line tool как реализация);
- уточнено, что для `lib/src/v2/**` нужно расширить tooling/инварианты, иначе новые слои не будут автоматически защищены текущими проверками границ импортов;
- этапы сведены к чеклисту с критериями приёмки, чтобы было удобно отмечать прогресс.

## 3) Выбранная стратегия (рекомендованная)

Рекомендация: **инкрементальный параллельный ввод v2**.

- сначала добавить `basic_v2.dart` и `advanced_v2.dart`;
- код v2 разрабатывать в `lib/src/v2/**`;
- v1 не ломать, пока v2 не закроет тесты и инварианты;
- после готовности переключить `basic.dart`/`advanced.dart` на v2, удалить legacy API и зафиксировать breaking changes в `CHANGELOG.md`.

Почему это лучший вариант:
- минимальный риск регрессий в текущем API;
- можно портировать модули поэтапно и тестировать изолированно;
- проще локализовать проблемы по фазам.

### 3.1) Reuse policy for legacy slices (batch guardrail)

- Разрешён только перенос **pure** логики из legacy:
  - без зависимостей на `InputSliceContracts` / `SceneController`;
  - без `notify/emit/commit` orchestration;
  - детерминированной и side-effect free.
- Запрещён перенос legacy orchestration "как есть":
  - `lib/src/input/slices/**`;
  - `lib/src/input/internal/contracts.dart`.
- Для batch `G2.1-G2.5` целевой перенос ограничен общей логикой порогов/декимации input-семплов (move/line/stroke/eraser), вынесенной в `core`-утилиту и переиспользуемой без изменения transaction-first контракта.

## 4) Основной чеклист реализации v2

### A. Guardrails и инварианты

- [x] A0. Аудит текущего плана и сверка с кодом выполнены.
- [x] A1. Добавить/обновить v2-инварианты в `tool/invariant_registry.dart`:
  - запрет внешней мутации документа;
  - транзакция как единственный путь записи;
  - атомарность commit;
  - epoch-инвалидация кэшей/индекса.
- [x] A2. Расширить `tool/check_import_boundaries.dart` (или аналогичный tool-check), чтобы `lib/src/v2/**` тоже проверялся на архитектурные границы.
- [x] A3. Добавить enforcement (`// INV:<id>`) в `test/**` и/или `tool/**` для всех новых v2-инвариантов.
- [x] A4. Держать зелёным `dart run tool/check_invariant_coverage.dart` на каждом шаге.

Критерий приёмки A:
- новые v2-инварианты зарегистрированы, покрыты enforcement, tooling их проверяет.

### B. Публичная read-only модель v2

- [x] B1. Создать `lib/src/v2/public/`:
  - `SceneSnapshot`, `LayerSnapshot`, `NodeSnapshot` (immutable);
  - `NodeSpec` (создание);
  - `NodePatch` (частичное изменение).
- [x] B2. Убедиться, что наружу не возвращаются mutable-объекты сцены/узлов.
- [x] B3. Добавить `basic_v2.dart` и `advanced_v2.dart` (временные entrypoints для миграции).

Критерий приёмки B:
- публичный API v2 предоставляет только read-only модель + команды через контроллер.

### C. Внутренний store, epoch и транзакции

- [x] C1. Создать `lib/src/v2/model/` с внутренней mutable-моделью (не экспортируется наружу).
- [x] C2. Создать store (`lib/src/v2/controller/store.dart`) с:
  - `controllerEpoch`;
  - `structuralRevision`, `boundsRevision`, `visualRevision`.
- [x] C3. Реализовать `SceneControllerV2.write(fn)` + `TxnContext` + `SceneWriter`.
- [x] C4. Сделать `ChangeSet` источником правды для commit:
  - `documentReplaced`, `structuralChanged`, `boundsChanged`, `visualChanged`, `selectionChanged`, `gridChanged`;
  - `added/removed/updated` ids.
- [x] C5. `boundsChanged` вычислять автоматически сравнением `oldBounds/newBounds` до/после мутации узла.

Критерий приёмки C:
- несколько операций внутри одного `write(...)` приводят к одному commit и консистентному `ChangeSet`.

### D. Input slices поверх транзакций

- [x] D1. Новый v2-контракт для slices: read-only чтение + write-доступ только внутри txn.
- [x] D2. Порт `commands` на txn; запрет `addNode` в background layer.
- [x] D3. Порт `move` и `draw` на txn; не должно быть прямых мутаций "мимо write".
- [x] D4. `selection` нормализует удалённые id на commit.
- [x] D5. Вынести spatial index в отдельный `spatial_index` slice (epoch + boundsRevision invalidation).
- [x] D6. `signals` буферизует события внутри txn и эмитит только после commit.
- [x] D7. `repaint` делает один flush на commit (batch mode).
- [x] D8. Нормализация grid в commit-пайплайне (`grid` slice или эквивалентный слой).
- [x] D9. Зафиксировать порядок `onCommit`:
  1) `selection`
  2) `grid`
  3) `spatial_index`
  4) `signals`
  5) `repaint`

Критерий приёмки D:
- мутация только через транзакции, commit-order фиксирован и покрыт тестами.

### E. Hit-test, render и view

- [x] E1. Исправить candidate bounds в hit-test v2 на строгую семантику scene units (без `_scenePaddingToWorldMax`-раздувания).
- [x] E2. Портировать `ScenePainter` + кэши с epoch-инвалидацией.
- [x] E3. Сделать `SceneStrokePathCache` fail-safe на `0/1` точке (без исключения).
- [x] E4. В `SceneView` добавить invalidation по epoch и очищать все кэши, включая static layer cache.
- [x] E5. Сохранить текущий контракт сетки: при over-density использовать stride-деградацию, а не "молчаливое исчезновение" сетки.

Критерий приёмки E:
- нет "призрачных" кэшей после `replaceScene`, hit-test предсказуем при анизотропии.

### F. Сериализация v2

- [x] F1. Портировать codec в `lib/src/v2/serialization/`.
- [x] F2. `decode` возвращает snapshot/document v2 (не mutable Scene).
- [x] F3. `encode` принимает snapshot/document v2.
- [x] F4. Портировать и адаптировать `test/serialization/*`.
- [x] F5. Сохранить совместимость `_requireInt`: принимать `num`, проверять целочисленность, затем приводить к `int`.

Критерий приёмки F:
- JSON v2 round-trip проходит на новой модели без утечек mutable-состояния наружу.

### G. Полный interactive parity c v1 (example-first)

- [x] G1. Зафиксировать baseline для сравнения parity:
  - использовать `baseline-vertical-slices-2026-02-04` как целевой ref;
  - если нужен другой baseline, явно записать commit/tag в этом пункте до начала cutover.
- [x] G2. Закрепить checklist интерактивных сценариев из `example/lib/main.dart`.
- [x] G2.1. Сценарий: переключение `move/draw` + семантика `selection`.
- [x] G2.2. Сценарий: механика выделения (`tap-select`, `marquee-select`, `clear selection` в ожидаемых режимах).
- [x] G2.3. Сценарий: draw-tools `pen/highlighter/line/eraser` + очистка `pending-state`.
- [x] G2.4. Сценарий: `line tool` (двухтаповый flow: `pending start -> commit line -> reset/cancel`).
- [x] G2.5. Сценарий: `eraser` (удаление пересечённых узлов в draw-режиме).
- [x] G2.6. Сценарий: text nodes (`double-tap -> inline edit overlay -> save/cancel`, где cancel = no-op закрытие через `tap outside` без изменения текста).
- [x] G2.7. Сценарий: text styling в selection-panel (`color/align/font size/line height/bold/italic/underline`).
- [x] G2.8. Сценарий: трансформации (`rotate/flip/delete`) и `marquee-selection`.
- [x] G2.9. Сценарий: `camera pan/zoom` + `hit-test`.
- [x] G2.10. Сценарий: `grid/system actions` (включая `import/export/replace scene`).
- [x] G2.11. Сценарий: `Add Sample` (создаются `RectNode + TextNode`, корректные size/position/id, сценарий повторяемый).
- [x] G2.12. Сценарий: system menu background flow (смена background color + `Clear Canvas`).
- [x] G2.13. Сценарий: visual parity индикаторов (`Camera X` и pending-line marker в draw-line режиме).
- [x] G2.14. Сценарий: text edit commit-триггеры (`onTapOutside` и auto-save при `setMode`).
- [x] G3. Добавить автоматические parity-регрессии для example-flow (`example/test/**`), детерминированные и с проверкой UI state + public controller state.
- [x] G3.1. Автотест для `G2.1`.
- [x] G3.2. Автотест для `G2.2`.
- [x] G3.3. Автотест для `G2.3`.
- [x] G3.4. Автотест для `G2.4`.
- [x] G3.5. Автотест для `G2.5`.
- [x] G3.6. Автотест для `G2.6`.
- [x] G3.7. Автотест для `G2.7`.
- [x] G3.8. Автотест для `G2.8`.
- [x] G3.9. Автотест для `G2.9`.
- [x] G3.10. Автотест для `G2.10`.
- [x] G3.11. Автотест для `G2.11`.
- [x] G3.12. Автотест для `G2.12`.
- [x] G3.13. Автотест для `G2.13`.
- [x] G3.14. Автотест для `G2.14`.
- [x] G4. Добавить engine-level parity harness v1 vs v2 (пока legacy ещё существует):
  - одинаковые входные event-script дают эквивалентный публичный результат (scene JSON, selected ids, contract-level signals/actions).
- [x] G5. Закрыть все найденные parity-gap без изменения UX-контракта baseline.

Критерий приёмки G:
- при открытии `example/lib/main.dart` и прохождении сценариев из G2 поведение и интерактивность не отличаются от baseline v1 в рамках зафиксированного checklist (включая выделение, ластик, line tool и редактирование текстовых узлов).

### G2. Parity lockstep перед cutover (инструменты + UI 1:1)

Цель этапа: **до переключения публичных entrypoints** довести v2 до полного
совпадения с legacy в `example`:
- те же пользовательские функции;
- тот же observable UX-контракт;
- тот же UI-контракт (layout/контролы/сценарии/индикаторы).

Правило этапа:
- `H1`/`H2` заблокированы до полного закрытия `G2L.*`.
- Нельзя удалять legacy-код, пока `example` не работает на v2 с 1:1 parity.

- [x] G2L.1. Ввести `SceneControllerInteractiveV2` (или эквивалентный слой) с high-level API, совместимым с legacy-контрактом:
  - `setMode(...)`;
  - `setDrawTool(...)`;
  - `setDrawColor(...)`;
  - `setBackgroundColor(...)`, `setGridEnabled(...)`, `setGridCellSize(...)`, `setCameraOffset(...)`;
  - `setSelection(...)`, `toggleSelection(...)`, `clearSelection(...)`;
  - `rotateSelection(...)`, `flipSelectionVertical(...)`, `flipSelectionHorizontal(...)`, `deleteSelection(...)`, `clearScene(...)`;
  - readonly-свойства для UI (`mode`, `drawTool`, `pendingLineStart`, `selectionRect`, и т.п. по необходимости для exact parity).
- [x] G2L.2. Перенести pointer-level orchestration в v2 без изменения UX:
  - `handlePointer(...)`;
  - `handlePointerSignal(...)`;
  - pending two-tap line таймер/timeout/reset semantics;
  - drag/marquee lifecycle, включая cancel/mode-switch rollback.
- [x] G2L.3. Портировать tool-state lifecycle 1:1:
  - pen/highlighter/line/eraser parity;
  - reset/dispose semantics без отложенных side-effects;
  - commit/cancel behavior идентичен legacy.
- [x] G2L.4. Подключить `example/lib/main.dart` к v2 interactive controller с сохранением текущего UI без визуальных/поведенческих изменений.
- [x] G2L.5. Зафиксировать UI parity контракт:
  - список обязательных виджет-ключей/контролов/иконок/панелей не меняется;
  - порядок и доступность контролов по режимам совпадают с baseline;
  - индикаторы (`Camera X`, pending-line marker и др.) совпадают по условиям показа.
- [x] G2L.6. Добавить adapter-level parity tests для interactive API (legacy vs v2) на одинаковых input scripts:
  - selection/marquee;
  - draw tools;
  - line two-tap;
  - eraser;
  - text edit/styling;
  - transform/delete;
  - system/grid/background/import-export.
- [x] G2L.7. Прогнать и зафиксировать "example on v2" regression пакет:
  - `example/test/**` зелёный без специальных fallback на legacy;
  - сравнение ключевых UI state и public controller state на каждом шаге сценариев G2.
- [x] G2L.8. Документировать матрицу parity в `DEVELOPMENT_PLAN.md` (таблица):
  - Feature;
  - Legacy API;
  - V2 API;
  - Test coverage id;
  - Status (`Done/Gap`).

| Feature | Legacy API | V2 API | Test coverage id | Status |
|---|---|---|---|---|
| Mode/tool switch + selection semantics | `SceneController.setMode/setDrawTool/setSelection` | `SceneControllerInteractiveV2.setMode/setDrawTool/setSelection` | `G3.1`, `G3.2` | Done |
| Pointer orchestration + marquee lifecycle | `handlePointer`, move/marquee internals | `SceneControllerInteractiveV2.handlePointer` | `G3.2`, `scene_controller_interactive_v2_unit_test` | Done |
| Draw tools (`pen/highlighter/line/eraser`) | draw slices + tool engines | draw path in `SceneControllerInteractiveV2` + v2 commands | `G3.3`, `G3.4`, `G3.5` | Done |
| Line two-tap pending lifecycle | line tool pending/timer | pending line state in `SceneControllerInteractiveV2` | `G3.4`, `T5` unit checks | Done |
| Text edit request + inline edit flow | `handlePointerSignal` + example inline editor | same contract in v2 interactive runtime | `G3.6`, `G3.14` | Done |
| Text styling panel actions | legacy node patch/update flows | v2 `write(...)` patch flow from example UI | `G3.7` | Done |
| Transform/delete/clear/system actions | legacy command surface | v2 commands via interactive controller | `G3.8`, `G3.10`, `G3.12` | Done |
| Camera/grid/background parity | legacy camera/grid/background setters | v2 `setCameraOffset/setGrid*/setBackgroundColor` | `G3.9`, `G3.10`, `G3.12`, `G3.13` | Done |
| Add Sample deterministic behavior | legacy example flow | v2 example flow | `G3.11` | Done |
| Lockstep legacy-v2 parity scripts | legacy runtime reference | v2 runtime under same scripts | `interactive_parity_batch1/2` (+ root v2 parity copies) | Done |

Критерий приёмки G2:
- `example` работает на v2 interactive controller.
- Все legacy-функции из текущего UX-контракта доступны в v2.
- Поведение и UI совпадают 1:1 по сценариям G2 и regression-тестам.
- После этого можно переходить к `H1`.

### H. Cutover и release

- [ ] H1. После прохождения parity, закрытия `G2L.*` и всех тестов переключить `basic.dart` и `advanced.dart` на v2.
- [ ] H2. Удалить legacy API в рамках major (без отдельного legacy entrypoint).
- [ ] H3. Обновить docs в том же PR:
  - `README.md`;
  - `API_GUIDE.md`;
  - `ARCHITECTURE.md`;
  - public dartdoc (если менялся публичный контракт).
- [ ] H4. Обновить `CHANGELOG.md` (`## Unreleased`, пометить breaking как `Breaking:`).

Критерий приёмки H:
- публичный API major-версии согласован, документация и changelog синхронны.

## 5) Обязательный набор тестов "без новых дыр"

- [x] T1. Внешняя мутация невозможна:
  - нельзя получить mutable сцену/узлы из публичного API;
  - запись вне `write(...)` блокируется и в debug, и в release.
- [x] T2. Атомарность транзакции:
  - внутри `write(...)` нет ранних flush/events/index rebuild;
  - после commit всё согласовано и происходит ровно один flush.
- [x] T3. Epoch-сценарии:
  - `replaceScene(...)` очищает selection;
  - spatial index rebuild;
  - render caches invalidated.
- [x] T4. Bounds/index связка:
  - изменение bounds гарантированно даёт `boundsRevision++` и rebuild индекса.
  - анизотропный transform не даёт "неожиданно дальних" кандидатов hit-test.
- [x] T5. Инструменты/таймеры:
  - pending state line tool корректно очищается на reset/mode switch/dispose flow;
  - reset у draw-tools не оставляет отложенных побочных эффектов после dispose.
- [x] T6. Example interactive parity:
  - каждый сценарий из G2 покрыт тестом в `example/test/**`;
  - зафиксированы ожидаемые состояния UI и публичного API на каждом ключевом шаге сценария.
  - отдельные regression-тесты обязательны для: selection-механики, line tool, eraser flow, text edit flow и text styling flow.
- [x] T8. Interactive parity lockstep (legacy vs v2):
  - одинаковые pointer/input scripts дают одинаковый observable UI state и controller state в `example`;
  - проверены mode/tool transitions, pending-line lifecycle, transform/delete/system flows;
  - тесты выполняются без fallback на legacy runtime.
- [x] T7. v1/v2 parity harness:
  - для набора детерминированных event-script итоговый scene JSON/selection/signals совпадают по контракту между baseline и v2.

## 6) Команды проверки (обязательно перед mark done крупных этапов)

```sh
dart format --output=none --set-exit-if-changed lib test example/lib tool
flutter analyze
flutter test
(cd example && flutter test)
flutter test --coverage
dart run tool/check_coverage.dart
dart run tool/check_invariant_coverage.dart
dart run tool/check_import_boundaries.dart
dart run tool/check_v2_guardrails.dart
```

Рекомендовано перед релизом:

```sh
dart doc
dart pub publish --dry-run
```
