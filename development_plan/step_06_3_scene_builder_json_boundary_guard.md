language: russian

# Шаг 6.3. Перевести `SceneBuilder.buildFromJson(...)` на model-local boundary guard

## Цель шага

`SceneBuilder.buildFromJson(...)` должен быть parsed-map импортным boundary,
эквивалентным `decodeScene(...)` по diagnostics contract, но сейчас этот путь
всё ещё зависит от локальной map-normalization и не имеет явно выделенного
guard owner-а на публичной границе builder API.

Задача подшага: сделать `SceneBuilder.buildFromJson(...)` тонким entrypoint-ом,
который использует model-local guard wrapper, не дублирует transport
normalization и гарантирует parity с `decodeScene(...)` по `code/path/details`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneBuilder.buildFromJson(...)` остаётся публичным parsed-map entrypoint и
   не меняет signature.
2. Любая map normalization из `Map<String, dynamic>` в внутреннюю форму живёт в
   model-local wrapper этого подшага, собранном на shared contract primitives
   из `6.1`, а не в `scene_builder_api.dart`.
3. Для одного и того же parsed payload `buildFromJson(...)` и `decodeScene(...)`
   обязаны совпадать по `code/path/details` и давать одну и ту же canonical
   `SceneSnapshot` по содержимому.
4. `buildFromSnapshot(...)` не переопределяется в `6.3`, кроме случаев, где
   tests/docs нужно выровнять с новым contract шага `6.1`.
5. `model/` не импортирует `serialization/`; builder guard остаётся локальным
   owner-ом model boundary wrapper и использует только разрешённые low-level
   primitives из `contract/`.
6. Подшаг не добавляет новый builder-layer abstraction и не тянет transport
   guards обратно в `scene_builder.dart`.

## Граница шага

- In:
  - `lib/src/model/scene_builder_api.dart`;
  - model-local `_guardBuild(...)`;
  - parity tests между `buildFromJson(...)` и `decodeScene(...)`.
- Out:
  - string JSON boundary `decodeSceneFromJson(...)`;
  - full codec rollout и encode contract-matrix closure;
  - пересмотр typed snapshot boundary, не связанный с новым error-contract.

## Последовательность реализации (только действия)

[x] Обернуть
    [SceneBuilder.buildFromJson(...)](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder_api.dart)
    в model-local `_guardBuild(...)`, собранный на shared contract primitives
    из `6.1`.
[x] Убрать сырой `Map<String, Object?>.from(rawJson)` из открытого пути
    `scene_builder_api.dart`, чтобы parsed-map normalization происходила только
    внутри builder-local wrapper.
[x] Проверить parity `buildFromJson(...)` и `decodeScene(...)` по
    `code/path/details` на nested decode errors и policy-owned scene-level
    diagnostics.
[x] Явно подтвердить, что реализация не вводит import `model -> serialization`
    и не ломает layer DAG.
[x] Обновить публичную документацию builder boundary так, чтобы она ссылалась
    на новый contract шага `6.1`, а не на exact `message`.
[x] Явно оставить `buildFromSnapshot(...)` вне scope transport guards, кроме
    минимальных docs/tests правок по новому error-contract.

## Критерии приёмки

[x] `SceneBuilder.buildFromJson(...)` использует model-local `_guardBuild(...)`
    и не содержит открытой transport normalization логики в API entrypoint-е.
[x] Для одного и того же parsed payload `buildFromJson(...)` и `decodeScene(...)`
    совпадают по `code/path/details`.
[x] `scene_builder_api.dart` остаётся thin public boundary entrypoint, а не
    вторым owner-ом guard/factory semantics.
[x] Реализация builder guard не нарушает dependency DAG (`model` не зависит от
    `serialization`).
[x] Публичные docs/tests для builder boundary не опираются на точный `message`
    как на единственный контракт эквивалентности.

## Тестовый контур шага

[x] `test/public_api/scene_builder_test.dart`
[x] `test/serialization/scene_codec_validation_test.dart`
[x] `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
[x] Точечные сценарии:
    - builder/decode parsed-map parity for nested path-aware validation errors
    - builder/decode parity for policy-owned duplicate/range defects
    - builder guard preserves `model -> contract` only dependency shape
    - public builder docs/examples reflect `code/path/details` contract
