language: russian

# Шаг 11.5. Замкнуть draw-side reset contract, pending-line owner и delete admissibility

## Цель шага

После `11.4` move-flow уже должен жить на одном policy contract, а `11.2`
уже должен быть завершён без регрессий и без зависимости от draw-side closure.
Но шаг `11` всё ещё останется архитектурно незавершённым, если draw-path
продолжит:

- полагаться на compatibility cleanup в controller boundary methods;
- держать cleanup pending line и timer-а в нескольких местах;
- смешивать draw lifecycle и delete admissibility.

Задача подшага: перевести draw-side lifecycle на controller-owned gesture
machine из `11.2`, привязать eraser delete admissibility к policy owner-у из
`11.3` и замкнуть draw-local reset contract так, чтобы:

- pending line;
- pending timer;
- active preview;
- explicit abort semantics;

имели одного owner-а и больше не требовали compatibility cleanup на controller
boundary call sites.

Этот подшаг не должен “дочинять” поведение, сломанное в `11.2`. Напротив,
`11.2` уже обязан сохранить старое observable behavior, а `11.5` лишь
переводит этот behavior на правильного draw-side owner-а и удаляет временные
совместимые обходы.

## Что уже подтверждено по текущему состоянию

1. [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
   сейчас сам хранит `_activePointerId`.
2. `cancel` path там же очищает pending line и reset-ит draw state локально,
   не будучи привязанным к одному draw-side owner contract-у.
3. [interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart)
   владеет и pending line, и timer-ом, но controller boundary сейчас частично
   обходит этот owner через прямые вызовы `clearPendingLine()`.
4. [interactive_draw_eraser_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_eraser_engine.dart)
   inline-проверяет `node.isDeletable` вместо shared policy owner-а.
5. Draw-path содержит latent state, который может жить после release active
   gesture owner-а. Поэтому его reset contract нельзя сводить к одному только
   active gesture machine из `11.2`.
6. Текущая диагностика `dcm calculate-metrics` показывает явные hotspot-ы
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
2. Pending line после первого tap line tool считается draw-local latent state,
   а не controller-owned active gesture owner state.
3. Draw-side cancel/reset semantics становятся position-agnostic и idempotent:
   forced cancel не зависит от того, пришёл ли real terminal input или
   controller boundary reset.
4. Pending line и его timer имеют одного owner-а:
   `InteractiveDrawLineEngine`.
   Controller и coordinator после этого шага не держат параллельный cleanup
   path и не вызывают ad hoc `clearPendingLine()` для сохранения behavior.
5. Любой forced reset:
   - `replaceScene(...)`
   - `setCameraOffset(...)`
   - `setMode(...)`
   - `setDrawTool(...)`
   - `dispose()`
   приходит из trigger-а `11.2`, но дальше проходит через draw-side owner
   contract и очищает pending line/timer/preview ровно один раз.
6. Explicit abort idle pending-line state и stray normalized terminal input
   получают явный draw-local contract именно здесь, а не в `11.1` и не в
   `11.2`.
7. Eraser delete admissibility использует `canDelete(...)` из
   `interaction_eligibility_policy.dart`.
8. `_eraserHitsLine(...)` и `_eraserHitsStroke(...)` входят в прямой scope
   этого подшага и обязаны перестать быть metric hotspot-ами. Это не refactor
   render/cache шага `12`, а closure draw-path control file шага `11`.
9. `11.2` владеет trigger forced reset-а, а этот подшаг владеет draw-local
   cleanup owner-ом, который этот trigger вызывает.
10. Разрезание `_eraserHitsLine(...)` и `_eraserHitsStroke(...)` здесь
    допускается только как behavior-preserving decomposition для closure metric
    gate. Изменение erase geometry semantics не входит в scope подшага.

## Граница шага

- In:
  - draw-side adoption controller-owned lifecycle;
  - draw-local смысл normalized `cancel` для active и idle pending-line state;
  - erase/delete admissibility;
  - pending-line owner contract;
  - замыкание forced reset cleanup для line/stroke/eraser state на одного
    draw-side owner-а;
  - удаление compatibility cleanup из controller boundary methods;
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
5. `SceneControllerInteractive` и `InteractiveDrawCoordinator` после подшага
   больше не обходят line-owner ad hoc вызовами, которые дублируют его cleanup
   logic. Временный compatibility cleanup, допустимый в `11.2`, здесь удаляется.
6. Eraser path определяет delete eligibility только через shared policy owner.
7. `_handleUp(...)`, `_eraserHitsLine(...)`, `_eraserHitsStroke(...)` и новые
   step-owned helper-ы после подшага укладываются в предел `10 / 4 / 40`.
8. Если для closure metric gate требуется разрезать eraser geometry methods,
   это делается без изменения erase hit semantics.

## Последовательность реализации (только действия)

[ ] Перевести draw coordinator на controller-approved lifecycle callbacks.
[ ] Явно зафиксировать draw-local semantics для idle pending-line abort и stray
    normalized terminal input.
[ ] Замкнуть forced reset на один draw-side owner cleanup contract.
[ ] Удалить compatibility cleanup и ad hoc `clearPendingLine()` обходы вне
    owner contract.
[ ] Перевести eraser delete admissibility на `canDelete(...)`.
[ ] Зафиксировать, что forced reset не оставляет pending line и preview leaks.
[ ] Разрезать `_handleUp(...)`, `_eraserHitsLine(...)` и
    `_eraserHitsStroke(...)`, если это требуется для закрытия metric gate.
[ ] Не менять erase geometry semantics сверх behavior-preserving decomposition.

## Критерии приёмки

[ ] Draw-side lifecycle больше не владеет pointer identity отдельно от
    controller gesture-machine.
[ ] `cancel` и forced reset используют один draw-side owner contract.
[ ] Explicit abort pending-line state и stray normalized terminal input
    используют явно описанный draw-local contract вместо скрытой логики в
    `11.1`/`11.2`.
[ ] Pending line, pending timer и active line preview очищаются на
    `replaceScene(...)`, `setCameraOffset(...)`, mode/tool change и `dispose()`
    через один owner contract без controller-side compatibility cleanup.
[ ] Eraser delete admissibility использует shared policy owner.
[ ] Параллельный не-владеющий pointer не может сбросить чужой draw gesture.
[ ] Trigger forced reset-а остаётся ownership `11.2`, а этот подшаг владеет
    только draw-local cleanup owner-ом по этому trigger.
[ ] `InteractiveDrawCoordinator._handleUp(...)`,
    `InteractiveDrawEraserEngine._eraserHitsLine(...)` и
    `InteractiveDrawEraserEngine._eraserHitsStroke(...)` перестают быть
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`.
[ ] После завершения шага controller boundary methods больше не содержат
    временный compatibility cleanup, который был допустим в `11.2`.
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
    - explicit abort idle pending-line state имеет явный draw-local contract
    - stray normalized terminal input не ломает draw-local contract
[ ] `test/interactive/core/interactive_draw_eraser_engine_test.dart`
    с покрытием:
    - erase admission использует `canDelete(...)`
    - `_eraserHitsLine(...)` и `_eraserHitsStroke(...)` после разреза сохраняют
      hit correctness
[ ] `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
    как boundary-check line lifecycle после удаления compatibility cleanup
[ ] `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`
    с покрытием delete admissibility и forced reset
[ ] `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
    с draw-side case для не-владеющего pointer-а
