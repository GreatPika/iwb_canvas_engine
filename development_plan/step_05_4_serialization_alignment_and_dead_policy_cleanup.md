language: russian

# Шаг 5.4. Выровнять serialization boundary и зачистить мёртвые policy-ветки

## Цель шага

После подшагов `5.1-5.3` нужно убедиться, что serialization/import/runtime
boundary действительно описывают одну и ту же модель сцены. Сейчас
[scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
частично опирается на builder/runtime validation, но при этом хранит отдельные
предположения о каноничности сцены, например non-null assertion для
`backgroundLayer`.

Задача подшага: перевести encode/decode/runtime alignment на тот же owner
policy, убрать обходные предположения вне `ScenePolicy` и зачистить мёртвые
ветки, которые остались после локализации решения в `5.1-5.3`.

## Что этот шаг считает своим владельцем

1. Serialization/runtime alignment для:
   - `encodeScene(...)`;
   - `encodeSceneToJson(...)`;
   - `encodeSceneDocument(...)`;
   - `decodeScene(...)`;
   - `decodeSceneFromJson(...)`.
2. Перевод `scene_codec.dart` на encode-oriented entrypoint `ScenePolicy`,
   введённый в `5.2`.
3. Symmetry-сценарии:
   - `decode -> encode -> decode`;
   - `Scene -> encodeSceneDocument(...)`.
4. Cleanup неподтверждённых и dead policy branches, найденных в предыдущих
   подшагах.

## Что уже подтверждено по текущему состоянию

1. Encode-path уже опирается на canonical scene/snapshot форму, но часть
   предположений выражена напрямую в codec-коде.
2. Snapshot import и runtime scene validation проходят через builder, но после
   шага `5.2` и `5.3` owner policy должен быть выражен явно, а не через
   исторический обход.
3. Canonical background semantics уже проверяются тестами round-trip, но это
   нужно связать с новым policy-owner без параллельных допущений.

## Рекомендуемое решение

Рекомендуемый вариант: использовать в encode/runtime boundary тот же
`ScenePolicy`, который уже принят как owner scene-level orchestration, и убрать
остаточные policy assumptions из `scene_codec.dart`, где они больше не нужны.

Что это означает на практике:

1. `encodeSceneDocument(...)` использует тот же encode-oriented policy entrypoint,
   а не полагается на ad hoc предположения о каноничности.
2. `encodeScene(...)`, `decodeScene(...)` и builder/import semantics
   интерпретируют одну и ту же модель `backgroundLayer`, duplicate-id и range
   policy.
3. Любые неподтверждённые error/code branches, пережившие `5.1-5.3`,
   удаляются, а не остаются "на всякий случай".
4. Подшаг не принимает новое policy-решение по `backgroundLayer`, а только
   переводит serialization boundary на уже принятые правила и entrypoints.

## Что именно менять

### `lib/src/serialization/scene_codec.dart`

[ ] Подтвердить, что encode-path использует тот же owner policy, что и import и
    runtime validation.
[ ] Перевести `scene_codec.dart` на encode-oriented entrypoint `ScenePolicy`,
    принятый в `5.2`, вместо локальных ad hoc допущений.
[ ] Убрать обходные предположения о каноничности сцены вне `ScenePolicy`, если
    после `5.2-5.3` они становятся лишними.
[ ] Зафиксировать одну boundary-семантику для `backgroundLayer`:
    - runtime может оставаться nullable;
    - наружу сериализуется canonical dedicated background layer.

### `lib/src/model/scene_builder.dart`

[ ] Убедиться, что import/runtime validation и serialization preflight опираются
    на один и тот же policy owner, а не на исторически разные ветки.

### Cleanup dead branches

[ ] Удалить неподтверждённые policy/error ветки, оставшиеся после решений
    `5.1-5.3`.
[ ] Не переносить в этот подшаг payload-size limits и общие codec guards:
    это остаётся в шаге `6`.

## Критерии приемки

[ ] `encodeScene(...)`, `encodeSceneToJson(...)`, `encodeSceneDocument(...)`,
    `decodeScene(...)` и `decodeSceneFromJson(...)` описывают одну и ту же
    scene policy модель.
[ ] `decode -> encode -> decode` сохраняет canonical background semantics без
    drift между runtime и serialization boundary.
[ ] `Scene -> encodeSceneDocument(...)` не зависит от скрытых ad hoc
    предположений вне `ScenePolicy`.
[ ] Подшаг не переоткрывает policy по `backgroundLayer`, а использует решение
    из `5.1` и encode-oriented entrypoint из `5.2`.
[ ] Все найденные dead policy branches либо удалены, либо явно подтверждены
    как достижимые и нужные.
[ ] Подшаг не разрастается до общей external data/error boundary нормализации
    шага `6`.

## Тестовый контур

[ ] `test/serialization/scene_codec_validation_test.dart`
[ ] `test/model/document_model_test.dart`
[ ] `test/public_api/scene_builder_test.dart`
[ ] Symmetry-сценарии:
    - `decode -> encode -> decode`
    - `Scene -> encodeSceneDocument(...)`
