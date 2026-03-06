language: russian

# Шаг 3.4. Выровнять ownership и allocation policy для collection payloads

## Цель шага

После шагов `3.2` и `3.3` public boundary для `snapshot/spec/patch` уже должна иметь один понятный validating owner, а downstream `write-txn` paths должны быть очищены от лишней primitive-дубликации. Задача этого шага: отдельно разобрать collection payloads, чтобы не держать долгосрочный конфликт между immutable ownership semantics и желанием убрать лишние allocations в no-op/change paths.

Шаг нужен потому, что после `3.2` сознательно закреплён контракт `owned immutable snapshot` для collection payloads на boundary, а локальная оптимизация через ослабление `PatchField<List<...>>` semantics признана неправильным направлением. Значит, дальнейшая работа должна идти не через специальные исключения в `NodePatch`, а через отдельный structural redesign.

## Что этот шаг считает своим владельцем

1. Ownership semantics для collection payloads на:
   - public `snapshot/spec/patch` boundary;
   - validated fast-path helpers;
   - runtime write/application paths, где payload может materialize/copy.
2. Allocation policy для list-like payloads:
   - где snapshot обязателен;
   - где допустимо reuse;
   - где no-op/change path можно оптимизировать без ослабления immutable contract.
3. Выделение dedicated immutable/owned collection representations, если без них нельзя одновременно сохранить compat, ownership и performance.

## Что уже подтверждено по текущему состоянию

1. После шага `3.2` collection payloads на public boundary закреплены как owned immutable snapshots.
2. Для `StrokeNodePatch.points` локальная no-op optimization через deferred-copy конфликтует с этим контрактом и поэтому сознательно не была принята в `3.2`.
3. `txnApplyNodePatch(...)` не алиасит внешний список точек в live `StrokeNode`, потому что runtime path копирует значения во внутренний `_RevisionedOffsetList`.
4. Internal fast-path helpers тоже должны сохранять ownership contract, иначе возникнет вторая семантика только для already-validated data.
5. Если optimization действительно нужна, текущей формы `PatchField<List<T>>` недостаточно: container выражает tri-state semantics, но не ownership/allocation policy.

## Рекомендуемое решение

Рекомендуемый вариант: сначала выделить один structural owner для collection payloads, а уже затем оптимизировать allocations. Не пытаться решать это специальными ветками внутри `NodePatch`, `NodeSpec` или runtime apply helpers.

Что это означает на практике:

1. Ownership и tri-state semantics должны быть разведены:
   - `PatchField` продолжает отвечать только за absent/value/null;
   - collection value получает свой отдельный immutable/owned contract.
2. Public boundary, validated fast-path и runtime path должны работать с одной моделью collection payload ownership, а не с тремя похожими, но разными правилами.
3. No-op/change-path optimization допускается только после того, как у list-like payloads появится representation, которое можно безопасно сравнивать и переиспользовать без потери immutable guarantees.

## Что именно менять

### Ownership model

[ ] Инвентаризировать все collection payloads на boundary, а не только `StrokeNodePatch.points`.
[ ] Подтвердить, какие из них реально нуждаются в dedicated immutable/owned representation, а какие уже достаточно безопасны и не создают allocation pressure.
[ ] Выбрать одну ownership-модель, одинаковую для public constructors, validated fast-path helpers и runtime apply paths.

### Dedicated collection representations

[ ] Если без этого нельзя одновременно сохранить immutable contract и убрать лишние allocations, ввести dedicated immutable/owned collection representations для list-like payloads.
[ ] Не вводить такой type точечно только для одного call-site; owner должен быть reusable и объяснимым.
[ ] По умолчанию оставлять решение internal-first; публичное раскрытие нового type допустимо только если без него нельзя удержать один честный контракт.

### Runtime/application policy

[ ] После выбора ownership-model определить, где copy обязателен всегда, а где допустим safe reuse.
[ ] Отдельно описать no-op/change-path policy для patch application, чтобы оптимизация не зависела от неявных свойств `List` или случайной unmodifiable-обёртки.
[ ] Не смешивать эту работу с primitive validation, `SceneWriteTxn` contract или export-surface alignment.

## Граница с соседними шагами

[ ] Не переоткрывать validated boundary-rules из шагов `2`, `3.1` и `3.2`.
[ ] Не смешивать шаг с cleanup write-txn semantics из `3.3`.
[ ] Не расширять шаг до общего public API alignment шага `4`, если только dedicated collection type не окажется неизбежно публичным.

## Конкретизация внедрения по порядку

1. Сначала завершить `3.3`, чтобы у write/runtime paths остался один владелец primitive-rules и один понятный apply contract.
2. Затем инвентаризировать collection payloads и их текущие ownership/allocation paths.
3. После этого выбрать один dedicated owner для immutable/owned collection semantics.
4. И только потом решать конкретные no-op/change-path optimizations поверх уже выбранного representation.

## Критерии приемки

[ ] Для collection payloads существует один понятный ownership contract, одинаковый на public boundary, validated fast-path и runtime paths.
[ ] Optimization no-op/change paths больше не требует ослаблять immutable semantics `NodePatch`/`NodeSpec`/`Snapshot`.
[ ] `PatchField` не получает скрытых обязанностей по ownership/allocation policy.
[ ] Решение не размазывает special-case logic по нескольким владельцам и не требует новых sync glue paths.

## Тестовый контур

[ ] Добавить regression-тесты на ownership/immutability для collection payloads в public boundary и validated fast-path.
[ ] Добавить regression-тесты на apply-path reuse/copy policy в no-op и changed scenarios после выбора representation.
[ ] Убедиться, что runtime state не начинает алиасить внешние mutable collections.
