language: russian

# Шаг 4.4. Довести writer/controller contract до точной публичной семантики

## Цель шага

Этот шаг закрывает controller-facing contract drift там, где поведение уже существовало, но было выражено неточно. Аудит подтвердил, что `DrawCommands.writeDrawStroke(...)` и `DrawCommands.writeDrawLine(...)` уже возвращают `NodeId`, а `writeSelectionTransform(...)` уже использует pre-multiply порядок композиции transform. Для закрытия шага нужно было зафиксировать это как публичный контракт в документации, тестах и plan artifacts без косметического переписывания всего command layer.

## Что этот шаг считает своим владельцем

1. Public draw command return types:
   - `DrawCommands.writeDrawStroke(...)`
   - `DrawCommands.writeDrawLine(...)`
2. Public transform semantics:
   - `SceneWriteTxn.writeSelectionTransform(...)`
   - `SceneWriter.writeSelectionTransform(...)`
3. Документирование и тестирование этих двух контрактов.

## Что уже подтверждено по текущему состоянию

1. `lib/src/controller/commands/draw_commands.dart` уже возвращает `NodeId` из `writeDrawStroke(...)` и `writeDrawLine(...)`.
2. `lib/src/contract/scene_write_txn.dart` уже фиксирует `writeSelectionTransform(...)` как pre-multiply semantics: `nextTransform = delta.multiply(existingTransform)`.
3. `lib/src/controller/scene_writer.dart` уже реализует тот же порядок через `delta.multiply(existing.node.transform)`.
4. `test/controller/internal/scene_writer_test.dart` уже содержит order-sensitive test, который ломается при смене порядка композиции.
5. Для остальных command-layer return types подтверждённого public mismatch нет, поэтому шаг не должен разрастаться до общего cleanup.

## Рекомендуемое решение

Рекомендуемый вариант: не добавлять новые runtime-изменения там, где контракт уже реализован, а закрыть шаг через audit, release-ready docs и синхронизацию roadmap с фактом реализации.

Что это означает на практике:

1. `writeDrawStroke(...)` и `writeDrawLine(...)` остаются `NodeId`-returning contract.
2. `writeSelectionTransform(...)` остаётся задокументированным как pre-multiply semantics:
   - `nextTransform = delta.multiply(existingTransform)`
3. Остальные command-layer сигнатуры не меняются без подтверждённого contract drift.

## Что именно менять

### `lib/src/controller/commands/draw_commands.dart`

[x] Подтвердить audit-ом, что `writeDrawStroke(...)` уже возвращает `NodeId`.
[x] Подтвердить audit-ом, что `writeDrawLine(...)` уже возвращает `NodeId`.

### `lib/src/contract/scene_write_txn.dart`

[x] Подтвердить и сохранить явную фиксацию порядка композиции для `writeSelectionTransform(...)` в doc comments.

### `lib/src/controller/scene_writer.dart`

[x] Подтвердить, что реализация соответствует публично задокументированному порядку композиции.
[x] Не расширять этот шаг до rewrite других write methods без подтверждённого contract drift.
[x] Зафиксировать шаг как narrow contract-alignment без общего rewrite writer documentation.

## Конкретизация внедрения по порядку

1. Подтвердить аудитом `NodeId` return types draw entrypoints.
2. Подтвердить и сохранить pre-multiply semantics в public doc comment `SceneWriteTxn`.
3. Подтвердить существующий отдельный тест на порядок композиции transform.
4. Обновить release-ready docs и plan artifacts, чтобы шаг не оставался открытым после фактического закрытия контракта.

## Критерии приемки

[x] `writeDrawStroke(...)` и `writeDrawLine(...)` возвращают `NodeId`, а не ослабленный `String`.
[x] Контракт `writeSelectionTransform(...)` явно описывает pre-multiply semantics.
[x] Есть отдельный тест, который ломается при смене порядка композиции transform.
[x] Шаг не превращается в cosmetic cleanup всего controller command layer.

## Тестовый контур

[x] `test/controller/commands/draw_commands_test.dart`
[x] `test/controller/commands/scene_commands_test.dart`
[x] `test/controller/internal/scene_writer_test.dart`
