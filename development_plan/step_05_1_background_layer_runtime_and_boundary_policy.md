language: russian

# Шаг 5.1. Зафиксировать runtime и boundary policy для `backgroundLayer`

## Цель шага

Сначала нужно принять одно решение по модели `backgroundLayer`, иначе остальные
подшаги шага `5` будут строиться на плавающем основании. Сейчас код уже
подтверждает split-семантику:

- `SceneSnapshot` держит canonical non-null `backgroundLayer`;
- mutable `Scene` всё ещё допускает `backgroundLayer == null`;
- encode/import boundary фактически опираются на каноническую форму;
- runtime write-path местами использует `ensureBackgroundLayer(...)` как
  utility.

Задача подшага: не делать широкий runtime redesign, а зафиксировать это как
сознательную policy-модель, подтвердить роль `ensureBackgroundLayer(...)`,
принять решение по `SceneDataErrorCode.multipleBackgroundLayers` и явно
отграничить step `5` от codec-boundary work шага `6`, не забирая себе форму
`ScenePolicy` API и wiring serialization.

## Что этот шаг считает своим владельцем

1. Модель `Scene.backgroundLayer` в runtime:
   - nullable или always-present;
   - где именно это считается нормой, а где только internal detail.
2. Boundary-canonicalization:
   - `SceneSnapshot`;
   - JSON import/export;
   - encode-boundary semantics for `backgroundLayer`.
3. Роль `ensureBackgroundLayer(...)`:
   - runtime utility;
   - не скрытый синхронизатор двух моделей.
4. Судьба `SceneDataErrorCode.multipleBackgroundLayers`.
5. Явная граница со step `6`:
   - JSON payload-size;
   - общие codec guards;
   - внешняя error-boundary нормализация сюда не входят.

## Что уже подтверждено по текущему состоянию

1. [scene.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/scene.dart)
   хранит `BackgroundLayer? backgroundLayer` как nullable runtime-состояние.
2. [snapshot.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/snapshot.dart)
   канонизирует `backgroundLayer` в обязательное поле на typed boundary.
3. [scene_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/serialization/scene_codec.dart)
   на encode-path уже исходит из наличия canonical background layer.
4. [background_layer_invariants.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/background_layer_invariants.dart)
   уже содержит `ensureBackgroundLayer(...)`, а write-path местами опирается на
   ленивое создание слоя.
5. В
   [invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart)
   уже закреплены два инварианта:
   - serialization keeps optional backgroundLayer separate from content layers;
   - snapshot/JSON boundaries canonicalize missing backgroundLayer to a single
     dedicated background layer.
6. `SceneDataErrorCode.multipleBackgroundLayers` существует, но typed
   runtime/snapshot модель не предоставляет формы, которая могла бы выразить
   несколько background layers.

## Рекомендуемое решение

Рекомендуемый вариант: на шаге `5.1` оставить `Scene.backgroundLayer`
nullable runtime-моделью и явно закрепить canonical non-null только на
snapshot/JSON/encode boundary.

Почему это лучший вариант:

1. Он совпадает с текущим кодом и инвариантами, а не требует широкого runtime
   рефакторинга без подтверждённой пользы.
2. Он оставляет `ensureBackgroundLayer(...)` простой runtime utility-функцией,
   а не "клеем" между двумя competing truth sources.
3. Он позволяет отдельным подшагам `5.2-5.4` строиться на уже принятой модели,
   не переоткрывая вопрос о non-null runtime scene.

## Что именно менять

### `lib/src/core/scene.dart`

[x] Явно зафиксировать через step/docs/tests, что nullable `backgroundLayer` у
    runtime `Scene` остаётся допустимой внутренней формой.
[x] Не переводить runtime `Scene` в always-present `backgroundLayer` без
    отдельного подтверждённого архитектурного основания.

### `lib/src/core/background_layer_invariants.dart`

[x] Зафиксировать `ensureBackgroundLayer(...)` как runtime utility, а не как
    механизм синхронизации двух разных источников истины.
[x] Проверить, что её использование остаётся локальным и осознанным на путях
    записи.

### `lib/src/contract/scene_data_exception.dart`

[x] Подтвердить достижимость `SceneDataErrorCode.multipleBackgroundLayers`.
[x] Если достижимый boundary не найден, удалить этот error code как мёртвую
    ветку контракта и отразить это в step/docs/tests.
[ ] Если достижимый boundary найден, явно закрепить, какой именно вход может
    породить ошибку и почему это не противоречит typed модели.

### `tool/invariant_registry.dart`

[x] Менять только если после решения по `backgroundLayer` нужно уточнить уже
    существующие invariants или убрать устаревшую формулировку.
[x] Не вводить новый invariant "на всякий случай", если существующие уже
    покрывают принятую модель.

## Критерии приемки

[x] Зафиксирована одна непротиворечивая модель:
    - runtime `Scene.backgroundLayer` остаётся nullable;
    - snapshot/JSON/encode boundary остаётся canonical non-null.
[x] `ensureBackgroundLayer(...)` описан как runtime utility, а не скрытый
    compensating sync layer.
[x] По `SceneDataErrorCode.multipleBackgroundLayers` принято решение на фактах:
    ветка либо подтверждена и локализована, либо удалена как мёртвая.
[x] Подшаг принимает policy-решение по `backgroundLayer`, но не вводит
    encode-oriented entrypoint `ScenePolicy` и не делает codec wiring.
[x] Подшаг не захватывает scope шага `6`: payload-size и codec guards сюда не
    перетаскиваются.

## Тестовый контур

[x] `test/core/background_layer_invariants_test.dart`
[x] `test/model/document_model_test.dart`
[x] `test/serialization/scene_codec_validation_test.dart`
[x] `dart run tool/check_invariant_coverage.dart` только если меняется
    `tool/invariant_registry.dart`
