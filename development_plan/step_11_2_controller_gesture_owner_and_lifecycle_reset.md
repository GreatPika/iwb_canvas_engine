language: russian

# Шаг 11.2. Ввести одного controller-owned owner-а active gesture и forced reset lifecycle

## Цель шага

После `11.1` controller entrypoint уже должен принимать terminal input по
одному канону, но gesture lifecycle всё ещё останется размазанным, если active
pointer и его reset semantics продолжат жить одновременно в:

- `SceneControllerInteractive`;
- `InteractiveMoveSession`;
- `InteractiveDrawCoordinator`.

Задача подшага: ввести одного controller-owned owner-а active gesture, который
фиксирует pointer-владельца и baseline `dragStartSlop` на весь gesture
lifetime, а также делает forced reset на `replaceScene(...)`,
`setCameraOffset(...)`, mode/tool transitions и других controller-owned
boundary changes.

## Что уже подтверждено по текущему состоянию

1. [interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart)
   сейчас сам хранит `_moveActivePointerId`.
2. [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
   сейчас сам хранит `_activePointerId`.
3. [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   сейчас лишь переключает dispatch между `_moveSession` и `_drawCoordinator`
   и передаёт им текущее значение `dragStartSlop`, а не baseline gesture state.
4. `replaceScene(...)` в
   [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   очищает только pending line и selection rect, но не делает единый forced
   cancel active gesture.
5. `setCameraOffset(...)` там же сейчас меняет камеру без общей gesture
   cancellation semantics.
6. Constructor `SceneControllerInteractive(...)` уже перегружен wiring-логикой,
   и именно этот подшаг неизбежно меняет его structural shape, если появляется
   новый internal owner gesture lifecycle.

## Рекомендуемое решение

Рекомендуемый вариант: выделить controller-local internal owner gesture
lifecycle в
`lib/src/interactive/internal/interactive_gesture_machine.dart`, а
`SceneControllerInteractive` оставить orchestrator-ом, который:

- получает canonical input из `11.1`;
- спрашивает gesture-machine, кому разрешён dispatch;
- вызывает mode-specific session entrypoints;
- инициирует forced cancel/reset на controller boundary changes.

Почему это лучший вариант:

1. Он убирает competing mutable pointer-owner state из move/draw session-ов.
2. Он позволяет фиксировать baseline `dragStartSlop` один раз на `down`, а не
   тянуть текущее значение через каждый `move/up`.
3. Он не возвращает raw-pointer lifecycle из шага `10` обратно в controller:
   gesture-machine знает только controller-level `pointerId`, одинаково
   пригодный для routed и direct path, но не raw host pointer ids.
4. Он даёт чистую границу со `11.1`: `11.1` фиксирует канонический входной
   contract, а `11.2` владеет новым owner-ом lifecycle и constructor rewiring
   вокруг него.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. После controller boundary admission active gesture owner живёт только в
   controller-side gesture-machine.
2. Gesture-machine хранит минимум следующий controller-owned state:
   - `pointerId` владельца;
   - режим gesture family (`move` / `draw`);
   - baseline `dragStartSlop`;
   - признак активного forced-cancel transition, если он нужен для
     детерминированного dispatch-а.
3. Baseline `dragStartSlop` фиксируется на `down` и не меняется до terminal
   завершения текущего gesture.
4. Параллельный не-владеющий pointer:
   - не коммитит;
   - не отменяет;
   - не сбрасывает чужой gesture.
5. Forced reset lifecycle принадлежит controller boundary:
   - `replaceScene(...)`
   - `setCameraOffset(...)`
   - `setMode(...)`
   - `setDrawTool(...)`
   - `dispose()`
   используют один controller-owned путь отмены активного gesture.
6. Gesture-machine не становится вторым public API. Это internal-only owner,
   доступный только внутри interactive controller слоя.
7. Подшаг не определяет, как именно move/draw session восстанавливает свой
   внутренний state после cancel. Это ownership `11.4` и `11.5`.
8. Подшаг определяет только owner-level delivery/reset contract:
   - какой pointer имеет право получить `move/up/cancel`;
   - когда controller запускает forced cancel/reset.
   Move-local rollback и draw-local cleanup, включая pending-line semantics
   после release owner-а, сюда не входят. Подшаг также не имеет права
   переписывать terminal phase, которую передал boundary contract `11.1`.
9. Этот подшаг владеет structural constructor rewiring
   `SceneControllerInteractive(...)`, которое требуется для подключения нового
   gesture owner-а. `11.1` владеет только constructor-side validation для
   `dragStartSlop`.

## Граница шага

- In:
  - controller-owned active gesture identity;
  - baseline `dragStartSlop`;
  - forced reset/cancel lifecycle;
  - dispatch contract между controller и mode-specific session-ами;
  - structural rewiring `SceneControllerInteractive(...)` под новый owner.
- Out:
  - controller pointer-entry normalization;
  - shared eligibility policy;
  - move-specific cancel restore;
  - draw-specific pending-line cleanup details;
  - idle draw-local pending state semantics после завершения active owner-а.

## Точная реализация, которую должен описывать код

1. `SceneControllerInteractive` больше не полагается на `_moveActivePointerId`
   и `_activePointerId` в session-ах как на owner decision source.
2. Один controller-owned owner определяет:
   - можно ли принять `down` как новый gesture;
   - какой pointer имеет право получить `move/up/cancel`;
   - должен ли controller выполнить forced cancel перед boundary mutation.
   Но он не кодирует сам move-local rollback или draw-local cleanup effect.
3. Dispatch в move/draw session после подшага использует уже разрешённый owner
   context, а не переигрывает pointer ownership внутри session-а.
4. `replaceScene(...)` и `setCameraOffset(...)` отменяют активный gesture через
   тот же lifecycle owner, а не через отдельные локальные workaround-вызовы.
5. Граница между шагами `10` и `11` остаётся жёсткой:
   gesture-machine не знает о raw host pointer ids, tracker state и timer path.
   Она работает только с controller-level `pointerId`, независимо от того,
   пришёл ли он из routed view path или direct controller entry.
6. Constructor `SceneControllerInteractive(...)` создаёт и подключает новый
   internal owner lifecycle; это не считается overlap с `11.1`.

## Последовательность реализации (только действия)

[ ] Создать `lib/src/interactive/internal/interactive_gesture_machine.dart`
    как internal owner active gesture lifecycle.
[ ] Перевести `SceneControllerInteractive` на один owner dispatch/reset
    contract.
[ ] Перенести structural constructor rewiring под новый gesture owner в этот
    подшаг, не затрагивая `11.1` сверх unified validation.
[ ] Зафиксировать baseline `dragStartSlop` на gesture `down`.
[ ] Перевести `replaceScene(...)`, `setCameraOffset(...)`, `setMode(...)`,
    `setDrawTool(...)` и `dispose()` на единый forced cancel path.
[ ] Убрать overlap между router gate из шага `10` и active gesture owner-ом
    шага `11`.

## Критерии приёмки

[ ] Controller-side gesture-machine является единственным owner-ом active
    gesture identity.
[ ] Baseline `dragStartSlop` фиксируется на `down` и не меняется до terminal
    завершения текущего gesture.
[ ] Параллельный не-владеющий pointer не может сбросить, закоммитить или
    отменить активный gesture другого pointer-а.
[ ] `replaceScene(...)` и `setCameraOffset(...)` полностью отменяют активный
    gesture через общий controller-owned path.
[ ] `setMode(...)`, `setDrawTool(...)` и `dispose()` используют тот же forced
    reset owner, а не отдельные ad hoc ветки.
[ ] Gesture-machine не импортирует и не дублирует view-side router/tracker
    state шага `10`.
[ ] Gesture-machine работает только с controller-level `pointerId` и не
    различает routed/direct path после boundary normalization `11.1`.
[ ] Gesture-machine не становится owner-ом move-local rollback или draw-local
    pending-line cleanup semantics.
[ ] Structural constructor rewiring `SceneControllerInteractive(...)`
    принадлежит этому подшагу и не требует возвращаться в `11.1`.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_gesture_machine.dart --report-all`
    приложена к результату шага; новый owner-файл и step-owned methods не
    содержат `HIGH` по `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`, а целевой предел остаётся `10 / 4 / 40`.

## Тестовый контур шага

[ ] `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
    с покрытием:
    - не-владеющий pointer не сбрасывает чужой gesture
    - новый pointer допускается только после terminal release owner-а
[ ] `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
    с покрытием forced reset на `replaceScene(...)` и `dispose()`
[ ] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    с boundary-check на `setCameraOffset(...)`
