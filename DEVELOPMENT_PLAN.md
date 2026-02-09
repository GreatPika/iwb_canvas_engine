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

- [ ] C1. Создать `lib/src/v2/model/` с внутренней mutable-моделью (не экспортируется наружу).
- [ ] C2. Создать store (`lib/src/v2/controller/store.dart`) с:
  - `controllerEpoch`;
  - `structuralRevision`, `boundsRevision`, `visualRevision`.
- [ ] C3. Реализовать `SceneControllerV2.write(fn)` + `TxnContext` + `SceneWriter`.
- [ ] C4. Сделать `ChangeSet` источником правды для commit:
  - `documentReplaced`, `structuralChanged`, `boundsChanged`, `visualChanged`, `selectionChanged`, `gridChanged`;
  - `added/removed/updated` ids.
- [ ] C5. `boundsChanged` вычислять автоматически сравнением `oldBounds/newBounds` до/после мутации узла.

Критерий приёмки C:
- несколько операций внутри одного `write(...)` приводят к одному commit и консистентному `ChangeSet`.

### D. Input slices поверх транзакций

- [ ] D1. Новый v2-контракт для slices: read-only чтение + write-доступ только внутри txn.
- [ ] D2. Порт `commands` на txn; запрет `addNode` в background layer.
- [ ] D3. Порт `move` и `draw` на txn; не должно быть прямых мутаций "мимо write".
- [ ] D4. `selection` нормализует удалённые id на commit.
- [ ] D5. Вынести spatial index в отдельный `spatial_index` slice (epoch + boundsRevision invalidation).
- [ ] D6. `signals` буферизует события внутри txn и эмитит только после commit.
- [ ] D7. `repaint` делает один flush на commit (batch mode).
- [ ] D8. Нормализация grid в commit-пайплайне (`grid` slice или эквивалентный слой).
- [ ] D9. Зафиксировать порядок `onCommit`:
  1) `selection`
  2) `grid`
  3) `spatial_index`
  4) `signals`
  5) `repaint`

Критерий приёмки D:
- мутация только через транзакции, commit-order фиксирован и покрыт тестами.

### E. Hit-test, render и view

- [ ] E1. Исправить candidate bounds в hit-test v2 на строгую семантику scene units (без `_scenePaddingToWorldMax`-раздувания).
- [ ] E2. Портировать `ScenePainter` + кэши с epoch-инвалидацией.
- [ ] E3. Сделать `SceneStrokePathCache` fail-safe на `0/1` точке (без исключения).
- [ ] E4. В `SceneView` добавить invalidation по epoch и очищать все кэши, включая static layer cache.
- [ ] E5. Сохранить текущий контракт сетки: при over-density использовать stride-деградацию, а не "молчаливое исчезновение" сетки.

Критерий приёмки E:
- нет "призрачных" кэшей после `replaceScene`, hit-test предсказуем при анизотропии.

### F. Сериализация v2

- [ ] F1. Портировать codec в `lib/src/v2/serialization/`.
- [ ] F2. `decode` возвращает snapshot/document v2 (не mutable Scene).
- [ ] F3. `encode` принимает snapshot/document v2.
- [ ] F4. Портировать и адаптировать `test/serialization/*`.
- [ ] F5. Сохранить совместимость `_requireInt`: принимать `num`, проверять целочисленность, затем приводить к `int`.

Критерий приёмки F:
- JSON v2 round-trip проходит на новой модели без утечек mutable-состояния наружу.

### G. Cutover и release

- [ ] G1. После прохождения всех тестов переключить `basic.dart` и `advanced.dart` на v2.
- [ ] G2. Удалить legacy API в рамках major (без отдельного legacy entrypoint).
- [ ] G3. Обновить docs в том же PR:
  - `README.md`;
  - `API_GUIDE.md`;
  - `ARCHITECTURE.md`;
  - public dartdoc (если менялся публичный контракт).
- [ ] G4. Обновить `CHANGELOG.md` (`## Unreleased`, пометить breaking как `Breaking:`).

Критерий приёмки G:
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

## 6) Команды проверки (обязательно перед mark done крупных этапов)

```sh
dart format --output=none --set-exit-if-changed lib test example/lib tool
flutter analyze
flutter test
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
| 2026-02-09 | G2 | Decision fixed | Legacy API в major удаляем, отдельный legacy entrypoint не поддерживаем. |
