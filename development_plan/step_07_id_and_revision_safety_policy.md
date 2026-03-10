language: russian

# Шаг 7. Ввести безопасную политику id и revision через подшаги 7.1-7.4

## Цель шага

После шагов `3.x-6.x` boundary и scene-policy уже достаточно выровнены, чтобы
закрыть следующий системный drift: runtime всё ещё опирается на три разные
хрупкие стратегии идентичности и версионирования одновременно:

- `nodeIdSeed` / `layerIdSeed` как простые `int`;
- scene-scan через `txnInitial*Seed(...)` и разбор сгенерированных id;
- `instanceRevision` и `controllerEpoch` как два связанных, но формально не
  объединённых механизма invalidation.

Этот umbrella-шаг нужен, чтобы не смешивать в одном документе сразу четыре
разные темы:

- новый contract generated id и owner генератора;
- перенос store/txn/runtime paths на stateful allocation без scene-scan;
- безопасную revision policy с `(epoch, revision)` и overflow semantics;
- render-cache invalidation contract поверх новой revision policy.

Дополнительное решение для этого этапа уже принято: старый generated-id
contract удаляется и не сохраняется как режим совместимости. Шаг `7` должен
закрыть это явно, а не оставлять параллельные ветки "на всякий случай".

## Как разбит этап

### Шаг 7.1

`development_plan/step_07_1_generated_id_contract_and_generator_owner.md`

Владелец решения по:

- судьбе public/generated-id contract;
- роли `lib/src/core/id_generator.dart` как единственного owner-а runtime
  generated ids;
- отказу от legacy generated-id semantics как обязательной совместимости;
- явной границе между public explicit id values и internal generated ids.

### Шаг 7.2

`development_plan/step_07_2_stateful_id_allocation_in_store_txn_and_document.md`

Владелец переноса stateful id allocation для:

- `lib/src/controller/store.dart`;
- `lib/src/controller/txn_context.dart`;
- `lib/src/model/document_clone.dart`;
- commit/adopt/replaceScene lifecycle без повторного scene-scan по id.

### Шаг 7.3

`development_plan/step_07_3_revision_policy_and_epoch_contract.md`

Владелец revision contract для:

- `lib/src/core/revision_policy.dart`;
- `txnNextInstanceRevision()` и store revision state;
- `SceneBuilder` / snapshot import allocation;
- overflow semantics и связи между `instanceRevision` и `controllerEpoch`.

### Шаг 7.4

`development_plan/step_07_4_render_cache_revision_contract.md`

Владелец render invalidation contract для:

- `lib/src/render/cache/**`;
- `lib/src/render/render_geometry_cache.dart`;
- `lib/src/view/**` epoch-driven cache lifecycle;
- явного решения, где достаточно owner-side `clearAll()`, а где ключ обязан
  включать composite revision identity.

## Карта переноса деталей из исходного шага 7

1. Создание `lib/src/core/id_generator.dart`, судьба generated-id format и
   breaking cleanup public helper-ов переносится в `7.1`.
2. Переписывание `txnNextNodeId()`, `txnNextLayerId()`, store state и
   отказ `document_clone.dart` от scene-scan по generated ids переносится в
   `7.2`.
3. Создание `lib/src/core/revision_policy.dart`, переписывание
   `txnNextInstanceRevision()`, safe range/overflow semantics и wiring в
   `SceneBuilder`/store переносится в `7.3`.
4. Выравнивание render-cache keys и epoch invalidation переносится в `7.4`.

## Уже принятые архитектурные решения

1. Internal generated ids остаются opaque runtime representation:
   - string-compatible;
   - уникальны в пределах allocator session;
   - не парсятся вне `id_generator.dart`;
   - не используются для восстановления allocator state.
2. Public surface после `7.1` сохраняет только explicit-id validation helper-ы;
   generated-id helper-ы удаляются.
3. Store/txn owner для id allocation:
   - `IdGeneratorState.sessionToken`
   - `IdGeneratorState.nextNodeCounter`
   - `IdGeneratorState.nextLayerCounter`
4. Revision rollover policy:
   - `epoch bump + revision reset`
   - без saturating behavior
   - без wraparound
5. Render/cache policy:
   - `epoch` не добавляется ни в один cache key;
   - epoch остаётся owner-level boundary через `SceneRenderCaches.clearAll()`.

## Общие правила для всех подшагов

1. Один runtime owner хранит состояние генерации и ревизий. Нельзя оставлять
   параллельно и stateful allocator, и scene-scan/max-from-scene как
   competing source of truth.
2. Старый generated-id contract не сохраняется. Если после внедрения нового
   contract остаются `isGenerated*` / `tryParseGenerated*Seed` / `generate*`
   helper-ы, их роль должна быть явно оправдана; иначе они удаляются из public
   surface.
3. Step `7.x` может менять public/generated-id contract, но тогда обязан
   обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md` и `CHANGELOG.md`
   как breaking behavior change.
4. `instanceRevision` и `controllerEpoch` рассматриваются как одна composite
   invalidation policy. Нельзя чинить overflow отдельным ad hoc reset-ом в
   writer-path без такой же формализации в cache/view lifecycle.
   Принятое решение для шага `7`: при исчерпании допустимого диапазона
   `instanceRevision` store делает `controllerEpoch += 1`, сбрасывает
   allocator revision на `1` и рассматривает это как обязательную полную
   invalidation-boundary. Saturating policy и тихий wraparound не допускаются.
5. В render/cache не добавляется двойная invalidation-механика "и clear, и
   epoch везде в ключах" без явной причины. Для каждого cache-owner должен
   быть выбран один объяснимый contract.
6. Если `tool/invariant_registry.dart` меняется в рамках какого-либо подшага,
   этот подшаг обязан прогонять `dart run tool/check_invariant_coverage.dart`.

## Критерии готовности umbrella-шага

1. Для шагов `7.1`, `7.2`, `7.3`, `7.4` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `7.1` отвечает за generated-id contract и owner генератора;
   - `7.2` отвечает за store/txn/document adoption новой id policy;
   - `7.3` отвечает за revision policy, overflow semantics и epoch linkage;
   - `7.4` отвечает за render/cache invalidation contract.
3. Шаг `7` явно фиксирует удаление старого generated-id contract и не
   оставляет "временный" dual-path без owner-а.
4. Store/runtime/caches больше не зависят от разового scene-scan по
   generated-id или от неформализованной связи между `instanceRevision` и
   `controllerEpoch`.

## Чеклист выполнения

[x] Переформулировать шаг `7` как umbrella-этап и вынести реализацию в `7.1`,
    `7.2`, `7.3`, `7.4`.
[x] В `7.1` принять финальное решение по public/generated-id contract и owner
    `id_generator.dart` с удалением старого generated-id contract.
[x] В `7.2` убрать scene-scan/max-generated-id как runtime owner из store/txn
    и `document_clone.dart`.
[x] В `7.3` формализовать composite revision policy для
    `instanceRevision + epoch`, включая overflow semantics.
[x] В `7.4` зафиксировать render-cache invalidation contract без двойной
    invalidation-механики.
