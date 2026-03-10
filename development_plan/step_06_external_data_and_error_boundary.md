language: russian

# Шаг 6. Нормализовать всю внешнюю границу данных и ошибок

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как отдельный критерий готовности. Здесь важнее не уменьшить количество helper-ов, а убедиться, что guard/error boundary становится компактнее и не размазан между codec и sanitization.

- Смотреть в первую очередь `cyclomatic-complexity` и `source-lines-of-code`.
- `number-of-parameters` здесь вторична и сама по себе не является целью шага.
- Контрольные файлы:
  - `lib/src/serialization/codec_guards.dart`
  - `lib/src/serialization/scene_codec.dart`
  - `lib/src/contract/scene_data_exception.dart`
  - `lib/src/model/scene_builder_api.dart`
- Полезный сигнал после шага: encode/decode guards и sanitization больше не живут в нескольких тяжёлых ветках с дублирующимся error-mapping, а новый guard-layer не становится новым местом концентрации всей boundary-логики.

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
