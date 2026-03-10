language: russian

# Шаг 6.1. Зафиксировать контракт `SceneDataException` и taxonomy error-codes

## Цель шага

После шагов `5.x` boundary уже выдаёт детерминированные ошибки по многим
scene-level дефектам, но публичный contract по-прежнему опирается на
`message`, а machine-readable payload для сравнения между boundary отсутствует.
Из-за этого docs/tests завязаны на точный текст, а разные boundary всё ещё
могут расходиться по способу сборки одной и той же ошибки.

Задача подшага: зафиксировать финальный public contract
`SceneDataException` вокруг `code/path/details`, перевести `message` в
производное user-facing поле и определить стабильную taxonomy error-codes до
того, как boundary wiring начнёт использовать unified guards.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Machine-readable contract ошибки после `6.1`:
   `SceneDataException.code`, `SceneDataException.path`,
   `SceneDataException.details`.
2. `message` остаётся публичным полем для человека, но считается производным
   шаблоном от `code/path/details` и не является primary contract для
   cross-boundary parity.
3. `details` имеет форму immutable JSON-like `Map<String, Object?>` с
   ограниченными вложенными `List`/`Map` и scalar values; boundary не должен
   класть в него живые mutable объекты или opaque runtime references.
4. Sanitization/preview diagnostic payload-ов остаётся централизованной в
   [scene_data_exception.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_data_exception.dart);
   guards/codec/builder передают сырой контекст в factory, а не реализуют свои
   локальные sanitizer-ветки.
5. Добавляется отдельный `SceneDataErrorCode.duplicateLayerId`; duplicate
   content layer id перестаёт использовать общий `invalidValue`.
6. `ScenePolicy` и decode helpers не переопределяют taxonomy дефектов в `6.1`;
   подшаг фиксирует только внешний contract и factory/template owner-а.

## Граница шага

- In:
  - `SceneDataException` public shape;
  - `SceneDataErrorCode` taxonomy;
  - factory/template semantics для derived `message`;
  - docs/tests, описывающие публичный error-contract.
- Out:
  - transport-level payload-size guards;
  - adoption в `SceneBuilder.buildFromJson(...)` и `scene_codec.dart`;
  - scene-level traversal или смена owner-а duplicate/range detection.

## Последовательность реализации (только действия)

[x] Расширить
    [lib/src/contract/scene_data_exception.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_data_exception.dart)
    полем `details` и зафиксировать его immutable JSON-like форму.
[x] Ввести factory/template слой, который строит `message` из
    `code/path/details`, чтобы boundary callers перестали собирать стабильные
    сообщения ad hoc.
[x] Добавить `SceneDataErrorCode.duplicateLayerId` и описать migration от
    текущего `invalidValue` для duplicate content layer id.
[x] Зафиксировать в docs, что `source` остаётся diagnostic/FormatException
    compatibility полем и не участвует в cross-boundary contract parity.
[x] Обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`
    так, чтобы public contract ссылался на `code/path/details`, а не на
    обязательный exact `message`.
[x] Сузить message-based проверки в tests/docs до template-focused snapshot
    сценариев и не оставлять массовых контрактных сравнений по тексту.

## Критерии приёмки

[x] `SceneDataException` явно экспонирует stable contract
    `code/path/details`.
[x] `message` документирован как derived user-facing field, а не как primary
    machine contract.
[x] `duplicateLayerId` имеет отдельную стабильную категорию ошибки.
[x] Sanitization/preview diagnostic payload-ов централизованы в
    `scene_data_exception.dart`, без parallel sanitizer-веток в других слоях.
[x] Публичные docs и контрактные tests больше не требуют exact `message` для
    доказательства эквивалентности дефекта между boundary.

## Тестовый контур шага

[x] `test/public_api/validated_boundary_value_test.dart`
[x] `test/serialization/scene_codec_validation_test.dart`
[x] Точечные сценарии:
    - `SceneDataException` keeps `FormatException` shape while exposing
      `details`
    - `duplicateLayerId` uses dedicated error code and stable details payload
    - source/details sanitization is deterministic and immutable
    - message template tests are explicit and limited to user-facing snapshots
