language: russian

# Шаг 9. Довести командный слой до правильной сложности и семантики

## `lib/src/controller/commands/draw_commands.dart`

Сделать:

1. `writeDrawStroke(...)`:

   * использовать одну каноническую политику точек,
   * не возвращать список, который потом может быть неожиданно разделён с внешним кодом.
2. `writeEraseNodes(...)`:

   * перейти на bulk delete.
3. Возвращать `NodeId`, а не `String`.

## `lib/src/controller/commands/scene_commands.dart`

Сделать:

1. `writeBackgroundColorSet(...)`
2. `writeGridEnabledSet(...)`
3. `writeGridCellSizeSet(...)`
4. `writeCameraOffsetSet(...)`

Они должны:

* не строить full snapshot до/после;
* использовать `changed`;
* сравнивать уже нормализованное значение;
* не слать ложные сигналы.

## `lib/src/model/document.dart`

Сделать:

1. Все пути удаления перевести на bulk-вариант.
2. Убрать квадратичные маршруты удаления.
3. Для `writeDeleteSelection` не делать полный скан документа, когда выбор маленький и есть локатор.
4. Для патча точек штриха:

   * сначала сравнивать длину и элементы,
   * копировать список только при реальном изменении,
   * **не менять `pointsRevision` на no-op**,
   * **не создавать новый список на no-op**.

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Оптимизировать:

   * `writeDeleteSelection()`
   * `writeSelectionSelectAll()`
   * `writeSelectionTransform()`
   * `writeSignalEnqueue(...)`
2. Убрать лишние проходы.
3. Убрать лишние копии.
4. Закрепить transform order.
5. Закрепить семантику пустой selection replacement.

