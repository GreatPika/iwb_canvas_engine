language: russian

# Шаг 6. Нормализовать всю внешнюю границу данных и ошибок

## `lib/src/model/scene_builder_api.dart`

Сделать:

1. Обернуть `buildFromJson(...)` в единый `_guardBuild(...)`.
2. Убрать сырой `Map<String, Object?>.from(rawJson)` из незащищённого пути.

## `lib/src/serialization/scene_codec.dart`

Сделать:

1. `decodeSceneFromJson(String)`:

   * лимит размера входа до `jsonDecode`,
   * общий `catch`,
   * нормализация в `SceneDataException`.
2. `decodeScene(Map<String, dynamic>)`:

   * убрать сырой `Map.from(...)` вне guard-слоя.
3. `encodeScene(...)` и `encodeSceneDocument(...)`:

   * прогонять через `encodePolicy`,
   * гарантировать симметрию `encode -> decode`.
4. Ошибки сериализации должны не терять `path`, включая ошибки `TextAlign`.

## Создать `lib/src/serialization/codec_guards.dart`

Реализовать:

1. `_guardDecode`
2. `_guardBuild`
3. `_guardEncode`
4. усечение `source`
5. нормализацию `path`
6. перевод системных исключений в доменные

