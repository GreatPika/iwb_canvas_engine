language: russian

# Шаг 11.2. Ввести одного controller-owned owner-а active gesture и единый reset trigger

## Цель шага

После `11.1` controller entrypoint уже должен принимать terminal input по
одному канону, но active gesture lifecycle всё ещё останется размазанным, если
pointer owner и baseline drag-threshold продолжат жить одновременно в:

- `SceneControllerInteractive`;
- `InteractiveMoveSession`;
- `InteractiveDrawCoordinator`.

Задача подшага: ввести одного controller-owned owner-а active gesture, который:

- фиксирует pointer-владельца;
- фиксирует baseline `dragStartSlop` на весь gesture lifetime;
- определяет, когда controller boundary обязан завершить active gesture до
  mutation или mode/tool transition.

Подшаг обязан закрываться самостоятельно. Он не может зависеть от реализации
`11.5` для корректности user-visible поведения и не имеет права вносить
регрессии в уже существующие reset/cleanup эффекты boundary methods.

## Что уже подтверждено по текущему состоянию

1. [interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart)
   сейчас сам хранит `_moveActivePointerId`.
2. [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
   сейчас сам хранит `_activePointerId`.
3. [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   сейчас лишь переключает dispatch между `_moveSession` и `_drawCoordinator`
   и передаёт им текущее значение `dragStartSlop`, а не baseline gesture state.
4. Boundary methods уже имеют observable reset/cleanup behavior:
   `replaceScene(...)`, `setCameraOffset(...)`, mode/tool transitions и
   `dispose()` по-разному чистят selection rect, pending line и другие
   mode-local состояния.
5. Эти boundary cleanup эффекты существуют независимо от того, есть ли сейчас
   active gesture owner. Поэтому нельзя приписывать весь их behavior одному
   только owner-у active gesture.
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
- через один controller-owned trigger решает, когда active gesture должен быть
  завершён до boundary mutation.

Почему это лучший вариант:

1. Он убирает competing mutable pointer-owner state из move/draw session-ов.
2. Он позволяет фиксировать baseline `dragStartSlop` один раз на `down`, а не
   тянуть текущее значение через каждый `move/up`.
3. Он не возвращает raw-pointer lifecycle из шага `10` обратно в controller:
   gesture-machine знает только controller-level `pointerId`, одинаково
   пригодный для routed и direct path, но не raw host pointer ids.
4. Он даёт чистую границу со `11.1`: `11.1` фиксирует канонический входной
   contract, а `11.2` владеет owner-ом active gesture и constructor rewiring
   вокруг него.
5. Он позволяет сохранить текущее boundary behavior без искусственной
   зависимости от `11.5`: active gesture owner меняется уже здесь, а cleanup
   latent mode-local state временно остаётся behavior-preserving на существующих
   call sites, пока соответствующий owner contract не будет введён отдельно.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. После controller boundary admission active gesture owner живёт только в
   controller-side gesture-machine.
2. Gesture-machine хранит минимум следующий controller-owned state:
   - `pointerId` владельца;
   - режим gesture family (`move` / `draw`);
   - baseline `dragStartSlop`;
   - при необходимости internal flag для deterministic release/reset path.
3. Baseline `dragStartSlop` фиксируется на `down` и не меняется до terminal
   завершения текущего gesture.
4. Параллельный не-владеющий pointer:
   - не коммитит;
   - не отменяет;
   - не сбрасывает чужой gesture.
5. Этот подшаг определяет только controller-owned reset trigger:
   - какой pointer имеет право получить `move/up/cancel`;
   - когда controller обязан завершить active gesture перед boundary mutation.
6. Этот подшаг не становится owner-ом move-local rollback,
   draw-local pending-line cleanup, timer cleanup или других latent
   mode-local состояний, которые могут жить после release active owner-а.
7. Однако подшаг обязан сохранить pre-existing observable behavior boundary
   methods. Если boundary method до начала шага уже очищал pending line,
   selection rect или другой latent state, это поведение не может пропасть
   только потому, что появился новый owner active gesture.
8. Следовательно, `11.2` допускает временный compatibility cleanup на
   существующих controller call sites, если это нужно для отсутствия
   регрессий. Такой cleanup не делает controller owner-ом draw-local semantics;
   он лишь сохраняет текущий контракт до следующего шага.
9. Полный owner contract для draw-local latent state остаётся ownership `11.5`.
   Но `11.5` не нужен для завершения `11.2`; он только убирает временный
   compatibility cleanup и замыкает его на draw-side owner.
10. Gesture-machine не становится вторым public API. Это internal-only owner,
    доступный только внутри interactive controller слоя.
11. Этот подшаг владеет structural constructor rewiring
    `SceneControllerInteractive(...)`, которое требуется для подключения нового
    gesture owner-а. `11.1` владеет только constructor-side validation для
    `dragStartSlop`.

## Граница шага

- In:
  - controller-owned active gesture identity;
  - baseline `dragStartSlop`;
  - controller-owned reset trigger перед boundary mutation;
  - dispatch contract между controller и mode-specific session-ами;
  - structural rewiring `SceneControllerInteractive(...)` под новый owner;
  - behavior-preserving compatibility cleanup на boundary call sites, если без
    него возникнет регрессия.
- Out:
  - controller pointer-entry normalization;
  - shared eligibility policy;
  - move-specific cancel restore;
  - draw-specific owner contract для pending line/timer cleanup;
  - архитектурное удаление compatibility cleanup из controller boundary methods.

## Точная реализация, которую должен описывать код

1. `SceneControllerInteractive` больше не полагается на `_moveActivePointerId`
   и `_activePointerId` в session-ах как на owner decision source.
2. Один controller-owned owner определяет:
   - можно ли принять `down` как новый gesture;
   - какой pointer имеет право получить `move/up/cancel`;
   - должен ли controller завершить active gesture перед boundary mutation.
3. Dispatch в move/draw session после подшага использует уже разрешённый owner
   context, а не переигрывает pointer ownership внутри session-а.
4. Boundary methods используют один controller-owned decision point для reset
   active gesture, но при этом не теряют pre-existing cleanup behavior для
   latent state, который ещё не получил собственного owner contract-а.
   No-op boundary mutation не имеет права молча прерывать active gesture, если
   после вызова не будет observable update.
   Rejected boundary mutation не имеет права прерывать active gesture, если
   validation/commit не дошли до observable state change.
5. `replaceScene(...)`, `setCameraOffset(...)`, `setMode(...)`,
   `setDrawTool(...)` и `dispose()` после подшага не должны демонстрировать
   user-visible регрессию относительно поведения до внедрения gesture-machine.
6. Граница между шагами `10` и `11` остаётся жёсткой:
   gesture-machine не знает о raw host pointer ids, tracker state и timer path.
   Она работает только с controller-level `pointerId`, независимо от того,
   пришёл ли он из routed view path или direct controller entry.
7. Constructor `SceneControllerInteractive(...)` создаёт и подключает новый
   internal owner lifecycle; это не считается overlap с `11.1`.

## Последовательность реализации (только действия)

[x] Создать `lib/src/interactive/internal/interactive_gesture_machine.dart`
    как internal owner active gesture lifecycle.
[x] Перевести `SceneControllerInteractive` на один owner dispatch contract.
[x] Перенести structural constructor rewiring под новый gesture owner в этот
    подшаг, не затрагивая `11.1` сверх unified validation.
[x] Зафиксировать baseline `dragStartSlop` на gesture `down`.
[x] Ввести единый controller-owned reset trigger для `replaceScene(...)`,
    `setCameraOffset(...)`, `setMode(...)`, `setDrawTool(...)` и `dispose()`.
[x] Сохранить pre-existing boundary cleanup behavior там, где latent
    mode-local state ещё не получил собственного owner contract-а.
[x] Убрать overlap между router gate из шага `10` и active gesture owner-ом
    шага `11`.

## Критерии приёмки

[x] Controller-side gesture-machine является единственным owner-ом active
    gesture identity.
[x] Baseline `dragStartSlop` фиксируется на `down` и не меняется до terminal
    завершения текущего gesture.
[x] Параллельный не-владеющий pointer не может сбросить, закоммитить или
    отменить активный gesture другого pointer-а.
[x] `replaceScene(...)`, `setCameraOffset(...)`, `setMode(...)`,
    `setDrawTool(...)` и `dispose()` используют один controller-owned decision
    point для reset active gesture.
[x] No-op boundary mutation не может silently abort-ить active gesture без
    последующего observable update.
[x] Rejected boundary mutation не может abort-ить active gesture, если
    операция завершилась exception до observable commit.
[x] После завершения шага нет user-visible регрессий в уже существовавшем
    boundary cleanup behavior, даже если часть cleanup временно остаётся на
    controller call sites как compatibility path.
[x] Gesture-machine не импортирует и не дублирует view-side router/tracker
    state шага `10`.
[x] Gesture-machine работает только с controller-level `pointerId` и не
    различает routed/direct path после boundary normalization `11.1`.
[x] Gesture-machine не становится owner-ом move-local rollback или draw-local
    pending-line cleanup semantics.
[x] Шаг закрывается самостоятельно и не требует завершения `11.5` для
    корректности behavior и acceptance.
[x] Structural constructor rewiring `SceneControllerInteractive(...)`
    принадлежит этому подшагу и не требует возвращаться в `11.1`.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_gesture_machine.dart --report-all`
    приложена к результату шага; новый owner-файл и step-owned methods не
    содержат `HIGH` по `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`, а целевой предел остаётся `10 / 4 / 40`.

## Тестовый контур шага

[x] `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
    с покрытием:
    - не-владеющий pointer не сбрасывает чужой gesture
    - новый pointer допускается только после terminal release owner-а
[x] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    с boundary-check на `setCameraOffset(...)` и `replaceScene(...)`,
    включая no-op и rejected path без silent gesture abort
[x] `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
    как regression guard, что mode/tool transitions не теряют pre-existing
    pending-line cleanup behavior
[x] `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
    как regression guard, что `replaceScene(...)` и `dispose()` не теряют
    pre-existing cleanup behavior при внедрении нового owner-а
