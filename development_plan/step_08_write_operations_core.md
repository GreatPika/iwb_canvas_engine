language: russian

# Шаг 8. Ввести ядро операций записи

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как отдельный критерий готовности. Шаг должен упростить write hot path через единый исполнитель операций, а не просто перераспределить длинные методы по новым файлам.

- Смотреть в первую очередь `cyclomatic-complexity` и `source-lines-of-code`.
- Дополнительно смотреть `maximum-nesting-level` в commit/apply/postcheck маршрутах.
- Контрольные файлы:
  - `lib/src/controller/mutation_executor.dart`
  - `lib/src/controller/scene_controller.dart`
  - `lib/src/controller/scene_writer.dart`
  - `lib/src/controller/txn_context.dart`
  - `lib/src/controller/scene_invariants.dart`
  - `lib/src/model/document.dart`
- Полезный сигнал после шага: commit/apply path больше не держит в одном месте preconditions, mutation, invariant checks и commit preparation, а `mutation_executor.dart` не становится новой monolith-точкой записи.

## Создать `lib/src/controller/mutation_op.dart`

Добавить типы операций:

1. `InsertNodeOp`
2. `PatchNodeOp`
3. `DeleteNodeOp`
4. `DeleteNodesBulkOp`
5. `ReplaceSceneOp`
6. `SetBackgroundColorOp`
7. `SetGridEnabledOp`
8. `SetGridCellSizeOp`
9. `SetCameraOffsetOp`
10. `TransformSelectionOp`
11. `TranslateSelectionOp`

## Создать `lib/src/controller/mutation_executor.dart`

Сделать единый маршрут:

1. preconditions
2. apply
3. postcheck
4. changeSet
5. commit preparation

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Перевести write-методы на общий исполнитель операций.
2. Не держать локальные частные правила там, где ими должен владеть `ScenePolicy`.
3. Убрать лишние копии selection и signals.
4. `selectedNodeIds` отдавать как безопасное представление, без лишнего пересоздания.

## `lib/src/controller/scene_controller.dart`

Сделать:

1. `write(...)` перевести на общий исполнитель.
2. Коммит выполнять только после postcheck.
3. `dispose()`:

   * либо запрещён во время write,
   * либо откладывается.
4. Из hot path убрать:

   * debug copies,
   * commit phase copying,
   * лишние списки и клонирования.
