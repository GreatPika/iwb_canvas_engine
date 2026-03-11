language: russian

# Шаг 11.6. Запретить внешние selection mutations во время active gesture

## Цель шага

После `11.2-11.5` controller уже должен владеть active gesture lifecycle, а
move/draw path-и должны иметь явный local cleanup semantics. Но шаг `11`
остаётся архитектурно незавершённым, если public selection APIs продолжают
параллельно менять selection во время active gesture.

Задача подшага: зафиксировать, что между `down` и terminal `up/cancel`
selection lifecycle принадлежит controller-owned gesture owner-у, а внешние
вызовы:

- `setSelection(...)`;
- `toggleSelection(...)`;
- `clearSelection(...)`;
- `selectAll(...)`;

не могут конкурировать с gesture-local transition-ами.

## Что уже подтверждено по текущему состоянию

1. `SceneControllerInteractive` уже владеет active gesture owner-ом из `11.2`.
2. `11.4` был вынужден отдельно защищать move-local `cancel` semantics от
   внешних selection updates, что показывает незамкнутый public contract.
3. Пока public selection APIs разрешены во время active gesture, любой новый
   gesture path вынужден неявно решать конфликт между external mutation и
   gesture-local rollback/commit.
4. Это создаёт competing owner-ов для одного selection lifecycle и повышает
   стоимость поддержки каждого следующего интерактивного шага.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Во время active gesture public selection APIs запрещены.
2. Запрет распространяется на:
   - `setSelection(...)`;
   - `toggleSelection(...)`;
   - `clearSelection(...)`;
   - `selectAll(...)`.
3. Запрет оформляется как controller-level guard с `StateError`, а не как
   silent no-op.
4. Internal gesture-owned selection writes не считаются внешними mutation-ами
   и продолжают работать.
5. Terminal pointer delivery `up/cancel` не блокируется этим guard-ом.
6. Этот шаг не запрещает автоматически все остальные public mutations.
   Расширение exclusivity на другие APIs возможно только отдельным решением.

## Граница шага

- In:
  - public selection API exclusivity во время active gesture;
  - единый controller guard для `setSelection(...)`, `toggleSelection(...)`,
    `clearSelection(...)`, `selectAll(...)`;
  - documentation contract для этого ограничения;
  - tests на recovery после `up/cancel`.
- Out:
  - запрет всех public side effects во время active gesture;
  - изменение move/draw local semantics;
  - refactor gesture-machine.

## Точная реализация, которую должен описывать код

1. `SceneControllerInteractive` получает один internal helper для проверки,
   разрешены ли внешние selection mutations в текущем controller state.
2. `setSelection(...)`, `toggleSelection(...)`, `clearSelection(...)`,
   `selectAll(...)`
   используют этот helper до выполнения write path.
3. Если active gesture отсутствует, selection APIs работают как раньше.
4. Если active gesture активен, соответствующий public API выбрасывает
   `StateError` с явным contract-oriented сообщением.
5. Internal move/draw path-и не обходят этот шаг через дублирующий public API,
   а продолжают использовать internal callbacks/write path.

## Последовательность реализации (только действия)

[x] Ввести единый controller guard для external selection mutations.
[x] Применить guard к `setSelection(...)`, `toggleSelection(...)`,
    `clearSelection(...)`, `selectAll(...)`.
[x] Зафиксировать, что `up/cancel` снимают запрет после terminal cleanup.
[x] Обновить release-ready documentation и changelog.
[x] Добавить targeted tests для move и draw gesture cases.

## Критерии приёмки

[x] `setSelection(...)` выбрасывает `StateError` во время active move gesture.
[x] `toggleSelection(...)` выбрасывает `StateError` во время active move
    gesture.
[x] `clearSelection(...)` выбрасывает `StateError` во время active move
    gesture.
[x] `selectAll(...)` выбрасывает `StateError` во время active move gesture.
[x] Те же запреты действуют во время active draw gesture.
[x] После terminal `up/cancel` public selection APIs снова доступны.
[x] Internal gesture-owned selection transitions продолжают работать без
    competing public path-а.
[x] `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md` обновлены и
    фиксируют новый public contract.

## Тестовый контур шага

[x] `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
    с покрытием:
    - selection APIs запрещены во время active move gesture
    - selection APIs запрещены во время active draw gesture
    - после terminal `up/cancel` запрет снимается
[x] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    или отдельный targeted test file для public API contract-а
