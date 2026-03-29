language: russian

# Шаг 3. Закрыть boundary-этап через подшаги 3.1-3.4

## Цель шага

Шаги `2` и `2.1` уже подготавливают validated boundary-layer и canonical generated-id semantics. Шаг `3` больше не должен жить как один тяжёлый кусок работы: это umbrella-этап, который закрывает boundary-переход через четыре подшага с разными владельцами ответственности.

Главная цель umbrella-шага: подтянуть enforcement и семантику к публичным входам `snapshot`, `spec`, `patch` и `write-txn`, не создавая второй набор primitive-правил и не смешивая boundary-semantics с задачами шага `4`, который отвечает уже за точный public API contract и release-facing surface.

## Как разбит этап

### Шаг 3.1

`plan/step_03_1_public_snapshot_boundary_on_validated_semantics.md`

Владелец публичной boundary-семантики для:

- `SceneSnapshot`
- `BackgroundLayerSnapshot`
- `ContentLayerSnapshot`
- `NodeSnapshot` и его публичных вариантов
- `TextNodeSnapshot.size`
- canonical non-null `backgroundLayer`

### Шаг 3.2

`plan/step_03_2_public_node_spec_and_patch_boundary_on_validated_semantics.md`

Владелец публичной boundary-семантики для:

- `NodeSpec`
- `NodePatch`
- `CommonNodePatch`
- validation only for present patch fields
- no revision-surface expansion
- no-op copy policy для patch points на публичной границе

### Шаг 3.3

`plan/step_03_3_scene_write_txn_semantics_and_downstream_cleanup.md`

Владелец публичной семантики и cleanup для:

- `SceneWriteTxn`
- `ClearSceneResult`
- `writeSelectionReplace(...)`
- immutability/throws contract
- схлопывания downstream primitive-дублирования в `spec/patch` путях после перевода public boundary на validated semantics

### Шаг 3.4

`plan/step_03_4_collection_payload_ownership_and_allocation_policy.md`

Владелец отдельного follow-up по structural semantics для:

- collection payload ownership на boundary и validated fast-path
- allocation policy для list-like payloads без ослабления immutable contract
- выделения dedicated immutable/owned collection representations там, где это действительно нужно
- снятия локальных no-op allocation trade-off'ов после завершения `3.2` и `3.3`

## Карта переноса деталей из исходного шага 3

1. Подтверждённая сырость публичных `snapshot/spec/patch` constructors разнесена по владельцам:
   - `snapshot`-часть в `3.1`;
   - `spec/patch`-часть в `3.2`.
2. Уже существующая поздняя валидация:
   - `sceneBuildFromSnapshot(...)` закреплена как downstream/runtime owner в `3.1`;
   - `txnNodeFromSpec(...)` и `txnApplyNodePatch(...)` закреплены как downstream owners в `3.2` и cleanup-target в `3.3`.
3. Семантика `TextNodeSnapshot.size` как derived value сохранена в `3.1`.
4. Семантика canonical non-null `backgroundLayer` сохранена в `3.1`.
5. Семантика `writeSelectionReplace([])` как no-op, а не clear, сохранена в `3.3`.
6. Уже существующая immutability discipline для `ClearSceneResult.removedNodeIds`, `selectedNodeIds` и immutable views на boundary сохранена в `3.1` и `3.3`, а не отброшена.
7. Риск лишнего копирования patch points и отсутствие revision-patch surface сохранены в `3.2`.
8. Отдельный follow-up по ownership/allocation policy collection payloads вынесен в `3.4`, чтобы не смешивать validated-boundary adoption с redesign immutable containers.

## Общие правила для всех подшагов

1. `contract/validated/**` из шагов `2` и `2.1` остаётся единственным владельцем boundary-rules.
2. Подшаги `3.1` и `3.2` подключают validated semantics к публичным entry points, но не заводят второй набор primitive-проверок.
3. Подшаг `3.3` владеет удалением или схлопыванием лишней downstream primitive-валидации в `spec/patch` путях после того, как публичная граница уже переведена.
4. Подшаг `3.4` владеет только ownership/allocation semantics для collection payloads и не должен переоткрывать validated rules или write-txn contract.
5. Новые публичные типы сверх validated-layer из шага `2` не вводятся раньше, чем это будет отдельно обосновано в `3.4`; по умолчанию шаг остаётся internal-first и compat-safe.
6. Этот этап закрывает semantics и enforcement публичной boundary; шаг `4` начинается только там, где речь идёт о точном export-surface, release-facing API contract, diagnostics и public-doc alignment.

## Критерии готовности umbrella-шага

1. Для каждого из подшагов `3.1`, `3.2`, `3.3`, `3.4` существует отдельный step-файл с собственной целью, границей ответственности, критериями приёмки и тестовым контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `3.1` отвечает за `snapshot`;
   - `3.2` отвечает за `spec/patch`;
   - `3.3` отвечает за `write-txn` semantics и downstream cleanup;
   - `3.4` отвечает за collection payload ownership/allocation redesign.
3. Граница со шагом `4` остаётся чистой: шаг `3.x` не расширяется до export-surface, release-facing docs и общей public API alignment-задачи.

## Чеклист выполнения

[ ] Переформулировать шаг `3` как umbrella-этап и вынести решение по реализации в `3.1`, `3.2`, `3.3`, `3.4`.
[ ] В каждом подшаге явно сослаться на шаг `2` как на единственный источник boundary-rules.
[ ] Детализировать первым именно `3.1`, потому что `snapshot`-boundary задаёт базовую семантику для последующих `spec/patch` изменений.
[ ] Оставить `3.2`, `3.3` и `3.4` decision-complete, но не смешивать их с задачами шага `4`.
