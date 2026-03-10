language: russian

# Шаг 7.2. Перевести store/txn/document на stateful id allocation без scene-scan

## Цель шага

После `7.1` generated-id contract должен уже иметь одного owner-а, но runtime
путь всё ещё останется небезопасным, если store и transaction layer продолжат
выводить "следующий id" из scene-scan или из простого `int seed`, который
переинициализируется по данным сцены.

Задача подшага: перенести `SceneStore`, `TxnContext` и связанные document
helpers на stateful id allocation, где текущее состояние генератора живёт в
runtime owner-е, а не вычисляется повторно по уже существующим id в сцене.

## Что уже подтверждено по текущему состоянию

1. [store.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/store.dart)
   сейчас хранит `nodeIdSeed` и `layerIdSeed`.
2. [txn_context.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/txn_context.dart)
   реализует `txnNextNodeId()` и `txnNextLayerId()` через цикл
   `generate* -> seed++ -> collision check`.
3. [document_clone.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/document_clone.dart)
   сейчас вычисляет `txnInitialNodeIdSeed(...)` и `txnInitialLayerIdSeed(...)`
   через scene-scan и разбор generated ids.
4. [scene_invariants.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_invariants.dart)
   проверяет именно monotonic lower bound для `nodeIdSeed` / `layerIdSeed`, то
   есть текущий invariant зашит в старую seed-модель.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Runtime allocator state становится частью store/txn state и не
   восстанавливается как основной механизм по id, найденным в сцене.
2. Collision check по live scene остаётся обязательным как защитный invariant,
   но перестаёт быть owner-ом стратегии генерации.
3. `document_clone.dart` после шага не отвечает за вычисление будущих runtime
   generated ids по данным сцены.
4. Подшаг не возвращает старый generated-id parsing даже как "временный"
   fallback path.
5. Store и txn path переходят на один конкретный state shape:
   - `IdGeneratorState.sessionToken`
   - `IdGeneratorState.nextNodeCounter`
   - `IdGeneratorState.nextLayerCounter`
6. `SceneStore` создаёт этот state один раз при bootstrap и дальше хранит его
   как runtime source of truth.
7. `TxnContext` получает mutable копию `IdGeneratorState` на старте write и
   коммитит её обратно в store только после успешного commit.
8. `txnAdoptScene(...)` не пересчитывает allocator state по сцене и не
   меняет `sessionToken`; adopt меняет только scene-owned runtime data.

## Граница шага

- In:
  - store/txn allocator state;
  - переписывание `txnNextNodeId()` и `txnNextLayerId()`;
  - commit/adopt/replaceScene propagation allocator state;
  - cleanup `document_clone.dart` от generated-id scene-scan.
- Out:
  - public generated-id contract;
  - revision/epoch policy;
  - render caches.

## Точная реализация, которую должен описывать код

1. Удаляются функции:
   - `txnInitialNodeIdSeed(...)`
   - `txnInitialLayerIdSeed(...)`
2. Сохраняются функции:
   - `txnCollectNodeIds(...)`
   - `txnCollectLayerIds(...)`
   Они нужны для invariants и structural bookkeeping, но больше не участвуют в
   расчёте future generated ids.
3. `SceneStore` вместо `nodeIdSeed` / `layerIdSeed` хранит
   `IdGeneratorState idGeneratorState`.
4. `TxnContext` вместо `nodeIdSeed` / `layerIdSeed` хранит
   `IdGeneratorState idGeneratorState` и вызывает allocator helper-ы из
   `id_generator.dart`.
5. Аллокация нового id работает так:
   - собрать candidate через owner helper в `id_generator.dart`, используя
     `sessionToken + next*Counter` как allocator state;
   - увеличить соответствующий counter в state;
   - если candidate уже занят explicit/runtime id в live scene, повторить цикл;
   - collision loop считается guardrail, а не owner-логикой.
6. `writeDocumentReplace(...)` и `txnAdoptScene(...)` сохраняют allocator state
   verbatim. Новый external scene не может переопределить внутренний allocator
   state своими id.
7. Bootstrap нового контроллера из `initialSnapshot` создаёт новый
   `sessionToken` и counters `1/1`; он не сканирует snapshot и не пытается
   восстановить старый allocator session.
8. `scene_invariants.dart` больше не проверяет lower-bound against scene для
   generated ids. Вместо этого он проверяет:
   - `IdGeneratorState.sessionToken` non-empty;
   - `nextNodeCounter >= 1`;
   - `nextLayerCounter >= 1`;
   - `allNodeIds` / `nodeLocator` остаются синхронны committed scene.

Почему именно так:

1. Если allocator state живёт в store, а не выводится из scene, исчезает
   главный drift: future generation больше не зависит от уже сохранённой формы
   id-строк.
2. Mutable `IdGeneratorState` подходит текущей архитектуре `TxnContext` лучше,
   чем новый immutable orchestration layer: код уже работает через mutable
   txn-state и commit/apply phase.
3. Сохранять `sessionToken` при adopt/replace важно, потому что replaceScene
   меняет документ, но не должен переопределять внутренний runtime allocator.
4. Новый controller bootstrap обязан создавать новый namespace, иначе он снова
   станет зависимым от того, какие id пришли из внешнего snapshot.
5. Collision retry оставляем, потому что public explicit ids всё ещё могут
   совпасть с internal generated ids. Но это именно защитный барьер, а не
   основная стратегия.

## Последовательность реализации (только действия)

[x] Заменить `nodeIdSeed` / `layerIdSeed` в `SceneStore` на
    `IdGeneratorState idGeneratorState`, owned by new `id_generator.dart`.
[x] Переписать `TxnContext.txnNextNodeId()` и `TxnContext.txnNextLayerId()` на
    allocator helper-ы из `id_generator.dart`, работающие через
    `sessionToken + counter`.
[x] Обновить adopt/commit/replaceScene lifecycle так, чтобы allocator state
    переносился явно и не переизобретался через scene-scan на hot path.
[x] Удалить из `document_clone.dart` `txnInitialNodeIdSeed(...)` и
    `txnInitialLayerIdSeed(...)`, оставив только structural collect/clone
    helpers.
[x] Переписать store invariants и tests на новый `IdGeneratorState` contract.

## Критерии приёмки

[x] `TxnContext` выдаёт новые `NodeId` / `LayerId` через stateful allocator, а
    не через старый seed-цикл.
[x] `SceneStore` хранит `IdGeneratorState` как runtime source of truth.
[x] `document_clone.dart` больше не сканирует сцену ради расчёта будущих
    generated ids.
[x] Collision protection на committed scene сохраняется, но не подменяет собой
    owner-а generation policy.
[x] Invariants и tests описывают уже новый `sessionToken + counter` contract, а
    не старую lower-bound seed-модель и не конкретный строковый шаблон id.

## Тестовый контур шага

[x] `test/controller/internal/change_set_txn_context_test.dart`
[x] `test/controller/internal/scene_writer_test.dart`
[x] `test/controller/scene_invariants_test.dart`
[x] `test/controller/core/scene_controller_copy_on_write_test.dart`
[x] `test/model/document_clone_test.dart`
[x] Новый targeted test на bootstrap/adopt semantics для `IdGeneratorState`
