language: russian

# Шаг 10. Вынести pointer-router в правильную форму через подшаги 10.1-10.3

## Диагностические метрики

Этот блок остаётся диагностическим радаром шага, но для `10.x` он также
обязан быть отражён в критериях приёмки: step-owned целевые файлы после
реализации не должны пробивать пороги из `analysis_options.yaml`.

- Смотреть в первую очередь `cyclomatic-complexity`,
  `maximum-nesting-level` и `source-lines-of-code`.
- Пороговые значения для step-owned owner-ов:
  - `cyclomatic-complexity <= 10`
  - `maximum-nesting-level <= 4`
  - `source-lines-of-code <= 40`
- Контрольные файлы:
  - `lib/src/view/scene_view_interactive.dart`
  - `lib/src/view/scene_view_pointer_router.dart`
  - `lib/src/core/pointer_input.dart`
  - `lib/src/interactive/scene_controller_interactive.dart`
- Acceptance gate по метрикам ставится не на весь файл целиком, а на
  step-owned owner-ы и методы этого этапа. Это важно, потому что соседние,
  неотносящиеся к шагу `10`, части тех же файлов уже могут иметь свои
  исторические watchpoints.
- Полезный сигнал после шага: raw-pointer lifecycle, routed slot ids,
  host-owned terminal cleanup, deferred flush/timer lifecycle и
  pointer-settings transition имеют одного owner-а на view-runtime boundary,
  а invalid terminal semantics, active gesture owner и cancel/abort recovery
  остаются в `scene_controller_interactive.dart` и шаге `11`.

## Цель шага

После шагов `7.x-9.x` controller и render lifecycle уже достаточно выровнены,
чтобы закрыть следующий системный drift: pointer-routing на view boundary всё
ещё не имеет одного owner-а и сейчас смешивает в
`lib/src/view/scene_view_interactive.dart` несколько разных задач:

- raw Flutter pointer lifecycle;
- internal routed pointer ids и slot reuse policy;
- active-pointer gate для signal tracking;
- deferred single-tap flush timer;
- live adoption `PointerInputSettings` при незавершённых указателях.

Исходный шаг `10` перечислял правильные проблемы, но в одном списке были
смешаны как минимум три разные ответственности. Без их декомпозиции
реализация почти неизбежно либо оставляет логику в `SceneViewInteractive`,
либо проталкивает view-runtime детали в `SceneControllerInteractive`, который
должен заниматься уже gesture-machine semantics из шага `11`.

## Как разбит этап

### Шаг 10.1

`development_plan/step_10_1_scene_view_pointer_router_owner_and_slot_contract.md`

Владелец решения по:

- `lib/src/view/scene_view_pointer_router.dart` как одному owner-у raw-to-slot
  routing;
- явному разделению raw pointer ids и routed pointer ids;
- slot reuse policy и signal-tracking gate для tracker/double-tap lifecycle;
- правилу, когда router считается idle и когда разрешён reset host tracking.

### Шаг 10.2

`development_plan/step_10_2_pointer_event_admission_and_flush_lifecycle.md`

Владелец решения по:

- admission policy pointer events на widget-host boundary;
- host-owned terminal cleanup для router/tracker/timer path;
- timer/flush lifecycle для deferred taps;
- mounted-safe поведению отложенных путей и controller listener-ов;
- устранению лишних allocation-path в host flush logic;
- явному запрету на view-side terminal bridge в controller.

### Шаг 10.3

`development_plan/step_10_3_pointer_settings_transition_and_value_semantics.md`

Владелец решения по:

- value semantics для `PointerInputSettings`;
- одному apply-on-router-idle контракту сравнения и применения pointer
  settings;
- pending-settings lifecycle при живых raw pointers;
- явной границе между view-side settings adoption и controller-side
  gesture semantics шага `11`.

## Карта переноса деталей из исходного шага 10

1. Ранний finite-gate для invalid `down/move` в `_handlePointerEvent(...)`
   переносится в `10.2`.
2. `Duration(milliseconds: ...)` через явный `toInt()` переносится в `10.2`.
3. Разделение raw pointer ids и internal slot ids переносится в `10.1`.
4. Стабильный routed id на весь raw-pointer lifetime переносится в `10.1`.
5. Запрет reset tracking при любом живом raw-pointer переносится в `10.1`.
6. Порядок `release slot -> only then idle reset/apply pending` переносится в
   `10.1`.
7. Замена линейного поиска минимума в `_acquirePointerSlot()` переносится в
   `10.1`.
8. Удаление ручного сравнения `PointerInputSettings` по полям переносится в
   `10.3`.
9. Устранение лишних коллекций в `flushPending` переносится в `10.2`.
10. `mounted`-проверки во всех отложенных путях и listener-ах переносятся в
    `10.2`.
11. Host-owned terminal cleanup для invalid `up/cancel` в
    router/tracker/timer path переносится в `10.2`.
12. Controller-side трактовка invalid `up/cancel`, active gesture owner и
    cancel/abort recovery переносятся в `11`.
13. Финальный контракт смены pointer settings при живых raw pointers
    переносится в `10.3`.

## Уже принятые архитектурные решения

1. Pointer-router concern фиксируется как view-runtime boundary и не
   переносится в `SceneControllerInteractive`.
2. Raw pointer ids и routed pointer ids после шага `10` живут в разных
   пространствах. Controller и `PointerInputTracker` получают только routed id
   как opaque runtime value.
3. Новый routed pointer id создаётся только на `down`. Unknown non-down raw
   pointer не имеет права синтезировать routed id из raw значения.
4. Router state считается idle только когда завершились все живые raw pointers.
   Освобождение tracked pointer gate раньше idle не даёт права reset-ить host
   tracking и применять pending settings.
5. Reuse свободного routed slot id остаётся policy owner-а router-а, но
   реализуется через упорядоченную структуру, а не через линейный scan.
6. `PointerInputSettings` фиксируется как immutable value object. View не
   держит локальный manual comparator по полям.
7. Смена pointer settings во время живых raw pointers работает по правилу
   "last write wins, apply on router idle". Частичное hot-swap поведение в
   середине raw-pointer lifetime не допускается.
8. Шаг `10` не принимает controller-side решения про gesture admissibility,
   preview/commit/cancel semantics и baseline `dragStartSlop`. Это полностью
   остаётся за шагом `11`.
9. Шаг `10.2` может делать только host-owned cleanup для router/tracker/timer
   state. Synthetic terminal dispatch в controller и view-side abort bridge не
   допускаются.

## Общие правила для всех подшагов

1. Один owner отвечает за raw-pointer routing. Нельзя оставлять одновременно
   routing state и в `SceneViewInteractive`, и в новом router helper-е.
2. Один owner отвечает за host timer/flush lifecycle. Router не должен
   становиться новым `StatefulWidget`-substitute с `Timer`, `mounted` и
   listener knowledge.
3. `SceneControllerInteractive` после шага `10` продолжает принимать routed
   `pointerId` как opaque integer и не знает о raw Flutter pointer ids.
4. View boundary не имеет права принимать решение, как invalid terminal input
   влияет на active gesture внутри controller. Это owner шага `11`.
5. Если в рамках подшага меняется `tool/invariant_registry.dart`, этот подшаг
   обязан прогонять `dart run tool/check_invariant_coverage.dart`.
6. Для каждого подшага повторная диагностика метрик обязана быть частью
   критериев приёмки, а не только фоновым комментарием.

## Критерии готовности umbrella-шага

1. Для шагов `10.1`, `10.2`, `10.3` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `10.1` отвечает за router owner и slot contract;
   - `10.2` отвечает за host admission, host terminal cleanup, timer/flush и
     mounted lifecycle;
   - `10.3` отвечает за settings transition и value semantics.
3. Ни один пункт исходного шага `10` не потерян при переносе, включая блок
   диагностических метрик и требование не пробивать пороги `10 / 4 / 40`.
4. Граница между шагами `10` и `11` зафиксирована явно:
   - шаг `10` закрывает view/runtime pointer-router boundary;
   - шаг `11` закрывает gesture-machine, invalid terminal semantics,
     admissibility и controller semantics.
5. После реализации шага `10.x` повторный прогон
   `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/view/scene_view_pointer_router.dart lib/src/core/pointer_input.dart --report-all`
   приложен к результату шага; `HIGH` по `cyclomatic-complexity`,
   `maximum-nesting-level` и `source-lines-of-code` не остаётся в step-owned
   owner-ах и методах шага `10`, а `scene_controller_interactive.dart`
   отдельно используется только как boundary watchpoint для шага `11`.

## Чеклист выполнения

[x] Переформулировать шаг `10` как umbrella-этап и вынести реализацию в
    `10.1`, `10.2`, `10.3`.
[x] В `10.1` принять финальное решение по owner-у raw-to-slot routing,
    active-pointer gate и slot reuse contract.
[ ] В `10.2` зафиксировать host admission, host-owned terminal cleanup и
    flush/timer lifecycle без view-side terminal bridge в controller.
[ ] В `10.3` зафиксировать value semantics и pending-apply contract для
    `PointerInputSettings` без overlap со шагом `11`.
[x] Закрепить в критериях приёмки каждого подшага повторную диагностику
    метрик с порогами `cyclomatic-complexity <= 10`,
    `maximum-nesting-level <= 4`, `source-lines-of-code <= 40`.
