language: russian

# Шаг 9.3. Перевести `DrawCommands` и `SceneCommands` на exact writer semantics

## Цель шага

После `9.1-9.2` low-level и writer boundary уже должны давать точные results,
но command-layer всё ещё останется неточным, если internal adapters продолжат:

- определять изменение через full snapshot before/after;
- выражать bulk erase как цикл single-delete;
- держать неявную policy для draw stroke points и scalar settings inputs.

Задача подшага: сделать `DrawCommands` и `SceneCommands` тонкими, но точными
internal adapters поверх writer-owned results, без расширения public surface и
без новых ложных signal/no-op paths.

## Что уже подтверждено по текущему состоянию

1. [draw_commands.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/commands/draw_commands.dart)
   сейчас реализует `writeEraseNodes(...)` как цикл `writeNodeErase(...)` с
   накоплением удалённых ids после факта.
2. `_resampleStrokePointsToLimit(...)` в
   [draw_commands.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/commands/draw_commands.dart)
   возвращает исходный `List<Offset>`, если лимит не превышен, то есть
   canonical point policy выражена неявно и завязана на промежуточный raw list.
3. [scene_commands.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/commands/scene_commands.dart)
   для scalar setters (`background`, `grid`, `camera`) сравнивает
   `writer.snapshot` до и после мутации, то есть строит full snapshot ради
   scalar no-op detection.
4. `writeSelectionSelectAll(...)` в
   [scene_commands.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/commands/scene_commands.dart)
   сейчас копирует текущее selection состояние только затем, чтобы после write
   ещё раз вычислить, нужно ли слать `selection.all`.
5. `DrawCommands` и `SceneCommands` не входят в public export surface пакета и
   уже сегодня являются internal controller adapters.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `DrawCommands` и `SceneCommands` остаются thin internal adapters. Новый
   command service, orchestration layer или registry не вводится.
2. Команды получают exact changed/effective values только от internal методов
   самого `SceneWriter`, зафиксированных в `9.2`. Snapshot diff для scalar
   setters и selection signals после шага `9.3` не допускается.
3. Multi-node erase в draw path использует один канонический bulk delete route.
   Нельзя оставлять цикл single-delete как owner bulk semantics.
4. `writeDrawStroke(...)` закрепляет одну каноническую draw-points policy:
   - resample делается только при превышении лимита;
   - первая и последняя точки сохраняются;
   - intermediate helper больше не выражает caller-owned raw list как
     отдельную reusable policy surface.
5. `writeDrawStroke(...)`, `writeDrawLine(...)` и draw-specific return values
   закрепляются как `NodeId`, а не как строковые compatibility aliases.
6. Scalar settings commands работают с уже нормализованным effective value.
   Если input после нормализации даёт тот же committed scalar state, signal не
   отправляется и commit revision не должен дрейфовать из-за command-layer.
7. Selection signal commands (`replace`, `toggle`, `clear`, `all`, `transform`,
   `delete`) используют exact writer results и committed ids; дополнительные
   до/после копии selection set только ради signal decision не допускаются.

## Граница шага

- In:
  - `DrawCommands`;
  - `SceneCommands`;
  - command-specific signal routing поверх writer results;
  - canonical draw/settings command semantics.
- Out:
  - low-level delete/patch algorithms;
  - public `SceneWriteTxn` contract;
  - новый command orchestration owner.

## Точная реализация, которую должен описывать код

1. `DrawCommands` и `SceneCommands` переходят с `SceneWriteTxn`-typed internal
   runner на `SceneWriter`-typed internal runner из `9.2`, потому что им нужны
   exact writer results, а не public boundary abstraction.
2. `writeDrawStroke(...)` строит финальный `StrokeNodeSpec` напрямую в одном
   месте. Private resample helper остаётся только внутренней деталью этой
   команды, возвращает fresh list только для overflow-case и не образует
   отдельный ownership seam для raw points.
3. `writeEraseNodes(...)` использует один bulk delete вызов, сортирует removed
   ids один раз и отправляет `draw.erase` только если реально что-то удалено.
4. `writeBackgroundColorSet(...)`, `writeGridEnabledSet(...)`,
   `writeGridCellSizeSet(...)`, `writeCameraOffsetSet(...)` опираются на exact
   writer result и normalized effective value без materialization
   `writer.snapshot`.
5. `writeSelectionSelectAll(...)` и другие selection signal commands больше не
   копируют current selection только затем, чтобы заново вычислить факт change
   после writer call.
6. Ни один command adapter после шага `9.3` не должен:
   - строить full snapshot до/после ради changed semantics;
   - делать repeated single-write loop там, где уже есть bulk owner path;
   - слать ложный signal для no-op normalized input.

## Последовательность реализации (только действия)

[x] Перевести `DrawCommands` и `SceneCommands` на writer-local internal seam из
    `9.2`.
[x] Убрать snapshot before/after diff из scalar settings commands.
[x] Перевести draw erase на один bulk delete route.
[x] Зафиксировать одну каноническую draw stroke points policy без утечки
    intermediate raw list semantics.
[x] Убрать selection set copy, которая нужна только для вторичного signal
    decision.
[x] Перепроверить tests на no-op signal behavior и commit revision drift.
[x] Повторно прогнать
    `dcm calculate-metrics lib/src/controller/commands/draw_commands.dart lib/src/controller/commands/scene_commands.dart --report-all`
    и зафиксировать итоговые watchpoints этих owner-ов в результате шага.

## Критерии приёмки

[x] `DrawCommands` и `SceneCommands` остаются thin internal adapters и не
    создают новый owner command orchestration.
[x] Scalar settings commands не используют full snapshot diff.
[x] Draw erase больше не реализован через цикл single-delete.
[x] Draw command return types закреплены как `NodeId`.
[x] Canonical draw stroke points policy выражена явно и не зависит от
    случайного reuse caller-owned raw list.
[x] No-op normalized settings/selection commands не шлют ложные сигналы и не
    вызывают лишний commit revision drift.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/controller/commands/draw_commands.dart lib/src/controller/commands/scene_commands.dart --report-all`
    приложена к результату шага; для step-owned watchpoints command adapters не
    остаётся необъяснённого snapshot-diff/bulk-loop drift.

## Тестовый контур шага

[x] `test/controller/commands/draw_commands_test.dart`
[x] `test/controller/commands/scene_commands_test.dart`
[x] `test/interactive/core/interactive_draw_eraser_engine_test.dart`
[x] `test/controller/core/scene_controller_spatial_index_test.dart`
[x] Повторная диагностика:
    `dcm calculate-metrics lib/src/controller/commands/draw_commands.dart lib/src/controller/commands/scene_commands.dart --report-all`

## Результат шага

- `DrawCommands` переведён на `SceneWriter`-typed internal runner и использует
  exact bulk-delete result вместо цикла `writeNodeErase(...)`.
- `SceneCommands` переведён на тот же internal seam и опирается на
  `SceneWriter` exact-result helpers для selection/scalar signal semantics.
- `SceneWriter` получил internal-only bulk delete helpers
  `writeDeleteNodesResult(...)` и `writeDeleteSelectionResult(...)`, поэтому
  command adapters больше не восстанавливают committed ids из входа.
- Закреплены tests на no-op erase/delete signal behavior и отсутствие лишнего
  commit revision drift.

## Метрики и watchpoints

- `dcm calculate-metrics lib/src/controller/commands/draw_commands.dart lib/src/controller/commands/scene_commands.dart --report-all`
  после шага:
  - `DrawCommands.writeEraseNodes(...)`: cyclomatic complexity `2`, nesting
    `2`, source lines `7`
  - `DrawCommands.writeDrawStroke(...)`: cyclomatic complexity `1`, nesting
    `1`, parameters `4` (`NEAR`), source lines `19`
  - `DrawCommands.writeDrawLine(...)`: cyclomatic complexity `1`, nesting `1`,
    parameters `4` (`NEAR`), source lines `16`
  - `SceneCommands.writeSelectionReplace(...)`: cyclomatic complexity `2`,
    nesting `2`, source lines `9`
  - `SceneCommands.writeDeleteSelection(...)`: cyclomatic complexity `2`,
    nesting `2`, source lines `10`
  - `SceneCommands.writeClearScene(...)`: cyclomatic complexity `3`, nesting
    `2`, source lines `11`
  - scalar setter commands `writeBackgroundColorSet(...)`,
    `writeGridEnabledSet(...)`, `writeGridCellSizeSet(...)`,
    `writeCameraOffsetSet(...)` остаются `BELOW` по всем метрикам
- Итог: для step-owned command adapters нет `HIGH`; остаются только ожидаемые
  `NEAR` по `number-of-parameters` у draw create commands.
