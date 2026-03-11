language: russian

# Шаг 11. Вынести gesture-machine и единый предикат допустимости через подшаги 11.1-11.5

## Диагностические метрики

Этот блок остаётся диагностическим радаром шага, но для `11.x` он также
обязан быть отражён в критериях приёмки каждого подшага: новые owner-ы и
step-owned методы не должны пробивать пороги из
[analysis_options.yaml](/Users/blackpika/iwb_canvas_engine/analysis_options.yaml).

- Смотреть в первую очередь `cyclomatic-complexity`,
  `maximum-nesting-level` и `source-lines-of-code`.
- Пороговые значения для новых owner-ов и step-owned методов:
  - `cyclomatic-complexity <= 10`
  - `maximum-nesting-level <= 4`
  - `source-lines-of-code <= 40`
- Контрольные файлы:
  - `lib/src/interactive/scene_controller_interactive.dart`
  - `lib/src/interactive/interaction_eligibility_policy.dart`
  - `lib/src/interactive/internal/interactive_gesture_machine.dart`
  - `lib/src/interactive/internal/interactive_move_session.dart`
  - `lib/src/interactive/internal/interactive_draw_coordinator.dart`
  - `lib/src/interactive/internal/interactive_draw_line_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- Acceptance gate ставится и на новые owner-ы, и на целевые файлы этого шага.
  Если в контрольном файле уже есть hotspot, он обязан быть явно закреплён за
  одним из подшагов `11.x`, чтобы к концу шага `11` в перечисленных файлах не
  оставалось `HIGH`/`VERY HIGH` по этим трём метрикам.
- Полезный сигнал после шага: invalid terminal semantics, active gesture owner,
  preview/commit/cancel admissibility и forced reset живут в одном controller
  contract, а не размазаны между view, controller и внутренними session-ами.

## Цель шага

После шагов `10.1-10.3` view/runtime boundary уже должна владеть только:

- raw-to-slot routing;
- host admission;
- host-owned terminal cleanup для router/tracker/timer;
- timer/listener lifecycle;
- apply-on-idle settings contract.

Следующий системный drift теперь в controller-side интерактивности:

- routed path через view и direct controller entry
  расходятся по семантике invalid terminal input;
- active gesture owner размазан между controller, move session и draw
  coordinator;
- `dragStartSlop` и forced reset lifecycle не описаны как один controller-owned
  contract;
- preview, commit, selection hit-test и delete используют несколько похожих,
  но не одинаковых admissibility правил.

Исходный шаг `11` перечислял правильные задачи, но без декомпозиции они
смешивали как минимум пять разных ownership-областей. Без их разведения
реализация почти неизбежно либо возвращает view-side bridge из шага `10`,
либо делает `interaction_eligibility_policy.dart` новым «бог-объектом».

## Как разбит этап

### Шаг 11.1

`development_plan/step_11_1_controller_pointer_entry_and_terminal_semantics.md`

Владелец решения по:

- contract `SceneControllerInteractive.handlePointer(...)`;
- transport-normalization invalid terminal input на controller boundary;
- единому правилу валидации `dragStartSlop`;
- сохранению controller-owned монотонности `timestampMs`.

### Шаг 11.2

`development_plan/step_11_2_controller_gesture_owner_and_lifecycle_reset.md`

Владелец решения по:

- одному controller-owned owner-у active gesture;
- baseline `dragStartSlop` на gesture lifetime;
- forced reset/cancel lifecycle для `replaceScene(...)`,
  `setCameraOffset(...)`, mode/tool transition и dispose;
- явной границе между router gate из шага `10` и active gesture owner-ом
  шага `11`.

### Шаг 11.3

`development_plan/step_11_3_interaction_eligibility_policy_owner.md`

Владелец решения по:

- `lib/src/interactive/interaction_eligibility_policy.dart` как одному owner-у
  interactive composite admissibility;
- устранению overlap между `interactive_selection_utils.dart`,
  controller-side preflight checks и ad hoc move/delete composition поверх
  низкоуровневых scene predicates;
- adoption этой policy в controller/runtime путях вне move/draw session-ов.

### Шаг 11.4

`development_plan/step_11_4_move_session_policy_and_cancel_semantics.md`

Владелец решения по:

- переносу move-flow на controller-owned gesture lifecycle;
- одному admissibility contract для move preview и move commit;
- move-local cancel semantics и восстановлению baseline selection;
- зачистке duplicate notify/reset веток внутри move session.

### Шаг 11.5

`development_plan/step_11_5_draw_gesture_lifecycle_and_pending_line_cleanup.md`

Владелец решения по:

- draw-side adoption controller-owned gesture lifecycle;
- safe cancel/reset semantics для line/stroke/eraser flow;
- owner-у pending-line timer/state;
- delete admissibility в eraser path и closure metric hotspot-ов draw-path.

## Карта переноса деталей из исходного шага 11

1. Валидация `dragStartSlop` в конструкторе, единое правило для
   `setDragStartSlop(...)` и `pointerSettings.tapSlop`, а также terminal
   transport normalization invalid terminal input в `handlePointer(...)`
   переносятся в `11.1`.
2. Controller-side active gesture owner, baseline `dragStartSlop`, forced reset
   на `replaceScene(...)` и `setCameraOffset(...)`, а также запрет
   не-владеющему pointer-у сбрасывать чужой gesture переносятся в `11.2`.
3. Создание `lib/src/interactive/interaction_eligibility_policy.dart` и
   консолидация `canSelect(...)`, `canPreviewMove(...)`,
   `canCommitMove(...)`, `canDelete(...)`, `canTransform(...)` переносятся
   в `11.3`.
4. Приведение move preview и move commit к одной policy-модели, восстановление
   baseline selection на cancel и удаление duplicate `onStateChanged`
   переносятся в `11.4`.
5. Draw/delete admissibility, safe cancel recovery, active draw gesture owner
   contract, timer/pending-line cleanup и closure metric hotspot-ов
   `interactive_draw_coordinator.dart` /
   `interactive_draw_eraser_engine.dart` переносятся в `11.5`.
6. Boundary-check, что
   [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   не возвращает synthetic terminal dispatch и abort bridge в controller,
   остаётся обязательной проверкой шага `11`, но ownership этого поведения
   не переносится обратно из шага `10`.

## Уже принятые архитектурные решения

1. После controller boundary admission active gesture meaning принадлежит
   только controller-side owner-у. View не принимает решений про invalid
   terminal semantics, forced abort и preview/commit admissibility, а direct
   controller entry использует тот же controller-owned owner contract.
2. `SceneControllerInteractive` получает один internal owner gesture lifecycle.
   Если для этого создаётся отдельный helper, он остаётся internal-only и не
   становится новым public/runtime service.
3. Invalid terminal input нормализуется на controller boundary до dispatch в
   owner-level lifecycle:
   - invalid `down/move` продолжают отбрасываться;
   - invalid terminal `up/cancel` не теряются только при cache hit по
     finite-позиции того же `pointerId`;
   - terminal phase сохраняется;
   - invalid terminal sample без cached finite-позиции остаётся no-op.
   Эта нормализация фиксирует только transport contract на boundary.
   Move-local и draw-local смысл terminal `up/cancel`, включая rollback,
   preview cleanup, pending-line abort и commit policy, остаётся ownership
   `11.4` и `11.5`.
4. Baseline `dragStartSlop` фиксируется один раз на `down` и не меняется до
   завершения текущего gesture, даже если `pointerSettings` или explicit
   `dragStartSlop` обновились в процессе.
5. `interaction_eligibility_policy.dart` становится owner-ом только для
   interactive preflight и selection shaping. Низкоуровневый
   [mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart)
   остаётся defensive write barrier и не импортирует interactive layer.
   [selection_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/selection_policy.dart)
   допускается как low-level leaf dependency, если не становится вторым owner-ом
   interactive composite policy и не начинает кодировать move/delete/preview
   composition шага `11`.
6. Step `11` не возвращает router/tracker/timer lifecycle обратно в controller
   и не вводит sync glue между raw-pointer host state и active gesture state.
7. Для каждого подшага повторная диагностика метрик является частью acceptance
   gate, а не справочным комментарием.

## Общие правила для всех подшагов

1. Один owner отвечает за active gesture identity. Нельзя одновременно держать
   competing mutable pointer-owner state и в controller, и в move/draw session.
   При этом boundary-normalization terminal input из `11.1` не должна сама по
   себе решать move/draw-local cleanup semantics, если для этого ещё нет
   единого owner contract из `11.2`, `11.4` и `11.5`.
2. Один owner отвечает за admissibility policy. Нельзя оставлять параллельно
   `interactive_selection_utils.dart`, controller-side ad hoc checks и новые
   helper-ы как competing источники одной и той же interactive composite
   policy. Низкоуровневые leaf predicates допустимы только как dependency, а не
   как второй owner move/delete/preview semantics.
3. Forced reset для camera/scene/mode/tool обязан идти через controller-owned
   gesture lifecycle, а не через view-side cleanup и не через ad hoc прямые
   вызовы отдельных session helper-ов из разных мест.
4. Если в рамках подшага меняется `tool/invariant_registry.dart`, этот подшаг
   обязан прогонять `dart run tool/check_invariant_coverage.dart`.
5. Любой новый internal owner этого этапа обязан проходить предел `10 / 4 / 40`
   по `cyclomatic-complexity`, `maximum-nesting-level` и
   `source-lines-of-code`.

## Ownership Matrix

- `11.1` владеет только boundary transport-normalization входного pointer
  event: phase, `pointerId`, monotonic `timestampMs`, finite/drop rules и
  fallback terminal position только при cache hit.
- `11.2` владеет только owner-level delivery/reset decision:
  какой controller-level `pointerId` активен, кому разрешён terminal dispatch,
  когда запускается forced reset.
- `11.3` владеет только определением interactive composite policy и
  controller-side preflight adoption вне session-ов.
- `11.4` владеет move-local смыслом `cancel`, rollback selection и adoption
  policy внутри move session.
- `11.5` владеет draw-local смыслом `cancel`, pending-line semantics,
  cleanup/timer owner contract и adoption policy внутри draw path.
- Ни один подшаг не должен одновременно владеть и event normalization, и
  local cleanup semantics одного и того же terminal случая.

## Критерии готовности umbrella-шага

1. Для шагов `11.1`, `11.2`, `11.3`, `11.4`, `11.5` существуют отдельные
   step-файлы с собственной целью, границей ответственности, критериями
   приёмки и тестовым контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `11.1` отвечает за controller pointer entry contract и canonical terminal
     input normalization;
   - `11.2` отвечает за active gesture owner и forced reset lifecycle;
   - `11.3` отвечает за owner admissibility policy;
   - `11.4` отвечает за move-session adoption этой policy и move-local cancel
     semantics;
   - `11.5` отвечает за draw-side lifecycle, terminal cleanup и pending-line
     cleanup.
3. Ни один пункт исходного шага `11` не потерян при переносе, включая блок
   диагностических метрик и требование не пробивать пороги `10 / 4 / 40`.
4. Граница между шагами `10` и `11` зафиксирована явно:
   - шаг `10` закрывает view/runtime pointer-router boundary;
   - шаг `11` закрывает invalid terminal semantics, active gesture owner,
     eligibility policy и forced gesture lifecycle на controller side.
5. После реализации шага `11.x` повторный прогон
   `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/interaction_eligibility_policy.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_move_session.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart --report-all`
   приложен к результату шага; в перечисленных контрольных файлах и новых
   owner-ах не остаётся `HIGH`/`VERY HIGH` по
   `cyclomatic-complexity`, `maximum-nesting-level` и
   `source-lines-of-code`.

## Чеклист выполнения

[ ] Переформулировать шаг `11` как umbrella-этап и вынести реализацию в
    `11.1`, `11.2`, `11.3`, `11.4`, `11.5`.
[x] В `11.1` зафиксировать controller pointer entry contract, unified
    `dragStartSlop` validation и terminal transport normalization для invalid
    terminal input.
[ ] В `11.2` ввести одного controller-owned owner-а active gesture и forced
    reset lifecycle без overlap со шагом `10`.
[ ] В `11.3` ввести одного owner-а interactive admissibility без инверсии layer
    DAG и без второго write-guard owner-а.
[ ] В `11.4` перевести move session на общий policy contract и move-local
    cancel restore.
[ ] В `11.5` перевести draw/eraser/line lifecycle на controller-owned reset,
    закрыть terminal/pending-line cleanup и убрать metric hotspot-ы draw-path.
[ ] Закрепить в критериях приёмки каждого подшага повторную диагностику
    метрик с порогами `cyclomatic-complexity <= 10`,
    `maximum-nesting-level <= 4`, `source-lines-of-code <= 40`.
