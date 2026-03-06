language: russian

# Шаг 3.3. Развести boundary validation и runtime write semantics как подготовку к write core

## Цель шага

После шагов `3.1` и `3.2` primitive boundary-rules для `snapshot/spec/patch`
должны жить только в `contract/validated/**` и публичных validating entry
points. Этот шаг закрепляет `SceneWriteTxn` как долгоживущий write seam и
убирает downstream primitive-дублирование из write/runtime path, оставляя там
только runtime/stateful semantics, которые потом без изменения модели можно
перенести в шаг `8`.

## Что этот шаг считает своим владельцем

1. Публичный contract-seam:
   - `SceneWriteTxn`
   - `ClearSceneResult`
   - `writeSelectionReplace(...)`
   - immutable snapshots/views, которые выдаются наружу
   - точные `throws` там, где они принадлежат runtime apply semantics
2. Архитектурное расслоение:
   - boundary validation остаётся на public constructors и validated-layer;
   - write/model path владеет только target/type/state checks, canonicalization
     и derived recomputation.
3. Границу:
   - без `mutation_op.dart` / `mutation_executor.dart` из шага `8`;
   - без ownership/allocation redesign из шага `3.4`;
   - без public API alignment из шага `4`.

## Что реализовано

### `lib/src/contract/scene_write_txn.dart`

[x] `writeSelectionReplace(...)` явно зафиксирован как no-op, если normalized
набор пуст; clear остаётся обязанностью `writeSelectionClear()`.
[x] `selectedNodeIds` и `writeClearSceneKeepBackground()` задокументированы как
immutable views/snapshots.
[x] `ClearSceneResult.removedNodeIds` остаётся immutable snapshot.
[x] `throws`-контракты уточнены только там, где они реально принадлежат
runtime/write semantics: duplicate id, missing layer, range/index, finite /
invertible transform, finite offset, positive grid size.

### Write/runtime seam

[x] `txnNodeFromSpec(...)` больше не повторяет boundary validation already
validated `NodeSpec`.
[x] `txnApplyNodePatch(...)` больше не повторяет boundary validation already
validated `NodePatch`.
[x] Вместо late primitive-validation в write-path остались только runtime
preconditions:
   - `patch.id` должен совпадать с target node id;
   - тип patch должен соответствовать типу target node;
   - дальнейшее apply-поведение остаётся stateful/no-op aware.
[x] Cleanup не трогает writer-owned guards в `SceneWriter` для finite /
invertible transform, camera/grid/delta и document-lifecycle semantics.

### Тестовый контур

[x] Добавлены тесты на immutable `selectedNodeIds` внутри writer transaction.
[x] Добавлены тесты на `writeSelectionReplace([])` и fully-filtered input как
no-op без implicit clear.
[x] Добавлен тест на immutable список из `writeClearSceneKeepBackground()`.
[x] Удалён regression-test, который закреплял неправильную роль runtime
safety-net для invalid fast-path primitive payloads.
[x] Сохранены runtime-only regression tests на mismatch id/type, range/index,
duplicate id, text layout recomputation и canonical clear semantics.

## Критерии приемки

[x] `SceneWriteTxn` остался тонким публичным контрактом без нового функционала.
[x] Публичные write-semantics, immutability и lifecycle contract совпадают с
реализацией и тестами.
[x] `contract/validated/**` и public constructors остаются единственным
владельцем primitive boundary-rules для `spec/patch`.
[x] Downstream write/model path больше не владеет независимой primitive
валидацией `NodeSpec`/`NodePatch`.
[x] В write/model path остаются только runtime/stateful semantics, пригодные к
дальнейшему механическому переносу в шаг `8`.
[x] Граница с шагами `3.4`, `4` и `8` остаётся чистой.
