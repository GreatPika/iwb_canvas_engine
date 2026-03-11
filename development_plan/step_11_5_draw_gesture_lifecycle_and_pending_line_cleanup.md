language: russian

# Шаг 11.5. Перевести draw lifecycle, delete admissibility и pending-line cleanup на controller-owned contract

## Цель шага

После `11.4` move-flow уже должен жить на одном policy contract, но шаг `11`
останется незавершённым, если draw-side путь продолжит хранить свой pointer
owner и отдельные reset semantics в `InteractiveDrawCoordinator` и
`InteractiveDrawLineEngine`.

Задача подшага: перевести draw-side lifecycle на controller-owned gesture
machine из `11.2`, привязать eraser delete admissibility к policy owner-у из
`11.3` и закрыть pending-line timer/state так, чтобы forced reset больше не
оставлял утечек preview или pending line. Сюда же входит draw-local смысл
terminal `cancel` после boundary-normalization из `11.1`, включая explicit
abort и поведение idle pending-line state между двумя tap-ами line tool.

## Что уже подтверждено по текущему состоянию

1. [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
   сейчас сам хранит `_activePointerId`.
2. `cancel` path там же очищает pending line и reset-ит draw state локально,
   не будучи привязанным к одному controller-owned forced reset owner-у.
3. [interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart)
   владеет и pending line, и timer-ом, но controller boundary сейчас частично
   обходит этот owner через прямые вызовы `clearPendingLine()`.
4. [interactive_draw_eraser_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_eraser_engine.dart)
   inline-проверяет `node.isDeletable` вместо shared policy owner-а.
5. Текущая диагностика `dcm calculate-metrics` показывает явные hotspot-ы
   этого подшага:
   - `InteractiveDrawCoordinator._handleUp(...)` имеет `HIGH` по
     `source-lines-of-code = 45`;
   - `InteractiveDrawEraserEngine._eraserHitsLine(...)` имеет `HIGH` по
     `source-lines-of-code = 51`;
   - `InteractiveDrawEraserEngine._eraserHitsStroke(...)` имеет `HIGH` по
     `cyclomatic-complexity = 15`, `maximum-nesting-level = 5`,
     `source-lines-of-code = 88`.
   Эти hotspot-ы принадлежат draw-path ownership этого шага и не могут быть
   оставлены за пределами metric gate.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `InteractiveDrawCoordinator` больше не является owner-ом pointer identity.
   Он получает lifecycle callbacks только от controller-owned gesture-machine.
2. Draw-side cancel/reset semantics становятся position-agnostic и idempotent:
   forced cancel не зависит от того, пришёл ли real terminal input или
   controller boundary reset.
3. Pending line после первого tap line tool считается draw-local latent state,
   а не controller-owned active gesture owner state. Поэтому решение о том,
   должен ли `cancel`:
   - очистить pending line как explicit abort;
   - проигнорироваться как stray terminal input;
   принадлежит этому подшагу, а не `11.1` или `11.2`.
4. Pending line и его timer имеют одного owner-а:
   `InteractiveDrawLineEngine`.
   Controller и coordinator не держат параллельный cleanup path.
5. Любой forced reset:
   - `replaceScene(...)`
   - `setCameraOffset(...)`
   - `setMode(...)`
   - `setDrawTool(...)`
   - `dispose()`
   проходит через draw-side owner contract и очищает pending line/timer ровно
   один раз.
6. Eraser delete admissibility использует `canDelete(...)` из
   `interaction_eligibility_policy.dart`.
7. `_eraserHitsLine(...)` и `_eraserHitsStroke(...)` входят в прямой scope
   этого подшага и обязаны перестать быть metric hotspot-ами. Это не refactor
   render/cache шага `12`, а closure draw-path control file шага `11`.
8. `11.2` владеет trigger forced reset-а, а этот подшаг владеет только
   draw-local cleanup, который этот trigger вызывает.
9. Разрезание `_eraserHitsLine(...)` и `_eraserHitsStroke(...)` здесь
   допускается только как behavior-preserving decomposition для closure metric
   gate. Изменение erase geometry semantics не входит в scope подшага.

## Граница шага

- In:
  - draw-side adoption controller-owned lifecycle;
  - draw-local смысл normalized `cancel` для active и idle pending-line state;
  - erase/delete admissibility;
  - pending-line owner contract;
  - forced reset cleanup для line/stroke/eraser state;
  - closure metric hotspot-ов draw control files.
- Out:
  - render/cache refactor;
  - move-session semantics;
  - изменение erase geometry semantics.

## Точная реализация, которую должен описывать код

1. `InteractiveDrawCoordinator` больше не фильтрует pointer events по
   собственному `_activePointerId`.
2. Draw lifecycle dispatch использует controller-approved owner context из
   `11.2`.
3. `InteractiveDrawLineEngine` получает один owner-level reset API, который:
   - очищает active preview;
   - очищает pending line;
   - отменяет pending timer;
   - безопасен при повторном вызове.
4. Draw-side owner contract явно описывает поведение terminal `cancel` для
   idle pending-line state после release owner-а, чтобы explicit abort и stray
   normalized terminal input не зависели от неявных правил `11.1`/`11.2`.
5. `SceneControllerInteractive` и `InteractiveDrawCoordinator` больше не
   обходят line-owner ad hoc вызовами, которые дублируют его cleanup logic.
6. Eraser path определяет delete eligibility только через shared policy owner.
7. `_handleUp(...)`, `_eraserHitsLine(...)`, `_eraserHitsStroke(...)` и новые
   step-owned helper-ы после подшага укладываются в предел `10 / 4 / 40`.
8. Если для closure metric gate требуется разрезать eraser geometry methods,
   это делается без изменения erase hit semantics.

## Последовательность реализации (только действия)

[ ] Перевести draw coordinator на controller-approved lifecycle callbacks.
[ ] Явно зафиксировать draw-local semantics для idle pending-line abort и stray
    normalized terminal input.
[ ] Замкнуть forced reset на один line-owner cleanup contract.
[ ] Убрать ad hoc `clearPendingLine()` обходы вне owner contract.
[ ] Перевести eraser delete admissibility на `canDelete(...)`.
[ ] Зафиксировать, что forced reset не оставляет pending line и preview leaks.
[ ] Разрезать `_handleUp(...)`, `_eraserHitsLine(...)` и
    `_eraserHitsStroke(...)`, если это требуется для закрытия metric gate.
[ ] Не менять erase geometry semantics сверх behavior-preserving decomposition.

## Критерии приёмки

[ ] Draw-side lifecycle больше не владеет pointer identity отдельно от
    controller gesture-machine.
[ ] `cancel` и forced reset используют один owner contract.
[ ] Explicit abort pending-line state и stray normalized terminal input
    используют явно описанный draw-local contract вместо скрытой логики в
    `11.1`/`11.2`.
[ ] Pending line, pending timer и active line preview очищаются на
    `replaceScene(...)`, `setCameraOffset(...)`, mode/tool change и dispose.
[ ] Eraser delete admissibility использует shared policy owner.
[ ] Параллельный не-владеющий pointer не может сбросить чужой draw gesture.
[ ] Trigger forced reset-а остаётся ownership `11.2`, а этот подшаг владеет
    только draw-local cleanup по этому trigger.
[ ] `InteractiveDrawCoordinator._handleUp(...)`,
    `InteractiveDrawEraserEngine._eraserHitsLine(...)` и
    `InteractiveDrawEraserEngine._eraserHitsStroke(...)` перестают быть
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[ ] `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
    с покрытием:
    - pending line не переживает forced reset
    - cancel и replaceScene используют один cleanup contract
    - explicit abort pending line и stray normalized terminal input закрыты
      явным draw-local contract
[ ] `test/interactive/core/interactive_draw_eraser_engine_test.dart`
    с покрытием:
    - erase admission использует `canDelete(...)`
    - `_eraserHitsLine(...)` и `_eraserHitsStroke(...)` после разреза сохраняют
      hit correctness
[ ] `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
    как boundary-check line lifecycle
[ ] `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`
    с покрытием delete admissibility и forced reset
[ ] `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
    с draw-side case для не-владеющего pointer-а
