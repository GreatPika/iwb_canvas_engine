language: russian

# Шаг 6.4. Довести `scene_codec.dart` до единого `code/path/details` boundary

## Цель шага

После `6.1-6.3` public error-contract и transport guards уже должны быть
определены, но именно
[scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
остаётся главным местом, где boundary contract либо окончательно принимается,
либо снова расползается по локальным исключениям, точечным message-сравнениям
и неявным различиям между string decode, parsed-map decode и encode.

Задача подшага: перевести codec entrypoint-ы на unified boundary path,
сохранить exact `path` для nested serialization/import errors и закрыть
contract-matrix в docs/tests так, чтобы cross-boundary parity проверялась по
`code/path/details`, а не по случайно совпавшему `message`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `decodeSceneFromJson(...)`, `decodeScene(...)`, `encodeScene(...)`,
   `encodeSceneDocument(...)` используют unified guard/factory path из
   `6.1-6.2`.
2. `encodeScene(...)` и `encodeSceneDocument(...)` сохраняют policy-aligned
   canonicalization шагов `5.4-5.5`; `6.4` нормализует только external
   boundary contract и error mapping вокруг уже существующего owner-а.
3. Nested serialization/import failures, включая `TextAlign` и другие
   field-level ошибки, обязаны сохранять exact `path`; `message` может быть
   derived, но `path` теряться не должен.
4. Contract parity между `decodeSceneFromJson(...)`, `decodeScene(...)`,
   `SceneBuilder.buildFromJson(...)` и encode-boundary выражается через
   `code/path/details`.
5. Exact `message` остаётся только в прицельных template/user-facing snapshot
   tests; массовые equality-assertions по тексту считаются техническим debt и
   закрываются в этом подшаге.

## Граница шага

- In:
  - `lib/src/serialization/scene_codec.dart`;
  - adoption unified guard/factory path в codec entrypoint-ах;
  - docs/tests contract matrix для builder/decode/encode boundary.
- Out:
  - новый public API;
  - изменение owner-а scene-level policy;
  - новые transport guards вне уже принятого `codec_guards.dart`.

## Последовательность реализации (только действия)

[ ] Перевести
    [lib/src/serialization/scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
    на unified guard/factory path для `decodeSceneFromJson(...)`,
    `decodeScene(...)`, `encodeScene(...)`, `encodeSceneDocument(...)`.
[ ] Удалить локальные ad hoc `SceneDataException(...)` ветки в codec там, где
    они дублируют guard/factory semantics шага `6.1-6.2`.
[ ] Проверить, что string decode boundary сохраняет payload-size limit и
    non-object root mapping через unified contract, а nested decode/encode
    ошибки не теряют exact `path`.
[ ] Подтвердить симметрию `encode -> decode` и `Scene -> encodeSceneDocument`
    без drift по `code/path/details`.
[ ] Обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md` и
    relevant tests так, чтобы contract-matrix сравнивала `code/path/details`,
    а exact `message` остался только в целевых template snapshot checks.
[ ] Закрыть диагностические watchpoints шага: `scene_codec.dart` не должен
    превратиться в новый owner transport logic после adoption guard-layer.

## Критерии приёмки

[ ] `scene_codec.dart` не содержит ad hoc boundary error mapping там, где уже
    существует unified guard/factory contract.
[ ] `decodeSceneFromJson(...)`, `decodeScene(...)`, `encodeScene(...)`,
    `encodeSceneDocument(...)` сохраняют deterministic `code/path/details`.
[ ] Nested serialization/import failures, включая `TextAlign`, не теряют
    exact `path`.
[ ] `encode -> decode` и builder/decode/encode boundary matrix не дают drift по
    `code/path/details`.
[ ] Публичные docs и контрактные tests перестают использовать точный `message`
    как основной критерий корректности boundary contract.

## Тестовый контур шага

[ ] `test/serialization/scene_codec_validation_test.dart`
[ ] `test/public_api/scene_builder_test.dart`
[ ] `test/model/document_model_test.dart`
[ ] Точечные сценарии:
    - oversized string JSON fails before parse and still reports stable
      contract
    - non-object root and parse failures use the same guard-owned contract
    - nested `TextAlign` and other field-level errors keep exact `path`
    - builder/decode/encode matrix compares `code/path/details`, not only
      `message`
    - exact message assertions remain only for explicit template coverage
