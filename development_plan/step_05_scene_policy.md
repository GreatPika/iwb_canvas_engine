language: russian

# Шаг 5. Ввести единый `ScenePolicy`

## Цель шага

Этот шаг не про добавление ещё одного слоя валидации поверх уже существующих helper-ов, а про наведение одного владельца для scene-level policy. Сейчас правила сцены размазаны между `scene_builder.dart`, `scene_builder_canonicalize_validate.part.dart`, `scene_value_validation*.part.dart`, JSON decode-путём и сериализацией. Из-за этого один и тот же инвариант проверяется в нескольких местах, а `backgroundLayer` живёт в двух разных семантиках: обязательный в `SceneSnapshot`, но опциональный в mutable `Scene`. Задача шага: локализовать реальные дубли, собрать orchestration в одном месте и оставить primitive/node validators внутренними зависимостями, а не параллельным источником истины.

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как отдельный критерий готовности. Цель не "лечить числа", а проверять, что scene-level policy действительно уходит из giant validators и decode-orchestration.

- Смотреть в первую очередь `cyclomatic-complexity` и `source-lines-of-code`.
- Вторично смотреть `maximum-nesting-level`, если после разрезания logic flow остаётся трудно читаемым.
- Контрольные файлы:
  - `lib/src/model/scene_policy.dart`
  - `lib/src/model/scene_builder_decode_json.part.dart`
  - `lib/src/model/scene_builder_canonicalize_validate.part.dart`
  - `lib/src/model/scene_value_validation_node.part.dart`
  - `lib/src/model/scene_value_validation_top_level.part.dart`
- Полезный сигнал после шага: не остаётся giant top-level validators/decoders, которые одновременно владеют traversal, policy decision и error mapping, а новый `ScenePolicy` не превращается в ещё один central god-object.

## Что уже подтверждено по текущему состоянию

1. `lib/src/model/scene_builder.dart` сейчас собирает политику сцены из трёх независимых кусков:
   - `_validateStructuralInvariants(...)`;
   - `sceneValidateSnapshotValues(...)` / `sceneValidateSceneValues(...)`;
   - `_validateSnapshotRanges(...)`.
   Это уже прямой признак размазанного владения правилами.
2. Проверка уникальности `NodeId` и `LayerId` дублируется минимум в двух местах:
   - в `_validateStructuralInvariants(...)`;
   - в `scene_value_validation_top_level.part.dart`.
   Значит одно и то же ограничение сейчас поддерживается не одним владельцем.
3. Эти дубли не полностью эквивалентны по доменной семантике ошибок:
   - structural path для дубля `NodeId` бросает `SceneDataErrorCode.duplicateNodeId`;
   - top-level validation идёт через общий `invalidValue` reporter.
   То есть один и тот же дефект может проходить через разные error-code ветки в зависимости от boundary.
4. `SceneSnapshot` уже канонизирует `backgroundLayer` в обязательное поле через `backgroundLayer ?? BackgroundLayerSnapshot()`, тогда как `lib/src/core/scene.dart` всё ещё хранит `BackgroundLayer? backgroundLayer` как nullable runtime-состояние.
5. `lib/src/serialization/scene_codec.dart` в `encodeSceneDocument(...)` уже исходит из канонической формы и делает `canonicalScene.backgroundLayer!`, то есть encode-path фактически требует наличие background layer после валидации.
6. `lib/src/core/background_layer_invariants.dart` уже содержит `ensureBackgroundLayer(...)`, а runtime write-path местами опирается на ленивое создание слоя. Это подтверждает, что политика фона существует, но не выражена как единое правило системы.
7. В `tool/invariant_registry.dart` уже зафиксированы инварианты:
   - serialization keeps optional backgroundLayer separate from content layers;
   - snapshot/JSON boundaries canonicalize missing backgroundLayer to a single dedicated background layer.
   Значит шаг должен опираться на уже объявленные инварианты, а не придумывать новую модель.
8. `SceneDataErrorCode.multipleBackgroundLayers` существует в `lib/src/contract/scene_data_exception.dart`, но в typed runtime/snapshot модели нет структуры, которая могла бы представить "несколько backgroundLayer". Это выглядит как неподтверждённая или уже устаревшая ветка контракта.
9. Лимиты `kMax*` уже сосредоточены в `lib/src/core/scene_limits.dart`. Проблема не в отсутствии места для констант, а в том, что их использование распределено по нескольким validation-path.
10. Отдельный лимит размера JSON-входа действительно отсутствует, но это codec-boundary concern из `scene_codec.dart`, а не scene-level policy. Значит этот подпункт должен оставаться в Шаге 6, а не раздувать Шаг 5.

## Рекомендуемое решение

Рекомендуемый вариант: ввести `lib/src/model/scene_policy.dart` как единый scene-level orchestrator, но не превращать его в новый god-object с десятком публичных однотипных функций и не переносить в него всю low-level validation логику копированием.

Что это означает на практике:

1. `ScenePolicy` владеет только orchestration и boundary-семантикой:
   - import/snapshot validation;
   - runtime scene validation перед encode;
   - background layer canonicalization policy;
   - единая policy по counts/ranges/ids для сцены.
2. `scene_value_validation*.part.dart` остаются внутренними primitive/node validators, но перестают быть самостоятельным top-level policy entrypoint.
3. Проверка уникальности id, counts, ranges и background semantics получает одного владельца внутри `ScenePolicy`, а остальные места либо вызывают его, либо удаляются.
4. `ScenePolicy` не должен забирать на себя всё подряд:
   - `NodeSpec`/`NodePatch` правила остаются в своём validated/node validation слое;
   - JSON payload-size и decode guard остаются в codec boundary шага 6.

Почему это лучший вариант:

1. Он убирает реальное дублирование правил и расхождение error semantics, а не просто переименовывает текущие функции.
2. Он сохраняет один источник истины:
   - константы лимитов остаются в `scene_limits.dart`;
   - primitive/node validation остаётся в существующих helper-ах;
   - orchestration scene-level policy переезжает в `ScenePolicy`.
3. Он чище исходной идеи с двенадцатью равноправными `validate*` entrypoints, потому что не создаёт второй "мини-фреймворк" поверх уже существующих validator-ов.
4. Он позволяет отдельно и явно принять решение по `backgroundLayer`: где допускается `null`, где выполняется canonicalization, и какой runtime-contract считается нормой.

## Альтернатива, которую не рекомендуется брать

Не рекомендуется просто создать `scene_policy.dart` и механически перенести туда все текущие функции как есть, оставив старые `scene_value_validation_*` и builder-проверки параллельно жить рядом. Это даст новый файл, но не даст одного владельца правил. Не рекомендуется и обратная крайность: продолжать чинить точечно каждый call site без единого policy entrypoint, потому что дубли `duplicateNodeId/backgroundLayer` уже подтверждены кодом.

## Что именно менять

### `lib/src/model/scene_policy.dart`

[ ] Создать `lib/src/model/scene_policy.dart` как единый orchestrator scene-level policy.
[ ] Держать у него компактный boundary API, а не длинный список равноправных top-level функций:
    - `validateImportSnapshot(...)`;
    - `validateRuntimeScene(...)`;
    - `validateEncodeScene(...)` или один явно названный encode-oriented entrypoint, если отдельный encode path действительно нужен.
[ ] Вынести внутрь этого модуля одного владельца для:
    - structural invariants;
    - counts;
    - ranges;
    - id uniqueness;
    - background layer semantics.
[ ] Не переносить сюда `NodeSpec`/`NodePatch` как отдельную domain-обязанность, если после локализации выясняется, что они уже корректно живут в validated/node-layer и ScenePolicy только переиспользует их.
[ ] Зафиксировать в комментарии или doc contract, какие boundary использует этот policy:
    - snapshot import;
    - runtime scene canonicalization;
    - encode preflight.

### `lib/src/model/scene_builder.dart`

[ ] Убрать прямую сборку policy из `_validateStructuralInvariants(...)`, `sceneValidateSnapshotValues(...)` и `_validateSnapshotRanges(...)`.
[ ] Свести `sceneCanonicalizeAndValidateSnapshot(...)` и `sceneCanonicalizeAndValidateScene(...)` к вызову `ScenePolicy`, чтобы builder перестал быть вторым владельцем scene-level правил.
[ ] Сохранить builder ответственным за преобразование `snapshot <-> scene`, а не за ручное владение всеми validation-ветками.
[ ] Если часть текущих private helper-ов остаётся рядом с builder только как implementation detail, явно сократить их до thin adapter-ов или удалить.

### `lib/src/model/scene_builder_canonicalize_validate.part.dart`

[ ] Перенести или свести к thin wrapper-ам функции, которые сегодня владеют structural/range policy.
[ ] Убрать самостоятельную проверку дублей `NodeId/LayerId`, если её владельцем становится `ScenePolicy`.
[ ] Добиться одного детерминированного error-contract для:
    - duplicate node id;
    - duplicate content layer id;
    - range violations.
[ ] Если часть range-checks по-прежнему удобнее оставить рядом как pure helper-ы, оставить их internal-only и вызывать только из `ScenePolicy`.

### `lib/src/model/scene_value_validation.dart`

### `lib/src/model/scene_value_validation_primitives.part.dart`

### `lib/src/model/scene_value_validation_node.part.dart`

### `lib/src/model/scene_value_validation_top_level.part.dart`

[ ] Оставить эти файлы источником primitive/node checks, но убрать у них роль второго top-level policy entrypoint для всей сцены.
[ ] Убрать дубли top-level scene traversal там, где тот же обход уже делает `ScenePolicy`.
[ ] Свести проверки уникальности и background-related scene traversal к одному месту владения.
[ ] Сохранить reusable node-level проверки для `svgPathData`, text, transform, palette/grid и других примитивов без копирования логики в новый файл.
[ ] Если после локализации окажется, что часть top-level validation вообще больше не нужна, удалить её, а не оборачивать ещё одним вызовом.

### `lib/src/core/scene.dart` и `lib/src/core/background_layer_invariants.dart`

[ ] Явно принять одну внутреннюю политику для runtime `backgroundLayer`:
    - либо runtime `Scene` остаётся nullable и canonicalization гарантирует непустой dedicated background layer только на import/encode boundary;
    - либо runtime переводится на always-present background layer, если это реально упрощает остальной код без широкого побочного рефакторинга.
[ ] Выбрать вариант на основе текущего кода, а не вкусовщины:
    - если `null` всё ещё нужен для дешёвых runtime-операций, оставить nullable runtime и формально зафиксировать boundary-canonicalization;
    - если почти весь код уже требует фон и постоянно вызывает `ensureBackgroundLayer(...)`, рассмотреть перевод на non-null как отдельное осознанное изменение.
[ ] Довести `ensureBackgroundLayer(...)` до статуса явной runtime utility, а не скрытого компенсатора плавающей модели.
[ ] Подтвердить судьбу `SceneDataErrorCode.multipleBackgroundLayers`:
    - либо найти реальный boundary, где ошибка достижима и должна жить;
    - либо удалить код как мёртвый и убрать его из плана.

### `lib/src/core/scene_limits.dart`

[ ] Оставить `scene_limits.dart` единым местом для констант, не превращая его в policy-модуль.
[ ] Выровнять использование `kMax*` через `ScenePolicy` и reusable validators, а не через случайные ad hoc проверки в нескольких entrypoint-ах.
[ ] Не переносить сюда JSON payload-size policy: этот лимит должен жить в codec guard из Шага 6, если после проверки необходимость подтвердится.

### `lib/src/serialization/scene_codec.dart`

[ ] Подтвердить, что encode-path опирается на ту же policy-модель, что и snapshot/runtime validation, а не на отдельный набор предположений о каноничности сцены.
[ ] Перевести `encodeScene(...)` и `encodeSceneDocument(...)` на явный вызов encode-oriented scene policy, если сейчас они заходят в builder validation обходным путём.
[ ] Зафиксировать одну семантику `backgroundLayer` на serialization boundary:
    - snapshot/JSON всегда сериализуют dedicated background layer;
    - runtime nullable-форма, если она остаётся, не протекает наружу как второй внешний контракт.

## Конкретизация внедрения по порядку

1. Сначала подтвердить точный объём проблемы:
   - где именно дублируются scene-level правила;
   - какие error-code расхождения уже есть;
   - действительно ли `multipleBackgroundLayers` достижим.
2. Отдельно принять решение по модели `backgroundLayer`, потому что от него зависят и `ScenePolicy`, и builder, и serialization:
   - nullable runtime + canonical boundary;
   - или always-present runtime.
3. После этого ввести `scene_policy.dart` как единственную orchestration-точку для scene-level validation.
4. Затем перевести на неё:
   - `scene_builder.dart`;
   - `scene_builder_canonicalize_validate.part.dart`;
   - scene-level обходы из `scene_value_validation_top_level.part.dart`.
5. Только потом подчистить оставшиеся дубли:
   - единый owner для duplicate id;
   - единый owner для counts/ranges;
   - единый owner для background semantics.
6. В конце сверить serialization boundary и runtime boundary, чтобы `encodeScene*`, `decode/build` и in-memory validation описывали одну и ту же модель сцены.
7. Если по итогам локализации выяснится, что часть исходного шага относится к codec guard или validated boundary values, вынести её в Шаг 6 или соседние шаги, а не тащить всё в `ScenePolicy`.

## Критерии приемки

[ ] Для каждого заявленного риска Шага 5 явно указано, он подтверждён кодом или опровергнут; план больше не смешивает scene policy с codec guard scope.
[ ] В коде есть один явный владелец scene-level policy orchestration, а builder и serializer больше не собирают те же правила вручную из нескольких мест.
[ ] Проверка уникальности `NodeId` и `LayerId` имеет одного владельца и выдаёт детерминированный error-contract на всех релевантных boundary.
[ ] `scene_value_validation*.part.dart` больше не выступают вторым независимым top-level policy-слоем для сцены.
[ ] Политика `backgroundLayer` принята явно и непротиворечиво описывает:
   - runtime model;
   - snapshot/JSON canonicalization;
   - encode semantics.
[ ] Решение по `SceneDataErrorCode.multipleBackgroundLayers` принято на фактах: либо код достижим и покрыт, либо мёртвый контракт удалён.
[ ] `scene_limits.dart` остаётся источником констант, а не превращается в дублирующий policy-layer.
[ ] Шаг не захватывает чужой scope: JSON payload-size и codec guards остаются в Шаге 6, если именно там локализована проблема.

## Чеклист выполнения

[ ] Инвентаризировать все scene-level validation entrypoint-ы в `scene_builder.dart`, `scene_builder_canonicalize_validate.part.dart` и `scene_value_validation_top_level.part.dart`.
[ ] Для каждого дублирующего правила отметить: кто должен быть единственным владельцем после рефакторинга.
[ ] Подтвердить или опровергнуть достижимость `SceneDataErrorCode.multipleBackgroundLayers`.
[ ] Принять одно финальное решение по внутренней модели `backgroundLayer`.
[ ] Создать `lib/src/model/scene_policy.dart` с компактным boundary API для scene-level orchestration.
[ ] Перевести `sceneCanonicalizeAndValidateSnapshot(...)` и `sceneCanonicalizeAndValidateScene(...)` на `ScenePolicy`.
[ ] Убрать дублирующий обход сцены и проверки уникальности из лишних validation-path.
[ ] Выровнять error-code и `path` semantics для duplicate id и других scene-level policy ошибок.
[ ] Проверить, что encode-path использует ту же каноническую policy-модель сцены.
[ ] Явно вынести из Шага 5 всё, что после локализации относится к codec guards, а не к scene policy.
