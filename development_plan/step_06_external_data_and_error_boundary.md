language: russian

# Шаг 6. Нормализовать всю внешнюю границу данных и ошибок

## Целевое решение по error-contract (фиксируется в этом шаге)

В этом шаге принимается финальная модель ошибок для внешней границы:

1. Машинный контракт ошибки: `code + path + details`.
2. `message` — производное человекочитаемое поле, не первичный контракт для
   межслойной логики.
3. Формирование boundary-ошибок централизуется в одном factory-слое, чтобы
   codec/builder/sanitization не собирали `SceneDataException` каждый по-своему.
4. Для разных семантических нарушений используются отдельные error-коды
   (включая duplicate content layer id), а не общий `invalidValue` там, где
   нарушение имеет стабильную категорию.
5. Decode fail-fast проверки допускаются, но обязаны выдавать тот же контракт
   (`code/path/details`), что и основной policy-owner.

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

## `lib/src/contract/scene_data_exception.dart`

Сделать:

1. Расширить доменный контракт ошибки структурированным `details`
   (машинно-читаемый payload).
2. Зафиксировать в API, что `code/path/details` являются контрактной частью.
3. Перевести формирование `message` на централизованные шаблоны по
   `code/details`.
4. Добавить отдельный error-code для duplicate content layer id и убрать
   зависимость от `invalidValue` в этом кейсе.

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
5. Не собирать ad hoc `SceneDataException` в codec-ветках; использовать единый
   boundary factory-контур с `details`.

## Создать `lib/src/serialization/codec_guards.dart`

Реализовать:

1. `_guardDecode`
2. `_guardBuild`
3. `_guardEncode`
4. усечение `source`
5. нормализацию `path`
6. перевод системных исключений в доменные
7. единый маппинг в `code/path/details` без локальных расхождений по message

## Критерии готовности шага 6 (добавочно к остальному scope)

1. Внешняя граница не опирается на точный текст `message` как на первичный
   контракт.
2. Для одной и той же ошибки на разных boundary получаются одинаковые
   `code/path/details`.
3. `duplicateLayerId` имеет отдельную стабильную категорию ошибки.
4. codec/build guards и policy-layer используют один и тот же error factory.
