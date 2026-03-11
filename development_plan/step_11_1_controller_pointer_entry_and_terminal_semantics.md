language: russian

# Шаг 11.1. Зафиксировать controller pointer entry contract и terminal transport normalization

## Цель шага

Сначала нужно принять одно решение по controller entrypoint. Пока
`SceneControllerInteractive.handlePointer(...)` сам по себе не умеет
канонически трактовать invalid terminal input и держит отдельное правило для
`dragStartSlop`, любой следующий подшаг будет строиться на плавающем
основании:

- direct controller entry и путь через view уже расходятся по terminal input
  normalization;
- `dragStartSlop` в сеттере и `pointerSettings.tapSlop` живут по разным
  правилам;
- forced reset и active gesture owner нельзя формализовать, пока сам
  controller entrypoint не задаёт канонический event contract.

Задача подшага: зафиксировать единый controller boundary для
`handlePointer(...)`, где invalid terminal input получает один
controller-owned transport contract для всех callers, `dragStartSlop`
валидируется по одному правилу, а монотонность `timestampMs` остаётся строго
controller-owned.

## Что уже подтверждено по текущему состоянию

1. [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   сейчас валидирует `pointerSettings` в конструкторе, но не валидирует
   `dragStartSlop` там же.
2. `setDragStartSlop(...)` в
   [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   требует strictly-positive значение, тогда как
   `PointerInputSettings.tapSlop` уже допускает `0`.
3. `handlePointer(...)` там же сейчас ранним `return` отбрасывает любые
   невалидные координаты, включая invalid `up/cancel`.
4. [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   после шага `10.2` делает только host cleanup для invalid terminal host
   event-ов и не dispatch-ит synthetic terminal input в controller.
5. `_resolveTimestampMs(...)` в
   [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   уже является owner-ом монотонности `timestampMs`; этот ownership нельзя
   размыть при нормализации invalid terminal input.
6. Текущая диагностика `dcm calculate-metrics` показывает ещё один hotspot
   вокруг `SceneControllerInteractive(...)`: constructor уже имеет `HIGH` по
   `source-lines-of-code = 55`, но structural constructor rewiring под новый
   gesture owner относится к `11.2`. В этом подшаге допустимы только те
   constructor-side правки, которые нужны для unified validation
   `dragStartSlop` и controller entry normalization.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneControllerInteractive.handlePointer(...)` становится единственным
   owner-ом canonical controller entry normalization для routed path через view
   и direct controller entry.
2. Единое правило для explicit `dragStartSlop` фиксируется как:
   - finite;
   - `>= 0`;
   - одинаковое в конструкторе и в `setDragStartSlop(...)`.
   Это правило намеренно выравнивается с `PointerInputSettings.tapSlop`, а не
   оставляет второй "почти такой же" numeric contract.
3. Controller boundary нормализует terminal transport так:
   - invalid `down` и `move` отбрасываются;
   - invalid terminal `up/cancel` не теряются только при cache hit по
     finite-позиции того же `pointerId`;
   - terminal phase (`up` vs `cancel`) сохраняется;
   - если cached finite-позиции нет, invalid terminal sample остаётся no-op.
4. Нормализация invalid terminal input выполняется до dispatch в
   controller-owned lifecycle из `11.2`.
5. `timestampMs` нормализуется только через controller-owned
   `_resolveTimestampMs(...)` и остаётся строго монотонным независимо от того,
   был ли входной terminal event валиден по координатам.
6. Этот подшаг владеет только constructor-side validation wiring для
   `dragStartSlop`. Полная structural перестройка constructor-а под новый
   gesture owner не входит сюда и относится к `11.2`.
7. Подшаг не решает:
   - какой active gesture должен принять terminal `cancel`;
   - должен ли `cancel` влиять на idle draw-local state после release owner-а;
   - какой move/draw-local cleanup должен произойти после normalized
     `cancel`.
   Это ownership `11.2`, `11.4` и `11.5`.

Почему именно так:

1. Если direct controller entry и routed path из view расходятся по boundary
   normalization terminal input, тесты и реальное поведение начинают зависеть
   от случайной точки входа, а не от одного runtime contract.
2. Разный numeric contract для `dragStartSlop` и `tapSlop` создаёт скрытую
   несовместимость в том самом месте, где нужен fallback от explicit значения к
   settings.
3. Boundary transport normalization не должна переписывать semantic meaning
   terminal event, потому что downstream move/draw lifecycle уже различает
   `up` и `cancel`.
4. Сохранять controller-owned монотонность timestamp важно, потому что именно
   controller, а не view, отвечает за deterministic action ordering и internal
   lifecycle.

## Граница шага

- In:
  - constructor/setter validation для `dragStartSlop`;
  - controller entry transport normalization в `handlePointer(...)`;
  - равенство entry normalization для direct path и routed path;
  - сохранение controller-owned монотонности `timestampMs`;
  - только тот constructor-side wiring, который нужен для unified validation.
- Out:
  - active gesture owner;
  - forced reset на `replaceScene(...)` / `setCameraOffset(...)`;
  - shared eligibility policy;
  - move/draw session cancel semantics;
  - draw-local pending-line abort и cleanup semantics после release owner-а.

## Точная реализация, которую должен описывать код

1. Конструктор `SceneControllerInteractive(...)` валидирует `dragStartSlop`
   тем же helper-ом, что и `setDragStartSlop(...)`.
2. `dragStartSlop == null` по-прежнему означает fallback к
   `pointerSettings.tapSlop`, но explicit non-null value использует тот же
   `>= 0` contract.
3. `handlePointer(...)` сначала переводит вход в canonical controller event:
   - phase;
   - pointerId;
   - normalized `timestampMs`;
   - resolved position, где invalid terminal input может переиспользовать
     последнюю finite-позицию того же `pointerId` только при cache hit.
4. Invalid terminal input не приводит к early `return` до controller-side
   owner dispatch decision, но boundary не меняет semantic type terminal
   event.
5. Подшаг фиксирует только transport contract terminal event на boundary и не
   вводит новый draw-local или move-local cleanup/commit contract для
   idle/active state.
6. Подшаг не вводит новый view-to-controller bridge API. Единственный вход
   остаётся `handlePointer(...)`.
7. Если для unified validation нужен небольшой private helper, он остаётся
   ownership этого подшага. Полная structural перестройка constructor-а под
   gesture-machine остаётся ownership `11.2`.

## Последовательность реализации (только действия)

[x] Выровнять numeric contract `dragStartSlop` между конструктором, сеттером и
    fallback к `pointerSettings.tapSlop`.
[x] Вынести controller-owned transport normalization для invalid terminal
    input.
[x] Убедиться, что direct `handlePointer(...)` и routed path через view
    не получают competing terminal input normalization.
[x] Сохранить controller-owned монотонность `timestampMs` после нормализации.
[x] Вынести только тот validation helper, который нужен для unified
    constructor/setter contract `dragStartSlop`.
[x] Не принимать в этом подшаге решения за move/draw-local cancel cleanup,
    которые принадлежат `11.4` и `11.5`.

## Критерии приёмки

[x] Constructor и `setDragStartSlop(...)` используют одно и то же правило
    валидации `dragStartSlop`.
[x] Invalid `cancel` не теряется и сохраняет terminal phase `cancel`.
[x] Invalid `up` не теряется и сохраняет terminal phase `up`.
[x] Invalid terminal input переиспользует последнюю finite-позицию того же
    `pointerId` только при cache hit.
[x] Invalid terminal input без cached finite-позиции остаётся no-op.
[x] Invalid `down/move` по-прежнему не создают controller-side interactive
    side effects.
[x] Direct controller entry остаётся единственным owner-ом terminal input
    normalization, а routed path через view не вводит competing boundary
    contract.
[x] Монотонность `timestampMs` сохраняется.
[x] Подшаг не вводит новый owner contract для move-local или draw-local
    cleanup/commit после invalid terminal input; это остаётся ownership
    `11.2`, `11.4` и `11.5`.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart --report-all`
    приложена к результату шага; `handlePointer(...)`, constructor-side
    validation helper-ы и новые или step-owned methods этого подшага не
    содержат `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`, а целевой предел остаётся `10 / 4 / 40`.

## Тестовый контур шага

[x] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    с покрытием unified validation для constructor/setter `dragStartSlop`
[x] `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
    с покрытием:
    - invalid `cancel` не теряется на boundary
    - invalid `up` сохраняет phase `up`
    - invalid terminal input переиспользует последнюю finite-позицию pointer-а
      только при cache hit
    - invalid terminal input без cached finite-позиции остаётся no-op
    - invalid `down/move` остаются no-op
[x] `test/view/scene_view_interactive_test.dart`
    только как boundary-check, что view не добавляет terminal bridge обратно в
    controller
[x] Cleanup/commit semantics для move/draw-local state после invalid terminal
    остаются вне тестового контура этого подшага и проверяются в `11.4`/`11.5`

## Диагностика шага

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart --report-all`
  после шага не содержит `HIGH` по step-owned constructor/helper surface.
- Зафиксированные значения для методов, которые этот подшаг добавил или
  переподчинил своему ownership:
  - `SceneControllerInteractive.SceneControllerInteractive`: `cyclomatic-complexity = 2`, `maximum-nesting-level = 0`, `source-lines-of-code = 4`
  - `SceneControllerInteractive._createMoveSession`: `1 / 0 / 12`
  - `SceneControllerInteractive._createDrawCoordinator`: `1 / 0 / 11`
  - `SceneControllerInteractive._commitMoveSelection`: `4 / 2 / 27`
  - `SceneControllerInteractive.handlePointer`: `4 / 2 / 23`
  - `SceneControllerInteractive._normalizePointerInput`: `7 / 1 / 22`
