language: russian

# Шаг 10. Вынести pointer-router в правильную форму

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

