language: russian

# Шаг 10. Вынести pointer-router в правильную форму

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как отдельный критерий готовности. Метрики здесь помогают проверить, что pointer-router действительно локализован, а сложность не утекла в соседние interactive paths.

- Смотреть в первую очередь `cyclomatic-complexity`, `maximum-nesting-level` и `source-lines-of-code`.
- Контрольные файлы:
  - `lib/src/view/scene_view_interactive.dart`
  - `lib/src/interactive/scene_controller_interactive.dart`
- Полезный сигнал после шага: pointer id routing, reset policy и deferred flush logic не требуют нескольких тяжёлых веток для одной и той же жизненной фазы указателя, а pointer-router concern не расползается обратно по соседним interactive owner-ам.

## `lib/src/view/scene_view_interactive.dart`

Сделать:

1. В самом начале `_handlePointerEvent(...)`:

   * отсекать `NaN/Infinity`
   * до:

     * `_captureActivePointer`
     * `handlePointer`
     * `_pointerTracker.handle`
     * `_syncPendingFlushTimer`

2. Исправить `Duration(milliseconds: ...)` через явный `toInt()`.

3. Развести пространства:

   * raw pointer ids
   * internal slot ids

4. Исправить `_resolvePointerId(...)`:

   * удерживаемый raw-pointer сохраняет свой internal id до конца жизни.

5. Изменить reset-политику:

   * нельзя сбрасывать tracking, пока есть хоть один живой raw-pointer.

6. Изменить порядок:

   * сначала release slot,
   * потом reset и очистка таблиц.

7. Убрать линейный поиск минимума в `_acquirePointerSlot()`.

8. Заменить ручное сравнение `PointerInputSettings` по полям на более надёжную схему.

9. `flushPending`:

   * не создавать коллекции, если результат дальше не используется.

10. Проверить `mounted` во всех отложенных путях и слушателях.

11. Пересмотреть смену pointer settings при активном жесте.
