language: russian

# Шаг 8.4. Довести `SceneControllerCore` до ясного commit pipeline и dispose contract

## Цель шага

После `8.1-8.3` executor уже должен уметь готовить operation result, а writer
должен перестать быть главным owner-ом mutation pipeline. Но пока commit path в
`SceneControllerCore` остаётся смешанным, архитектура шага `8` всё ещё будет
неполной.

Задача подшага: сузить `SceneControllerCore` до явного owner-а store commit,
invariant precheck, spatial prepare/apply и post-commit effects, а также
зафиксировать fail-fast поведение `dispose()` во время активного write.

## Что уже подтверждено по текущему состоянию

1. [scene_controller.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_controller.dart)
   сейчас в `write(...)` сам создаёт `TxnContext` и `SceneWriter`, а затем
   вызывает `_txnWriteCommit(...)`.
2. `_txnWriteCommit(...)` уже содержит две разные ветки:
   - signal/repaint only path без state commit;
   - full state-change path с `resolveNextControllerEpoch(...)`,
     invariant precheck, `SpatialIndexCache.writePrepareCommit(...)`,
     `_applyCommittedStore(...)` и post-commit effects.
3. `dispose()` сейчас не защищён от вызова во время активного `write(...)`:
   метод просто помечает controller disposed и закрывает signal buffer.
4. Invariant precheck уже существует как отдельный safety barrier и должен
   остаться строго перед store apply.

## Рекомендуемое решение

Рекомендуемый вариант: оставить `SceneControllerCore` единственным owner-ом
store commit и post-commit lifecycle, но перевести его с raw `TxnContext` на
prepared result executor-а. Одновременно нужно явно запретить `dispose()` во
время активного write, чтобы controller не входил в half-disposed state.

Почему это лучший вариант:

1. Он сохраняет один owner store lifecycle и не даёт executor-у тихо
   эволюционировать в "второй controller".
2. Он убирает архитектурную двусмысленность: controller больше не должен
   заново решать, какие данные коммитить, если executor уже подготовил
   candidate.
3. Fail-fast `dispose()` проще и надёжнее, чем deferred dispose queue в
   синхронном write API.

Принятое решение по dispose semantics:

1. Если `dispose()` вызывается во время активного `write(...)`, controller
   выбрасывает `StateError`.
2. Такой вызов не должен:
   - частично закрыть signals buffer;
   - отменить уже идущий commit посередине;
   - переводить controller в permanently disposed state.
3. Deferred dispose path в шаге `8` не вводится.

## Граница шага

- In:
  - controller-side commit orchestration поверх executor result;
  - invariant precheck / spatial prepare / store apply ordering;
  - signal-only и repaint-only branch semantics;
  - fail-fast `dispose()` during write.
- Out:
  - redesign public command layer;
  - render-cache contract beyond already existing epoch/spatial wiring;
  - external API changes.

## Точная реализация, которую должен описывать код

1. `SceneControllerCore.write(...)` создаёт один txn/executor context на write и
   коммитит только prepared result после postcheck.
2. Controller commit order остаётся жёстким:
   - txn/executor execution;
   - selection/grid normalization when required;
   - invariant precheck;
   - spatial prepare;
   - store apply;
   - signal commit / emit;
   - repaint / notify scheduling.
3. Signal-only и repaint-only writes сохраняют отдельный fast path, но он
   должен основываться на том же prepared result contract, а не на скрытой
   логике "если случайно ничего не поменяли".
4. `_applyCommittedStore(...)` остаётся единственной точкой записи committed
   runtime state в store.
5. `dispose()` во время `_writeInProgress == true` выбрасывает `StateError` и
   не меняет runtime state controller-а.

## Последовательность реализации (только действия)

[ ] Перевести `SceneControllerCore.write(...)` и `_txnWriteCommit(...)` на
    prepared result executor-а.
[ ] Сохранить invariant precheck строго перед store apply.
[ ] Упростить state-change и signals-only branches без потери atomicity.
[ ] Зафиксировать fail-fast `dispose()` during write и добавить отдельные tests.

## Критерии приёмки

[ ] Controller остаётся единственным owner-ом store commit и post-commit
    lifecycle.
[ ] Commit выполняется только после executor postcheck и invariant precheck.
[ ] Signal/repaint branches не ломают atomicity и не требуют ad hoc условий.
[ ] `dispose()` во время write завершается fail-fast ошибкой и не оставляет
    controller в half-disposed состоянии.

## Тестовый контур шага

[ ] `test/controller/core/scene_controller_commit_atomicity_test.dart`
[ ] `test/controller/core/scene_controller_commit_failures_test.dart`
[ ] `test/controller/core/scene_controller_signals_delivery_test.dart`
[ ] `test/controller/core/scene_controller_writer_lifecycle_test.dart`
[ ] `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
[ ] `test/controller/core/scene_controller_spatial_index_test.dart`
