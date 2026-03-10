language: russian

# Шаг 5.2. Ввести entrypoints `ScenePolicy` и делегацию из builder

## Цель шага

После фиксации модели `backgroundLayer` нужно ввести одного owner-а для
scene-level orchestration. Сейчас
[scene_builder.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder.dart)
сам собирает policy из нескольких разрозненных веток:

- `_validateStructuralInvariants(...)`;
- `sceneValidateSnapshotValues(...)` / `sceneValidateSceneValues(...)`;
- `_validateSnapshotRanges(...)`.

Задача подшага: создать внутренний `ScenePolicy` как единую orchestration
точку и перевести builder на делегацию, не смешивая этот шаг с повторным
обсуждением duplicate-id и range semantics.

## Что этот шаг считает своим владельцем

1. Новый внутренний модуль
   [scene_policy.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_policy.dart).
2. Компактный internal API scene-level orchestration:
   - `validateImportSnapshot(...)`;
   - `validateRuntimeScene(...)`;
   - `validateEncodeScene(...)` или один явно encode-oriented entrypoint с той
     же ролью.
3. Делегация из `scene_builder.dart`:
   - `sceneCanonicalizeAndValidateSnapshot(...)`;
   - `sceneCanonicalizeAndValidateScene(...)`;
   - `sceneValidateCore(...)`.
4. Сужение роли builder до snapshot/scene transformations и thin adapters.

## Что уже подтверждено по текущему состоянию

1. Builder сейчас выступает вторым владельцем scene-level policy orchestration,
   а не только сборщиком snapshot/runtime conversion.
2. Reusable primitive/node validation уже существует в
   `scene_value_validation*.part.dart`, так что новый orchestrator не должен
   копировать low-level checks.
3. Лимиты уже централизованы в `scene_limits.dart`, поэтому проблема именно в
   orchestration-owner, а не в отсутствии места для констант.

## Рекомендуемое решение

Рекомендуемый вариант: ввести `ScenePolicy` как internal orchestrator с
небольшим набором entrypoints и перевести builder на вызов этого модуля.

Что это означает на практике:

1. `ScenePolicy` владеет только orchestration и boundary-семантикой.
2. Builder перестаёт вручную собирать policy из нескольких validation веток.
3. Primitive/node validators остаются внутренними зависимостями `ScenePolicy`,
   а не вытесняются новым дублирующим слоем.
4. Подшаг не переоткрывает вопрос о точных duplicate/range error semantics:
   это целиком уходит в `5.3`.
5. Подшаг вводит форму internal API для encode boundary, но не принимает здесь
   новое policy-решение по `backgroundLayer` и не делает serialization
   alignment work: это остаётся в `5.1` и `5.4`.

## Что именно менять

### `lib/src/model/scene_policy.dart`

[x] Создать internal orchestrator для scene-level policy.
[x] Держать API компактным и boundary-oriented, без длинного списка
    равноправных top-level функций.
[x] Явно зафиксировать, какие boundary он обслуживает:
    - snapshot import;
    - runtime scene validation;
    - encode-oriented validation entrypoint для последующего codec wiring.

### `lib/src/model/scene_builder.dart`

[x] Перевести `sceneCanonicalizeAndValidateSnapshot(...)` на делегацию в
    `ScenePolicy`.
[x] Перевести `sceneCanonicalizeAndValidateScene(...)` на делегацию в
    `ScenePolicy` с сохранением текущей внешней семантики.
[x] Сохранить за builder ответственность за
    `snapshot <-> scene` conversion, а не за orchestration policy.

### `lib/src/model/scene_builder_canonicalize_validate.part.dart`

[x] Оставить рядом только те helper-ы, которые после шага `5.2` действительно
    являются internal implementation detail builder/policy wiring.
[x] Удалить или сузить private helper-ы, которые больше не нужны как
    самостоятельные entrypoints.

## Критерии приемки

[x] `ScenePolicy` существует как один явный owner scene-level orchestration.
[x] `scene_builder.dart` больше не собирает policy вручную из нескольких
    top-level validation entrypoints.
[x] Builder остаётся ответственным за преобразование между snapshot и runtime
    scene, а не за независимое владение scene policy.
[x] Подшаг не дублирует работу `5.3`: duplicate/range error semantics здесь не
    нормализуются повторно, кроме необходимого wiring.
[x] Подшаг не переоткрывает policy по `backgroundLayer` и не забирает
    serialization alignment из `5.4`.

## Тестовый контур

[x] `test/model/scene_builder_test.dart`
[x] `test/public_api/scene_builder_test.dart`
[x] `test/serialization/scene_codec_validation_test.dart`
[x] Проверка, что `sceneBuildFromSnapshot(...)`,
    `sceneBuildFromJsonMap(...)`, `sceneCanonicalizeAndValidateScene(...)`
    сохраняют прежнее поведение после делегации
