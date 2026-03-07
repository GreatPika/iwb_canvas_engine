language: russian

# Шаг 4.2. Уточнить контракт `SceneBuilder` и codec entrypoints

## Цель шага

Этот шаг фиксирует точный публичный контракт import/codec boundary. `SceneBuilder` и `encode/decode` уже экспортируются из barrel, но их поведение пока описано слишком общо. Нужно выровнять doc comments, `API_GUIDE.md`, `throws`-контракт и ожидания по `SceneDataException.path`, не добавляя новых фасадов и не смешивая этот шаг с общей error-boundary нормализацией из шага `6`.

## Что этот шаг считает своим владельцем

1. Public import entrypoints:
   - `SceneBuilder.buildFromSnapshot(...)`
   - `SceneBuilder.buildFromJson(...)`
2. Public serialization entrypoints:
   - `encodeScene(...)`
   - `encodeSceneToJson(...)`
   - `decodeScene(...)`
   - `decodeSceneFromJson(...)`
3. Документированный `throws`-контракт:
   - `SceneDataException` на schema/data/validation failures
   - `invalidJson` для JSON parse/root-shape failures
4. Документированная гарантия по `path`:
   - nested boundary failures обязаны отдавать path;
   - root-level parse/schema failures могут не иметь path, если точное поле ещё не известно.

## Что уже подтверждено по текущему состоянию

1. `SceneBuilder` уже является canonical public gateway для import/canonicalization, но doc comments пока не фиксируют точный `throws`-контракт.
2. `decodeSceneFromJson(...)` уже оборачивает `FormatException` в `SceneDataException` c `invalidJson`.
3. Nested decode/import validation уже активно использует `SceneDataException.path`.
4. Основной риск шага не в отсутствии поведения, а в том, что публичная документация отстаёт от фактического контракта.

## Рекомендуемое решение

Рекомендуемый вариант: не менять модель public API, а сделать существующий import/codec contract явно документированным и проверяемым.

Что это означает на практике:

1. `SceneBuilder` формально описывается как public import/canonicalization gateway.
2. `encodeScene*` и `decodeScene*` документируют фактический `throws`-контракт через `SceneDataException`.
3. Гарантия по `path` формулируется точно:
   - nested validation path обязателен;
   - root parse/schema failures могут не иметь `path`, если boundary ещё не знает точное местоположение значения.

## Что именно менять

### `lib/src/model/scene_builder_api.dart`

[ ] Уточнить doc comments для `buildFromSnapshot(...)` и `buildFromJson(...)`.
[ ] Явно зафиксировать, что эти entrypoints выполняют validation и canonicalization.
[ ] Явно описать `SceneDataException` как ожидаемый failure contract для malformed input.
[ ] Если между raw snapshot import и raw JSON import остаются разные пути validation/canonicalization/diagnostics, описать это различие явно, а не оставлять его скрытой деталью реализации.

### `lib/src/serialization/scene_codec.dart`

[ ] Уточнить doc comments для `encodeSceneToJson(...)`, `decodeSceneFromJson(...)`, `encodeScene(...)` и `decodeScene(...)`.
[ ] Зафиксировать фактический `throws`-контракт через `SceneDataException`.
[ ] Зафиксировать, где boundary гарантирует заполненный `path`, а где root-level failures допустимо обходятся без него.

### `API_GUIDE.md`

[ ] Синхронизировать описание `SceneBuilder` и serialization boundary с реальным поведением.
[ ] Не обещать более сильные гарантии по `path`, чем реально даёт код.

## Конкретизация внедрения по порядку

1. Подтвердить фактическое поведение codec/import boundary по коду и существующим тестам.
2. Обновить doc comments в `SceneBuilder` и `scene_codec.dart`.
3. Обновить `API_GUIDE.md` до той же формулировки.
4. Доработать tests только для тех контрактов, которые ещё не зафиксированы явно.

## Критерии приемки

[ ] `SceneBuilder.buildFromSnapshot(...)` и `SceneBuilder.buildFromJson(...)` описаны как public import/canonicalization gateway.
[ ] `decodeSceneFromJson(...)` явно документирует wrapping JSON parse failures в `SceneDataException` с `invalidJson`.
[ ] `encodeScene*` и `decodeScene*` имеют точный публичный `throws`-контракт, совпадающий с кодом.
[ ] Гарантия по `SceneDataException.path` сформулирована точно и не расходится с фактическим поведением boundary.
[ ] Различие между snapshot-import и JSON-import path либо задокументировано явно, либо подтверждено, что внешне они образуют один и тот же contract surface.

## Тестовый контур

[ ] `test/public_api/scene_builder_test.dart`
[ ] `test/serialization/scene_test.dart`
[ ] `test/serialization/scene_codec_validation_test.dart`
