language: russian

# Шаг 7.3. Ввести безопасную revision policy и связать её с `epoch`

## Цель шага

После `7.2` id allocation уже должен иметь одного owner-а, но revision policy
по-прежнему останется расщеплённой, если проект будет отдельно держать
`instanceRevision`, отдельно `controllerEpoch` и отдельно ad hoc lower-bound
логики для snapshot import и replaceScene.

Задача подшага: ввести `lib/src/core/revision_policy.dart`, зафиксировать
composite contract `(epoch, revision)`, определить safe range и overflow
semantics, а затем перевести на этот contract `TxnContext`, `SceneStore`,
`SceneBuilder` и invariant checks.

## Что уже подтверждено по текущему состоянию

1. [txn_context.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/txn_context.dart)
   реализует `txnNextInstanceRevision()` как простой `int++`.
2. [document_clone.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/document_clone.dart)
   вычисляет `txnInitialNodeInstanceRevisionSeed(...)` через max-from-scene.
3. [scene_builder_scene_from_snapshot.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder_scene_from_snapshot.part.dart)
   использует отдельный snapshot allocator для недостающих или невалидных
   ревизий.
4. [store.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/store.dart)
   уже хранит `controllerEpoch`, но связь этого epoch с `instanceRevision`
   формально не описана как единая policy.
5. [scene_invariants.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_invariants.dart)
   пока проверяет только monotonic lower bound для `nextInstanceRevision`.

## Рекомендуемое решение

Рекомендуемый вариант: не расширять public snapshot/node surface новым
публичным типом ревизии, а формализовать composite invalidation identity как
пару `controllerEpoch + instanceRevision`.

Почему это лучший вариант:

1. Он использует уже существующий `controllerEpoch` вместо ввода второго
   параллельного epoch-источника.
2. Он сохраняет public `instanceRevision` как простой `int`, не раздувая
   boundary surface без продуктовой пользы.
3. Он даёт понятную overflow semantics: revision не оборачивается молча, а
   приводит к управляемому epoch bump и cache invalidation path.

Принятое решение по overflow policy:

1. `instanceRevision` и `controllerEpoch` оба остаются в safe-int диапазоне,
   уже закреплённом в
   [validated_value_support.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/validated/validated_value_support.dart).
2. Рабочий диапазон `instanceRevision` для runtime nodes: `1..validatedSafeIntegerMax`.
3. Если следующий `instanceRevision` превысил `validatedSafeIntegerMax`, store:
   - увеличивает `controllerEpoch` на `1`;
   - сбрасывает allocator `nextInstanceRevision` на `1`;
   - трактует это как обязательную полную invalidation-boundary для caches/view state.
4. Если для такого rollover уже нельзя безопасно увеличить `controllerEpoch`,
   операция завершается fail-fast ошибкой вместо saturating behavior или
   тихого wraparound.
5. Snapshot/import path сохраняет уже существующий положительный safe-int
   `instanceRevision`, а не переписывает его без причины; rollover применяется
   только при следующем runtime allocation.

Почему именно так:

1. Saturating policy плоха тем, что после достижения потолка новые мутации
   начинают повторно использовать одно и то же значение ревизии. Для render
   caches это означает скрытый риск stale-hit, если поверх saturation не
   построить отдельный compensating mechanism.
2. Тихий wraparound ещё хуже: он делает коллизии revision identity
   неявными и разносит риск по всем cache/view путям, которые сейчас
   полагаются на monotonic revision semantics.
3. `epoch bump + revision reset` использует уже существующий
   `controllerEpoch` как естественную invalidation-boundary. Это не требует
   вводить второй global epoch и сохраняет один owner composite identity.
4. Safe-int предел уже закреплён в validated-layer и тестах. Значит правильнее
   построить revision policy вокруг этого существующего ограничения, чем
   создавать отдельный "почти такой же" диапазон только для runtime.
5. Сохранять положительный safe-int `instanceRevision` при import/build
   важно для минимальности изменений: snapshot import не должен переписывать
   корректные данные только потому, что runtime allocator использует более
   сложную composite policy.
6. Fail-fast при исчерпании и `revision`, и `epoch` лучше, чем скрытая
   деградация semantics. В такой точке система уже не может гарантировать
   корректную invalidation identity, значит безопаснее остановить операцию,
   чем молча продолжить с некорректным state.
7. Убирать `max(scene)+1` из runtime/import path важно не только ради
   производительности. Пока allocator зависит от scene scan, revision policy
   остаётся data-derived, а не state-owned, и любой `replaceScene(...)`
   продолжает переопределять внутренний runtime lifecycle внешними данными.
8. Локальная нормализация missing/non-positive revision с `1` достаточна,
   потому что `instanceRevision` не обязана быть globally unique между разными
   node id. Cache identity и так составная: `nodeId + instanceRevision`.

## Граница шага

- In:
  - `lib/src/core/revision_policy.dart`;
  - safe range и overflow semantics;
  - `TxnContext` / `SceneStore` / `SceneBuilder` adoption;
  - invariant updates для composite revision policy.
- Out:
  - generated-id public contract;
  - render-cache key design per cache owner.

## Точная реализация, которую должен описывать код

1. `lib/src/core/revision_policy.dart` вводит owner-модуль с:
   - `kMaxInstanceRevision = validatedSafeIntegerMax`
   - `kMaxControllerEpoch = validatedSafeIntegerMax`
   - mutable `RevisionAllocatorState`
2. `RevisionAllocatorState` хранит ровно два runtime-поля:
   - `nextInstanceRevision`
   - `epochBumpRequested`
3. Аллокация новой revision работает так:
   - вернуть текущее `nextInstanceRevision`;
   - если оно меньше `kMaxInstanceRevision`, увеличить его на `1`;
   - если оно равно `kMaxInstanceRevision`, сбросить
     `nextInstanceRevision = 1` и выставить `epochBumpRequested = true`.
4. `TxnContext` хранит `RevisionAllocatorState revisionState` вместо голого
   `nextInstanceRevision`.
5. Commit-path считает `epoch` так:
   - если `documentReplaced == true` или `epochBumpRequested == true`,
     `nextEpoch = currentEpoch + 1`;
   - иначе `nextEpoch = currentEpoch`.
6. Если commit требует epoch bump, а `currentEpoch == kMaxControllerEpoch`,
   commit завершается fail-fast `StateError` и не меняет store.
7. `txnAdoptScene(...)` не сканирует принятую сцену ради `max(instanceRevision)`.
   Adopt сохраняет текущий allocator state.
8. `txnSceneFromSnapshot(...)` и `SceneBuilder` default allocator для
   missing/non-positive `instanceRevision` начинают локальную нормализацию с
   `1`, а не с `max(snapshot)+1`.
9. Уже существующий положительный safe-int `instanceRevision` из snapshot не
   переписывается.
10. Удаляется `txnInitialNodeInstanceRevisionSeed(...)` как owner future
    runtime allocation.

## Последовательность реализации (только действия)

[x] Создать `lib/src/core/revision_policy.dart` как owner safe range,
    `(epoch, revision)` contract и overflow policy.
[x] Перевести `TxnContext.txnNextInstanceRevision()` на новый revision policy.
[x] Заменить в `TxnContext` голый `nextInstanceRevision` на
    `RevisionAllocatorState`.
[x] Убрать ad hoc seed/max-from-scene semantics из runtime/import paths, где
    revision state уже должен жить в store/runtime owner-е.
[x] Обновить `SceneBuilder` snapshot import path так, чтобы missing/invalid
    revisions нормализовались через `revision_policy.dart` с local start `1`, а
    не через `max(snapshot)+1`.
[x] Обновить invariants, чтобы они описывали composite revision policy и
    overflow behavior, а не только `nextInstanceRevision >= max(scene) + 1`.

## Критерии приёмки

[x] `revision_policy.dart` является одним owner-ом safe revision semantics.
[x] `instanceRevision` и `controllerEpoch` описаны как единый composite
    invalidation contract.
[x] Overflow ревизий реализован только через `epoch bump + revision reset`;
    saturating behavior и тихий wraparound отсутствуют.
[x] `SceneBuilder`, store и txn path используют одну и ту же revision policy.
[x] Runtime path больше не вычисляет future revision через `max(scene)+1`.
[x] Invariants и tests проверяют новый contract, включая overflow и adopt /
    replaceScene lifecycle.

## Тестовый контур шага

[x] `test/controller/internal/change_set_txn_context_test.dart`
[x] `test/controller/scene_invariants_test.dart`
[x] `test/controller/core/scene_controller_copy_on_write_test.dart`
[x] `test/model/document_model_test.dart`
[x] Новый targeted test для `lib/src/core/revision_policy.dart`
[x] `dart run tool/check_invariant_coverage.dart` если меняется
    `tool/invariant_registry.dart`
