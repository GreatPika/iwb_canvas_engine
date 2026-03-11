language: russian

# Шаг 11.1. Зафиксировать controller pointer entry contract и canonical terminal semantics

## Цель шага

Сначала нужно принять одно решение по controller entrypoint. Пока
`SceneControllerInteractive.handlePointer(...)` сам по себе не умеет
канонически трактовать invalid terminal input и держит отдельное правило для
`dragStartSlop`, любой следующий подшаг будет строиться на плавающем
основании:

- direct controller entry и путь через view уже расходятся по terminal
  semantics;
- `dragStartSlop` в сеттере и `pointerSettings.tapSlop` живут по разным
  правилам;
- forced reset и active gesture owner нельзя формализовать, пока сам
  controller entrypoint не задаёт канонический event contract.

Задача подшага: зафиксировать единый controller boundary для
`handlePointer(...)`, где invalid terminal input нормализуется одинаково для
всех callers, `dragStartSlop` валидируется по одному правилу, а монотонность
`timestampMs` остаётся строго controller-owned.

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
   owner-ом canonical controller entry semantics для routed и direct path.
2. Единое правило для explicit `dragStartSlop` фиксируется как:
   - finite;
   - `>= 0`;
   - одинаковое в конструкторе и в `setDragStartSlop(...)`.
   Это правило намеренно выравнивается с `PointerInputSettings.tapSlop`, а не
   оставляет второй "почти такой же" numeric contract.
3. Controller boundary нормализует фазы так:
   - invalid `down` и `move` отбрасываются;
   - invalid `cancel` трактуется как terminal `cancel`;
   - invalid `up` трактуется как terminal `cancel`.
4. Нормализация invalid terminal input выполняется до dispatch в
   gesture-machine из `11.2`.
5. `timestampMs` нормализуется только через controller-owned
   `_resolveTimestampMs(...)` и остаётся строго монотонным независимо от того,
   был ли входной terminal event валиден по координатам.
6. Этот подшаг владеет только constructor-side validation wiring для
   `dragStartSlop`. Полная structural перестройка constructor-а под новый
   gesture owner не входит сюда и относится к `11.2`.
7. Подшаг не решает, какой active gesture должен принять terminal `cancel`, и
   не вводит forced reset lifecycle. Это полностью ownership `11.2`.

Почему именно так:

1. Если direct controller entry и routed path из view расходятся по terminal
   semantics, тесты и реальное поведение начинают зависеть от случайной точки
   входа, а не от одного runtime contract.
2. Разный numeric contract для `dragStartSlop` и `tapSlop` создаёт скрытую
   несовместимость в том самом месте, где нужен fallback от explicit значения к
   settings.
3. invalid `up -> cancel` безопаснее, чем тихий drop: gesture получает
   terminal meaning, но не получает фальшивого commit-разрешения.
4. Сохранять controller-owned монотонность timestamp важно, потому что именно
   controller, а не view, отвечает за deterministic action ordering и internal
   lifecycle.

## Граница шага

- In:
  - constructor/setter validation для `dragStartSlop`;
  - controller entry normalization в `handlePointer(...)`;
  - равенство semantics для direct path и routed path;
  - сохранение controller-owned монотонности `timestampMs`;
  - только тот constructor-side wiring, который нужен для unified validation.
- Out:
  - active gesture owner;
  - forced reset на `replaceScene(...)` / `setCameraOffset(...)`;
  - shared eligibility policy;
  - move/draw session cancel semantics.

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
   - optional finite position только там, где она реально нужна downstream
     dispatch-у.
4. Invalid terminal input не приводит к early `return` до controller-side
   gesture-machine.
5. Подшаг не вводит новый view-to-controller bridge API. Единственный вход
   остаётся `handlePointer(...)`.
6. Если для unified validation нужен небольшой private helper, он остаётся
   ownership этого подшага. Полная structural перестройка constructor-а под
   gesture-machine остаётся ownership `11.2`.

## Последовательность реализации (только действия)

[ ] Выровнять numeric contract `dragStartSlop` между конструктором, сеттером и
    fallback к `pointerSettings.tapSlop`.
[ ] Вынести canonical controller normalization для invalid terminal input.
[ ] Убедиться, что direct `handlePointer(...)` и routed path через view
    не получают competing terminal semantics.
[ ] Сохранить controller-owned монотонность `timestampMs` после нормализации.
[ ] Вынести только тот validation helper, который нужен для unified
    constructor/setter contract `dragStartSlop`.

## Критерии приёмки

[ ] Constructor и `setDragStartSlop(...)` используют одно и то же правило
    валидации `dragStartSlop`.
[ ] Invalid `cancel` не теряется и трактуется как terminal `cancel`.
[ ] Invalid `up` трактуется как terminal `cancel`, а не как drop или fake `up`.
[ ] Invalid `down/move` по-прежнему не создают controller-side interactive
    side effects.
[ ] Direct controller entry остаётся единственным owner-ом terminal semantics,
    а routed path через view не вводит competing terminal contract.
[ ] Монотонность `timestampMs` сохраняется.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart --report-all`
    приложена к результату шага; `handlePointer(...)`, constructor-side
    validation helper-ы и новые или step-owned methods этого подшага не
    содержат `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`, а целевой предел остаётся `10 / 4 / 40`.

## Тестовый контур шага

[ ] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    с покрытием unified validation для constructor/setter `dragStartSlop`
[ ] `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
    с покрытием:
    - invalid `cancel` не теряется
    - invalid `up` трактуется как `cancel`
    - invalid `down/move` остаются no-op
[ ] `test/view/scene_view_interactive_test.dart`
    только как boundary-check, что view не добавляет terminal bridge обратно в
    controller
