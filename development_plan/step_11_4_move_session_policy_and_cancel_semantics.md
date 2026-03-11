language: russian

# Шаг 11.4. Перевести move session на shared eligibility policy и canonical cancel semantics

## Цель шага

После `11.3` admissibility policy уже должна иметь одного owner-а, но move-flow
всё ещё останется расщеплённым, если `InteractiveMoveSession` продолжит:

- сам решать pointer ownership;
- стартовать preview по одному правилу, а commit делать по другому;
- менять selection на `down`, но не восстанавливать baseline на `cancel`.

Задача подшага: перевести move session на controller-owned gesture lifecycle из
`11.2` и на shared admissibility policy из `11.3`, чтобы selection hit-test,
move preview, move commit и cancel semantics использовали один согласованный
contract.

## Что уже подтверждено по текущему состоянию

1. [interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart)
   сейчас сам хранит `_moveActivePointerId`.
2. Там же `_moveHandleDown(...)` стартует move preview для любого hit node,
   который прошёл `isVisible && isSelectable`, даже если `commitMoveSelection`
   потом отфильтрует этот node как `!isTransformable` или `isLocked`.
3. `cancel` path в том же файле сбрасывает preview/state, но не восстанавливает
   baseline selection, уже изменённый на `down`.
4. `_nodesIntersecting(...)` и `_hitTestTopNode(...)` содержат свои inline
   admissibility checks вместо одного owner policy.
5. `resetGestureState()`, `setSelectionRect(null)` и `callbacks.onStateChanged()`
   сейчас легко образуют duplicate notify-path.
6. Текущая диагностика `dcm calculate-metrics` показывает, что
   `_moveHandleMove(...)` уже имеет `HIGH` по
   `cyclomatic-complexity = 12`, а `_moveHandleUp(...)` имеет `HIGH` по
   `cyclomatic-complexity = 11`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `InteractiveMoveSession` больше не является owner-ом pointer identity. Она
   получает только controller-approved lifecycle callbacks из `11.2`.
2. Move preview и move commit используют одну и ту же admissibility model:
   node участвует в preview только если проходит `canPreviewMove(...)`, и тот
   же predicate определяет eligibility для commit.
3. `down` на selectable, но не previewable node:
   - может изменить selection по `canSelect(...)`;
   - не имеет права запускать move preview.
4. Marquee selection использует `canSelect(...)` как owner policy для включения
   node в итоговый selection set.
5. `cancel` восстанавливает baseline selection, если текущий gesture изменил
   selection до terminal завершения.
6. Move session обязана emit-ить `onStateChanged` один раз на semantic
   transition и не оставлять duplicate notify/reset ветки.

## Граница шага

- In:
  - move-session adoption controller-owned lifecycle;
  - policy usage для hit-test, preview, commit и marquee;
  - cancel restore baseline selection;
  - notify/reset cleanup внутри move session.
- Out:
  - controller-owned active gesture machine;
  - draw-side lifecycle и pending line;
  - policy owner outside move session.

## Точная реализация, которую должен описывать код

1. `InteractiveMoveSession` больше не фильтрует события по собственному
   `_moveActivePointerId`.
2. Preview node set строится из policy owner-а, а не из ad hoc selection logic.
3. `_hitTestTopNode(...)` и `_nodesIntersecting(...)` используют shared policy
   вместо inline `isVisible/isSelectable/...` веток.
4. `cancel` path:
   - очищает preview;
   - убирает selection rect;
   - восстанавливает baseline selection, если gesture его менял;
   - не делает duplicate `onStateChanged`.
5. Move commit продолжает эмитить action только при реальном применённом delta,
   но admissibility для preview и commit теперь совпадает.

## Последовательность реализации (только действия)

[ ] Перевести move session на controller-approved lifecycle callbacks.
[ ] Применить shared policy к hit-test, preview, commit и marquee selection.
[ ] Восстановить baseline selection на cancel.
[ ] Убрать duplicate notify/reset ветки.
[ ] Зафиксировать, что preview и commit используют один predicate owner.

## Критерии приёмки

[ ] Move session не владеет pointer identity и не конфликтует с controller
    gesture-machine.
[ ] Preview и commit используют одну и ту же admissibility model.
[ ] Selectable, но non-previewable node не запускает move preview.
[ ] Marquee selection использует `canSelect(...)`.
[ ] `cancel` восстанавливает baseline selection и очищает preview/selectionRect.
[ ] Step-owned move methods не содержат duplicate `onStateChanged` веток.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/internal/interactive_move_session.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[ ] `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
    с покрытием:
    - preview использует ту же admissibility model, что и commit
    - cancel восстанавливает baseline selection
    - hit-test использует preview-shifted geometry без второго owner-а policy
[ ] `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
    с покрытием move commit/action semantics после policy unification
