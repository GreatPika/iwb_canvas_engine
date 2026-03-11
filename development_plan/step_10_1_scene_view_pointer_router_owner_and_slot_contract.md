language: russian

# Шаг 10.1. Зафиксировать owner `scene_view_pointer_router` и контракт raw-to-slot routing

## Цель шага

Сначала нужно выделить pointer-router в одного owner-а. Иначе все следующие
исправления шага `10` будут делаться поверх плавающего состояния, где
`SceneViewInteractive` одновременно хранит raw-pointer tables, slot allocator,
active-pointer gate и правила reset-а tracking state.

Задача подшага: ввести `lib/src/view/scene_view_pointer_router.dart` как один
owner raw-pointer lifecycle и routed slot ids, а также зафиксировать точный
контракт, по которому host получает routed `pointerId` и узнаёт, когда router
действительно стал idle.

## Что уже подтверждено по текущему состоянию

1. [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   сейчас сам хранит `_pointerSlotByRawPointer`, `_freePointerSlots`,
   `_nextPointerSlotId` и `_activePointerId`.
2. `_resolvePointerId(...)` в
   [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   для unknown non-down event возвращает `rawPointer`, то есть смешивает raw и
   routed pointer spaces.
3. `_acquirePointerSlot()` там же ищет минимальный свободный slot через
   линейный проход по `List<int>`.
4. `_resetPointerTracking(...)` опирается только на `_activePointerId`, а не
   на число живых raw pointers, поэтому host lifecycle ещё не имеет одного
   строгого idle predicate.
5. Текущие view invariants уже закреплены в:
   - `INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE`
   - `INV-ENG-VIEW-ACTIVE-POINTER-GATE`

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `lib/src/view/scene_view_pointer_router.dart` вводится как единственный
   owner:
   - raw-to-routed id mapping;
   - routed slot reuse policy;
   - live raw-pointer accounting;
   - active signal-tracking gate.
2. Routed `pointerId` создаётся только на `PointerPhase.down`.
   Unknown non-down raw pointer:
   - не получает synthetic routed id;
   - не пробрасывает raw id в controller или `PointerInputTracker`;
   - трактуется как stray host event.
3. Один raw pointer сохраняет свой routed slot id до собственного `up` или
   `cancel`. Reuse того же slot для другого raw pointer возможен только после
   terminal release предыдущего владельца.
4. Router хранит один mutable source of truth о том, какие raw pointers сейчас
   живы:
   - mapping `rawPointer -> routedPointerId`.
   Из него derive-ятся:
   - `isIdle`;
   - `liveRawPointerCount` / `hasLiveRawPointers`.
   Active signal-tracking gate хранится отдельно как узкое router-owned state,
   но не дублируется второй mutable таблицей живых raw pointers.
5. Если tracked routed pointer завершился, но другие raw pointers ещё живы,
   router переходит в состояние "gate blocked until idle":
   - signal tracking не переносится на другой живой raw pointer;
   - pending settings не применяются;
   - host не делает reset tracking до полного idle.
   Это не вводит и не обещает multi-touch interaction contract: дополнительные
   raw pointers по-прежнему не становятся новой активной gesture-сессией, а
   лишь не должны ломать host/runtime state.
6. Политика reuse минимального свободного slot id сохраняется, но реализуется
   через упорядоченную структуру `SplayTreeSet<int>`, а не через линейный
   поиск минимума.
7. Порядок terminal cleanup фиксируется жёстко:
   - сначала router release соответствующего raw pointer;
   - затем host проверяет `router.isIdle`;
   - только после этого допускается reset/apply pending logic.
8. `SceneControllerInteractive` продолжает видеть routed `pointerId` только как
   opaque integer. Никакая raw-pointer policy не переносится в controller.

Почему именно так:

1. Пока raw mapping, slot pool и signal gate лежат в `SceneViewInteractive`,
   один и тот же lifecycle размазан между несколькими полями без общего
   owner-а.
2. Возврат raw pointer id как fallback для unknown non-down события ломает саму
   идею routed id space и делает downstream код зависимым от случайного host
   значения.
3. Переносить signal gate на другой живой raw pointer нельзя безопасно:
   `PointerInputTracker` не видел его исходный `down`, значит середина чужого
   lifecycle не должна внезапно становиться tracked state.
4. `SplayTreeSet<int>` закрывает требование "reuse minimum free slot" без
   нового самодельного heap abstraction и без линейной деградации.
5. Контракт `gate until idle` здесь нужен не для поддержки многопальцевых
   жестов как фичи, а для fail-safe поведения при параллельных raw pointer
   событиях со стороны host/test/runtime. Система всё равно остаётся
   single-pointer interactive policy.

## Граница шага

- In:
  - `lib/src/view/scene_view_pointer_router.dart`;
  - routed slot contract;
  - idle predicate и active gate contract;
  - adoption нового router owner-а в `SceneViewInteractive`.
- Out:
  - timer/flush lifecycle;
  - finite admission policy для host events;
  - value semantics `PointerInputSettings`;
  - controller-side gesture semantics.

## Точная реализация, которую должен описывать код

1. `SceneViewInteractive` больше не владеет напрямую raw-pointer tables и free
   slot list; этим владеет `SceneViewPointerRouter`.
2. Новый router owner хранит state, достаточный для:
   - route `down`;
   - resolve routed id для known raw pointer;
   - terminal release raw pointer;
   - ответа на вопрос `isIdle`;
   - single-pointer signal gate без второй raw-pointer table.
3. Router API обязан позволять host-у различать три случая:
   - новый routed `pointerId` на `down`;
   - known routed `pointerId` на non-down;
   - stray event без routed id.
4. Active signal gate остаётся single-pointer policy, но больше не выражается
   формулой "active == null => track everything".
5. `SceneViewInteractive` после подшага использует только router API и не
   держит параллельный raw-pointer state рядом.

## Последовательность реализации (только действия)

[ ] Создать `lib/src/view/scene_view_pointer_router.dart` как owner
    raw-to-slot lifecycle.
[ ] Перевести `SceneViewInteractive` с прямых коллекций на новый router API.
[ ] Убрать fallback raw pointer id для unknown non-down events.
[ ] Перевести free-slot reuse на упорядоченную структуру без линейного scan.
[ ] Зафиксировать idle/gate contract так, чтобы reset/apply pending были
    возможны только после полного release всех raw pointers.

## Критерии приёмки

[ ] `SceneViewPointerRouter` является одним owner-ом raw-to-slot routing и
    active signal gate.
[ ] Raw pointer ids и routed pointer ids больше не смешиваются в одном
    пространстве.
[ ] Unknown non-down raw pointer не получает synthetic routed id и не
    пробрасывается дальше как raw-id fallback.
[ ] Один raw pointer сохраняет routed slot id до terminal release, после чего
    slot возвращается в минимальный свободный pool.
[ ] Host не делает reset/apply pending, пока router не стал idle.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/view/scene_view_pointer_router.dart --report-all`
    приложена к результату шага; новый owner-файл
    `scene_view_pointer_router.dart` и step-owned router methods не содержат
    `HIGH` по `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`, а целевой предел остаётся `10 / 4 / 40`.

## Тестовый контур шага

[ ] Новый targeted test:
    `test/view/scene_view_pointer_router_test.dart`
[ ] `test/view/scene_view_interactive_test.dart`
    с покрытием:
    - `INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE`
    - `INV-ENG-VIEW-ACTIVE-POINTER-GATE`
    - parallel raw-pointer case для `liveRawPointerCount` reset gate
    - порядок `release slot -> only then reset/apply pending`
[ ] `dart run tool/check_invariant_coverage.dart` если меняется
    `tool/invariant_registry.dart`
