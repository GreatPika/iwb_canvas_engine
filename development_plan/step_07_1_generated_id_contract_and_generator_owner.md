language: russian

# Шаг 7.1. Зафиксировать новый generated-id contract и owner `id_generator`

## Цель шага

Сначала нужно принять одно решение по generated ids, иначе все последующие
подшаги шага `7` будут строиться на плавающем основании. Сейчас в проекте
смешаны два разных смысла:

- public boundary принимает explicit `NodeId` / `LayerId` как обычные
  валидированные строки;
- runtime generation всё ещё выражена через public helper-ы
  `generateNodeId(int)` / `generateLayerId(int)` и старый формат
  `node-<n>` / `layer-<n>`.

Задача подшага: зафиксировать, что generated ids становятся внутренней
runtime-policy, определить роль `lib/src/core/id_generator.dart` как
единственного owner-а этой политики и явно удалить старый generated-id
contract, а не переносить его в новый слой.

## Что уже подтверждено по текущему состоянию

1. [ids.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/ids.dart)
   сейчас экспортирует `generateNodeId(...)`, `generateLayerId(...)`,
   `isGenerated*` и `tryParseGenerated*Seed(...)` как часть public surface.
2. [node_id_value.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/validated/node_id_value.dart)
   и
   [layer_id_value.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/validated/layer_id_value.dart)
   уже отделяют explicit value validation от generated-id helper-ов, но
   методы `generate(...)`, `isGeneratedLegacyFormat(...)` и
   `tryParseGeneratedSeed(...)` по-прежнему закрепляют старый seed-based
   format.
3. [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md)
   и
   [API_GUIDE.md](/Users/blackpika/iwb_canvas_engine/API_GUIDE.md)
   прямо документируют `node-<n>` / `layer-<n>` как текущую contract policy.
4. Runtime allocator фактически живёт не в одном owner-е, а размазан между
   `ids.dart`, `TxnContext`, `SceneStore` и `document_clone.dart`.

## Рекомендуемое решение

Рекомендуемый вариант: generated ids становятся purely internal runtime
concern, а public API перестаёт обещать seed-based generation helpers как
стабильную часть контракта.

Почему это лучший вариант:

1. Он убирает ложный public contract, который сейчас протаскивает legacy
   generation semantics в места, где нужен только explicit validated id.
2. Он позволяет `TxnContext` и `SceneStore` перейти на stateful allocator без
   обязательства сохранять `node-<n>` / `layer-<n>` как canonical runtime
   формат.
3. Он устраняет главный источник drift: generated-id policy больше не
   разносится между boundary helper-ами, scene-scan и transactional code.

Принятое решение по public helper-ам:

- оставить:
  - `parseNodeId(...)`
  - `parseLayerId(...)`
  - `NodeIdValue.parse(...)`
  - `NodeIdValue.of(...)`
  - `NodeIdValue.fromJson(...)`
  - `LayerIdValue.parse(...)`
  - `LayerIdValue.of(...)`
  - `LayerIdValue.fromJson(...)`
- удалить из public surface:
  - `generateNodeId(...)`
  - `generateLayerId(...)`
  - `isGeneratedNodeId(...)`
  - `isGeneratedLayerId(...)`
  - `tryParseGeneratedNodeIdSeed(...)`
  - `tryParseGeneratedLayerIdSeed(...)`
  - `NodeIdValue.generate(...)`
  - `LayerIdValue.generate(...)`
  - `NodeIdValue.isGeneratedLegacyFormat(...)`
  - `LayerIdValue.isGeneratedLegacyFormat(...)`
  - `NodeIdValue.tryParseGeneratedSeed(...)`
  - `LayerIdValue.tryParseGeneratedSeed(...)`

То есть public boundary сохраняет только explicit-id validation. Любая
generated-id logic после шага `7.1` живёт только во внутреннем
`id_generator.dart`.

Принятое решение по внутреннему generated-id format:

1. Точный строковый шаблон не фиксируется как часть плана или архитектурного
   контракта.
2. Generated ids после шага `7.1` обязаны оставаться:
   - string-compatible;
   - уникальными в пределах одного allocator session;
   - различимыми по type domain (`NodeId` против `LayerId`) на стороне owner-а
     генератора;
   - opaque для остального кода базы.
3. Вне `id_generator.dart` generated ids нельзя:
   - парсить;
   - классифицировать по внутреннему шаблону;
   - использовать для восстановления allocator state.
4. Конкретная строковая форма выбирается в `id_generator.dart` как
   implementation detail, если она удовлетворяет правилам выше.

Точная структура owner-а:

1. `lib/src/core/id_generator.dart` вводит mutable internal state
   `IdGeneratorState` со строго тремя полями:
   - `sessionToken`
   - `nextNodeCounter`
   - `nextLayerCounter`
2. `sessionToken` создаётся один раз на store bootstrap и сохраняется при
   `writeDocumentReplace(...)`, `txnAdoptScene(...)` и обычных commit-path.
3. `sessionToken` не сериализуется отдельно в snapshot/JSON и не
   восстанавливается из существующей сцены.
4. `nextNodeCounter` и `nextLayerCounter` начинаются с `1` и дальше растут
   только внутри allocator state.
5. Генератор делает collision check только как защитный барьер против
   пользовательских explicit id, но не как источник восстановления state.

Почему именно так:

1. `parse*` / `*.parse/of/fromJson` нужны на публичной границе, потому что они
   валидируют пользовательский и сериализованный explicit id. Это стабильная
   boundary-задача, не зависящая от того, как runtime сам генерирует новые id.
2. `generate*`, `isGenerated*` и `tryParseGenerated*` не описывают boundary
   значения пользователя; они описывают внутреннюю стратегию runtime
   allocation. Держать их в public surface означает навсегда зафиксировать
   внутренний формат generated ids как внешний контракт.
3. Пока generated-id helper-ы публичные, любой рефакторинг allocator-а
   автоматически становится breaking change для API_GUIDE, README и внешних
   клиентов. Это делает шаг `7.2` и любой следующий cleanup дороже без
   продуктовой пользы.
4. Удаление generated-id helper-ов из public surface уменьшает число owners:
   boundary валидирует explicit ids, а runtime генерирует свои ids. Между ними
   больше нет полускрытого "shared contract", который приходится синхронно
   поддерживать в нескольких слоях.
5. Хранить generated-id policy только во внутреннем `id_generator.dart`
   проще для тестирования: его можно проверять как isolated runtime owner,
   не размазывая одни и те же ожидания по public boundary tests.
6. Проблемой был не сам текстовый шаблон, а parsing-driven ownership. Поэтому
   полезно фиксировать не строковую форму, а свойства generated ids и границу
   owner-а.
7. Если жёстко зашить строковый шаблон в план, это снова превратит внутреннюю
   деталь allocator-а в псевдо-контракт, который потом сложнее менять без
   лишней миграции тестов и документации.
8. `sessionToken` в allocator state всё равно нужен, чтобы generation не
   зависела от scene-scan и внешних id. Но сам способ его кодирования в строке
   не должен становиться архитектурным обязательством.
9. UUID, base36, `prefix-counter` или другая форма допустимы только как
   implementation detail, если они не ломают свойства generated ids и не
   протекают в public contract.
10. Не встраивать `epoch`, `revision` или другой lifecycle-state внутрь id
   принципиально важно: id описывает identity, а не invalidation. Смешивание
   этих смыслов снова привело бы к скрытому sync glue между allocator и
   revision policy.

## Граница шага

- In:
  - решение по fate public generated-id helper-ов;
  - ввод `lib/src/core/id_generator.dart`;
  - фиксация ownership generated-id policy;
  - breaking cleanup документации и тестов, если public surface меняется.
- Out:
  - перенос store/txn/document на новый allocator state;
  - revision policy и overflow semantics;
  - render-cache invalidation.

## Последовательность реализации (только действия)

[x] Создать `lib/src/core/id_generator.dart` как единственный internal owner
    runtime generated ids.
[x] Зафиксировать в шаге и документации, что public boundary по-прежнему
    принимает explicit string-compatible `NodeId` / `LayerId`, но runtime
    generated ids больше не являются public compatibility promise.
[x] Удалить из public surface все generated-id helper-ы на `ids.dart` и
    `NodeIdValue` / `LayerIdValue`, оставив только explicit-id validation API.
[x] Обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`
    как часть breaking generated-id contract change.
[x] Обновить публичные и contract-level тесты так, чтобы они проверяли новый
    owner generated ids, а не старый seed-based format.

## Критерии приёмки

[x] Generated-id policy имеет одного owner-а:
    [id_generator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/id_generator.dart).
[x] Internal generated ids описаны через обязательные свойства, а не через
    публично зафиксированный строковый шаблон; allocator state хранится только
    в `IdGeneratorState`.
[x] Public API больше не содержит generated-id helper-ов; он содержит только
    explicit-id validation API.
[x] Explicit `NodeId` / `LayerId` validation остаётся отдельной boundary-задачей
    и не смешивается с runtime generation policy.
[x] Документация и public tests больше не закрепляют старый generated-id
    contract как обязательное поведение.

## Тестовый контур шага

[x] `test/public_api/validated_boundary_value_test.dart`
[x] `test/entrypoints/basic_smoke_test.dart`
[x] Новый targeted test для `lib/src/core/id_generator.dart`
[x] `dart run tool/check_public_api_surface.dart`
