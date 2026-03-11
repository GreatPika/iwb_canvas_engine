language: russian

# Шаг 10.2. Нормализовать pointer event admission и flush/timer lifecycle в `SceneViewInteractive`

## Цель шага

После `10.1` raw routing уже должен иметь одного owner-а, но сам widget-host
всё ещё останется хрупким, если `_handlePointerEvent(...)`, deferred flush
timer и controller listener-ы продолжат смешивать event admission, timer
reschedule и mounted lifecycle в одном месте.

Задача подшага: закрепить один host contract для pointer event admission,
deferred tap flush и mounted-safe отложенных путей так, чтобы
`SceneViewInteractive` остался owner-ом widget lifecycle, но перестал быть
источником случайных invalid/timer drift-ов.

## Что уже подтверждено по текущему состоянию

1. [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   сейчас в `_handlePointerEvent(...)` строит `CanvasPointerInput` и
   `PointerSample`, а затем трогает controller, tracker и timer path в одном
   методе.
2. Там же finite gate для `NaN/Infinity` отсутствует на host boundary до
   controller/tracker side effects.
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

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneViewInteractive` остаётся owner-ом:
   - Flutter `PointerEvent` admission;
   - `PointerInputTracker` lifecycle;
   - deferred tap timer;
   - controller subscription/unsubscription.
   Этот lifecycle не переносится в router и не проталкивается в controller.
2. Finite admission на host boundary фиксируется так:
   - `down` и `move` с невалидной позицией отбрасываются до любых
     controller/tracker/timer side effects;
   - `up` и `cancel` с невалидной позицией не должны оставлять host или
     controller в подвешенном terminal state;
   - view-host не пробрасывает invalid coordinates как есть в downstream math,
     но и не теряет terminal semantics pointer lifecycle.
3. `Duration(milliseconds: ...)` строится только из явно нормализованного
   `int` через `toInt()` после `clamp(...)`.
4. `PointerInputTracker` получает no-allocation primitive для host discard path:
   host timer больше не обязан материализовывать `List<PointerSignal>`, если
   эти сигналы не используются. List-returning `flushPending(...)` при этом
   остаётся лишь thin wrapper над одной канонической primitive, а не вторым
   owner-ом той же логики.
5. Все deferred paths и listener callbacks, которые могут сработать после
   dispose/controller swap, обязаны проверять `mounted` и актуальность owner-а
   до изменения state или повторного планирования timer-а.
6. Шаг `10.2` не меняет final direct controller API contract для публичного
   `handlePointer(...)`. Каноническая трактовка invalid `up/cancel` для direct
   controller entrypoint остаётся задачей шага `11`; host step здесь только
   обязан не потерять terminal lifecycle.

Почему именно так:

1. View boundary должна первой отсекать host invalid data, иначе raw event
   lifecycle, controller semantics и tracker lifecycle снова связываются через
   ad hoc guard-ы.
2. Timer path принадлежит widget-host owner-у, потому что он зависит от
   `mounted`, `dispose`, controller swap и конкретного event loop lifecycle.
3. No-allocation flush primitive нужен не ради микрооптимизации, а чтобы host
   не создавал временную коллекцию в path, где результат заведомо не
   используется.

## Граница шага

- In:
  - `_handlePointerEvent(...)` и связанные host helper-ы;
  - `PointerInputTracker` flush primitive для discard path;
  - mounted-safe timer/listener lifecycle.
- Out:
  - raw-to-slot router owner;
  - value semantics `PointerInputSettings`;
  - controller-side invalid pointer API contract.

## Точная реализация, которую должен описывать код

1. `SceneViewInteractive` разделяет:
   - event admission;
   - routed dispatch;
   - signal tracking;
   - timer reschedule/finalize.
   Эти фазы больше не сливаются в одно неявное тело.
2. Host finite gate срабатывает до вызовов:
   - `widget.controller.handlePointer(...)`;
   - `_pointerTracker.handle(...)`;
   - `_syncPendingFlushTimer(...)`.
3. `_handlePendingTapTimer()` после подшага:
   - не работает, если widget уже unmounted;
   - не reschedule-ит timer после dispose/controller swap;
   - использует discard-friendly flush primitive.
4. `_handleControllerChanged()` после подшага:
   - остаётся owner-ом listener lifecycle и epoch adoption;
   - вызывает settings transition policy, определённую в `10.3`, а не
     дублирует её локально;
   - не мутирует host state после dispose;
   - не делает лишнего reset/resubscribe при stale callback.
5. Для invalid terminal event host делает одно из двух, но не смешивает оба
   пути одновременно:
   - либо локально нормализует событие в безопасный terminal dispatch без
     invalid coordinates;
   - либо вызывает отдельный terminal-reset path, который гарантированно не
     оставляет controller/router/tracker в зависшем состоянии.
   Выбор между этими двумя вариантами должен быть совместим с controller-side
   contract шага `11`, а не вводить третий ad hoc режим.

## Последовательность реализации (только действия)

[ ] Вынести host finite admission в явную раннюю фазу `_handlePointerEvent(...)`.
[ ] Нормализовать terminal cleanup для invalid `up/cancel` без проброса invalid
    coordinates в tracker/controller.
[ ] Исправить timer delay на явный `int`.
[ ] Ввести no-allocation flush primitive в `PointerInputTracker` и перевести на
    него host timer path.
[ ] Зафиксировать `mounted`-guard во всех deferred/listener путях этого owner-а.

## Критерии приёмки

[ ] `SceneViewInteractive` имеет один явный host admission/flush lifecycle и не
    смешивает его с router ownership.
[ ] Invalid `down/move` не вызывают controller/tracker side effects.
[ ] Invalid `up/cancel` не пробрасывают invalid coordinates как есть в
    downstream math, но и не оставляют terminal lifecycle в зависшем состоянии.
[ ] Deferred timer path не создаёт лишнюю коллекцию сигналов, если host её не
    использует.
[ ] Timer/listener callbacks безопасны относительно `mounted` и controller swap.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/core/pointer_input.dart --report-all`
    приложена к результату шага; новые или step-owned host lifecycle methods и
    flush primitive не содержат `HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
    остаётся `10 / 4 / 40`.

## Тестовый контур шага

[ ] `test/view/scene_view_interactive_test.dart`
    с новыми targeted cases для:
    - invalid `down/move` не создают slot, gate и pending timer
    - invalid terminal host events не оставляют stuck gesture / stuck gate;
    - timer safety после dispose/controller swap;
    - deferred flush без лишнего host-side signal materialization
[ ] `test/core/pointer_input_test.dart`
[ ] `dart run tool/check_invariant_coverage.dart` если меняется
    `tool/invariant_registry.dart`
