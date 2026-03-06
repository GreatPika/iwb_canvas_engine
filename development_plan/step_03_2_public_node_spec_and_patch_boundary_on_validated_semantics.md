language: russian

# Шаг 3.2. Перевести public NodeSpec/NodePatch boundary на validated semantics

## Цель шага

После шага `3.1` публичная snapshot-semantics уже должна быть закреплена. Задача этого шага: тем же принципом перевести `NodeSpec`, `NodePatch` и `CommonNodePatch` на validated public boundary, чтобы write-insert и write-patch входы перестали принимать сырые примитивы без проверки, но при этом downstream cleanup не размазался по нескольким владельцам.

Этот шаг использует validated-layer из шагов `2` и `2.1` как единственный источник boundary-rules, но не занимается схлопыванием downstream primitive-дублирования в runtime/model paths. Этим владеет шаг `3.3`.

## Что этот шаг считает своим владельцем

1. Публичные validating entry points для:
   - `NodeSpec`
   - `NodePatch`
   - `CommonNodePatch`
2. Политику `validate only present fields` для patch surface.
3. Ограничение области:
   - без расширения revision-patch surface;
   - без переноса в этот шаг `SceneWriteTxn` semantics;
   - без переноса сюда шага `4`.

## Что уже подтверждено по текущему состоянию

1. `lib/src/contract/node_spec.dart` сейчас в основном принимает значения как есть и не валидирует boundary-fields при публичном создании.
2. `lib/src/contract/node_patch.dart` сейчас позволяет пронести значения через `PatchField` без early boundary enforcement, если downstream path позже их не отвергнет.
3. Поздняя валидация уже существует глубже:
   - `txnNodeFromSpec(...)` через `sceneValidateNodeSpecValues(...)`;
   - `txnApplyNodePatch(...)` через `sceneValidateNodePatchValues(...)`.
4. `NodeSpec` и `NodePatch` уже частично делают только structural work:
   - прокидывают значения вниз;
   - копируют коллекции там, где это нужно для immutable boundary-shape;
   - не владеют полноценной boundary-валидацией.
5. Для patch-путей подтверждён отдельный риск лишнего копирования списков точек в no-op сценариях:
   - в runtime path список может materialize/copy раньше проверки на фактическое изменение;
   - этот риск должен быть зафиксирован именно как задача `3.2`, а не потеряться внутри общего cleanup.
6. Публичного revision-patch surface сейчас нет, поэтому придумывать его на этом шаге не нужно.

## Рекомендуемое решение

Рекомендуемый вариант: сделать public `NodeSpec` и `NodePatch` thin-but-validating boundary-объектами поверх validated-layer из шага `2`, при этом оставить downstream runtime/model cleanup целиком шагу `3.3`.

Что это означает на практике:

1. Public `NodeSpec` entry points валидируют id, geometry, text/font/path values и numeric/range fields до попадания в write paths.
2. Public `NodePatch` entry points валидируют только те поля, которые реально присутствуют в `PatchField`, и не вводят скрытую вторую семантику absent/present/update.
3. `TextNodeSpec` не получает отдельный user-controlled `size`; layout semantics остаётся согласованной с шагом `3.1`.
4. Для patch points no-op copy policy фиксируется на public boundary: материализация/copy допустима только когда изменение действительно нужно.

## Что именно менять

### `lib/src/contract/node_spec.dart`

[ ] Перевести все public `NodeSpec` entry points на validated boundary поверх шага `2`.
[ ] Закрыть обходы по `id`, `imageId`, `text`, `fontFamily`, `svgPathData`, `opacity`, `hitPadding`, `thickness`, `size`, `fontSize`, `maxWidth`, `lineHeight`, `transform`, `start`, `end`, `points`.
[ ] Не вводить вторую независимую семантику текстового размера; `TextNodeSpec` продолжает описывать layout inputs.
[ ] Сохранить write-path совместимым с уже валидированным boundary-object, а не с сырым контейнером.

### `lib/src/contract/node_patch.dart`

[ ] Перевести public `NodePatch` и `CommonNodePatch` на validating entry points поверх того же validated-layer.
[ ] Проверять только присутствующие patch fields и не валидировать absent-поля ради симметрии.
[ ] Не расширять revision-surface без отдельного продуктового требования.
[ ] Зафиксировать no-op copy policy для `StrokeNodePatch.points`: сначала определять, есть ли реальное изменение, и только потом materialize immutable copy.
[ ] Сохранить downstream logic пересчёта derived text size после layout-affecting patch, не добавляя sync glue между patch и runtime-model.

### Граница с соседними шагами

[ ] Не переносить сюда snapshot-boundary semantics; это владелец шага `3.1`.
[ ] Не переносить сюда `SceneWriteTxn`, immutability/throws contract и downstream primitive cleanup; это владелец шага `3.3`.
[ ] Не переносить сюда точный export-surface и release-facing contract; это владелец шага `4`.

## Конкретизация внедрения по порядку

1. Подтвердить, какие поля `NodeSpec` и `NodePatch` уже фактически ограничены глубже в runtime/model, но не защищены на public boundary.
2. Сначала перевести `NodeSpec` на validated public creation, потому что write-insert path должен начать получать уже корректный boundary-object.
3. Затем перевести `CommonNodePatch` и `NodePatch` на validation only for present fields.
4. Отдельно закрепить no-op copy policy для patch points.
5. Оставить схлопывание downstream primitive-дублирования шагу `3.3`, чтобы owner cleanup был один.

## Критерии приемки

[ ] Public `NodeSpec` entry points больше не принимают невалидные boundary-values как допустимые объекты.
[ ] Public `NodePatch` и `CommonNodePatch` валидируют только присутствующие поля и не дают протащить невалидные boundary-values через patch surface.
[ ] Уже существующая late validation в downstream paths не считается потерянной: до cleanup шага `3.3` она остаётся safety-net, а не silently удаляется заранее.
[ ] `TextNodeSpec` и text-related patch paths не создают второй независимой size-semantics.
[ ] Revision-patch surface не расширен.
[ ] No-op сценарии patch points не создают лишние копии без необходимости.
[ ] Все primitive boundary-rules берутся из validated-layer шага `2`, а downstream cleanup остаётся отдельно зафиксирован в шаге `3.3`.

## Тестовый контур

[ ] Добавить тесты на rejection невалидных id/text/font/path/numeric/geometry значений на уровне public `NodeSpec`.
[ ] Добавить тесты на rejection невалидных present-fields на уровне public `NodePatch` и `CommonNodePatch`.
[ ] Добавить тесты на то, что absent patch fields не триггерят лишнюю валидацию.
[ ] Добавить тесты на no-op copy scenario для patch points.
[ ] Добавить тесты на сохранение согласованной text/layout semantics с шагом `3.1`.
