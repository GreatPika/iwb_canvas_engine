language: russian

# Шаг 10.3. Зафиксировать `PointerInputSettings` как value object и apply-on-idle contract

## Цель шага

После `10.1` router уже даёт правильный idle predicate, а `10.2` должен
сузить view до host lifecycle. Следующий источник drift-а теперь в том, как
host сравнивает и применяет `PointerInputSettings`: локальный manual compare и
неявная семантика applied/pending state делают settings adoption зависимой от
случайной формы view state, а не от одного явного контракта.

Задача подшага: зафиксировать `PointerInputSettings` как value object и принять
один apply-on-router-idle contract для view-owned tracker settings без overlap
со gesture-machine решениями шага `11`.

## Что уже подтверждено по текущему состоянию

1. [pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input.dart)
   уже задаёт immutable `PointerInputSettings` и валидирует их на runtime
   boundary, но не фиксирует value semantics через `==` / `hashCode`.
2. [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   содержит manual `_pointerSettingsEqual(...)` со сравнением по каждому полю.
3. Там же view хранит `_lastPointerSettings` и `_pendingPointerSettings`, но
   applied и pending semantics пока выражены не как один явный state contract, а
   как набор полей с частично пересекающимся смыслом.
4. После `10.1` router уже экспонирует `hasLiveRawPointers` и `isIdle`; это и
   должно быть единственной границей для применения новых tracker settings.
5. [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart)
   уже экспонирует `pointerSettings` и `dragStartSlop`, но baseline-семантика
   `dragStartSlop`, invalid terminal semantics и active gesture ownership по
   текущему gesture lifecycle принадлежат шагу `11`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `PointerInputSettings` становится value object:
   - equality и `hashCode` выражают все его поля;
   - локальный manual comparator в view удаляется.
2. View-host после шага `10.3` хранит два явно разных состояния:
   - applied tracker settings;
   - pending tracker settings.
   Их нельзя подменять одним `_lastPointerSettings`.
3. Контракт применения новых settings фиксируется так:
   - если router idle, новые settings применяются сразу;
   - если есть живые raw pointers, новые settings сохраняются как pending;
   - при нескольких обновлениях действует правило `last write wins`.
4. Применение новых tracker settings всегда выполняется через новый
   `PointerInputTracker(settings: ...)` после router idle. Частичный hot-swap
   state внутри живого raw-pointer lifetime не допускается.
5. Смена controller instance:
   - отбрасывает pending settings старого controller;
   - сразу принимает settings нового controller как новый owner state;
   - не переносит pending state между разными controller owner-ами.
6. Step `10.3` не замораживает `dragStartSlop` на gesture baseline внутри
   controller и не решает invalid terminal semantics. Это controller-side
   ownership шага `11`.
7. `scene_controller_interactive.dart` после шага `10.3` не получает:
   - manual compare `PointerInputSettings`;
   - raw-pointer accounting;
   - view-side pending-settings state;
   - settings-specific bridge helper из view.

Почему именно так:

1. `PointerInputSettings` уже выглядит как immutable config value; отсутствие
   value semantics сейчас лишь вынуждает view дублировать знание о его полях.
2. Router idle, а не "tracked pointer закончился", является единственным
   безопасным моментом для пересоздания tracker state.
3. Разделение `applied` и `pending` убирает неявную семантику, где одно поле
   одновременно пытается быть и текущим, и отложенным значением.
4. Если попытаться закрыть здесь ещё и `dragStartSlop` baseline, invalid
   terminal recovery или active gesture owner, шаг `10` снова залезет в
   ownership шага `11`.

## Граница шага

- In:
  - value semantics `PointerInputSettings`;
  - pending/apply contract для view-owned tracker settings;
  - adoption этого контракта в `SceneViewInteractive`.
- Out:
  - raw router owner;
  - timer/flush host lifecycle;
  - controller gesture baseline semantics;
  - controller invalid terminal semantics и recovery.

## Точная реализация, которую должен описывать код

1. `SceneViewInteractive` больше не содержит `_pointerSettingsEqual(...)`.
2. `PointerInputSettings` сравнивается по value semantics везде, где host
   решает "нужно ли реально применять новое config state".
3. Pending settings коалесцируются до одного final value и применяются ровно
   один раз при переходе router в idle.
4. View state явно различает:
   - applied tracker settings;
   - pending tracker settings.
5. Смена controller instance:
   - отбрасывает pending settings старого controller;
   - пересобирает tracker по settings нового controller;
   - не переносит pending state между разными controller owner-ами.
6. Listener path `10.3` меняет только settings adoption state и не принимает
   controller-side terminal decisions.

## Последовательность реализации (только действия)

[x] Ввести value semantics для `PointerInputSettings`.
[x] Удалить manual compare settings из `SceneViewInteractive`.
[x] Разделить applied/pending tracker settings state.
[x] Зафиксировать `last write wins` и apply-on-router-idle contract.
[x] Явно задокументировать boundary со шагом `11` по `dragStartSlop`,
    invalid terminal semantics и active gesture owner.

## Критерии приёмки

[x] `PointerInputSettings` сравнивается по value semantics, а не через
    view-local manual comparator.
[x] `SceneViewInteractive` хранит отдельно applied и pending settings.
[x] Новые tracker settings не применяются, пока router не стал idle.
[x] При серии обновлений во время живых raw pointers применяется только
    последнее pending значение.
[x] `scene_controller_interactive.dart` не получает view-side pointer-router
    state и не становится вторым owner-ом settings transition policy.
[x] Шаг `10.3` не добавляет controller bridge для invalid terminal или gesture
    baseline semantics.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/core/pointer_input.dart --report-all`
    приложена к результату шага; `HIGH` не остаётся в step-owned settings
    owner-ах и методах, а `scene_controller_interactive.dart` рассматривается
    отдельно только как boundary watchpoint шага `11`. Целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[x] `test/view/scene_view_interactive_test.dart`
    с покрытием:
    - `INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY`
    - pending settings `last write wins`
    - apply-on-idle, а не apply-on-tracked-pointer-release
[x] `test/core/pointer_input_test.dart`
    с отдельной проверкой value semantics `PointerInputSettings`
[x] `test/interactive/core/scene_controller_interactive_basics_test.dart`
    только как boundary-check для public validation surface
