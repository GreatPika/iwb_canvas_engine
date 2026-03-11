language: russian

# Шаг 11. Вынести gesture-machine и единый предикат допустимости

## Цель шага

После `10.1-10.3` view/runtime boundary уже должна владеть только:

- raw-to-slot routing;
- host admission;
- host-owned terminal cleanup для router/tracker/timer;
- timer/listener lifecycle;
- apply-on-idle settings contract.

Всё, что придаёт terminal event смысл для активного gesture, должно
сконцентрироваться здесь. Задача шага `11`: сделать controller-side
gesture-machine единственным source of truth для:

- active gesture owner;
- invalid terminal semantics;
- cancel/abort recovery;
- preview/commit admissibility.

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как
отдельный критерий готовности. Здесь метрики нужны, чтобы проверить не только
вынос eligibility policy, но и то, что preview/commit/cancel больше не живут в
нескольких похожих тяжёлых ветках.

- Смотреть в первую очередь `cyclomatic-complexity`,
  `maximum-nesting-level` и `source-lines-of-code`.
- Контрольные файлы:
  - `lib/src/interactive/interaction_eligibility_policy.dart`
  - `lib/src/interactive/scene_controller_interactive.dart`
  - `lib/src/interactive/internal/interactive_move_session.dart`
  - `lib/src/interactive/internal/interactive_draw_coordinator.dart`
  - `lib/src/interactive/internal/interactive_draw_line_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- Полезный сигнал после шага: active gesture owner, invalid terminal recovery,
  preview, commit и cancel-path используют одну policy-модель вместо нескольких
  частично пересекающихся веток, а `interaction_eligibility_policy.dart`
  остаётся компактным правилом допуска, а не новым центром всей интерактивной
  логики.

## Граница шага

- In:
  - controller-side трактовка invalid `up/cancel`;
  - active gesture owner и правило, какой pointer может abort/reset текущий
    gesture;
  - единый cancel/abort contract;
  - baseline `dragStartSlop` для текущего gesture lifecycle;
  - общий eligibility policy для preview/commit.
- Out:
  - raw-to-slot router owner;
  - host timer/listener lifecycle;
  - value semantics `PointerInputSettings`;
  - apply-on-idle settings contract.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneControllerInteractive` и его internal session-ы становятся
   единственным owner-ом active gesture meaning после routed dispatch.
2. View не имеет права:
   - синтезировать safe terminal `up/cancel` для controller;
   - вызывать ad hoc abort bridge в controller;
   - принимать решение, как invalid terminal input влияет на active gesture.
3. Каноническое правило для invalid terminal input фиксируется в
   `handlePointer(...)`:
   - invalid `cancel` не отбрасывается и трактуется как terminal `cancel`;
   - invalid `up` трактуется как `cancel`;
   - direct controller entrypoint и path через view используют одну и ту же
     semantics.
4. Terminal recovery применяется только к активному controller-side gesture
   owner-у. Параллельный не-владеющий pointer не имеет права сбрасывать чужой
   gesture.
5. `replaceScene(...)` и `setCameraOffset(...)` отменяют активный gesture
   полностью здесь, а не через view-side workaround.
6. Preview/commit/cancel используют один eligibility policy вместо нескольких
   разрозненных ad hoc проверок.
7. Монотонность `timestampMs` сохраняется.

## `lib/src/interactive/scene_controller_interactive.dart`

Сделать:

1. В конструкторе та же валидация `dragStartSlop`, что и в сеттере.
2. Отдельно выбрать и закрепить **одно правило** для:
   - `setDragStartSlop(...)`
   - `pointerSettings.tapSlop`
   если сейчас одно допускает `0`, а другое требует `> 0`.
3. В `handlePointer(...)`:
   - `cancel` не отбрасывается из-за невалидной позиции;
   - `up` с невалидной позицией трактуется как `cancel`;
   - semantics одинаковы для direct entrypoint и routed path через view.
4. Явно держать active gesture owner на controller-side и не путать его с
   router/tracker gate из шага `10.1`.
5. На `down` фиксировать baseline `dragStartSlop` для текущего gesture.
6. `replaceScene(...)` отменяет активный gesture полностью.
7. `setCameraOffset(...)` отменяет активный gesture полностью.
8. Сохранить монотонность `timestampMs`.
9. Привести preview/commit к одному предикату допустимости.

## `lib/src/interactive/internal/interactive_move_session.dart`

Сделать:

1. Preview использует тот же предикат, что commit:
   - `isLocked`
   - `isTransformable`
   - `isSelectable`
2. На `cancel` откатить baseline выбора.
3. Убрать дублирующие `onStateChanged`.
4. Логику допустимости держать не в нескольких местах, а в одном.

## `lib/src/interactive/internal/interactive_draw_coordinator.dart`

Сделать:

1. Допустимость удаления и рисования привести к общей политике.
2. Проверить восстановление после безопасного `cancel`.
3. Зафиксировать, что reset/abort относится только к активному draw gesture
   owner-у.

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

- interactive move
- selection
- delete
- writer/runtime, где релевантно

## Критерии приёмки

[ ] Controller-side gesture machine является единственным owner-ом active
    gesture semantics.
[ ] Invalid `up/cancel` трактуются по одному каноническому правилу в
    `handlePointer(...)`.
[ ] View больше не содержит synthetic terminal dispatch или abort bridge в
    controller.
[ ] Параллельный не-владеющий pointer не сбрасывает активный gesture другого
    pointer-а.
[ ] `replaceScene(...)` и `setCameraOffset(...)` полностью отменяют активный
    gesture.
[ ] Preview/commit/cancel используют один eligibility policy.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_move_session.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH` по `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`.

## Тестовый контур шага

[ ] `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
    с покрытием:
    - invalid `cancel` не теряется;
    - invalid `up` трактуется как `cancel`;
    - параллельный не-владеющий pointer не сбрасывает активный gesture
[ ] `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
[ ] `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
[ ] `test/view/scene_view_interactive_test.dart`
    только как boundary-check, что view не добавляет terminal bridge в
    controller
