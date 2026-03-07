language: russian

# Шаг 4.4. Довести writer/controller contract до точной публичной семантики

## Цель шага

Этот шаг закрывает controller-facing contract drift там, где поведение уже существует, но выражено неточно. Сейчас draw entrypoints возвращают `String`, хотя публичный writer contract оперирует `NodeId`, а `writeSelectionTransform(...)` уже использует конкретный порядок композиции transform, который пока зафиксирован только кодом. Нужно подтянуть именно эти подтверждённые несоответствия без косметического переписывания всего command layer.

## Что этот шаг считает своим владельцем

1. Public draw command return types:
   - `DrawCommands.writeDrawStroke(...)`
   - `DrawCommands.writeDrawLine(...)`
2. Public transform semantics:
   - `SceneWriteTxn.writeSelectionTransform(...)`
   - `SceneWriter.writeSelectionTransform(...)`
3. Документирование и тестирование этих двух контрактов.

## Что уже подтверждено по текущему состоянию

1. Внутренний writer contract уже работает через `NodeId`, а `String` в draw commands только ослабляет выраженность public API.
2. `writeSelectionTransform(...)` уже использует `delta.multiply(existingTransform)`, но это поведение пока не описано как публичная семантика.
3. Для остальных command-layer return types подтверждённого public mismatch сейчас нет, поэтому шаг не должен разрастаться до общего cleanup.

## Рекомендуемое решение

Рекомендуемый вариант: исправить только подтверждённые public mismatches и зафиксировать их тестами/доками.

Что это означает на практике:

1. `writeDrawStroke(...)` и `writeDrawLine(...)` возвращают `NodeId`.
2. `writeSelectionTransform(...)` документируется как pre-multiply semantics:
   - `nextTransform = delta.multiply(existingTransform)`
3. Остальные command-layer сигнатуры меняются только при подтверждённом contract drift.

## Что именно менять

### `lib/src/controller/commands/draw_commands.dart`

[ ] Заменить `String` на `NodeId` в `writeDrawStroke(...)`.
[ ] Заменить `String` на `NodeId` в `writeDrawLine(...)`.

### `lib/src/contract/scene_write_txn.dart`

[ ] Явно зафиксировать порядок композиции для `writeSelectionTransform(...)` в doc comments.

### `lib/src/controller/scene_writer.dart`

[ ] Убедиться, что реализация соответствует публично задокументированному порядку композиции.
[ ] Не расширять этот шаг до rewrite других write methods без подтверждённого contract drift.
[ ] Если обнаружатся другие public write methods с уже де-факто закреплённым behavior, сузить изменение до минимально необходимого набора и не превращать подшаг в общий rewrite writer documentation.

## Конкретизация внедрения по порядку

1. Выравнять return types draw entrypoints до `NodeId`.
2. Зафиксировать pre-multiply semantics в public doc comment `SceneWriteTxn`.
3. Добавить отдельный тест на порядок композиции transform.
4. Проверить, что существующие controller tests по-прежнему проходят без дополнительных сигнатурных обходных слоёв.

## Критерии приемки

[ ] `writeDrawStroke(...)` и `writeDrawLine(...)` возвращают `NodeId`, а не ослабленный `String`.
[ ] Контракт `writeSelectionTransform(...)` явно описывает pre-multiply semantics.
[ ] Есть отдельный тест, который ломается при смене порядка композиции transform.
[ ] Шаг не превращается в cosmetic cleanup всего controller command layer.

## Тестовый контур

[ ] `test/controller/commands/draw_commands_test.dart`
[ ] `test/controller/commands/scene_commands_test.dart`
[ ] `test/controller/internal/scene_writer_test.dart` при необходимости
