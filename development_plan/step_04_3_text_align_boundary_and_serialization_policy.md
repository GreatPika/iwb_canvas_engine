language: russian

# Шаг 4.3. Выровнять политику `TextAlign` на публичной границе и в сериализации

## Цель шага

Этот шаг закрывает конкретный contract drift вокруг `TextAlign`. Сейчас boundary constructors и render/runtime surface уже допускают больше значений, чем JSON serialization/decode path. Нужно выбрать одну политику и провести её через `snapshot/spec/patch`, builder/import и codec, чтобы у пакета не было полуподдержанного enum-контракта.

## Что этот шаг считает своим владельцем

1. Supported `TextAlign` values на публичной границе:
   - `snapshot`
   - `NodeSpec`
   - `NodePatch`
2. Поддержка тех же значений в:
   - encode/decode JSON
   - builder/import semantics
   - runtime/render-consumed snapshot state
3. Diagnostics на unsupported/unknown align values:
   - детерминированный `SceneDataException.code`
   - заполненный `path`, когда boundary знает точное расположение поля

## Что уже подтверждено по текущему состоянию

1. Public boundary уже допускает `TextAlign.start`, `TextAlign.end` и `TextAlign.justify`.
2. Render surface уже использует эти значения как легитимные runtime cases.
3. Codec/decode path пока поддерживает только подмножество значений, поэтому здесь есть реальный contract mismatch.
4. Encode-path знает точный `nodePath`, значит при ошибке на align может и должен отдавать заполненный `path`.

## Рекомендуемое решение

Рекомендуемый вариант: не сужать boundary до текущего codec-подмножества, а выровнять serialization/import path до уже существующей public/render semantics.

Что это означает на практике:

1. Supported public contract включает:
   - `left`
   - `center`
   - `right`
   - `justify`
   - `start`
   - `end`
2. Encode/decode используют тот же набор значений.
3. Unsupported/unknown values продолжают приводить к `SceneDataException`, а `path` обязателен там, где location уже известно.

## Что именно менять

### `lib/src/serialization/scene_codec.dart`

[ ] Добавить поддержку полного публичного набора `TextAlign` в encode path.
[ ] Убедиться, что error contract на unsupported align содержит `path`, если boundary знает `nodePath`.

### `lib/src/model/scene_builder_json_require.part.dart`

[ ] Добавить поддержку того же набора строковых align values в decode path.
[ ] Сохранить детерминированную `SceneDataException`-диагностику для неизвестных значений.

### Документация и тесты

[ ] Явно зафиксировать финальную политику `TextAlign` в `API_GUIDE.md` и/или релевантных public docs.
[ ] Доработать tests на round-trip и reject-path только для реально расходящихся сценариев.
[ ] Если после локализации выясняется, что drift лежит шире, чем `TextAlign`, сузить подшаг до реального enum-boundary mismatch и не раздувать изменение до общего rewrite enum semantics.

## Конкретизация внедрения по порядку

1. Принять один финальный supported set `TextAlign`.
2. Выровнять encode path.
3. Выровнять decode/import path.
4. Добавить тесты на round-trip для `justify/start/end`.
5. Проверить, что unknown align по-прежнему даёт детерминированный `SceneDataException`.

## Критерии приемки

[ ] Больше нет расхождения между `snapshot/spec/patch`, render/runtime surface и serialization/import path по `TextAlign`.
[ ] `justify`, `start` и `end` проходят encode/decode round-trip так же, как уже поддерживаемые значения.
[ ] Unknown/unsupported align values продолжают давать `SceneDataException`.
[ ] `SceneDataException.path` заполнен там, где boundary уже знает точный путь к `align`.

## Тестовый контур

[ ] `test/serialization/scene_codec_validation_test.dart`
[ ] Релевантные public/render tests, если они фиксируют supported `TextAlign` surface
