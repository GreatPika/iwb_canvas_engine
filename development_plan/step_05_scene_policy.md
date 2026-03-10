language: russian

# Шаг 5. Ввести единый `ScenePolicy` через подшаги 5.1-5.6

## Цель шага

После завершения шагов `3.x` и `4.x` проблема шага `5` больше не выглядит как
один цельный рефакторинг. Здесь смешаны как минимум четыре разные темы:

- runtime/boundary policy для `backgroundLayer`;
- ввод одного scene-level orchestrator;
- схлопывание дублей scene traversal и error semantics;
- выравнивание serialization/runtime boundary и зачистка мёртвых веток
  контракта.

Этот umbrella-шаг нужен, чтобы развести владельцев ответственности и не
оставить один большой документ, где одновременно обсуждаются модель runtime
сцены, wiring `SceneBuilder`, duplicate-id semantics и codec alignment.

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как
отдельный критерий готовности. Цель не "лечить числа", а проверять, что
scene-level policy действительно уходит из giant validators и
decode-orchestration.

- Смотреть в первую очередь `cyclomatic-complexity` и
  `source-lines-of-code`.
- Вторично смотреть `maximum-nesting-level`, если после разрезания logic flow
  остаётся трудно читаемым.
- Контрольные файлы:
  - `lib/src/model/scene_policy.dart`
  - `lib/src/model/scene_builder_decode_json.part.dart`
  - `lib/src/model/scene_value_validation_node.part.dart`
  - `lib/src/model/scene_value_validation_top_level.part.dart`
- Полезный сигнал после шага: не остаётся giant top-level
  validators/decoders, которые одновременно владеют traversal, policy decision
  и error mapping, а новый `ScenePolicy` не превращается в ещё один central
  god-object.

## Как разбит этап

### Шаг 5.1

`development_plan/step_05_1_background_layer_runtime_and_boundary_policy.md`

Владелец policy-решения для:

- runtime-модели `Scene.backgroundLayer`;
- boundary-семантики `backgroundLayer` для `SceneSnapshot`, JSON и encode;
- роли `ensureBackgroundLayer(...)`;
- судьбы `SceneDataErrorCode.multipleBackgroundLayers`;
- явной границы между `ScenePolicy` scope и codec guards из шага `6`.

### Шаг 5.2

`development_plan/step_05_2_scene_policy_entrypoints_and_builder_delegation.md`

Владелец ввода внутреннего orchestrator-модуля для:

- `lib/src/model/scene_policy.dart`;
- компактных scene-level entrypoints;
- делегации из `scene_builder.dart`;
- отказа от builder как второго owner-а scene-level orchestration.

### Шаг 5.3

`development_plan/step_05_3_scene_level_validation_owner_and_error_contract.md`

Владелец одного owner-а для:

- duplicate `NodeId` / duplicate content `LayerId`;
- counts/ranges и scene-level применения `kMax*`;
- background-related scene traversal;
- детерминированного `SceneDataException.code` / `path` semantics;
- схлопывания дублей между
  `scene_policy.dart`,
  `scene_value_validation_top_level.part.dart` и
  `scene_builder_decode_json.part.dart`.

### Шаг 5.4

`development_plan/step_05_4_serialization_alignment_and_dead_policy_cleanup.md`

Владелец boundary alignment и cleanup для:

- `scene_codec.dart` и перевода codec на encode-oriented entrypoint `ScenePolicy`;
- симметрии `decode -> encode -> decode` и `Scene -> encodeSceneDocument(...)`;
- удаления обходных предположений о каноничности сцены вне `ScenePolicy`;
- зачистки неподтверждённых или мёртвых policy/error веток, найденных в
  `5.1-5.3`.

### Шаг 5.5

`development_plan/step_05_5_decode_pipeline_decomposition_and_policy_boundary.md`

Владелец разрезания decode-orchestration для:

- `scene_builder_decode_json.part.dart` и giant функций
  `_decodeSnapshotFromJson(...)` / `_decodeNode(...)`;
- явного отделения JSON parsing/traversal от policy-owned diagnostics;
- прекращения ситуации, где decode-path остаётся вторым owner-ом scene policy;
- локализации fail-fast decode guardrails без возврата в ad hoc error mapping.

### Шаг 5.6

`development_plan/step_05_6_validator_decomposition_and_metrics_closure.md`

Владелец зачистки giant validators для:

- `scene_value_validation_node.part.dart`;
- `scene_value_validation_top_level.part.dart`;
- укрупнившихся scene-level функций в `scene_policy.dart`;
- закрытия оставшихся watchpoints по `cyclomatic-complexity` и
  `source-lines-of-code`, найденных после `5.4`.

## Карта переноса деталей из исходного шага 5

1. Решение по nullable runtime `backgroundLayer` и canonical non-null boundary
   переносится в `5.1`.
2. Создание `scene_policy.dart` и перевод builder на делегацию переносится в
   `5.2`.
3. Дубли scene traversal, duplicate-id проверки, counts/ranges и единый
   error-contract переносятся в `5.3`.
4. Перевод serialization boundary на encode-oriented entrypoint `ScenePolicy`,
   выравнивание encode/runtime/import semantics и cleanup dead branches
   переносятся в `5.4`.
5. Разрезание giant decode-пути и отделение parsing/traversal от
   policy-owned diagnostics переносятся в `5.5`.
6. Разрезание giant validator-функций и закрытие диагностических метрик
   validator/policy слоя переносятся в `5.6`.
7. JSON payload-size limits, общие codec guards и внешняя error-boundary
   нормализация остаются в шаге `6` и не возвращаются в `5.x`.

## Общие правила для всех подшагов

1. `ScenePolicy` остаётся внутренним модулем `src/**`; новый публичный API не
   добавляется.
2. Шаг `5.x` не меняет import root, schema version и public surface
   `snapshot/spec/patch`.
3. Допустимы только такие изменения diagnostics/error semantics, которые
   устраняют уже подтверждённый drift между существующими validation-path.
4. `scene_limits.dart` остаётся источником констант, а не превращается в
   отдельный policy-layer.
5. `scene_value_validation_primitives.part.dart` и
   `scene_value_validation_node.part.dart` остаются reusable primitive/node
   validators и не становятся вторым top-level policy layer после шага `5`.
6. Если `tool/invariant_registry.dart` меняется в рамках какого-либо подшага,
   этот подшаг обязан прогонять `dart run tool/check_invariant_coverage.dart`.

## Критерии готовности umbrella-шага

1. Для шагов `5.1`, `5.2`, `5.3`, `5.4`, `5.5`, `5.6` существуют отдельные
   step-файлы с собственной целью, границей ответственности, критериями
   приёмки и тестовым контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `5.1` отвечает за `backgroundLayer` policy;
   - `5.2` отвечает за orchestration entrypoints и builder delegation;
   - `5.3` отвечает за одного owner-а scene-level traversal/error semantics и
     применение scene-level `kMax*`;
   - `5.4` отвечает за serialization alignment и dead-branch cleanup;
   - `5.5` отвечает за decode decomposition и чистую policy-boundary в
     JSON decode-пути;
   - `5.6` отвечает за decomposition validator/policy функций и closure
     диагностических метрик.
3. Шаг `5` не разрастается обратно в один тяжёлый документ со смешанным scope.
4. Граница со шагом `6` остаётся чистой: общие codec guards и payload-size
   policy не возвращаются в `5.x`.

## Чеклист выполнения

[x] Переформулировать шаг `5` как umbrella-этап и вынести решение по
    реализации в `5.1`, `5.2`, `5.3`, `5.4`.
[x] В `5.1` явно зафиксировать nullable runtime `backgroundLayer` и canonical
    non-null boundary как рекомендуемый дефолт.
[x] В `5.2` описать компактный internal API `ScenePolicy` и builder delegation
    без повторного обсуждения duplicate/range semantics.
[x] В `5.3` свести duplicate-id, counts/ranges и scene traversal к одному
    owner-у с единым error-contract.
[x] В `5.4` закрепить serialization/runtime alignment и cleanup dead policy
    branches без захвата scope шага `6`.
[x] В `5.5` разрезать decode-orchestration так, чтобы decode-path не оставался
    вторым owner-ом scene-level policy.
[x] В `5.6` разрезать giant validators и закрыть оставшиеся watchpoints шага 5
    без ввода нового публичного API.
