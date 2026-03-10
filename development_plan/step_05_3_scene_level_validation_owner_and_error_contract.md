language: russian

# Шаг 5.3. Свести scene-level validation к одному владельцу и единому error-contract

## Цель шага

После шага `5.2` в коде всё ещё есть два конкурирующих пути scene-level
валидации: policy-ветка в
[scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart)
и top-level обход в
[scene_value_validation_top_level.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_value_validation_top_level.part.dart).
Из-за этого одинаковые дефекты дают разные `SceneDataException.code/path/message`.

Задача подшага: зафиксировать одного owner-а для scene-level traversal,
duplicate/count/range policy и сделать единый детерминированный error-contract
на всех релевантных boundary.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Единственный owner scene-level policy в `5.3`:
   [scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart).
2. `scene_value_validation_top_level.part.dart` после `5.3` не владеет policy.
   Он остаётся только как internal helper-слой для обхода и вызова
   primitive/node validators либо удаляется, если helper-роль не нужна.
3. `scene_builder_decode_json.part.dart` остаётся decode-boundary guardrail
   слоем, но не становится вторым owner-ом duplicate/count/range semantics.
   Если проверки выполняются во время decode для fail-fast, код/path/message
   берутся из policy-owned contract.
4. `scene_limits.dart` остаётся только источником констант. Владение
   применением scene-level `kMax*` фиксируется за `ScenePolicy`.
5. Публичный enum `SceneDataErrorCode` в `5.3` не расширяется. Новый код для
   duplicate content layer id в этом подшаге не вводится.

## Единый error-contract, который фиксируем в шаге

1. Duplicate node id:
   - `code`: `SceneDataErrorCode.duplicateNodeId`
   - `path`: точный путь к повторному id (`backgroundLayer.nodes[i].id` или
     `layers[l].nodes[n].id`)
   - `message`: `Must be unique across scene layers.`
2. Duplicate content layer id:
   - `code`: `SceneDataErrorCode.invalidValue`
   - `path`: `layers[i].id`
   - `message`: `Field layers[i].id must be unique across content layers.`
3. Scene-level numeric range violations:
   - `code`: `SceneDataErrorCode.outOfRange`
   - `path`: точный путь поля
   - `message`: `Field <path> must be within [<min>, <max>].`
4. Scene-level count limits:
   - превышение `kMaxContentLayersPerScene`:
     - `code`: `SceneDataErrorCode.invalidValue`
     - `path`: `layers`
     - `message`: `Field layers must contain at most <limit> items.`
   - превышение `kMaxNodesPerScene`:
     - `code`: `SceneDataErrorCode.invalidValue`
     - `path`: путь коллекции, где зафиксировано переполнение
       (`backgroundLayer.nodes` или `layers[i].nodes`)
     - `message`: `Scene must contain at most <limit> nodes.`

## Граница шага

- In:
  - один owner для duplicate/count/range semantics;
  - устранение drift по `code/path/message`;
  - локализация scene-level `kMax*` применения.
- Out:
  - новые публичные error-коды;
  - payload-size policy и общие codec guards шага `6`;
  - serialization alignment шага `5.4`.

## Последовательность реализации (только действия)

[ ] Зафиксировать в `scene_policy.dart` единый scene-level traversal для
    `backgroundLayer.nodes`, `layers`, `layers[*].nodes` и вынести туда
    duplicate/count/range decisions как единственный policy-owner.
[ ] Перевести `scene_value_validation_top_level.part.dart` в helper-only режим:
    убрать из него duplicate `NodeId`, duplicate `LayerId`, scene-level count
    limits и range policy decisions.
[ ] Сохранить `scene_value_validation_primitives.part.dart` и
    `scene_value_validation_node.part.dart` как переиспользуемый низкоуровневый
    validation слой без scene-level policy владения.
[ ] В `scene_builder_decode_json.part.dart` оставить только decode guardrails и
    выровнять их ошибки с policy-owned contract по `code/path/message`.
[ ] Убедиться, что `scene_builder.dart` и его entrypoints
    (`sceneCanonicalizeAndValidateSnapshot`, `sceneCanonicalizeAndValidateScene`,
    `sceneValidateCore`) используют только policy-owner и не имеют
    параллельного top-level policy path.
[ ] Обновить тестовые ожидания там, где сейчас зафиксирован drift между
    `invalidValue` и `duplicateNodeId`, а также между разными message/path для
    одного дефекта.
[ ] Обновить описание шага и чекбоксы в этом файле после завершения реализации
    без переоткрытия решений выше.

## Критерии приемки

[ ] Для каждого дефекта из таблицы выше существует ровно один owner и один
    детерминированный `code/path/message` контракт.
[ ] Один и тот же дефект сцены даёт одинаковую ошибку независимо от boundary
    (`sceneBuildFromSnapshot`, `sceneCanonicalizeAndValidateScene`,
    codec-related пути, где применим этот шаг).
[ ] `scene_value_validation_top_level.part.dart` не является вторым owner-ом
    scene-level duplicate/count/range policy.
[ ] Scene-level применение `kMax*` больше не размазано между конкурирующими
    validation-path.
[ ] Подшаг не заходит в scope `5.4` и `6`.

## Тестовый контур шага

[ ] `test/model/scene_builder_test.dart`
[ ] `test/public_api/scene_builder_test.dart`
[ ] `test/serialization/scene_codec_validation_test.dart`
[ ] `test/model/document_model_test.dart`
[ ] `test/controller/core/scene_controller_commit_failures_test.dart`
[ ] Точечные сценарии:
    - duplicate node id (`backgroundLayer` и `layers`)
    - duplicate content layer id
    - scene-level count limits (`kMaxNodesPerScene`, `kMaxContentLayersPerScene`)
    - scene-level range violations с точным `outOfRange` contract
