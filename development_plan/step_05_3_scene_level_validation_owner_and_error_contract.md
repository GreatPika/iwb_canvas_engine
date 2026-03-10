language: russian

# Шаг 5.3. Свести scene-level validation к одному владельцу и единому error-contract

## Цель шага

После ввода `ScenePolicy` нужно убрать реальные дубли scene-level validation.
Сейчас одни и те же ограничения частично живут и в
[scene_builder_canonicalize_validate.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_builder_canonicalize_validate.part.dart),
и в
[scene_value_validation_top_level.part.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/scene_value_validation_top_level.part.dart).
Из-за этого один и тот же дефект сцены проходит по разным веткам с разными
`SceneDataException.code` и сообщениями.

Задача подшага: сделать один owner для scene traversal, duplicate-id,
counts/ranges и связанных error semantics, сохранив primitive/node validators
как переиспользуемый internal слой.

## Что этот шаг считает своим владельцем

1. Scene-level traversal поверх:
   - `backgroundLayer.nodes`;
   - content `layers`;
   - их `nodes`.
2. Один owner для:
   - duplicate `NodeId`;
   - duplicate content `LayerId`;
   - scene-level counts;
   - range violations, которые проверяются на уровне сцены;
   - scene-level применения `kMax*` из `scene_limits.dart`.
3. Детерминированный `SceneDataException` contract:
   - `code`;
   - `path`;
   - message semantics.
4. Роль `scene_value_validation_top_level.part.dart` после шага `5.3`.

## Что уже подтверждено по текущему состоянию

1. Duplicate `NodeId` проверяется как минимум в двух местах:
   - structural path в builder part;
   - top-level scene validation path.
2. Duplicate content `LayerId` тоже проверяется не одним owner-ом.
3. Эти ветки уже расходятся по diagnostics:
   - где-то используется `duplicateNodeId`;
   - где-то общий `invalidValue`;
   - тексты и `path` semantics формируются разными кусками кода.
4. Range checks на уровне сцены тоже находятся отдельно от остальных
   scene-level policy decisions.
5. Использование `kMax*` уже централизовано по объявлениям в `scene_limits.dart`,
   но не до конца централизовано по месту применения в scene-level validation.
6. Primitive/node validators сами по себе не являются проблемой; проблема в том,
   что top-level traversal дублируется поверх них.

## Рекомендуемое решение

Рекомендуемый вариант: отдать весь top-level scene traversal одному owner-у
внутри `ScenePolicy`, а `scene_value_validation_top_level.part.dart` либо
свести к thin helpers, либо удалить, если отдельный top-level слой больше не
нужен.

Почему это лучший вариант:

1. Он убирает реальное дублирование, а не просто переименовывает функции.
2. Он делает diagnostics детерминированными на всех релевантных boundary.
3. Он сохраняет reusable primitive/node validators без копирования логики в
   новый файл.
4. Он возвращает одного owner-а для применения scene-level лимитов без
   превращения `scene_limits.dart` во второй policy layer.

## Что именно менять

### `lib/src/model/scene_builder_canonicalize_validate.part.dart`

[ ] Убрать роль самостоятельного owner-а duplicate-id и range policy, если эта
    роль окончательно переезжает в `ScenePolicy`.
[ ] Убрать ad hoc применение scene-level `kMax*`, если оно дублирует owner-а,
    выбранного для counts/ranges policy.
[ ] Оставить здесь только internal helper-ы, которые действительно нужны
    `ScenePolicy` и не образуют второй top-level validation path.

### `lib/src/model/scene_value_validation_top_level.part.dart`

[ ] Убрать самостоятельный scene traversal там, где тот же обход уже выполняет
    `ScenePolicy`.
[ ] Не оставлять файл как параллельный top-level policy entrypoint только ради
    legacy convenience.
[ ] Если часть logic после локализации больше не нужна, удалить её, а не
    оборачивать ещё одним вызовом.

### `lib/src/model/scene_value_validation_primitives.part.dart`

### `lib/src/model/scene_value_validation_node.part.dart`

[ ] Сохранить reusable primitive/node validation для text, transform, palette,
    grid, `svgPathData` и node-level fields.
[ ] Не поднимать эти файлы обратно в статус независимого scene-level owner-а.

### `SceneDataException` diagnostics

[ ] Принять единый contract для duplicate node id.
[ ] Принять единый contract для duplicate content layer id.
[ ] Принять единый contract для range violations на scene-level boundary.
[ ] Выровнять `path` и message semantics, чтобы один и тот же дефект больше не
    зависел от того, через какой internal path он был найден.

### `lib/src/core/scene_limits.dart`

[ ] Оставить `scene_limits.dart` единым источником констант.
[ ] Сделать `ScenePolicy` или его internal helper-ы единым owner-ом применения
    scene-level `kMax*` для counts/ranges.
[ ] Убрать параллельные ad hoc проверки тех же `kMax*` из конкурирующих
    validation-path.

## Критерии приемки

[ ] Duplicate `NodeId` имеет одного owner-а и один детерминированный
    error-contract.
[ ] Duplicate content `LayerId` имеет одного owner-а и один детерминированный
    error-contract.
[ ] Scene-level counts/ranges больше не живут параллельными top-level
    validation-path.
[ ] Scene-level `kMax*` применяются через одного owner-а и не дублируются между
    builder/top-level validation path.
[ ] `scene_value_validation_top_level.part.dart` больше не является вторым
    независимым owner-ом scene policy.
[ ] Primitive/node validators остаются reusable internal dependency, а не
    вытесняются копипастой в `ScenePolicy`.

## Тестовый контур

[ ] `test/model/scene_builder_test.dart`
[ ] `test/public_api/scene_builder_test.dart`
[ ] Точечные тесты на duplicate node id, duplicate content layer id и range
    violations с одинаковыми `code`/`path` expectations на всех релевантных
    boundary
