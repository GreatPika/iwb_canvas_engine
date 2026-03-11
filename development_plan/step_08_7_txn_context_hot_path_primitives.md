language: russian

# Шаг 8.7. Упростить `TxnContext` hot primitives без второго runtime cache

## Цель шага

После `8.2` `TxnContext` уже стал правильным owner-ом runtime-owned state и
copy-on-write primitives, но в hot path всё ещё остались branch-heavy helper-ы,
которые усложняют executor/controller pipeline и затрудняют дальнейшую
эволюцию write-core.

Задача подшага: упростить mutable layer/node resolution primitives в
`TxnContext`, убрать хрупкий layer-index bookkeeping там, где он больше не
нужен, и переиспользовать существующие locator-based helpers вместо
дублированного base-node resolve logic.

## Что уже подтверждено по текущему состоянию

1. [txn_context.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/txn_context.dart)
   сейчас содержит следующие watchpoints:
   - `txnEnsureContentLayer(...)`: `cyclomatic-complexity = 12`
   - `txnResolveMutableNode(...)`: `source-lines-of-code = 44`
   - `_txnBaseNodeById(...)`: `cyclomatic-complexity = 12`
2. `txnEnsureContentLayer(...)` после вставки слоя вручную сдвигает:
   - layer indexes в `nodeLocator`;
   - bookkeeping по cloned layers.
3. `txnResolveMutableNode(...)` повторяет несколько стадий:
   - resolve node;
   - ensure mutable container;
   - re-resolve node;
   - compare against base node;
   - clone mutable node.
4. `_txnBaseNodeById(...)` дублирует locator-based lookup отдельно для
   background layer и content layers, хотя в проекте уже есть общий
   `txnFindNodeByLocator(...)`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `TxnContext` остаётся единственным owner-ом runtime-owned state, copy-on-
   write layer/node ownership и commit-facing views.
2. Второй locator cache, второй layer-index cache или любой новый derived
   runtime snapshot не вводится.
3. Для cloned-layer bookkeeping предпочтительна identity, которая не требует
   сдвигать индексы после вставки слоя. Рекомендуемое решение: перейти с
   tracking по `layerIndex` на tracking по `LayerId`, сохраняя invariant
   уникальности content-layer ids внутри scene.
4. Locator shift после layer insert должен остаться явным и single-purpose, но
   low-level mutation map-entries должна жить рядом с существующими
   scene/locator helpers, а не как большой inline loop внутри `TxnContext`.
5. Base-node resolve должен переиспользовать существующий locator-based helper
   или один общий private primitive. Дублирование background/content веток в
   отдельном большом методе не считается финальной формой.
6. Упрощение не должно приводить к extra scene scans, повторным
   materialization или потере copy-on-write contract.
7. Для `txnResolveMutableNode(...)` недостаточно убрать только base-node
   lookup. Шаг должен ввести узкий helper для mutable slot/container
   preparation, иначе giant helper легко сохранится под другим именем.

## Граница шага

- In:
  - `TxnContext` layer/node hot primitives;
  - cloned-layer bookkeeping cleanup;
  - reuse locator-based node resolution;
  - закрытие `TxnContext` watchpoints umbrella-шага `8`.
- Out:
  - новый ownership для runtime state;
  - public API changes;
  - command-layer logic;
  - commit/controller concerns outside `TxnContext`.

## Точная реализация, которую должен описывать код

1. Tracking cloned content layers больше не требует ручного shift по layer
   indexes при вставке нового content layer.
2. `txnEnsureContentLayer(...)` остаётся owner-ом решения "когда вставить
   слой", но перестаёт держать лишний bookkeeping noise, который можно убрать
   через более устойчивую identity или narrow helper.
3. `_txnBaseNodeById(...)` либо исчезает, либо схлопывается до reuse общего
   locator-based lookup helper-а вместо ручного дублирования background/content
   веток.
4. `txnResolveMutableNode(...)` раскладывается на понятные стадии mutable
   container/slot preparation и node clone decision, без повторения одной и той
   же логики внутри большого метода.
5. После шага `TxnContext` не строит новые derived structures сверх уже
   существующих `_baseNodeLocator`, `_materializedNodeLocator` и layer-id
   index map.

## Последовательность реализации (только действия)

[x] Перевести cloned-layer bookkeeping на identity, которая не требует
    последующего index shift после вставки слоя.
[x] Вынести locator shift после layer insert в narrow helper рядом с
    scene/locator primitives или переиспользовать уже существующий helper, если
    он покрывает нужную семантику.
[x] Схлопнуть `_txnBaseNodeById(...)` до reuse locator-based lookup logic.
[x] Разделить `txnResolveMutableNode(...)` на узкие стадии подготовки mutable
    container/slot и clone decision без изменения COW semantics.
[x] Явно зафиксировать или переиспользовать invariant уникальности content
    layer ids там, где cloned-layer bookkeeping переводится на `LayerId`.
[x] Повторно снять диагностические метрики по `TxnContext` watchpoint-owner-ам
    и убедиться, что сложность исчезла по ownership, а не просто сменила имя.

## Критерии приёмки

[x] `TxnContext` остаётся единственным owner-ом runtime mutable state и COW
    semantics.
[x] В коде не появляется второй runtime cache или новый derived snapshot.
[x] Tracking cloned layers больше не требует шумного index-shift bookkeeping.
[x] Base-node resolve использует один locator-based path вместо дублированных
    background/content веток.
[x] Для `TxnContext` watchpoint зоны шага `8` не остаётся giant helper-ов,
    которые продолжают смешивать разные стадии mutable resolution.

## Тестовый контур шага

[x] `test/controller/internal/change_set_txn_context_test.dart`
[x] `test/controller/internal/mutation_executor_test.dart`
[x] `test/controller/internal/scene_writer_test.dart`
[x] Точечные сценарии:
    - layer insert перед существующими слоями не ломает locator mapping
    - mutable node resolve сохраняет copy-on-write semantics
    - background/content node lookup остаётся семантически эквивалентным

## Итоговые метрики

1. Повторная диагностика `dcm calculate-metrics lib/src/controller/txn_context.dart --report-all`
   показывает:
   - `TxnContext.txnEnsureContentLayer(...)`:
     `cyclomatic-complexity = 6`, `source-lines-of-code = 18`
   - `TxnContext.txnResolveMutableNode(...)`:
     `cyclomatic-complexity = 1`, `source-lines-of-code = 3`
   - `TxnContext.txnFindContentLayerIndexById(...)`:
     `cyclomatic-complexity = 3`, `source-lines-of-code = 13`
   - `TxnContext._txnBaseNodeById(...)`:
     `cyclomatic-complexity = 2`, `source-lines-of-code = 5`
   - узкие helper-ы закрывают прежний giant owner без переноса сложности:
     - `TxnContext._txnPrepareMutableNodeSlot(...)`:
       `cyclomatic-complexity = 5`, `source-lines-of-code = 17`
     - `TxnContext._txnCloneResolvedNodeIfNeeded(...)`:
       `cyclomatic-complexity = 6`, `source-lines-of-code = 28`
2. Cloned content-layer bookkeeping теперь держится на `LayerId`, поэтому
   вставка нового content layer больше не требует ручного shift для tracking
   cloned layers.
3. Locator shift после layer insert переиспользует отдельный
   `txnShiftNodeLocatorLayersFrom(...)` рядом с existing scene/locator
   primitives, а `_txnBaseNodeById(...)` больше не дублирует
   background/content resolve logic.
