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
- [ ] G4. Добавить engine-level parity harness v1 vs v2 (пока legacy ещё существует):
  - одинаковые входные event-script дают эквивалентный публичный результат (scene JSON, selected ids, contract-level signals/actions).
- [ ] G5. Закрыть все найденные parity-gap без изменения UX-контракта baseline.

Критерий приёмки G:
- при открытии `example/lib/main.dart` и прохождении сценариев из G2 поведение и интерактивность не отличаются от baseline v1 в рамках зафиксированного checklist (включая выделение, ластик, line tool и редактирование текстовых узлов).

### H. Cutover и release

- [ ] H1. После прохождения parity и всех тестов переключить `basic.dart` и `advanced.dart` на v2.
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

- [ ] T1. Внешняя мутация невозможна:
  - нельзя получить mutable сцену/узлы из публичного API;
  - запись вне `write(...)` блокируется и в debug, и в release.
- [ ] T2. Атомарность транзакции:
  - внутри `write(...)` нет ранних flush/events/index rebuild;
  - после commit всё согласовано и происходит ровно один flush.
- [ ] T3. Epoch-сценарии:
  - `replaceScene(...)` очищает selection;
  - spatial index rebuild;
  - render caches invalidated.
- [ ] T4. Bounds/index связка:
  - изменение bounds гарантированно даёт `boundsRevision++` и rebuild индекса.
  - анизотропный transform не даёт "неожиданно дальних" кандидатов hit-test.
- [ ] T5. Инструменты/таймеры:
  - pending state line tool корректно очищается на reset/mode switch/dispose flow;
  - reset у draw-tools не оставляет отложенных побочных эффектов после dispose.
- [ ] T6. Example interactive parity:
  - каждый сценарий из G2 покрыт тестом в `example/test/**`;
  - зафиксированы ожидаемые состояния UI и публичного API на каждом ключевом шаге сценария.
  - отдельные regression-тесты обязательны для: selection-механики, line tool, eraser flow, text edit flow и text styling flow.
- [ ] T7. v1/v2 parity harness:
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

## 7) Журнал прогресса

| Дата | Пункт | Статус | Комментарий |
|---|---|---|---|
| 2026-02-09 | A0 | Done | План сокращён, исправлен и приведён к чеклист-формату. |
| 2026-02-09 | A1-A4 | Done | Добавлены INV-V2-*, расширены import boundaries для `lib/src/v2/**`, добавлен `tool/check_v2_guardrails.dart`, добавлены tool-тесты и enforcement-маркеры. |
| 2026-02-09 | B1-B3 | Done | Добавлены immutable v2 public-модели (`snapshot/spec/patch`), tri-state `PatchField`, временные entrypoints `basic_v2.dart`/`advanced_v2.dart` и тесты на immutable-контракт. |
| 2026-02-09 | C1-C5, D1-D9 | Done | Добавлены `SceneControllerV2`/`SceneWriter`/`TxnContext`/`ChangeSet`/`V2Store`, внутренний mutable-документ с конвертерами `SceneSnapshot <-> Scene`, транзакционные v2-slices (`commands/move/draw/selection/spatial_index/signals/repaint/grid`), commit-order `selection->grid->spatial_index->signals->repaint`, `writeReplaceScene(...)` с `controllerEpoch++`, и тесты на atomic commit/rollback/epoch/signal buffering. |
| 2026-02-09 | H2 | Decision fixed | Legacy API в major удаляем, отдельный legacy entrypoint не поддерживаем. |
| 2026-02-09 | E1-E5 | Done | Candidate bounds переведены на strict scene units, добавлены `ScenePainterV2`/`SceneViewV2` и v2 caches с epoch-based invalidation, `SceneStrokePathCache` сделан fail-safe для 0/1 точки, добавлены v2 render/view и core hit-test regression тесты. |
| 2026-02-09 | F1-F5 | Done | Добавлен `lib/src/v2/serialization/scene_codec.dart` с публичным snapshot API (`encode/decode*`), внутренними document adapters через `txnSceneFromSnapshot`/`txnSceneToSnapshot`, сохранена совместимость `_requireInt` для integer-valued `num`, портированы `test/serialization/*` на `basic_v2.dart`, добавлен тест на immutable decode-контракт. |
| 2026-02-09 | G/H rescope | Done | Этап `G` разделён: сначала полный interactive parity c baseline v1 (`example-first`), затем отдельный cutover/release этап `H`; добавлены обязательные тесты `T6-T7` и проверка `(cd example && flutter test)`. |
| 2026-02-09 | G1 | Done | Baseline parity зафиксирован на `baseline-vertical-slices-2026-02-04` по решению PM. |
| 2026-02-09 | G2/T6 scope | Done | По решению PM явно закреплены обязательные parity-сценарии: выделение, ластик, line tool, текстовые узлы (редактирование + styling). |
| 2026-02-09 | G2/G3 split | Done | Пункты `G2` и `G3` декомпозированы на подшаги `G2.1..G2.10` и `G3.1..G3.10` для прозрачного трекинга прогресса по каждому сценарию и тесту. |
| 2026-02-09 | G2/G3 scope extend | Done | Добавлены сценарии из `example/lib/main.dart`, которые не были явными: `Add Sample`, background+clear, визуальные индикаторы камеры/line-pending, text edit commit-триггеры; добавлены `G3.11..G3.14`. |
| 2026-02-09 | G2.1-G2.5, G3.1-G3.5 | Done | Добавлены scenario-parity tests в `example/test/interactive_parity_batch1_test.dart`, в `example/lib/main.dart` добавлены non-breaking test hooks (опциональная инъекция `SceneController` + стабильные keys), а также вынесена общая pure-логика порогов/декимации в `lib/src/core/input_sampling.dart` с переиспользованием в `move/line/stroke/eraser` slices. |
| 2026-02-10 | G2.6, G3.6 | Done | Зафиксирован parity-сценарий text inline edit в текущем UX-контракте example: открытие только по double-tap, save через `onTapOutside`, no-op cancel как закрытие сессии без изменения текста; добавлен regression-тест в `example/test/interactive_parity_batch1_test.dart`. |
| 2026-02-10 | G2.7, G3.7 | Done | Добавлены deterministic test hooks для text styling controls (`bold/italic/underline`, `align`, `font size`, `line height`, color swatches) в `example/lib/main.dart`; добавлен parity regression-тест `G3.7` с multi-select проверкой controller/UI state в `example/test/interactive_parity_batch1_test.dart`. |
| 2026-02-10 | G2.8, G3.8 | Done | Добавлены стабильные test hooks для action-кнопок transform (`rotate/flip`) в `example/lib/main.dart`; добавлен parity regression-тест `G3.8` на связку `marquee-select -> rotate/flip -> delete` с проверкой, что невыделенные ноды не изменяются. |
| 2026-02-10 | G2.9, G3.9 | Done | Добавлены camera pan controls (`left/right/up/down`, шаг `50`) в `example/lib/main.dart` и parity regression-тест `G3.9` в `example/test/interactive_parity_batch1_test.dart`; `zoom` сознательно оставлен вне scope по текущему single-pointer/no-zoom контракту движка. |
| 2026-02-10 | G2.10, G3.10 | Done | Для `grid/system actions` добавлены стабильные test hooks в `example/lib/main.dart` (grid toggle/size, background swatches, system export/import, import dialog), зафиксирована import-политика `replace scene => clear selection`, и добавлен parity regression-тест `G3.10` в `example/test/interactive_parity_batch1_test.dart` с проверкой grid/background/export/import/clear flow. |
| 2026-02-10 | G2.11, G3.11 | Done | Добавлен widget parity-тест `G3.11` для `Add Sample`: проверены типы/порядок/id/позиции/размеры `RectNode+TextNode`, повторяемость второго добавления и отсутствие побочного изменения selection. |
