language: russian

# Шаг 14. Закрыть тестами и невозвратом все этапы

## `test/serialization/**`

Добавить и обновить:

1. bad map → всегда `SceneDataException`
2. huge JSON → доменная ошибка до `jsonDecode`
3. safe-int для `int`
4. unsupported schema version → правильный `code`
5. `TextAlign` по финальной политике
6. unsupported align → заполненный `path`
7. пустые и длинные id
8. симметрия `encode -> decode`
9. контрактные матрицы `code/path/details` для одинаковых дефектов на разных
   boundary (decode, builder, codec guards)
10. ограниченные snapshot-проверки `message` только для user-facing шаблонов,
    без повсеместной проверки точного текста

## `test/model/**`

Добавить и обновить:

1. policy `backgroundLayer`
2. `TextNodeSnapshot.size`
3. лимиты `kMax*` не только на JSON-пути
4. legacy id format reading
5. revision policy
6. отсутствие двойной проверки уникальности с расхождением по ошибкам
7. выбранная судьба `multipleBackgroundLayers`
8. выбранная судьба `ensureBackgroundLayer`

## `test/controller/**`

Добавить и обновить:

1. `writeSelectionReplace([])` по финальной семантике
2. bulk delete для всех путей
3. transform composition order
4. `dispose()` во время write
5. неизменяемость `ClearSceneResult`
6. no-op patch точек:

   * не копирует список,
   * не меняет `pointsRevision`

## `test/interactive/**`

Добавить и обновить:

1. `dragStartSlop` constructor validation
2. `dragStartSlop` frozen on down
3. invalid `up/cancel`
4. cancel rollback of selection baseline
5. replaceScene cancels active gesture
6. setCameraOffset cancels active gesture
7. monotonic timestamp
8. preview/commit parity for locked/untransformable nodes
9. единое правило для `dragStartSlop` и `tapSlop = 0`

## `test/view/**`

Добавить и обновить:

1. invalid pointer filtered before side effects
2. slot release order
3. raw-id/slot-id separation
4. no reset while raw pointers alive
5. mounted guard
6. no useless collections on flush path

## `test/render/**`

Добавить и обновить:

1. save/restore integrity
2. grid line generation bounded by actual step
3. same grid algorithm in painter and static cache
4. no color in text layout cache key if layout unchanged
5. path cache invalidation invariant
6. revision contract for caches

## `test/core/**`

Добавить и обновить:

1. validated value types
2. id factories
3. revision policy
4. one-owner defaults


# Финальный критерий готовности

Работа закончена только когда для **каждой** проблемы из этапов 0–10 выполнены одновременно три вещи:

1. изменён конкретный файл,
2. применён конкретный механизм закрытия,
3. есть конкретный тест, guardrail или CI-проверка, которая не даст проблеме вернуться.

Если хочешь, следующим сообщением я превращу **этот уже исправленный план** в самый жёсткий формат:
**по каждому файлу — список точных правок внутри файла**, без фаз и без абстракций.
