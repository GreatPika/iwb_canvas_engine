language: russian

# Шаг 4.3. Выровнять политику `TextAlign` на публичной границе и в сериализации

## Цель шага

Этот шаг закрывает конкретный contract drift вокруг `TextAlign`. Финальная
политика уже выровнена между public boundary, JSON serialization/decode,
builder/import и render/runtime semantics; задача шага теперь состоит в том,
чтобы зафиксировать это состояние как завершённый публичный контракт и не
раздувать scope до общей enum-policy нормализации.

## Что этот шаг считает своим владельцем

1. Supported `TextAlign` values на публичной границе:
   - `SceneSnapshot`
   - `NodeSpec`
   - `NodePatch`
2. Поддержка того же набора значений в:
   - encode/decode JSON
   - builder/import semantics
   - runtime/render-consumed snapshot state
3. Diagnostics на unsupported/unknown align values:
   - детерминированный `SceneDataException.code`
   - заполненный `path`, когда boundary знает точное расположение поля

## Что подтверждено по итоговому состоянию

1. Public boundary поддерживает единый набор `TextAlign`:
   - `left`
   - `center`
   - `right`
   - `justify`
   - `start`
   - `end`
2. Encode path использует тот же набор в
   `lib/src/serialization/scene_codec.dart`.
3. Decode/import path использует тот же набор в
   `lib/src/model/scene_builder_json_require.part.dart`.
4. Render/runtime semantics уже обрабатывают `justify`, `start` и `end`,
   включая direction-aware поведение для `start`/`end`.
5. Public docs зафиксировали тот же supported set в `API_GUIDE.md`.
6. Unknown align values продолжают давать `SceneDataException` с заполненным
   `path`, когда decode/build boundary знает точное поле.

## Итоговое решение

Принята и закреплена одна финальная политика: пакет не сужает public boundary
до старого codec-подмножества, а поддерживает единый `TextAlign` contract на
всех релевантных границах.

Это означает на практике:

1. Supported public contract включает:
   - `left`
   - `center`
   - `right`
   - `justify`
   - `start`
   - `end`
2. Encode/decode и builder/import используют тот же набор значений без
   специальных compat-веток или второго фасада.
3. Unsupported/unknown values продолжают приводить к `SceneDataException`, а
   `path` обязателен там, где boundary знает точное местоположение `align`.
4. Отдельный invariant/guardrail для `TextAlign` в рамках этого шага не
   добавляется: текущие serialization/public/render tests уже достаточно жёстко
   фиксируют контракт, а дополнительный tooling здесь только искусственно
   расширит scope.

## Где это закреплено

### Реализация

[x] `lib/src/serialization/scene_codec.dart` кодирует весь supported set
`TextAlign`.
[x] `lib/src/model/scene_builder_json_require.part.dart` декодирует тот же
набор значений и отдаёт path-aware diagnostics для unknown `align`.

### Документация

[x] `API_GUIDE.md` фиксирует единый supported set и path-aware diagnostics на
decode/build boundary.
[x] Этот step-файл отражает завершённое состояние шага, а не будущую
implementation work.

### Подтверждающие тесты

[x] `test/serialization/scene_codec_validation_test.dart` покрывает
round-trip для `justify`, `start`, `end`, полный supported decode set и reject
path для unknown `align`.
[x] `test/public_api/scene_builder_test.dart` подтверждает, что
`SceneBuilder.buildFromJson(...)` отдаёт те же path-aware diagnostics, что и
`decodeScene(...)`.
[x] `test/render/scene_painter_test.dart` фиксирует render semantics для
`TextAlign.start` и `TextAlign.end`.

## Критерии приемки

[x] Больше нет расхождения между `snapshot/spec/patch`, render/runtime surface
и serialization/import path по `TextAlign`.
[x] `justify`, `start` и `end` проходят encode/decode round-trip так же, как
и уже поддерживаемые значения.
[x] Unknown/unsupported align values продолжают давать
`SceneDataException`.
[x] `SceneDataException.path` заполнен там, где boundary уже знает точный путь
к `align`.
[x] Публичный контракт и step-документация синхронизированы и не обещают
дополнительный рефакторинг вне scope `4.3`.

## Тестовый контур

[x] `flutter test test/serialization/scene_codec_validation_test.dart --plain-name "TextAlign"`
[x] `flutter test test/public_api/scene_builder_test.dart --plain-name "path-aware diagnostics"`
[x] Ручная проверка `API_GUIDE.md` на совпадение supported set с кодом и
тестами.
