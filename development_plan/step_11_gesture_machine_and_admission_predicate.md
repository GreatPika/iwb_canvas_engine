language: russian

# Шаг 11. Вынести gesture-machine и единый предикат допустимости

## `lib/src/interactive/scene_controller_interactive.dart`

Сделать:

1. В конструкторе та же валидация `dragStartSlop`, что и в сеттере.
2. Отдельно выбрать и закрепить **одно правило** для:

   * `setDragStartSlop(...)`
   * `pointerSettings.tapSlop`
     если сейчас одно допускает `0`, а другое требует `> 0`.
3. В `handlePointer(...)`:

   * `cancel` не отбрасывается из-за невалидной позиции,
   * `up` с невалидной позицией трактуется как `cancel`.
4. На `down`:

   * фиксировать baseline `dragStartSlop` для текущего жеста.
5. `replaceScene(...)`:

   * отменяет активный жест полностью.
6. `setCameraOffset(...)`:

   * отменяет активный жест полностью.
7. Сохранить монотонность `timestampMs`.
8. Привести preview/commit к одному предикату допустимости.

## `lib/src/interactive/internal/interactive_move_session.dart`

Сделать:

1. Preview использует тот же предикат, что commit:

   * `isLocked`
   * `isTransformable`
   * `isSelectable`
2. На `cancel`:

   * откатить baseline выбора.
3. Убрать дублирующие `onStateChanged`.
4. Логику допустимости держать не в нескольких местах, а в одном.

## `lib/src/interactive/internal/interactive_draw_coordinator.dart`

Сделать:

1. Допустимость удаления и рисования привести к общей политике.
2. Проверить восстановление после безопасного `cancel`.

## `lib/src/interactive/internal/interactive_draw_line_engine.dart`

Сделать:

1. Пересмотреть таймеры и pending-state при cancel и при смене сцены.
2. Не допускать утечки активной pending-линии после общего сброса интерактива.

## Создать `lib/src/interactive/interaction_eligibility_policy.dart`

Добавить:

1. `canSelect(...)`
2. `canPreviewMove(...)`
3. `canCommitMove(...)`
4. `canDelete(...)`
5. `canTransform(...)`

Этим модулем должны пользоваться:

* interactive move
* selection
* delete
* writer/runtime, где релевантно

