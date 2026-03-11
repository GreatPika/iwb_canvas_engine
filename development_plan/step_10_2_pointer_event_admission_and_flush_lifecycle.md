language: russian

# Шаг 10.2. Зафиксировать host admission, host terminal cleanup и flush/timer lifecycle в `SceneViewInteractive`

## Цель шага

После `10.1` raw routing уже имеет одного owner-а, но сам widget-host всё ещё
легко превращается во второй gesture-owner, если в `_handlePointerEvent(...)`
вместе живут:

- finite filtering host event-ов;
- terminal cleanup для router/tracker/timer;
- deferred tap timer и listener lifecycle;
- ad hoc попытки восстановить controller-side gesture semantics.

Задача подшага: сузить `SceneViewInteractive` до одного host runtime contract:

- admission для invalid host events;
- host-owned terminal cleanup для router/tracker/timer;
- deferred tap timer;
- mounted-safe listener/deferred lifecycle.

Controller-side meaning invalid `up/cancel`, active gesture recovery,
preview/commit/cancel semantics и abort contract сюда не входят и остаются
owner-ом шага `11`.

## Что уже подтверждено по текущему состоянию

1. [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   сейчас в `_handlePointerEvent(...)` строит `CanvasPointerInput` и
   `PointerSample`, а затем трогает router, controller, tracker и timer path в
   одном методе.
2. Там же finite gate для invalid `down/move` отсутствует на host boundary до
   router/controller/tracker/timer side effects.
3. `_syncPendingFlushTimer(...)` использует `Duration(milliseconds: delayMs)`,
   где `delayMs` приходит из `num` после `clamp(...)`, а не из явно
   нормализованного `int`.
4. `_handlePendingTapTimer()` и `_handleControllerChanged()` не зафиксированы
   как mounted-safe lifecycle contract и сейчас не описаны как отдельный owner
   deferred behavior.
5. В
   [pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input.dart)
   `flushPending(...)` возвращает `List<PointerSignal>`, хотя host timer path в
   `SceneViewInteractive` этот результат не использует.
6. Invalid terminal host event сейчас легко провоцирует overlap: если чинить его
   локально в view через synthetic dispatch или controller abort bridge, виджет
   начинает принимать controller-side terminal decisions, которые по плану
   принадлежат шагу `11`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneViewInteractive` остаётся owner-ом:
   - Flutter `PointerEvent` host admission;
   - host interaction с `SceneViewPointerRouter`;
   - `PointerInputTracker` lifecycle;
   - deferred tap timer;
   - controller subscription/unsubscription.
   Этот lifecycle не переносится в router и не проталкивается в controller.
2. Finite admission на host boundary фиксируется так:
   - invalid `down` и `move` отбрасываются до любых
     router/controller/tracker/timer side effects;
   - valid события идут по обычному routed path;
   - invalid `up/cancel` не превращаются здесь в synthetic safe dispatch в
     controller.
3. Для invalid `up/cancel` шаг `10.2` владеет только host-owned cleanup:
   - release routed raw pointer в router;
   - drop active tracker state для этого routed `pointerId`, если это нужно
     host lifecycle;
   - cleanup/reschedule host timer state только как части host contract.
   Этот шаг не определяет controller-side смысл такого terminal event.
4. `Duration(milliseconds: ...)` строится только из явно нормализованного
   `int` через `toInt()` после `clamp(...)`.
5. `PointerInputTracker` получает no-allocation primitive для host discard path:
   host timer больше не обязан материализовывать `List<PointerSignal>`, если
   эти сигналы не используются. List-returning `flushPending(...)` при этом
   остаётся thin wrapper над одной канонической primitive, а не вторым owner-ом
   той же логики.
6. Все deferred paths и listener callbacks, которые могут сработать после
   dispose/controller swap, обязаны проверять `mounted` и актуальность owner-а
   до изменения state или повторного планирования timer-а.
7. Шаг `10.2` не добавляет новый internal controller API, единственная цель
   которого состоит во view-side recovery invalid terminal input.

Почему именно так:

1. View boundary должна закрывать host leaks и invalid host data, но не должна
   становиться второй gesture-machine.
2. Router/tracker/timer path принадлежат widget-host owner-у, потому что
   зависят от `mounted`, `dispose`, controller swap и event loop lifecycle.
3. Active gesture meaning знает только controller-side gesture owner; если
   view начнёт восстанавливать его локально, шаг `10.2` снова залезет в `11`.
4. No-allocation flush primitive нужен не ради микрооптимизации, а чтобы host
   не создавал временную коллекцию в path, где результат заведомо не
   используется.

## Граница шага

- In:
  - `_handlePointerEvent(...)` и связанные host helper-ы;
  - ранний gate для invalid `down/move`;
  - host-owned terminal cleanup для invalid `up/cancel` в router/tracker/timer
    path;
  - `PointerInputTracker` flush primitive для discard path;
  - mounted-safe timer/listener lifecycle.
- Out:
  - raw-to-slot router owner;
  - value semantics `PointerInputSettings`;
  - controller-side invalid pointer API contract;
  - controller abort/recovery API для invalid terminal input.

## Точная реализация, которую должен описывать код

1. `SceneViewInteractive` разделяет:
   - host admission;
   - routed dispatch;
   - signal tracking;
   - timer reschedule/finalize;
   - host terminal cleanup.
   Эти фазы больше не сливаются в одно неявное тело.
2. Host finite gate срабатывает до вызовов:
   - router route для invalid `down/move`;
   - `widget.controller.handlePointer(...)`;
   - `_pointerTracker.handle(...)`;
   - `_syncPendingFlushTimer(...)`.
3. Valid `up/cancel` продолжают идти по обычному routed path без изменения
   controller semantics шага `10.2`.
4. Invalid `up/cancel` обновляют только host-owned router/tracker/timer state:
   - без synthetic safe `up`;
   - без synthetic `cancel` в controller;
   - без controller abort bridge из view.
5. `_handlePendingTapTimer()` после подшага:
   - не работает, если widget уже unmounted;
   - не reschedule-ит timer после dispose/controller swap;
   - использует discard-friendly flush primitive.
6. `_handleControllerChanged()` после подшага:
   - остаётся owner-ом listener lifecycle и epoch adoption;
   - вызывает settings transition policy, определённую в `10.3`, а не
     дублирует её локально;
   - не мутирует host state после dispose;
   - не делает лишнего reset/resubscribe при stale callback.
7. `PointerInputTracker.flushPendingTo(...)` становится канонической primitive,
   а `flushPending(...)` остаётся thin wrapper над ней.

## Последовательность реализации (только действия)

[x] Вынести host finite admission для invalid `down/move` в явную раннюю фазу
    `_handlePointerEvent(...)`.
[x] Выделить host-owned terminal cleanup для invalid `up/cancel` без
    controller-side recovery bridge.
[x] Исправить timer delay на явный `int`.
[x] Ввести no-allocation flush primitive в `PointerInputTracker` и перевести на
    него host timer path.
[x] Зафиксировать `mounted`-guard во всех deferred/listener путях этого owner-а.

## Критерии приёмки

[x] `SceneViewInteractive` имеет один явный host pipeline и не смешивает host
    lifecycle с controller gesture semantics.
[x] Invalid `down/move` не создают routed slot и не вызывают
    router/controller/tracker/timer side effects.
[x] Invalid terminal host events делают только host-owned cleanup для
    router/tracker/timer state и не создают view-side terminal bridge в
    controller.
[x] Valid `up/cancel` сохраняют прежний routed dispatch path.
[x] Deferred timer path не создаёт лишнюю коллекцию сигналов, если host её не
    использует.
[x] Timer/listener callbacks безопасны относительно `mounted` и controller swap.
[x] Шаг `10.2` не добавляет новый internal controller API ради invalid terminal
    recovery из view.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/core/pointer_input.dart --report-all`
    приложена к результату шага; новые или step-owned host lifecycle methods и
    flush primitive не содержат `HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
    остаётся `10 / 4 / 40`.

## Тестовый контур шага

[x] `test/view/scene_view_interactive_test.dart`
    с новыми targeted cases для:
    - invalid `down/move` не создают slot, gate и pending timer
    - invalid terminal host events освобождают host gate/router state без
      проверки controller-side preview/commit recovery
    - timer safety после dispose/controller swap
    - deferred flush без лишнего host-side signal materialization
[x] `test/core/pointer_input_test.dart`
[x] `dart run tool/check_invariant_coverage.dart` если меняется
    `tool/invariant_registry.dart` (не требовалось: `tool/invariant_registry.dart`
    не менялся)

## Диагностика шага

- `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/core/pointer_input.dart --report-all`
  завершился без `HIGH`; целевые step-owned methods остаются в пределах
  `cyclomatic-complexity <= 10`, `maximum-nesting-level <= 4`,
  `source-lines-of-code <= 40`.
