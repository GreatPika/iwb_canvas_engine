language: russian

# Шаг 6. Нормализовать внешнюю границу данных и ошибок через подшаги 6.1-6.4

## Цель шага

После шагов `5.x` owner scene-level policy уже зафиксирован, но внешняя
граница данных и ошибок всё ещё размазана между
[scene_data_exception.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_data_exception.dart),
[scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart),
[scene_builder_api.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder_api.dart)
и внутренними decode/build catch-ветками.

В одном документе здесь смешивались как минимум четыре разные темы:

- публичный contract `SceneDataException` и stable error-codes;
- transport-level guard/factory слой для string/map/encode boundary;
- parsed-map boundary `SceneBuilder.buildFromJson(...)`;
- финальное принятие unified boundary в codec вместе с миграцией docs/tests
  от `message`-driven контрактов к `code/path/details`.

Этот umbrella-шаг нужен, чтобы разнести владельцев ответственности и не
оставить один тяжёлый этап, где одновременно обсуждаются public error model,
payload-size guards, builder wiring и rollout по codec/docs/tests.

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как
отдельный критерий готовности. Цель не "сделать меньше helper-ов любой
ценой", а убедиться, что external boundary получает одного owner-а на contract
и одного owner-а на transport guards, без повторного размазывания логики по
codec и builder.

- Смотреть в первую очередь `cyclomatic-complexity` и
  `source-lines-of-code`.
- Вторично смотреть `maximum-nesting-level`, если новый guard-layer начнёт
  собирать в одном месте весь boundary branching.
- Контрольные файлы:
  - `lib/src/contract/scene_data_exception.dart`
  - `lib/src/serialization/codec_guards.dart`
  - `lib/src/serialization/scene_codec.dart`
  - `lib/src/model/scene_builder_api.dart`
- Полезный сигнал после шага: transport guards и error factory больше не
  дублируются между codec/builder/sanitization, а `scene_codec.dart` и
  `scene_builder_api.dart` остаются тонкими boundary entrypoint-ами вместо
  новых owner-ов contract semantics.

## Как разбит этап

### Шаг 6.1

`development_plan/step_06_1_scene_data_exception_contract_and_error_codes.md`

Владелец публичного error-contract для:

- `SceneDataException.code/path/details` как machine-readable boundary model;
- роли `message` как производного user-facing поля;
- стабильной taxonomy error-codes, включая `duplicateLayerId`;
- одного factory/template owner-а для формирования boundary diagnostics;
- явной границы между contract-level sanitization и transport-level guards.

### Шаг 6.2

`development_plan/step_06_2_codec_guards_and_boundary_factory.md`

Владелец serialization-local guard слоя для:

- `lib/src/serialization/codec_guards.dart`;
- `_guardDecode`, `_guardEncode`;
- payload-size limits до `jsonDecode`;
- применения contract primitives шага `6.1` без нарушения layer DAG;
- прекращения ad hoc catch-веток в codec без нарушения layer DAG.

### Шаг 6.3

`development_plan/step_06_3_scene_builder_json_boundary_guard.md`

Владелец parsed-map builder boundary для:

- `SceneBuilder.buildFromJson(...)`;
- model-local `_guardBuild(...)`, собранного на contract primitives из `6.1`;
- удаления сырого `Map.from(...)` из незащищённого пути;
- parity `buildFromJson(...)` и `decodeScene(...)` по `code/path/details`.

### Шаг 6.4

`development_plan/step_06_4_scene_codec_boundary_adoption_and_contract_matrix.md`

Владелец codec rollout и contract-matrix closure для:

- `decodeSceneFromJson(...)`, `decodeScene(...)`,
  `encodeScene(...)`, `encodeSceneDocument(...)`;
- сохранения exact `path` для nested serialization/import ошибок, включая
  `TextAlign`;
- унификации `encode/decode/build` boundary вокруг contract шага `6.1`;
- миграции docs/tests с точного `message` как первичного контракта на
  `code/path/details`.

## Карта переноса деталей из исходного шага 6

1. Финальная модель ошибки `code + path + details`, производный `message`,
   stable error-codes и `duplicateLayerId` переносятся в `6.1`.
2. Serialization-local
   `codec_guards.dart`, payload-size policy и translation системных исключений
   в доменный contract переносятся в `6.2`.
3. Model-local `_guardBuild(...)` для `SceneBuilder.buildFromJson(...)` и
   удаление сырого `Map<String, Object?>.from(rawJson)` из открытого пути
   переносятся в `6.3`.
4. Перевод `scene_codec.dart` на unified guard/factory path, сохранение exact
   `path` при encode/decode ошибках и симметрия `encode -> decode` переносятся
   в `6.4`.
5. Очистка docs/tests от массовой привязки к точному `message` переносится в
   `6.4`; `message` остаётся только в прицельных snapshot-тестах шаблонов.
6. Owner scene-level defects (`duplicate ids`, ranges, limits, background
   semantics) не переоткрывается в `6.x`: их detection остаётся в `ScenePolicy`
   из шагов `5.x`, а шаг `6` нормализует только внешнее представление ошибок и
   transport boundary around it.

## Общие правила для всех подшагов

1. `ScenePolicy` остаётся единственным owner-ом решения, какой scene-level
   дефект обнаружен; `6.x` меняет contract presentation и transport guards, но
   не возвращает ownership duplicate/count/range semantics в codec/builder.
2. `code/path/details` являются primary contract для межслойной логики и
   cross-boundary parity; `message` остаётся user-facing производным полем и не
   должен использоваться как единственный критерий эквивалентности дефекта.
3. `details` должен оставаться immutable JSON-like payload
   (`Map<String, Object?>` с ограниченными вложенными коллекциями и scalar
   values), чтобы contract был детерминированным и сериализуемым для tests/docs.
4. Sanitization/preview diagnostic payload-ов остаётся в
   `scene_data_exception.dart`; transport guards, codec и builder не должны
   заводить собственные parallel sanitizer-ветки.
5. Layer DAG не нарушается: `model/` не импортирует `serialization/`; shared
   boundary primitives живут в `contract/`, а transport wrappers остаются
   локальными для своего слоя-owner-а.
6. Любой подшаг `6.x`, меняющий публичный contract ошибок, обязан в том же
   изменении обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md` и
   `CHANGELOG.md`; docs не откладываются "на потом".
7. Подшаги `6.x` не добавляют новый public entrypoint, новый scene traversal,
   вторую materialized representation сцены или sync glue между boundary
   слоями.

## Критерии готовности umbrella-шага

1. Для шагов `6.1`, `6.2`, `6.3`, `6.4` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `6.1` отвечает за public error-contract и taxonomy;
   - `6.2` отвечает за serialization-local guards;
   - `6.3` отвечает за parsed-map builder boundary и model-local `_guardBuild`;
   - `6.4` отвечает за codec adoption и contract-matrix closure в docs/tests.
3. После выполнения `6.x` одинаковый внешний дефект на string decode,
   parsed-map decode, builder import и encode boundary сравнивается по
   `code/path/details`, а не по точному `message`.
4. Шаг `6` не переоткрывает решения шага `5` о scene-level ownership и не
   превращается в новый central god-step для всех boundary concerns.

## Чеклист выполнения

[ ] Переформулировать шаг `6` как umbrella-этап и вынести реализацию в `6.1`,
    `6.2`, `6.3`, `6.4`.
[x] В `6.1` зафиксировать `SceneDataException.details`, derived `message` и
    отдельный `duplicateLayerId` без повторного обсуждения scene-level owner-а.
[x] В `6.2` описать serialization-local guards, использующие primitives шага
    `6.1`, без нарушения layer DAG, второго sanitizer или нового codec
    god-object.
[x] В `6.3` перевести `SceneBuilder.buildFromJson(...)` на model-local
    `_guardBuild(...)` и закрыть unguarded map-normalization path.
[x] В `6.4` перевести `scene_codec.dart` на unified boundary и явно описать
    migration docs/tests от `message`-driven контрактов к `code/path/details`.
[x] Удержать чистую границу со шагами `5.x`: detection scene-level defects
    остаётся в `ScenePolicy`, а `6.x` отвечает только за external
    representation и transport guards.
