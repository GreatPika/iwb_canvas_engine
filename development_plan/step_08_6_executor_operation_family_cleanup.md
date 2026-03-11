language: russian

# Шаг 8.6. Довести `MutationExecutor` до operation-family hot path без пустого postcheck

## Цель шага

После `8.1-8.4` executor уже является правильным owner-ом operation lifecycle,
но его hot path всё ещё держит слишком много ветвления в одном месте. Это
означает, что архитектурный drift убран лишь частично: ответственность уже в
нужном owner-е, но финальная форма кода всё ещё неустойчива.

Задача подшага: довести `MutationExecutor` до устойчивой operation-family
структуры, убрать формальный postcheck, который не несёт реальной проверки, и
сделать bulk delete понятным двухфазным маршрутом без смешения discovery,
apply и bookkeeping в одном методе.

## Что уже подтверждено по текущему состоянию

1. [mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart)
   сейчас содержит следующие watchpoints:
   - `_apply(...)`: `cyclomatic-complexity = 14`
   - `_runPostcheck(...)`: `cyclomatic-complexity = 15`
   - `_deleteNodesBulk(...)`: `cyclomatic-complexity = 12`,
     `source-lines-of-code = 42`
2. `_runPostcheck(...)` перечисляет почти все operation types, но в текущем
   виде по сути лишь повторно вызывает `ctx.txnEnsureActive()` для changed path.
3. `_deleteNodesBulk(...)` сейчас смешивает:
   - поиск удаляемых id;
   - подготовку mutable layers;
   - low-level erase;
   - cleanup selection;
   - `ChangeSet` bookkeeping.
4. `MutationOp` уже является data-only контрактом и не должен превращаться в
   поведенческий visitor/command framework.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `MutationOp` остаётся data-only sealed contract. Поведение не переносится в
   op-классы и не оформляется через visitor/virtual dispatch.
2. Closure строится через operation families внутри executor-а для всего
   lifecycle `preconditions -> apply -> postcheck`. Минимально
   допустимые family owner-ы:
   - structural/document ops;
   - node mutation ops;
   - scene settings ops;
   - selection transform ops.
3. Postcheck сохраняется только там, где есть реальный post-apply invariant.
   Если общий postcheck не делает ничего кроме "проверить active", он должен
   быть удалён или схлопнут в более точный contract.
   Selection/grid normalization, store invariants и spatial preparation не
   переезжают в executor в рамках этого шага.
4. Bulk delete становится двухфазным маршрутом:
   - phase 1: resolve deletable ids и подготовить mutable targets;
   - phase 2: выполнить low-level erase один раз и затем один раз завершить
     selection / `ChangeSet` bookkeeping.
   На low-level erase передаётся уже отфильтрованный набор deletable ids, а не
   исходный входной `nodeIds`, чтобы decomposition не сохраняла скрытую двойную
   работу.
5. Нельзя добавлять snapshot diff, второй `ChangeSet`, или derived commit
   model только ради closure метрик.
6. Любые новые helper-ы остаются narrow и executor-local. Новый внешний
   orchestration owner не вводится.

## Граница шага

- In:
  - decomposition `MutationExecutor` по operation families;
  - cleanup postcheck contract;
  - bulk delete hot path;
  - закрытие executor watchpoints umbrella-шага `8`.
- Out:
  - selection-only methods `SceneWriter`;
  - command-layer step `9`;
  - controller commit lifecycle step `8.5`;
  - redesign internal op contract beyond data-only form;
  - redesign low-level delete algorithms в `document.dart` beyond
    executor-owned prepare/finalize contract.

## Точная реализация, которую должен описывать код

1. `execute(...)` остаётся единственной public/internal entrypoint executor-а.
2. Giant `_apply(...)` больше не остаётся единственной точкой для всех op
   family dispatch decisions. Либо он исчезает, либо становится thin router к
   family-specific handlers.
3. `_runPreconditions(...)` не остаётся отдельным будущим giant dispatcher:
   family decomposition покрывает и precondition stage тоже.
4. Общий `_runPostcheck(...)` либо исчезает, либо сужается до тех op families,
   у которых действительно есть post-apply contract.
5. Bulk delete должен иметь явный prepare/apply/finalize pipeline без
   повторного сканирования тех же данных на каждом этапе, если этого можно
   избежать.
6. `document.dart` остаётся owner-ом low-level erase semantics, `TxnContext`
   остаётся owner-ом mutable runtime state, а executor завершает selection и
   `ChangeSet` bookkeeping. Ownership не размазывается между helper-ами.
7. Family decomposition должна быть смысловой, а не случайной нарезкой "по 20
   строк". Если какой-то helper не выражает устойчивую группу операций, его
   вводить не нужно.

## Последовательность реализации (только действия)

[ ] Разбить executor routing на устойчивые operation families без переноса
    поведения в `MutationOp`.
[ ] Удалить или резко сузить `_runPostcheck(...)`, оставив postcheck только
    там, где он реально защищает invariant или contract.
[ ] Перевести `_runPreconditions(...)` на тот же family-based routing, чтобы
    рост operation set не перенёс giant dispatcher из `_apply(...)` в другой
    lifecycle hook.
[ ] Вынести bulk delete prepare phase в отдельный narrow helper/value object,
    чтобы `_deleteNodesBulk(...)` перестал смешивать discovery и finalize.
[ ] Передавать в low-level erase уже отфильтрованный deletable id set, а не
    исходный входной набор.
[ ] Сохранить один low-level erase call для bulk delete и один finalize pass по
    selection / `ChangeSet`.
[ ] Перепроверить node/transform/settings routes, чтобы decomposition не
    добавила повторные scene/node lookups и лишние копии.
[ ] Повторно снять диагностические метрики по executor watchpoint-owner-ам и
    зафиксировать, что прежние giant методы либо упрощены, либо исчезли.

## Критерии приёмки

[ ] `MutationExecutor` остаётся единственным owner-ом operation orchestration.
[ ] В коде не остаётся формального postcheck switch-а, который не выполняет
    реальной post-apply проверки.
[ ] В коде не появляется новый giant dispatcher в `_runPreconditions(...)`.
[ ] Bulk delete выражен как явный двухфазный hot path без смешения discovery,
    erase и bookkeeping в одном giant method body.
[ ] Bulk delete decomposition не сохраняет скрытую двойную работу через
    повторную передачу неотфильтрованного набора в low-level erase path.
[ ] Family decomposition не создаёт новый visitor/framework и не ухудшает
    runtime cost лишними проходами или копиями.
[ ] Для executor watchpoint зоны шага `8` не остаётся необъяснённых
    превышений, которые просто переехали в новые helper-ы без смены ownership.

## Тестовый контур шага

[ ] `test/controller/internal/mutation_executor_test.dart`
[ ] `test/controller/internal/scene_writer_test.dart`
[ ] `test/controller/internal/spatial_index_cache_test.dart`
[ ] Точечные сценарии:
    - bulk delete удаляет только deletable content nodes
    - no-op routes не трогают `ChangeSet`
    - decomposition не меняет transform/delete semantics
