language: russian

# Шаг 5.5. Разрезать decode pipeline и убрать второй owner policy в JSON decode

## Цель шага

После `5.4` serialization boundary уже выровнен вокруг
[scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart),
но
[scene_builder_decode_json.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder_decode_json.part.dart)
остаётся слишком крупным decode-orchestration слоем. В нём giant-функции
`_decodeSnapshotFromJson(...)` и `_decodeNode(...)` продолжают одновременно
владеть JSON parsing, scene traversal, частично diagnostics mapping и
boundary-последовательностью decode.

Задача подшага: разрезать decode pipeline на маленькие decode-only helper-ы,
явно отделить parsing/traversal от policy-owned diagnostics и прекратить
ситуацию, где JSON decode путь фактически остаётся вторым owner-ом scene-level
policy.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Единственный owner duplicate/count/range/background diagnostics после `5.5`:
   [scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart).
2. `scene_builder_decode_json.part.dart` после `5.5` владеет только:
   - JSON shape parsing;
   - path-aware extraction значений;
   - сборкой одного канонического decode boundary payload
     (`SceneSnapshot`), который затем уходит в policy-owned
     validation/canonicalization путь.
3. Fail-fast decode guardrails допустимы, только если они не переопределяют
   policy-owned `code/path/message`, уже зафиксированные в `5.3`.
4. В `5.5` не вводится новый публичный API, новый codec entrypoint или новый
   internal policy-layer поверх `ScenePolicy`.
5. Payload-size limits, unified error factory, `details`-model и прочая внешняя
   error-boundary нормализация остаются scope шага `6`.
6. Разрезание decode pipeline не должно добавлять новый полный scene traversal
   или вторую materialized scene representation только ради архитектурной
   чистоты; декомпозиция должна сохранять текущую asymptotic cost decode-пути.

## Граница шага

- In:
  - decomposition giant decode functions;
  - отделение JSON parsing/traversal от scene policy decisions;
  - локализация decode helper-ов по фазам и ответственности.
- Out:
  - новые публичные error-коды;
  - payload-size и transport-level guardrails шага `6`;
  - повторное обсуждение serialization alignment из `5.4`.

## Последовательность реализации (только действия)

[x] Разбить `_decodeSnapshotFromJson(...)` на короткие phase-specific helper-ы:
    decode envelope, decode layers/background payload, finalize through
    policy-owned validation path.
[x] Разбить `_decodeNode(...)` на type-dispatch и field-extraction helper-ы так,
    чтобы одна функция не совмещала traversal, branching и full payload
    assembly.
[x] Убрать из decode helper-ов ad hoc policy checks, если та же семантика уже
    принадлежит `ScenePolicy`; при fail-fast оставить только вызов
    policy-owned contract либо shape-level guardrail.
[x] Проверить, что decode path больше не является вторым owner-ом duplicate id,
    scene counts/ranges и background policy semantics.
[x] Сохранить точные `path` для shape/parsing ошибок, не смешивая их с
    scene-level policy diagnostics.
[x] Убедиться, что разрезание `_decodeSnapshotFromJson(...)` и `_decodeNode(...)`
    не добавило лишний полный проход по сцене или второе materialized
    representation между decode и policy validation.
[x] Обновить этот step-файл после реализации и не переоткрывать решения выше.

## Критерии приёмки

[x] В
    [scene_builder_decode_json.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder_decode_json.part.dart)
    больше нет giant decode-функций, одновременно владеющих parsing,
    traversal и policy mapping.
[x] Decode helper-ы разделены по фазам и имеют явно локальную ответственность.
[x] Один и тот же scene-level дефект после decode продолжает идти через
    policy-owned `code/path/message`, а не через локальную decode-ветку.
[x] `scene_builder_decode_json.part.dart` не забирает обратно scope шага `6`.
[x] `_decodeSnapshotFromJson(...)` больше не остаётся giant decode-orchestrator
    по `source-lines-of-code`, а `_decodeNode(...)` улучшается и по
    `source-lines-of-code`, и по `cyclomatic-complexity`.
[x] Декомпозиция decode-path не добавляет лишнюю materialization cost или
    дополнительный полный traversal поверх уже существующего decode/policy
    контура.

## Тестовый контур шага

[x] `test/serialization/scene_codec_validation_test.dart`
[x] `test/model/scene_builder_test.dart`
[x] `test/public_api/scene_builder_test.dart`
[x] Точечные сценарии:
    - invalid JSON shape errors keep exact decode paths
    - duplicate/range defects still use policy-owned diagnostics after decode
    - decode of heterogeneous node types is covered through split helpers
