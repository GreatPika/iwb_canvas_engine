language: russian

# Шаг 11.3. Ввести одного owner-а interactive admissibility в `interaction_eligibility_policy.dart`

## Цель шага

После `11.2` lifecycle active gesture уже должен иметь одного owner-а, но сам
gesture всё ещё останется непредсказуемым, если preview, commit, selection и
delete будут продолжать опираться на несколько похожих helper-ов:

- `core/selection_policy.dart`;
- `interactive_selection_utils.dart`;
- controller-side preflight logic в `SceneControllerInteractive`;
- ad hoc inline checks, от которых потом зависят move/draw session-ы.

Задача подшага: создать
`lib/src/interactive/interaction_eligibility_policy.dart` как единственный
owner interactive composite admissibility и перевести на него
controller-side preflight callers вне move/draw session-ов без инверсии layer
DAG и без расширения scope в core/write layer. Session-local adoption этого
policy в `InteractiveMoveSession` и draw-path сознательно остаётся ownership
`11.4` и `11.5`.

## Что уже подтверждено по текущему состоянию

1. [selection_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/selection_policy.dart)
   уже владеет low-level scene predicates, которые используются в writer/runtime
   слоях ниже interactive.
2. [interactive_selection_utils.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_selection_utils.dart)
   дублирует snapshot-level правила для transform/delete selection.
3. [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   использует эти helper-ы в `rotateSelection(...)`, `flipSelection*`,
   `deleteSelection(...)`.
4. [mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart)
   уже содержит defensive write guards для transform и translate selection.
5. Текущая структура опасна тем, что новый policy-модуль легко может стать
   четвёртым owner-ом поверх уже существующих helper-ов, если не принять
   жёсткое решение по ownership.

## Рекомендуемое решение

Рекомендуемый вариант: сделать `interaction_eligibility_policy.dart` pure
owner-ом interactive composite preflight и selection shaping, а
`selection_policy.dart` оставить low-level leaf dependency для scene/write
слоёв. Низкоуровневые write guards в `mutation_executor.dart` при этом
остаются defensive barrier-ом, но не owner-ом interactive composite policy.

Почему это лучший вариант:

1. Он не ломает layer DAG: controller core не начинает импортировать
   interactive layer ради write guard logic.
2. Он убирает размножение interactive composite правил в нескольких helper-ах,
   не требуя controller core импортировать interactive layer.
3. Он даёт move/draw/controller путям один понятный набор policy entrypoints.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `lib/src/interactive/interaction_eligibility_policy.dart` становится одним
   owner-ом следующих interactive composite predicates:
   - `canSelect(...)`
   - `canPreviewMove(...)`
   - `canCommitMove(...)`
   - `canDelete(...)`
   - `canTransform(...)`
2. Политика намеренно остаётся pure и side-effect free:
   - без store state;
   - без pointer/gesture lifecycle;
   - без write orchestration.
3. Базовые node-level semantics фиксируются так:
   - `canSelect(node)` требует visibility и selectable;
   - `canTransform(node)` требует `isTransformable && !isLocked`;
   - `canPreviewMove(node)` требует `canSelect(node) && canTransform(node)`;
   - `canCommitMove(node)` совпадает с `canPreviewMove(node)`;
   - `canDelete(node)` требует delete eligibility runtime node-а.
   `canPreviewMove(...)` и `canCommitMove(...)` остаются отдельными entrypoint-ами,
   даже если их текущая формула совпадает, чтобы call site выражал intent.
4. `selection_policy.dart` остаётся допустимым low-level leaf dependency для
   scene/write слоёв, но не получает ownership над move preview/commit/delete
   composition. `interactive_selection_utils.dart` перестаёт быть owner-ом
   overlapping admissibility:
   - interactive composite helper-ы переносятся в новый owner;
   - geometry-only helper-ы и низкоуровневые scene predicates могут остаться на
     месте, если они не кодируют interactive composite semantics.
5. `mutation_executor.dart` и writer-level ops не импортируют
   `interaction_eligibility_policy.dart`. Их guard-ы остаются defensive и не
   подменяют owner-а preflight policy.
6. Controller/runtime callers выше mutation layer обязаны использовать новый
   policy owner там, где им нужен именно interactive composite admissibility, а
   не write safety fallback.
7. Session-local wiring этого policy в move/draw path не входит в этот
   подшаг, даже если именно там сегодня живут часть inline checks. Этим владеют
   `11.4` и `11.5`.

## Граница шага

- In:
  - `interaction_eligibility_policy.dart`;
  - миграция overlapping composite admissibility helper-ов;
  - adoption policy в controller-side preflight путях вне move/draw session-ов.
- Out:
  - active gesture lifecycle;
  - session-specific pointer flow;
  - write-layer defensive guards;
  - превращение `selection_policy.dart` в interactive-layer owner;
  - session-local adoption policy в `InteractiveMoveSession` и draw-path.

## Точная реализация, которую должен описывать код

1. Новый policy owner экспортирует ровно канонические interactive composite
   predicates и нужные derived helper-ы для selection shaping поверх тех же
   predicates.
2. `SceneControllerInteractive.rotateSelection(...)`,
   `flipSelectionHorizontal(...)`, `flipSelectionVertical(...)`,
   `deleteSelection(...)` и другие direct runtime callers используют новый
   policy owner вместо scattered helper-ов.
3. `interactive_selection_utils.dart` после подшага либо удаляется, либо
   перестаёт содержать owner-level interactive composite rules.
4. `selection_policy.dart` после подшага остаётся только low-level dependency и
   не становится параллельным owner-ом move/delete/preview composition.
5. Подшаг явно документирует: write-layer guard и interactive preflight policy
   не конкурируют друг с другом, потому что отвечают за разные boundary-level
   обязанности.

## Последовательность реализации (только действия)

[ ] Создать `lib/src/interactive/interaction_eligibility_policy.dart`.
[ ] Перенести в него overlapping interactive composite rules из старых helper-ов.
[ ] Перевести controller-side preflight callers вне session-ов на новый policy
    owner.
[ ] Явно оставить session-local adoption policy для `11.4` и `11.5`, чтобы
    не возник overlap по ownership.
[ ] Удалить или раз-owner-ить прежние helper-ы, чтобы не осталось dual-source
    of truth.
[ ] Зафиксировать boundary между preflight policy и write-layer defensive guard.

## Критерии приёмки

[ ] `interaction_eligibility_policy.dart` является одним owner-ом interactive
    composite admissibility.
[ ] `canSelect(...)`, `canPreviewMove(...)`, `canCommitMove(...)`,
    `canDelete(...)` и `canTransform(...)` определены однозначно и не дублируют
    друг друга в нескольких файлах.
[ ] `interactive_selection_utils.dart` больше не является competing source of
    truth для той же interactive composite semantics.
[ ] `selection_policy.dart` используется только как low-level leaf dependency и
    не становится вторым owner-ом move/delete/preview composition.
[ ] Controller-side preflight callers используют новый policy owner.
[ ] Session-local adoption policy остаётся вне scope этого подшага и не
    пересекается с `11.4`/`11.5`.
[ ] `mutation_executor.dart` не импортирует interactive layer и остаётся только
    defensive write barrier-ом.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/interactive/interaction_eligibility_policy.dart lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_selection_utils.dart lib/src/core/selection_policy.dart --report-all`
    приложена к результату шага; новый owner-файл и step-owned methods не
    содержат `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[ ] Новый targeted test:
    `test/interactive/core/interaction_eligibility_policy_test.dart`
[ ] `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
    с покрытием delete/transform preflight на shared policy
[ ] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    как boundary-check, что public interactive APIs не обходят новый policy
