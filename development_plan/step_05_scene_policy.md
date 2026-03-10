language: russian

# Шаг 5. Ввести единый `ScenePolicy` через подшаги 5.1-5.4

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
  `scene_builder_canonicalize_validate.part.dart` и
  `scene_value_validation_top_level.part.dart`.

### Шаг 5.4

`development_plan/step_05_4_serialization_alignment_and_dead_policy_cleanup.md`

Владелец boundary alignment и cleanup для:

- `scene_codec.dart` и перевода codec на encode-oriented entrypoint `ScenePolicy`;
- симметрии `decode -> encode -> decode` и `Scene -> encodeSceneDocument(...)`;
- удаления обходных предположений о каноничности сцены вне `ScenePolicy`;
- зачистки неподтверждённых или мёртвых policy/error веток, найденных в
  `5.1-5.3`.

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
5. JSON payload-size limits, общие codec guards и внешняя error-boundary
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

1. Для шагов `5.1`, `5.2`, `5.3`, `5.4` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `5.1` отвечает за `backgroundLayer` policy;
   - `5.2` отвечает за orchestration entrypoints и builder delegation;
   - `5.3` отвечает за одного owner-а scene-level traversal/error semantics и
     применение scene-level `kMax*`;
   - `5.4` отвечает за serialization alignment и dead-branch cleanup.
3. Шаг `5` не разрастается обратно в один тяжёлый документ со смешанным scope.
4. Граница со шагом `6` остаётся чистой: общие codec guards и payload-size
   policy не возвращаются в `5.x`.

## Чеклист выполнения

[ ] Переформулировать шаг `5` как umbrella-этап и вынести решение по
    реализации в `5.1`, `5.2`, `5.3`, `5.4`.
[ ] В `5.1` явно зафиксировать nullable runtime `backgroundLayer` и canonical
    non-null boundary как рекомендуемый дефолт.
[ ] В `5.2` описать компактный internal API `ScenePolicy` и builder delegation
    без повторного обсуждения duplicate/range semantics.
[ ] В `5.3` свести duplicate-id, counts/ranges и scene traversal к одному
    owner-у с единым error-contract.
[ ] В `5.4` закрепить serialization/runtime alignment и cleanup dead policy
    branches без захвата scope шага `6`.
