language: russian

# Шаг 5.4. Выровнять serialization boundary и зачистить мёртвые policy-ветки

## Цель шага

После шагов `5.1-5.3` owner policy уже зафиксирован в
[scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart),
но в
[scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
остались локальные допущения (включая non-null assertion для
`backgroundLayer`) и дублирование encode-пути. Этот подшаг закрывает только
serialization alignment и cleanup мёртвых policy-веток.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Единственный owner policy для encode/runtime/import boundary в `5.4`:
   `ScenePolicy` через builder entrypoints из `scene_builder.dart`.
2. `encodeScene(SceneSnapshot)` остаётся snapshot-boundary entrypoint и
   использует `sceneCanonicalizeAndValidateSnapshot(...)`; отдельный
   scene-level policy внутри codec не добавляется.
3. `encodeSceneDocument(Scene)` обязан идти через encode-oriented policy путь
   (`sceneValidateCore(...)`) и затем сериализоваться через тот же общий
   encode-контур, что и `encodeScene(...)`, без отдельной ручной сборки JSON.
4. Non-null assertion `backgroundLayer!` в codec считается ad hoc policy
   допущением и удаляется; canonical background-layer гарантия должна следовать
   из policy+canonicalization, а не из `!` в boundary-коде.
5. Целевая семантика `backgroundLayer` не меняется:
   runtime `Scene.backgroundLayer` остаётся nullable;
   serialized boundary всегда содержит canonical
   `backgroundLayer: {"nodes": [...]}`.
6. `decodeScene(...)` и `decodeSceneFromJson(...)` не получают в `5.4` новых
   guard/factory/error-details механизмов; это scope шага `6`.
7. В `5.4` не вводятся новые публичные error-коды и не меняется публичный API.
8. Любая policy/error ветка в codec, не имеющая достижимого сценария после
   `5.1-5.3`, удаляется, а не оставляется "на всякий случай".

## Граница шага

- In:
  - выравнивание encode/decode/runtime boundary вокруг уже принятого owner-а;
  - удаление ad hoc policy assumptions в codec;
  - устранение дублирующих encode-веток, ведущих к drift.
- Out:
  - payload-size guards, unified error factory, `details`-contract и прочая
    внешняя error-boundary нормализация шага `6`;
  - новые policy-решения по `backgroundLayer`, duplicate-id и range semantics
    (они уже приняты в `5.1-5.3`).

## Последовательность реализации (только действия)

[x] В
    [lib/src/serialization/scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
    свести `encodeScene(...)` и `encodeSceneDocument(...)` к одному
    serialization-контуру, чтобы JSON-структура собиралась в одном месте.
[x] Перевести `encodeSceneDocument(...)` на явную цепочку:
    `sceneValidateCore(...)` -> canonical representation -> общий encode-контур,
    без локальной ручной policy-логики в codec.
[x] Удалить из codec non-null assertion и связанные suppressions/комментарии,
    которые дублируют policy-gарантии вместо использования результата
    canonicalization.
[x] Проверить, что `decodeScene(...)` и `decodeSceneFromJson(...)` остаются
    в текущем scope (без внедрения шага `6`), но продолжают давать контракт,
    согласованный с `5.3`, для дефектов, уже покрытых `ScenePolicy`.
[x] Удалить мёртвые/private helper-ветки codec, ставшие неиспользуемыми после
    схлопывания encode-path (например, локальные encoder-ветки, не являющиеся
    общим контуром).
[x] Обновить этот step-файл: отметить выполненные пункты и не переоткрывать
    зафиксированные решения.

## Критерии приёмки

[x] `encodeScene(...)` и `encodeSceneDocument(...)` используют один и тот же
    policy-aligned encode-контур и не расходятся по canonical JSON форме.
[x] В codec нет `backgroundLayer!` и других ad hoc policy-допущений о
    каноничности сцены вне `ScenePolicy`-пути.
[x] `decode -> encode -> decode` сохраняет canonical background semantics и
    не даёт drift по duplicate/range диагностике, уже закреплённой в `5.3`.
[x] `Scene(with backgroundLayer == null) -> encodeSceneDocument(...)`
    детерминированно сериализуется с dedicated `backgroundLayer.nodes`.
[x] Подшаг не добавляет scope шага `6` (payload-size guards, unified boundary
    factory, `details`-model, новые error-codes).

## Тестовый контур шага

[x] `test/serialization/scene_codec_validation_test.dart`
[x] `test/model/document_model_test.dart`
[x] `test/public_api/scene_builder_test.dart`
[x] Точечные сценарии:
    - `encodeSceneDocument canonicalizes null runtime background layer`
    - `encodeSceneDocument rejects duplicate node ids across background/content`
    - `encodeScene preserves import-boundary duplicate-id diagnostics`
    - symmetry: `decode -> encode -> decode`
