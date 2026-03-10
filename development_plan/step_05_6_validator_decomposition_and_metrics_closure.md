language: russian

# Шаг 5.6. Разрезать giant validators и закрыть диагностические watchpoints шага 5

## Цель шага

После `5.5` decode boundary должен перестать быть вторым owner-ом policy, но в
validator слое всё ещё остаются giant функции в
[scene_value_validation_node.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_value_validation_node.part.dart),
[scene_value_validation_top_level.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_value_validation_top_level.part.dart)
и укрупнившиеся scene-level helper-ы в
[scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart).

Задача подшага: разрезать validator/policy функции по устойчивым границам
ответственности, закрыть оставшиеся watchpoints шага 5 по
`cyclomatic-complexity` и `source-lines-of-code` и не породить новый sync glue
или ещё один слой policy wrappers.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `ScenePolicy` остаётся единственным owner-ом scene-level policy. `5.6` не
   добавляет поверх него фасад, registry или orchestration wrapper.
2. `scene_value_validation_node.part.dart` остаётся reusable node-validation
   слоем, но giant-функции режутся на helper-ы по node family / field group /
   invariant group, а не по случайным техническим кускам.
3. `scene_value_validation_top_level.part.dart` после `5.6` либо остаётся
   тонким helper-слоем обхода, либо схлопывается дальше, если отдельный owner
   ему больше не нужен.
4. `scene_policy.dart` может иметь несколько private helper-ов, но не должен
   превращаться в central god-object, который знает все низкоуровневые детали
   primitive/node validation.
5. Цель `5.6` не в косметическом "порезать до порога любой ценой", а в
   фиксации устойчивых модульных границ. Но текущие watchpoints шага 5
   (`sceneValidateNode*`, top-level scene validators, крупные private helper-ы
   `ScenePolicy`) не считаются закрытыми, пока их превышения не сняты или не
   исчезнет сам watchpoint-owner после схлопывания слоя.

## Граница шага

- In:
  - decomposition giant validator/policy functions;
  - закрытие watchpoints шага 5 по метрикам;
  - устранение последних крупных owner-монолитов после `5.5`.
- Out:
  - public API changes;
  - новый validation framework или дополнительный abstraction layer;
  - шаг `6` и его external boundary concerns.

## Последовательность реализации (только действия)

[ ] Разделить `sceneValidateNode(...)` и `sceneValidateNodeSnapshot(...)` на
    helper-ы по семействам инвариантов или группам полей, чтобы giant-функции
    перестали быть единственной точкой для всех node checks.
[ ] Проверить, можно ли удалить или дополнительно истончить
    `scene_value_validation_top_level.part.dart`, не возвращая ему владение
    scene-level policy.
[ ] Разделить крупные private helper-ы в
    [scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart)
    по смысловым группам (`structural duplicates`, `scene count limits`,
    `range application`), не вытягивая primitive validation внутрь policy.
[ ] Явно проверить текущие offending symbols шага 5:
    `sceneValidateNode(...)`,
    `sceneValidateNodeSnapshot(...)`,
    `sceneValidateSceneValues(...)`,
    `sceneValidateSnapshotValues(...)`,
    `_validateStructuralInvariants(...)`,
    `_validateNodeRanges(...)`.
[ ] Повторно прогнать диагностические метрики шага 5 и зафиксировать остаточные
    watchpoints только там, где соответствующий owner реально исчез или стал
    thin helper без прежней зоны ответственности.
[ ] Обновить umbrella-файл шага 5 и этот step-файл после реализации.

## Критерии приёмки

[ ] Giant-функции validator/policy слоя больше не совмещают слишком много
    разных invariant groups в одном теле без необходимости.
[ ] `scene_value_validation_node.part.dart` улучшается по
    `cyclomatic-complexity` и `source-lines-of-code`.
[ ] `scene_value_validation_top_level.part.dart` не остаётся скрытым вторым
    owner-ом scene-level orchestration.
[ ] `scene_policy.dart` не продолжает разрастаться как central god-object.
[ ] Для текущих offending symbols шага 5 не остаётся необъяснённых
    превышений, которые просто перенесены в новые helper-ы без смены ownership.
[ ] После шага остаётся понятная карта ownership между
    `scene_policy.dart`, `scene_value_validation_node.part.dart` и возможным
    top-level helper-слоем.

## Тестовый контур шага

[ ] `test/model/scene_builder_test.dart`
[ ] `test/public_api/scene_builder_test.dart`
[ ] `test/serialization/scene_codec_validation_test.dart`
[ ] `test/model/document_model_test.dart`
[ ] Точечные сценарии:
    - node validation parity for runtime and snapshot paths
    - scene-level range/count/duplicate semantics stay unchanged
    - diagnostic metric rerun is attached to the step result
