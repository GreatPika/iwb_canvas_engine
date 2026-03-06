language: russian

# Шаг 3.3. Зафиксировать SceneWriteTxn semantics и убрать downstream primitive-дублирование

## Цель шага

После шагов `3.1` и `3.2` публичная boundary уже должна валидировать `snapshot`, `spec` и `patch` на входе. Задача этого шага: закрепить точную публичную семантику `SceneWriteTxn` и убрать лишнюю downstream primitive-валидацию в `spec/patch` runtime paths, чтобы после завершения boundary-этапа в проекте остался один владелец primitive-rules и один согласованный контракт write-транзакций.

Этот шаг не добавляет новый функционал в `SceneWriteTxn`. Он фиксирует уже существующее поведение, чистит дублирование и подготавливает чистую передачу в шаг `4`, где дальше выравнивается уже public API contract и diagnostics.

## Что этот шаг считает своим владельцем

1. Публичную семантику:
   - `SceneWriteTxn`
   - `ClearSceneResult`
   - `writeSelectionReplace(...)`
   - immutability snapshots, которые возвращаются наружу
   - documented throws contract
2. Cleanup:
   - удаление или схлопывание независимой primitive-валидации в downstream `spec/patch` путях после перевода public boundary на validated semantics
3. Границу:
   - без изменения public `NodeSpec`/`NodePatch` surface сверх решений шага `3.2`
   - без задач шага `4` по barrel/export/docs alignment

## Что уже подтверждено по текущему состоянию

1. `writeSelectionReplace(...)` сейчас фактически работает как no-op для пустого или полностью отфильтрованного набора ids, а не как clear.
2. `ClearSceneResult.removedNodeIds` уже копируется в immutable snapshot.
3. `selectedNodeIds` в транзакции уже выдаётся наружу как immutable view.
4. `snapshot/spec`-контракты уже выдают immutable views для коллекций, поэтому задача шага не в "изобретении immutability с нуля", а в точной контрактной фиксации и покрытии тестами там, где это уже считается публичным поведением.
5. Поздняя primitive-валидация для `NodeSpec`/`NodePatch` всё ещё живёт в downstream runtime/model paths, потому что до завершения шага `3.2` она нужна как фактическая boundary-защита.
6. После завершения `3.1` и `3.2` часть этой downstream primitive-валидации станет дублированием и должна быть либо удалена, либо сведена к вызову того же validated owner.

## Рекомендуемое решение

Рекомендуемый вариант: сначала зафиксировать точные `SceneWriteTxn` semantics как публичный контракт, затем схлопнуть downstream primitive-дублирование в `spec/patch` путях, оставив внутри только scene-level invariants, canonicalization и runtime-specific checks.

Что это означает на практике:

1. `writeSelectionReplace(...)` официально остаётся no-op при пустом/невалидном после normalization наборе ids; явное очищение selection остаётся обязанностью `writeSelectionClear()`.
2. Публичные возвращаемые структуры и снапшоты транзакции фиксируются как immutable contract, а не как случайная реализация.
3. `throws`-контракты `SceneWriteTxn` описываются точно:
   - `StateError` после завершения txn;
   - `ArgumentError`/`RangeError` только там, где они реально возможны;
   - без расплывчатых формулировок.
4. Downstream runtime/model paths перестают быть вторым владельцем primitive-rules после того, как public boundary уже валидирует те же данные.

## Что именно менять

### `lib/src/contract/scene_write_txn.dart`

[ ] Явно закрепить `writeSelectionReplace(...)` как no-op, а не clear, для пустого или полностью отфильтрованного набора ids.
[ ] Зафиксировать immutable semantics для `ClearSceneResult.removedNodeIds`, `selectedNodeIds` и других публично возвращаемых коллекций, если они входят в transaction contract.
[ ] Описать точные `throws`-контракты публичных методов без расплывчатых формулировок.
[ ] Не менять поведение ради документации, если текущая реализация уже корректна; при подтверждённой корректности ограничиться фиксацией contract + test.

### Downstream `spec/patch` cleanup

[ ] После завершения `3.1` и `3.2` инвентаризировать, какие primitive-checks в `txnNodeFromSpec(...)`, `txnApplyNodePatch(...)`, `sceneValidateNodeSpecValues(...)`, `sceneValidateNodePatchValues(...)` и соседних путях стали дублированием.
[ ] Удалить или свести эти проверки к вызову того же validated owner из шага `2`, не оставляя независимую копию правил.
[ ] Оставить внутри только:
   - scene-level invariants;
   - canonicalization;
   - runtime-specific checks;
   - поведение, завязанное на уже существующее состояние документа.

### Граница с соседними шагами

[ ] Не переносить сюда перевод `snapshot`-boundary; это владелец шага `3.1`.
[ ] Не переносить сюда перевод public `NodeSpec`/`NodePatch`; это владелец шага `3.2`.
[ ] Не переносить сюда barrel/export-surface и общий public API alignment; это владелец шага `4`.

## Конкретизация внедрения по порядку

1. Сначала зафиксировать контракт `SceneWriteTxn` в точках, где поведение уже подтверждено кодом.
2. Затем добавить тесты на `writeSelectionReplace(...)`, immutability и documented throws.
3. После этого инвентаризировать downstream primitive-checks, которые больше не нужны после `3.1` и `3.2`.
4. Удалить или схлопнуть только подтверждённые дубли, не трогая scene-level/runtime-specific validation.
5. Завершить шаг только когда public write semantics и downstream ownership of rules перестанут расходиться.

## Критерии приемки

[ ] `writeSelectionReplace(...)` имеет один явный контракт и совпадает с реализацией и тестами.
[ ] `SceneWriteTxn` не получает новый функционал, а лишь фиксирует точную семантику уже существующего поведения.
[ ] Публичные возвращаемые структуры транзакции не отдают наружу изменяемые внутренние коллекции.
[ ] Уже существующая immutability discipline не теряется при cleanup: шаг фиксирует её как контракт и не ослабляет возвращаемые snapshot/view semantics.
[ ] `throws`-контракты `SceneWriteTxn` совпадают с фактическим поведением реализации.
[ ] После завершения cleanup downstream `spec/patch` paths больше не владеют собственной независимой primitive boundary-валидацией.
[ ] В runtime/model остаются только scene-level invariants, canonicalization и runtime-specific checks.
[ ] Граница со шагом `4` остаётся чистой: этот шаг не расширяется в public API alignment, export-surface и diagnostics beyond write contract.

## Тестовый контур

[ ] Добавить тесты на `writeSelectionReplace([])` как no-op.
[ ] Добавить тесты на immutable `removedNodeIds` и `selectedNodeIds`.
[ ] Добавить тесты на точные `StateError`/`ArgumentError`/`RangeError` сценарии там, где они реально задокументированы.
[ ] Добавить regression-тесты на отсутствие поведения, завязанного на удалённую downstream primitive-дубликацию.
[ ] Убедиться, что после cleanup scene-level/runtime-specific checks продолжают ловить свои сценарии и не деградируют.
