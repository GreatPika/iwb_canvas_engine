
Этап: Этап 1. Публичный API и сценарий внешнего потребителя

Проверенная область:
lib/iwb_canvas_engine.dart
lib/src/api/**
lib/src/contracts/public/**
docs/contracts/public_api_v1.md
docs/_registry/public_api_v1.yaml
example/**
test/api/**
test/api_contract/**

Ограничение проверки:
В окружении отсутствуют dart/flutter CLI, поэтому analyzer, flutter pub get и тесты не запускались. Выводы ниже основаны на статическом чтении кода, контрактов, example и public-facing fixtures.

Итог:
Найдено 2 проблемы.

ID: API-001
Этап: Этап 1. Публичный API и сценарий внешнего потребителя
Название проблемы: Контракт CanvasToolPort.handleDoubleTap противоречит фактическому публичному поведению
Приоритет: P1
Вероятность проявления: R3
Краткое описание:
Документированный public API v1 утверждает, что прямой вызов CanvasToolPort.handleDoubleTap должен бросать UnsupportedError, не создавать context-action request и не иметь state/action/timestamp/diagnostics effects. Реализация делает обратное: публичный tool port вызывает RuntimeRoot.handleDoubleTap, runtime передаёт событие в interaction engine и при наличии intent публикует CanvasContextActionRequested. Public-facing тестовая fixture также ожидает успешный context request после прямого вызова handleDoubleTap.

Это делает публичный контракт недетерминированным для внешнего потребителя: приложение не может понять, является ли прямой double tap поддерживаемым API для context actions/text editing или запрещённым методом, который должен быть заменён другим entrypoint.

Доказательство в коде:
docs/contracts/public_api_v1.md:1769-1772:
`CanvasToolPort.handleDoubleTap` должен бросать UnsupportedError и не иметь request/state/action/timestamp/DiagnosticsHub effect.

docs/contracts/public_api_v1.md:2350-2354:
повторно зафиксировано, что unsupported direct CanvasToolPort.handleDoubleTap бросает UnsupportedError и не создаёт request/state/action/timestamp effect.

lib/src/runtime/runtime_root.dart:1331-1343:
RuntimeRoot.handleDoubleTap вызывает _interactionEngine.handleDoubleTap(...), а затем _emitContextRequest(intent), если intent != null.

lib/src/runtime/runtime_root.dart:2448-2450:
_RuntimeToolPort.handleDoubleTap напрямую прокидывает публичный вызов в root.handleDoubleTap(...), без UnsupportedError.

test/api/fixtures/tool_port_settings_fixture.dart:156-166:
fixture вызывает runtime.tools.handleDoubleTap(position: const Offset(1, 1)) и ожидает, что requests имеет длину 1.

Пользовательский или инженерный сценарий проявления:
Внешний разработчик строит Flutter surface или собственный gesture adapter вокруг публичного CanvasRuntime. Он читает public_api_v1.md и реализует double tap через другой путь, потому что handleDoubleTap документирован как unsupported. После обновления или интеграции с example/tests оказывается, что фактический runtime ожидает прямой handleDoubleTap как producer context-action request. Обратный сценарий также реалистичен: разработчик использует handleDoubleTap по фактическому поведению, но contract/API docs требуют UnsupportedError, поэтому downstream-код опирается на поведение, которое формально не является стабильным.

Почему это не теоретический edge case:
Double tap является обычным пользовательским действием для context actions и text editing. Метод находится на публичном CanvasToolPort, вызывается через runtime.tools и уже используется public-facing fixture. Вероятность проявления R3, потому что любой прямой вызов handleDoubleTap сталкивается с одним из двух несовместимых контрактов.

Рекомендуемое исправление:
Выбрать один канонический public API contract.

Вариант A, если прямой handleDoubleTap должен быть поддерживаемым public API:
- обновить docs/contracts/public_api_v1.md;
- удалить утверждения про UnsupportedError/no-effect;
- явно описать, что handleDoubleTap является context-action request producer;
- зафиксировать async delivery semantics, timestamp semantics, diagnostics behavior и dispose behavior;
- убедиться, что docs/_registry/public_api_v1.yaml отражает поддерживаемый метод.

Вариант B, если прямой handleDoubleTap действительно должен быть unsupported:
- изменить _RuntimeToolPort.handleDoubleTap так, чтобы он бросал UnsupportedError с documented message;
- не вызывать RuntimeRoot.handleDoubleTap из public tool port;
- перенести production context-action request в разрешённый surface/interaction entrypoint;
- обновить test/api fixtures, которые сейчас ожидают request от прямого вызова.

Минимальная проверка после исправления:
Добавить public-only contract test, импортирующий только package:iwb_canvas_engine/iwb_canvas_engine.dart.

Для варианта A:
- создать runtime с документом;
- подписаться на runtime.contextActionRequests;
- вызвать runtime.tools.handleDoubleTap(...);
- проверить ровно один CanvasContextActionRequested и отсутствие внутренних imports.

Для варианта B:
- вызвать runtime.tools.handleDoubleTap(...);
- проверить UnsupportedError;
- проверить, что contextActionRequests не получил event;
- проверить, что document, selection, preview, timestamp и diagnostics не изменились.


ID: API-002
Этап: Этап 1. Публичный API и сценарий внешнего потребителя
Название проблемы: Публичный CanvasPointerSample не позволяет представить documented invalid terminal cleanup
Приоритет: P1
Вероятность проявления: R2
Краткое описание:
Контракт public API v1 говорит, что pointer position должна быть finite для down/move, а invalid terminal samples должны маршрутизироваться в cleanup logic. Но публичная фабрика CanvasPointerSample валидирует position без учёта phase и отклоняет non-finite Offset для любых фаз, включая up и cancel. В результате внешний потребитель не может создать terminal sample, который контракт обещает обработать как cleanup signal.

Дополнительно surface adapter также отбрасывает любой PointerEvent с non-finite localPosition до создания CanvasPointerSample, включая up/cancel. Это усиливает проблему на публичной границе: terminal cleanup, описанный в public API, фактически недостижим через стандартный surface path.

Доказательство в коде:
docs/contracts/public_api_v1.md:1774-1783:
validation contract: pointer position -> finite for down/move; invalid terminal samples are routed to cleanup logic.

lib/src/contracts/public/canvas_pointer.dart:92-103:
CanvasPointerSample factory всегда вызывает validateOffset(position, path: 'pointer.position') до создания sample, независимо от phase.

lib/src/surface/pointer_adapter.dart:35-39:
CanvasSurfacePointerAdapter._route возвращается без routeSample, если localPosition не finite, независимо от того, является ли phase down/move/up/cancel.

lib/src/surface/pointer_adapter.dart:41-48:
только после finite-check создаётся CanvasPointerSample и передаётся в routeSample.

Пользовательский или инженерный сценарий проявления:
Внешний потребитель реализует собственный pointer adapter или использует CanvasSurfaceWidget. Во время drag/preview platform layer или transform даёт terminal cancel/up событие без finite localPosition. Контракт обещает, что invalid terminal sample будет использован для cleanup. На практике public API либо не даёт создать такой CanvasPointerSample, либо surface adapter молча отбрасывает событие. Активная pointer/session cleanup логика не получает terminal signal через documented public path.

Почему это не теоретический edge case:
Pointer cancel/up при потере pointer stream, detach/rebuild surface, некорректной coordinate conversion или synthetic platform event — реалистичный lifecycle-сценарий для Flutter integration. Контракт специально описывает invalid terminal cleanup, значит этот сценарий считается частью API surface, а не произвольным out-of-contract вводом.

Рекомендуемое исправление:
Сделать validation CanvasPointerSample phase-aware.

Возможная реализация:
- для CanvasPointerLifecyclePhase.down и CanvasPointerLifecyclePhase.move оставить обязательный validateOffset(position);
- для CanvasPointerLifecyclePhase.up и CanvasPointerLifecyclePhase.cancel разрешить documented invalid terminal representation;
- либо добавить отдельный публичный constructor/factory, например CanvasPointerSample.terminalCleanup(...), который не требует finite position и явно выражает cleanup-only terminal event;
- обновить CanvasSurfacePointerAdapter так, чтобы non-finite up/cancel не отбрасывались молча, а маршрутизировались как terminal cleanup;
- сохранить rejection для non-finite down/move.

Также нужно синхронизировать docs/contracts/public_api_v1.md с фактической моделью: либо invalid terminal cleanup действительно поддерживается public API, либо этот пункт должен быть удалён из public contract.

Минимальная проверка после исправления:
Добавить public-only contract test:
- создать CanvasPointerSample с phase cancel или up и non-finite position через documented public API;
- передать sample в runtime.tools.handlePointer(...);
- проверить, что вызов не бросает validation exception;
- проверить, что active preview/session cleanup выполняется согласно public contract.

Добавить surface-level public boundary test:
- смоделировать terminal PointerCancelEvent или PointerUpEvent с non-finite localPosition;
- проверить, что adapter не теряет terminal cleanup event;
- проверить, что routeSample вызывается cleanup-safe representation.
```

```text
Этап 2. Контракт JSON schema v1, codec и загрузка документа

Метод проверки:
Статический анализ репозитория. Тесты не запускались: в окружении не обнаружены dart/flutter CLI.

Проверенная область:
lib/src/codec/**
lib/src/edit/staged_document_load.dart
lib/src/store/schema_v1_store_import.dart
lib/src/api/canvas_codec.dart
docs/contracts/schema_v1.md
docs/contracts/codec_boundary.md
docs/contracts/load_document.md
docs/contracts/validation_limits.md
test/codec/**
релевантные store/load fixtures

ID: CODEC-001
Этап: Этап 2. Контракт JSON schema v1, codec и загрузка документа
Название проблемы: Runtime JSON load не применяет агрегатный лимит metadata на весь документ
Приоритет: P1
Вероятность проявления: R2
Краткое описание:
Контракт schema v1 задаёт лимит “max total encoded metadata bytes per document -> 1MB”. Public DTO-путь применяет этот лимит в CanvasDocument, но runtime load path специально не материализует CanvasDocument и поэтому может принять JSON, где каждая отдельная metadata-map валидна, но суммарный metadata budget документа превышен. В результате runtime может успешно загрузить документ, который затем невозможно безопасно спроецировать через readDocument() без позднего CanvasDataException.

Доказательство в коде:
docs/contracts/schema_v1.md:246-254 описывает агрегатный лимит metadata на документ.
docs/contracts/validation_limits.md:61-73 и 103-106 требуют применять metadata limits на schema v1 JSON validation/import.
lib/src/contracts/public/canvas_document.dart:51 вызывает _validateDocumentMetadataBudget(...), а lib/src/contracts/public/canvas_document.dart:263-304 суммирует document/resource/element/layer metadata и отклоняет total > canvasMetadataMaxEncodedBytes.
lib/src/edit/staged_document_load.dart:125-158 строит runtime load через importSchemaV1DocumentFromJsonIntoIsolatedSink(...) и _store.prepareSchemaV1Import(...), не через CanvasDocument.
lib/src/edit/staged_document_load.dart:57-61 явно запрещает материализацию CanvasDocument в PreparedDocumentLoad.
lib/src/codec/schema_v1_import_emitter.dart:77-133 и 138-215 валидируют/эмитят resources/layers/elements, но не накапливают общий metadata byte budget.
lib/src/codec/schema_v1_import_emitter.dart:1387-1403 применяет CanvasMetadata.fromMap(...) только к отдельной metadata-map.
lib/src/store/schema_v1_store_import.dart:87-130 собирает CommittedDocument из import tables без агрегатной проверки metadata.
lib/src/store/document_projection_cache.dart:28-47 позже строит CanvasDocument из CommittedDocument; именно здесь агрегатный DTO-лимит снова может сработать уже после успешной загрузки.

Пользовательский или инженерный сценарий проявления:
Пользователь импортирует schema v1 JSON, сгенерированный внешним инструментом: например, 20 элементов, у каждого metadata содержит строку около 60KB. Каждая отдельная metadata-map проходит CanvasMetadata.fromMap(...), raw JSON остаётся меньше 32MB, но суммарно metadata превышает 1MB. loadDocumentFromJson(...) может завершиться успешно и заменить текущий документ, а последующий runtime.readDocument() или encode/read projection падает из-за aggregate metadata budget.

Почему это не теоретический edge case:
Metadata — документированная extension area schema v1. Импорт JSON из внешних источников является основным сценарием codec/load boundary. Для превышения лимита не нужны экстремальные размеры: достаточно десятков элементов с допустимой по отдельности metadata.

Рекомендуемое исправление:
Добавить агрегатор metadata byte budget в runtime import path до store install. Практически: во время _validateSchemaV1ImportEvents(...) или во время StoreSchemaV1ImportBuilder.prepare(...) суммировать canvasMetadataEncodedByteLength(...) для document metadata, resource metadata, layer metadata и element metadata. Если total > canvasMetadataMaxEncodedBytes, выбрасывать CanvasDataException(code: invalidMetadata, path: 'metadata') до consume/install. Не полагаться на последующую CanvasDocument projection как на validation boundary.

Минимальная проверка после исправления:
Добавить тест runtime load:
1. Создать runtime с валидным предыдущим документом.
2. Сформировать schema v1 JSON с несколькими элементами, где каждая metadata-map меньше 1MB, но суммарно metadata > 1MB.
3. Вызвать runtime.edits.loadDocumentFromJson(json).
4. Проверить CanvasDataException.invalidMetadata.
5. Проверить, что предыдущий document/revision/camera/selection не изменились.
6. Проверить, что runtime.readDocument() после failed load возвращает предыдущий документ без исключения.


ID: CODEC-003
Этап: Этап 2. Контракт JSON schema v1, codec и загрузка документа
Название проблемы: Default palette в codec/load не совпадает с canonical schema v1 shape
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
schema_v1.md описывает canonical JSON shape с непустыми default palette values: шесть penColors, четыре backgroundColors и gridSizes [10.0, 20.0, 40.0, 80.0]. В коде CanvasPalette.defaults() содержит пустые списки, а decode/load отсутствующего palette тоже материализует пустую palette. Поэтому новый CanvasDocument() или минимальный JSON {"schemaVersion":1} кодируются/загружаются не в соответствии с документированным canonical shape.

Доказательство в коде:
docs/contracts/schema_v1.md:39-58 показывает canonical JSON shape, где palette содержит:
penColors: ["#FF000000", "#FFE53935", "#FF1E88E5", "#FF43A047", "#FFFB8C00", "#FF8E24AA"]
backgroundColors: ["#FFFFFFFF", "#FFFFF9C4", "#FFBBDEFB", "#FFC8E6C9"]
gridSizes: [10.0, 20.0, 40.0, 80.0]
lib/src/contracts/public/canvas_document.dart:15-23 подставляет CanvasPalette.defaults(), если CanvasDocument.palette == null.
lib/src/contracts/public/canvas_document.dart:239-242: CanvasPalette.defaults() задаёт _penColors = [], _backgroundColors = [], _gridSizes = [].
lib/src/codec/schema_v1_encoder.dart:54-59 пишет palette из document.palette без добавления documented defaults.
lib/src/codec/schema_v1_import_emitter.dart:469-502 при отсутствующем palette читает пустые списки через _readColorList/_readDoubleList.
lib/src/codec/schema_v1_decoder.dart:213-250 делает аналогично для internal decode path.

Пользовательский или инженерный сценарий проявления:
Внешний потребитель создаёт CanvasDocument() и вызывает encodeCanvasDocumentToJson(...). Полученный JSON содержит пустую palette, хотя контракт schema v1 показывает canonical default palette как непустую. Другой сценарий: пользователь загружает минимальный schema v1 JSON {"schemaVersion":1}; runtime принимает документ с пустой palette, после чего UI/consumer, ожидающий documented default colors/grid sizes, получает пустые lists.

Почему это не теоретический edge case:
Создание нового пустого документа и загрузка минимального schema v1 JSON уже покрыты как базовые сценарии. Вероятность высокая, потому что CanvasDocument() без explicit palette — естественный public DTO path, а {"schemaVersion":1} уже принимается тестами как валидный минимальный документ.

Рекомендуемое исправление:
Выбрать один источник истины и синхронизировать код/контракт. Если текущий schema_v1.md является authoritative:
- изменить CanvasPalette.defaults() на documented default colors/gridSizes;
- изменить schema v1 decode/import defaulting так, чтобы отсутствующий palette использовал CanvasPalette.defaults(), а не пустые lists;
- оставить encoder как writer фактической palette.
Если пустая palette является intended design, обновить docs/contracts/schema_v1.md, public_api_v1.md и example/default fixtures, чтобы canonical shape не обещал непустые defaults.

Минимальная проверка после исправления:
Добавить codec/load тесты:
1. encodeCanvasDocument(CanvasDocument())['palette'] совпадает с documented canonical default palette.
2. runtime.edits.loadDocumentFromJson('{"schemaVersion":1}') затем runtime.readDocument().palette содержит те же default values.
3. encode → decode/load → encode для default document стабилен и не превращает documented defaults в пустые списки.
```


```text
Основание проверки: стратегия код-ревью, Этап 3 — Store, edit kernel, commit semantics и revision model. fileciteturn0file0

ID: EDIT-001
Этап: Этап 3. Store, edit kernel, commit semantics и revision model
Название проблемы: Materialized edit commit может публиковать resource descriptors со старой revision
Приоритет: P1
Вероятность проявления: R2
Краткое описание:
В materialized-пути commit применяется документ, обёрнутый в CommittedDocument с нулевым RevisionState, а уже затем store продвигает верхнеуровневые revisions через revisionDelta. Из-за этого embedded ResourceTable внутри CommittedDocument может сохранить descriptors с resourceRevision = 0, хотя committed document/frame revisions уже продвинуты. Для ресурсов это опасно: frame/runtime видят новую resourceRevision документа, но descriptor, который уходит в asset resolving/cache key, может остаться на старой revision.

Доказательство в коде:
lib/src/edit/commit_applier.dart:
- _installAcceptedDocument(...) для AcceptedMaterializedDocument создаёт:
  final storeDocument = CommittedDocument(document);
- затем вызывает replaceDocument(storeDocument, revisionDelta) или installDocument(storeDocument, revisionDelta).

lib/src/store/committed_document.dart:
- factory CommittedDocument(CanvasDocument document) создаёт CommittedDocument.withRevisions(document, revisions: const RevisionState()).
- ResourceTable строится с resourceRevision: revisions.resourceRevision.
- Следовательно, materialized document получает ResourceTable с resourceRevision = 0.

lib/src/store/document_store_kernel.dart:
- installDocument(...) и replaceDocument(...) вызывают document.copyWith(revisions: delta.advance(_document.revisions)).
- Они продвигают revisions у CommittedDocument, но не перестраивают ResourceTable descriptors под уже принятый accepted resource revision.

Для сравнения, sparse-путь делает это корректнее:
lib/src/store/document_store_kernel.dart:
- _upsertResource(...) передаёт revision: acceptedRevisions.resourceRevision в resourceTable.upsert(...).

Это важно для downstream frame/resource pipeline:
lib/src/runtime/runtime_root.dart:
- resource descriptor facts передают StoreResourceDescriptorFacts.resourceRevision дальше во frame facts.

lib/src/frame/paint_asset_binding_service.dart:
- descriptor.resourceRevision используется в ResourceImageResolveRequest.

lib/src/resources/surface_resource_session.dart:
- ImageResolveCacheKey включает resourceRevision.
- Если descriptor остался на revision 0, image cache может вернуть stale asset для изменённого ресурса.

Пользовательский или инженерный сценарий проявления:
1. Runtime содержит документ с image resource id = r.
2. Пользователь выполняет edit, который заставляет materialized path, например:
   - внутри edit callback вызывает edit.readDraftDocument(), а затем edit.upsertResource(...), или
   - replaceDraftDocument(...) заменяет документ/ресурсы.
3. Commit успешно принимается, root/frame revisions показывают, что resource revision изменилась.
4. Descriptor ресурса всё ещё несёт старую revision.
5. Rendering/resource bridge может запросить или закешировать asset как r@0 вместо r@1.

Почему это не теоретический edge case:
Materialized path — нормальный публичный путь edit kernel, потому что draft materialization включается при readDraftDocument()/replaceDraftDocument(). Ресурсы являются частью supported document state, а resourceRevision явно используется в cache key. Это не экстремальный ввод и не нарушение предыдущей границы: обычное редактирование ресурса после materialized draft достаточно для проявления.

Рекомендуемое исправление:
Не создавать CommittedDocument для materialized accepted document с const RevisionState().

Вариант исправления:
1. В materialized commit заранее вычислять acceptedRevisions = revisionDelta.advance(currentRevisions).
2. Создавать committed representation так:
   CommittedDocument.withRevisions(document, revisions: acceptedRevisions)
3. Либо перенести materialized installation в store-level API, который строит CommittedDocument уже с accepted revisions и одним источником истины для RevisionState/ResourceTable.

Менее предпочтительный вариант:
- В installDocument(...)/replaceDocument(...) после advance revisions перестраивать embedded ResourceTable descriptors под новые revisions. Это хуже, потому что store принимает уже неконсистентный CommittedDocument и исправляет его постфактум.

Минимальная проверка после исправления:
Добавить тест materialized resource commit:
1. Создать runtime/store с документом и image resource r.
2. Выполнить edit:
   - вызвать edit.readDraftDocument();
   - затем edit.upsertResource(CanvasImageResource(id: r, source: updatedAppKey)).
3. Проверить:
   - commit success;
   - document/resource/frame revision продвинулась ровно на 1;
   - root/resource descriptor для r имеет resourceRevision == accepted resourceRevision;
   - asset resolve request использует эту новую revision, а не 0.
4. Повторить аналогичный тест для replaceDraftDocument(...) с resource table.


ID: EDIT-002
Этап: Этап 3. Store, edit kernel, commit semantics и revision model
Название проблемы: Net-no-op edit может продвигать revisions и публиковать effects без фактического изменения документа
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
Commit delta сейчас накапливается по промежуточным операциям, а не по финальному diff между исходным committed document и итоговым document facts. Поэтому edit, который меняет состояние туда и обратно в рамках одного commit, может быть принят как mutating commit: revisions продвигаются, touched/effects публикуются, listeners получают обновление, хотя итоговый документ равен исходному.

Доказательство в коде:
lib/src/edit/draft_document.dart:
- addElement(...) всегда добавляет touched added id и вызывает structural mark.
- removeElement(...) всегда добавляет touched removed id и вызывает structural mark.
- setBackgroundColor(...), setGrid(...), setPalette(...), setCamera... сравнивают новое значение только с текущим mutable draft state, но не с исходным committed base.
- Если значение меняется A -> B -> A в одном edit, intermediate deltas уже накоплены.

lib/src/edit/edit_session.dart:
- sparse path аналогично journal-based:
  - addElement(...) добавляет StoreSparseAddElement и structural delta;
  - removeElement(...) добавляет StoreSparseRemoveElement и structural delta;
  - setBackgroundColor(...), setPalette(...), setCamera... добавляют sparse mutations и revision delta на основании промежуточного изменения.
- Нет финальной нормализации sparse overlay относительно исходного store.

lib/src/store/document_store_kernel.dart:
- prepareSparseCommit(...) применяет mutations последовательно.
- didMutateFacts становится true, если хотя бы одна промежуточная mutation что-то изменила.
- Затем accepted document получает advanced revisions через accumulated revisionDelta.
- Проверки “final nextDocument facts == previous document facts” перед публикацией нет.

Контрактный риск:
docs/contracts/edit_kernel.md описывает различие между accepted edit и no-op edit: no-op не должен публиковать новое состояние. Этап 3 также требует, чтобы revision state менялся только при фактическом изменении документа.

Пользовательский или инженерный сценарий проявления:
Сценарий 1:
edit.setBackgroundColor(black);
edit.setBackgroundColor(originalWhite);

Сценарий 2:
edit.addElement(tempElement, layerId: existingLayer);
edit.removeElement(tempElement.id);

Сценарий 3:
edit.setPalette(customPalette);
edit.setPalette(CanvasPalette.defaults());

В каждом случае итоговое состояние может совпадать с состоянием до edit, но commit будет выглядеть как mutating: revisions/effects/listeners/cache invalidation сработают.

Почему это не теоретический edge case:
Такие net-no-op операции возникают в реальных editor flows:
- пользователь начал drag/preview/update и вернулся в исходную позицию;
- tool создал временный элемент и отменил его внутри одного edit callback;
- UI применил optimistic setting и затем вернул прежнее значение;
- batching layer сгенерировал несколько операций, которые взаимно компенсировались.
Revision-based consumers — autosave, sync, undo grouping, repaint scheduling, projection cache invalidation — будут видеть ложное изменение документа.

Рекомендуемое исправление:
RevisionDelta и commit effects должны определяться по финальному изменению committed facts, а не только по журналу операций.

Возможные варианты:
1. В prepareSparseCommit(...) после применения sparse mutations сравнить итоговые facts с исходными:
   - background;
   - grid;
   - palette;
   - camera;
   - element registry/order/family rows;
   - resource descriptors;
   - metadata/document-level facts.
   Если финальных изменений нет, вернуть no-op commit без revision advance и без publish effects.

2. Для sparse journal добавить canonicalization:
   - set A -> B -> A схлопывать в отсутствие mutation;
   - add new element -> remove same element схлопывать в отсутствие structural mutation;
   - upsert resource old -> new -> old схлопывать в отсутствие resource mutation.

3. Для materialized DraftDocument path хранить base document/revisions и перед install вычислять final diff against base. Не доверять accumulated draft delta как единственному источнику истины.

Минимальная проверка после исправления:
Добавить тесты:
1. setBackgroundColor(new); setBackgroundColor(original):
   - commit result должен быть no-op или success without mutation, согласно принятой модели;
   - documentRevision/backgroundRevision не меняются;
   - state listener не получает новое published state;
   - frame/cache revision не меняется.

2. addElement(temp); removeElement(temp.id):
   - element отсутствует;
   - structural/document/projection revisions не меняются;
   - touched added/removed не публикуются как committed effect.

3. setPalette(custom); setPalette(default):
   - paletteRevision не меняется;
   - cache invalidation не происходит.

4. При наличии public diagnostics/result model проверить, что операция не возвращает диагностически “успешный mutating edit”, если фактического изменения нет.


ID: EDIT-003
Этап: Этап 3. Store, edit kernel, commit semantics и revision model
Название проблемы: Контракт edit taxonomy расходится с кодом и тестами для CanvasElementUpdate.isSelectable
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
Для update поля isSelectable документация edit kernel классифицирует spatial effect как none, но compiler и тесты считают изменение isSelectable spatial mutation. С учётом того, что spatial entry фактически исключает non-selectable элементы из hit membership, поведение кода выглядит оправданным, но written contract противоречит executable contract. Это делает commit semantics неоднозначной: будущий разработчик может “исправить” код под документацию и сломать hit/spatial consistency, либо обновить тесты без обновления контракта.

Доказательство в коде:
docs/contracts/edit_kernel.md:
- taxonomy для CanvasElementUpdate.isSelectable указывает spatial effect: none.

lib/src/edit/element_update_compiler.dart:
- update taxonomy выставляет touchesSpatial: delta.bounds || before.isSelectable != after.isSelectable.

test/edit/fixtures/edit_matrix_effects_fixture.dart:
- кейс CanvasElementUpdate.isSelectable ожидает touchesSpatial: true.

lib/src/geometry/spatial_entry.dart:
- spatial entry admission зависит от facts.isSelectable.
- non-selectable элемент не попадает в spatial candidate membership.
- Следовательно, изменение isSelectable действительно влияет на spatial index/hit membership.

Пользовательский или инженерный сценарий проявления:
Разработчик меняет isSelectable у элемента:
- если code path следует текущему compiler/test behavior, spatial index invalidation происходит;
- если будущий refactor будет следовать docs/contracts/edit_kernel.md, spatial invalidation может быть убрана;
- после этого hit-testing может продолжить видеть старую membership: non-selectable элемент останется selectable candidate или selectable элемент не попадёт в spatial index до полного rebuild.

Почему это не теоретический edge case:
isSelectable — обычное редактируемое свойство элемента. Spatial index используется для выбора/hit-testing, а commit semantics/touched sets управляют тем, что именно инвалидируется после edit. Несогласованность уже присутствует в трёх местах: contract, compiler и fixture.

Рекомендуемое исправление:
Выбрать один authoritative contract.

Наиболее согласованный с текущей архитектурой вариант:
1. Обновить docs/contracts/edit_kernel.md и docs/contracts/operation_matrix.md:
   - CanvasElementUpdate.isSelectable должен иметь spatial effect, потому что влияет на spatial hit membership.
2. Оставить compiler behavior touchesSpatial: before.isSelectable != after.isSelectable.
3. Добавить contract guard test, который защищает taxonomy от повторного расхождения с executable fixture.

Альтернативный вариант, если документация считается истинной:
1. Убрать isSelectable из spatial admission/membership.
2. Обеспечить фильтрацию selectable на другом уровне hit-test pipeline.
3. Тогда убрать touchesSpatial для isSelectable из compiler/tests.
Этот вариант выглядит более рискованным, потому что текущая geometry implementation уже использует isSelectable как spatial admission fact.

Минимальная проверка после исправления:
1. Тест update isSelectable true -> false:
   - spatial candidate для элемента удаляется или перестаёт возвращаться hit query.
2. Тест update isSelectable false -> true:
   - spatial candidate появляется без полного reload документа.
3. Contract/test guard:
   - taxonomy в документации или registry не должна расходиться с _UpdateTaxonomyCase / element update compiler для spatial effects.


Проверенная область:
- lib/src/edit/**, кроме staged_document_load.dart как codec/load boundary этапа 2;
- lib/src/store/**;
- docs/contracts/edit_kernel.md;
- docs/contracts/cache_policy.md;
- docs/contracts/operation_matrix.md;
- test/edit/**;
- test/store/**.

Что именно было проверено:
- commit application path: sparse и materialized;
- revisionDelta propagation;
- touched/effects construction;
- resource table revision propagation;
- element update compiler;
- конфликтующие updates одного элемента;
- projection/document cache invalidation через revision facts;
- immutable/stale edit handle behavior на уровне edit session;
- store sparse mutation preparation;
- релевантные тестовые fixtures для edit/store effects.

Оставшиеся неопределённости:
- Dart/Flutter toolchain в окружении проверки недоступен, поэтому тесты не запускались. Выводы основаны на статическом чтении кода, контрактов и тестовых fixtures.
- stage 2 load boundary, stage 5 interaction tools, stage 6 geometry correctness и stage 7 rendering behavior отдельно не оценивались, кроме мест, где они являются прямыми downstream-потребителями store/edit revisions.
```

```text
Формат и область проверки: этап 4 из стратегии код-ревью. fileciteturn0file0
Проверка: статическое ревью runtime composition / ownership / lifecycle по `lib/src/runtime/**`, `lib/src/api/canvas_runtime.dart`, runtime surface/frame bridges, runtime-related docs и runtime tests.
Ограничение проверки: `dart` и `flutter` SDK в среде отсутствуют, поэтому тесты не запускались.

ID: RUNTIME-002
Этап: Этап 4. Runtime composition, ownership и lifecycle состояния
Название проблемы: Runtime timestamp cursor расходуется для runtime outputs, которые затем suppress/cancel и не должны создавать timestamp
Приоритет: P2
Вероятность проявления: R2

Краткое описание:
Контракт timestamp говорит, что no-op, cancel, resolver cancel, load cleanup и dispose cleanup остаются timestamp-silent. Но runtime timestamp cursor сейчас мутируется сразу при вызове `RuntimeActionFinalizer.reserveTimestamp(...)`. Этот метод используется для tentative outputs: queued context-action requests и selected-move resolver requests. Если такой output потом suppress/cancel, cursor уже продвинут, хотя публичного события или принятого результата нет.

В результате следующий реальный runtime-created timestamp может “перепрыгнуть” значение из-за события, которое по контракту должно быть timestamp-silent.

Доказательство в коде:
- Контракт timestamp: runtime владеет одним cursor; no-op/cancel/load cleanup/dispose cleanup/resolver cancel не создают timestamped outputs и остаются timestamp-silent: `docs/contracts/public_api_v1.md:1433-1471`.
- Operation matrix повторяет, что no-op, stale, invalid, cancel, resolver cancel, rollback, load cleanup и dispose cleanup не resolve action/request timestamps: `docs/contracts/operation_matrix.md:158-166`.
- `RuntimeActionFinalizer.reserveTimestamp(...)` сразу вызывает `_resolveTimestamp(...)`, а `_resolveTimestamp(...)` сразу записывает `_timestampCursor = resolved`: `lib/src/runtime/runtime_action_finalizer.dart:14-16`, `lib/src/runtime/runtime_action_finalizer.dart:35-39`.
- Direct double tap resolve-ит timestamp до передачи request в runtime queue: `lib/src/interaction/interaction_engine.dart:294-299`; context tap через pointer делает то же: `lib/src/interaction/interaction_engine.dart:966-969`.
- Runtime потом только queue-ит уже timestamped request и доставляет его позже через microtask: `lib/src/runtime/runtime_root.dart:1745-1759`.
- Successful load cleanup suppresses queued request через interaction cleanup / generation bump: `lib/src/runtime/runtime_root.dart:1552-1558`; существующий тест проверяет, что queued request не доставлен, но не проверяет, что timestamp cursor не был потрачен: `test/runtime/fixtures/load_interaction_cleanup_fixture.dart:225-238`.
- Selected move с resolver резервирует timestamp до вызова resolver: `lib/src/runtime/runtime_root.dart:1791-1803`.
- Если resolver возвращает `CanvasMoveCancel()` или нулевой delta, runtime делает cleanup и `return`, но зарезервированный timestamp уже записан в cursor: `lib/src/runtime/runtime_root.dart:1808-1811`.
- Тесты покрывают “resolver cancel cleans preview without action”, но не проверяют timestamp cursor после cancel: `test/interaction/fixtures/move_machine_fixture.dart:961-974`.

Пользовательский или инженерный сценарий проявления:
Сценарий 1: пользователь double tap по элементу, runtime queue-ит context request с `timestampMs: 10`, затем приложение сразу загружает новый документ. Request suppresses, но cursor уже стал 10. Следующее реальное действие с `timestampMs: null` получит 11 вместо ожидаемого первого/следующего значения без учёта suppressed request.

Сценарий 2: app-level `moveCommitResolver` запрещает move и возвращает `CanvasMoveCancel()`. Пользовательского action нет, document не меняется, но следующий action timestamp будет учитывать отменённый resolver request.

Почему это не теоретический edge case:
Оба пути уже представлены в тестах как реальные lifecycle/interaction сценарии: queued context request suppression on load и resolver cancel. Недостаёт именно проверки cursor continuity после suppressed/cancelled output. Это не экстремальный timing case, а обычное поведение async stream delivery и app-level move resolver.

Рекомендуемое исправление:
Разделить вычисление candidate timestamp и commit timestamp cursor.

Возможные варианты:
1. Ввести tentative reservation API в `RuntimeActionFinalizer`, например `beginTimestamp(hint)` → `{value, commit(), discard()}`. Cursor обновляется только в `commit()`.
2. Для queued context-action requests хранить не готовый `CanvasContextActionRequested`, а pending intent/request builder с timestamp hint. Финализировать timestamp только в момент фактической доставки request в stream. Если load/dispose/tool cleanup suppresses pending request, timestamp reservation не создаётся.
3. Для selected move resolver request использовать tentative timestamp. Если resolver возвращает `CanvasMoveCommit` с ненулевым delta и commit path продолжается, reservation commit-ится; если resolver возвращает `CanvasMoveCancel`, zero delta или cleanup/no-op path, reservation discard-ится.
4. Добавить explicit tests на cursor после suppressed queued context request и resolver cancel.

Минимальная проверка после исправления:
- Test A: вызвать `handleDoubleTap(... timestampMs: 10)`, затем successful `loadDocumentFromJson(...)` до microtask delivery, затем выполнить первое реальное action с `timestampMs: null`; проверить, что action timestamp не стал 11 из-за suppressed context request.
- Test B: настроить `moveCommitResolver: (_) => const CanvasMoveCancel()`, выполнить selected move terminal с `timestampMs: 10`, затем выполнить следующее реальное action с `timestampMs: null`; проверить, что timestamp cursor не учитывает cancelled resolver path.
- Test C: сохранить существующее поведение accepted resolver path: resolver request timestamp и последующий move action timestamp остаются монотонными и различимыми.


```text
Этап 5. Interaction engine, pointer tools и preview/commit flow

Проверенная область:
lib/src/interaction/**
lib/src/api/canvas_pointer.dart
lib/src/api/canvas_tools.dart
lib/src/api/canvas_preview.dart
lib/src/runtime/runtime_root.dart в части доставки pointer/context/text-edit interaction intents
lib/src/runtime/runtime_interaction_read_adapter.dart в части interaction read facts
docs/contracts/interaction_engine.md
docs/diagrams/state_pending_context_action_request.mmd
docs/contracts/operation_matrix.md
test/interaction/**
test/selection/** в части scenarios через tools

Ограничение проверки:
Dart-тесты в среде не запускались; вывод основан на статическом чтении кода, контрактов и существующих тестовых фикстур.

---

ID: INTERACTION-001
Этап: Этап 5. Interaction engine, pointer tools и preview/commit flow
Название проблемы: Marquee/point selection может закоммитить selection по недостоверному spatial query
Приоритет: P1
Вероятность проявления: R2

Краткое описание:
Marquee selection и tap-to-select принимают `MarqueeCommitFacts` даже тогда, когда associated query сообщает `staleIndex`, `budgetExceeded` или содержит unresolved/skipped candidates. В таком случае `nextSelectedIds` может быть пустым или неполным, но `SelectMachine.terminal(...)` всё равно создаёт `MarqueeCommitIntent`, если текущий selection отличается от этого результата. Пользовательский эффект — selection может быть очищен или заменён на неполный набор из-за недостоверного hit/selection read.

Доказательство в коде:
lib/src/runtime/runtime_interaction_read_adapter.dart:171-202:
`marqueeCommitFacts(...)` строит `nextSelectedIds` из результата spatial query и возвращает `query: interactionQueryFacts(query, candidates)`, но не отклоняет не-candidates / stale / budget / skipped cases.

lib/src/runtime/runtime_interaction_read_adapter.dart:205-238:
zero-area point-selection path делает то же самое для tap selection.

lib/src/interaction/interaction_engine.dart:1130-1140:
`_tryMarqueeSelectionTapTerminal(...)` вызывает `_recordQueryDiagnostics(facts.query)`, но затем всё равно передаёт `facts` в `_selectMachine.terminal(...)`.

lib/src/interaction/interaction_engine.dart:1479-1496:
`_handleMarqueeTerminal(...)` аналогично только записывает diagnostics и затем допускает terminal decision.

lib/src/interaction/select_machine.dart:35-54:
`SelectMachine.terminal(...)` проверяет только `selectionRevision`, `controllerEpoch` и равенство ids. Статус `facts.query.status` и `facts.query.skippedCandidateCount` не участвуют в admission.

test/interaction/fixtures/interaction_read_port_fixture.dart:320-340:
существующий тест фиксирует ситуацию `budgetExceeded` с `nextSelectedIds == empty`, но не проверяет, что pointer terminal должен отказаться от selection commit.

Пользовательский или инженерный сценарий проявления:
Пользователь работает с большим canvas. У него выделен объект. Он кликает по canvas или тянет marquee в области, где spatial query превышает бюджет или spatial index временно stale. Read adapter возвращает пустой `nextSelectedIds` вместе с `budgetExceeded`/`staleIndex`. InteractionEngine записывает diagnostic, но selection commit всё равно проходит и очищает выделение.

Почему это не теоретический edge case:
`InteractionReadQueryStatus.budgetExceeded`, `staleIndex` и `skippedCandidateCount` являются явными моделями в коде, а не гипотетическими состояниями. Для large-document сценариев budgetExceeded уже покрыт тестовой фикстурой. Пользовательский ущерб не ограничен диагностикой: selection state реально может измениться.

Рекомендуемое исправление:
Ввести единый admission gate для selection terminal facts:
- разрешать commit только при `facts.query.status == InteractionReadQueryStatus.candidates`;
- требовать `facts.query.skippedCandidateCount == 0`;
- для `staleIndex`, `budgetExceeded`, `invalidIndex` и unresolved candidates возвращать cleanup-only без selection mutation, action timestamp и selection action;
- diagnostics оставлять, но не совмещать “diagnostic rejection” с фактическим commit.

Минимальная проверка после исправления:
Добавить тест pointer-flow уровня:
1. Есть текущий selection `[element-a]`.
2. Выполняется tap или marquee terminal.
3. Fake `InteractionReadPort.marqueeCommitFacts(...)` возвращает `previousSelectedIds: [element-a]`, `nextSelectedIds: []`, `query: budgetExceeded` или `staleIndex`.
4. Проверить: admission cleanup-only/no-op, selection остаётся `[element-a]`, `CanvasActionType.selectMarquee` не эмитится, timestamp не резервируется, diagnostic записан.

---

ID: INTERACTION-002
Этап: Этап 5. Interaction engine, pointer tools и preview/commit flow
Название проблемы: Context action target admission допускает unresolved/skipped spatial candidates
Приоритет: P1
Вероятность проявления: R1

Краткое описание:
Context-action read path отклоняет `invalidIndex`, `staleIndex` и `budgetExceeded`, но не отклоняет candidate query, в котором часть spatial handles не удалось разрешить во frame facts. В результате topmost target вычисляется по неполному списку candidates. Если unresolved candidate был реальным верхним объектом, direct/pending context action может быть создан для нижнего объекта или для empty canvas.

Доказательство в коде:
lib/src/runtime/runtime_interaction_read_mapping.dart:21-45:
`resolveInteractionCandidates(...)` пропускает handle, если `resolve(handle)` возвращает `null`, и увеличивает `skippedCandidateCount`.

lib/src/runtime/runtime_interaction_read_adapter.dart:399-423:
`_contextTargetFacts(...)` отклоняет только случаи, где `interactionQueryHasCandidates(query)` false. `skippedCandidateCount` не проверяется.

lib/src/runtime/runtime_interaction_read_adapter.dart:426-465:
`_admittedContextTarget(...)` вычисляет `topmostContextHit(...)` по уже отфильтрованным `candidates.handles`; если hit не найден, возвращает admitted empty-canvas target.

lib/src/interaction/interaction_engine.dart:899-908:
`_admittedContextTargetFacts(...)` пишет query diagnostics только для `RejectedContextTargetRead`. Если read adapter вернул `AdmittedContextTargetRead` с `query.status == candidates` и `skippedCandidateCount > 0`, diagnostic rejection не произойдёт.

docs/contracts/interaction_engine.md:332-339:
контракт требует, чтобы context action request появлялся только после accepted context-action target и candidate spatial admission; rejected stale/budget reads не должны эмитить request.

Пользовательский или инженерный сценарий проявления:
Spatial index содержит stale handle верхнего элемента, а frame facts уже не может его разрешить. Пользователь делает double-tap по верхнему объекту. Read adapter пропускает unresolved верхний handle и выбирает нижний объект или empty canvas. Host получает `CanvasContextActionRequested` для неправильной цели и может открыть меню или inline text editor не на том объекте.

Почему это не теоретический edge case:
Код уже моделирует unresolved candidates через `skippedCandidateCount`, а diagnostics layer имеет путь `recordStaleCandidateRejected(...)` для skipped candidates. Значит состояние считается достижимым и диагностируемым. Ошибка именно в том, что context-action admission не использует этот сигнал как rejection gate.

Рекомендуемое исправление:
В `_contextTargetFacts(...)` считать context target reliable только при:
`queryFacts.status == InteractionReadQueryStatus.candidates && queryFacts.skippedCandidateCount == 0`.
Иначе возвращать `RejectedContextTargetRead(query: queryFacts)`, чтобы InteractionEngine записал bounded diagnostics и не эмитил request.

Минимальная проверка после исправления:
Добавить тест для direct context action:
1. Spatial query возвращает candidates, но один top-order handle не разрешается во frame facts.
2. `RuntimeInteractionReadAdapter.directContextTargetFacts(...)` должен вернуть `RejectedContextTargetRead`.
3. `CanvasToolPort.handleDoubleTap(...)` не должен эмитить `CanvasContextActionRequested`.
4. Для skipped candidates должен появиться bounded stale-candidate diagnostic, если это предусмотрено diagnostic policy.

---

ID: INTERACTION-004
Этап: Этап 5. Interaction engine, pointer tools и preview/commit flow
Название проблемы: Direct handleDoubleTap bypasses mode/active-session guards и конфликтует с state diagram
Приоритет: P2
Вероятность проявления: R2

Краткое описание:
Direct `CanvasToolPort.handleDoubleTap(...)` может создать context-action request в draw mode и даже при активной pointer preview/session. При этом engine-owned pointer-sample path для context tap проверяет move mode. Контрактная state diagram говорит, что active pointer conflict или wrong mode должны игнорироваться. В тестах текущее поведение, наоборот, закреплено как допустимое, поэтому здесь есть конфликт между contract diagram, реализацией и test expectations.

Доказательство в коде:
docs/diagrams/state_pending_context_action_request.mmd:14-15:
direct double-tap допускается из Idle, а `active pointer conflict` / `wrong mode` ведут в Idle без request.

docs/diagrams/state_pending_context_action_request.mmd:86-87:
pending context tap должен уходить в cleanup-only при mode mismatch / mode change / interactive=false.

lib/src/interaction/interaction_engine.dart:275-302:
`handleDoubleTap(...)` проверяет только finite position, очищает pending context tap и сразу делает `directContextTargetFacts(...)`. Нет проверки `_mode == CanvasInteractionMode.move` и нет проверки `_activeSession == null`.

lib/src/interaction/interaction_engine.dart:1202-1213:
engine-owned pointer-sample context tap path, наоборот, явно требует `_mode == CanvasInteractionMode.move`.

test/api/fixtures/tool_port_settings_fixture.dart:162-166:
тест ожидает, что после `runtime.tools.setMode(CanvasInteractionMode.draw)` direct double tap всё равно создаст один context request.

test/interaction/fixtures/eraser_context_action_routing_fixture.dart:367-390:
тест ожидает, что direct double tap при активном pencil preview/session вернёт request и сохранит active preview.

Пользовательский или инженерный сценарий проявления:
Пользователь находится в draw mode и рисует stroke. Host-level double-tap recognizer вызывает `handleDoubleTap(...)`. Engine создаёт context action request, хотя pointer tool находится не в selection/context mode и есть активный drawing preview. Если application автоматически запускает inline text edit по context request, пользователь может получить text editing/menu во время drawing interaction.

Почему это не теоретический edge case:
`CanvasToolPort.handleDoubleTap(...)` — публичный direct host-recognized API. Flutter host может вызывать его независимо от текущего tool mode. Существующие тесты прямо покрывают draw-mode и active-preview сценарии.

Рекомендуемое исправление:
Сначала выбрать и зафиксировать единственный контракт:
- если direct context action должен быть move/idle-only, добавить в `InteractionEngine.handleDoubleTap(...)` guard:
  `_mode == CanvasInteractionMode.move && _activeSession == null`;
  rejected path не должен читать target, резервировать timestamp или эмитить request;
  обновить тесты, которые сейчас ожидают request в draw/active-preview state;
- если mode-independent direct double-tap является намеренным поведением, обновить `state_pending_context_action_request.mmd` и contract text, явно описав, что direct host double-tap может работать поверх draw/active preview и какие isolation guarantees при этом действуют.

Минимальная проверка после исправления:
Для варианта move/idle-only:
1. В draw mode вызвать `tools.handleDoubleTap(...)` — request stream остаётся пустым, timestamp не резервируется.
2. В move mode с active pointer session вызвать direct double tap — request не создаётся, active preview/session не ломается.
3. В move mode без active session direct double tap по content/empty canvas по-прежнему создаёт ровно один request.
```

```text
Проверенная область:
lib/src/geometry/**
lib/src/api/canvas_geometry.dart
lib/src/api/canvas_transform_admission.dart
lib/src/contracts/public/canvas_geometry.dart
lib/src/contracts/public/canvas_transform_admission.dart
docs/contracts/geometry.md
docs/contracts/spatial_kernel.md
docs/contracts/validation_limits.md
test/geometry/**
test/spatial/**

Ограничение проверки:
Тесты не запускались: в среде проверки отсутствуют dart/flutter. Выводы ниже основаны на статическом чтении кода и контрактов.

ID: GEOMETRY-001
Этап: Этап 6. Geometry, transforms, hit-testing и spatial index
Название проблемы: Валидный transform может привести к exception в hit-testing из-за валидации производного inverse-transform
Приоритет: P1
Вероятность проявления: R2
Краткое описание:
CanvasTransform.invert() создаёт inverse через публичный factory CanvasTransform(...). Этот factory повторно применяет публичные coordinate limits к translation inverse-transform. Для валидного element transform с малым допустимым scale и обычной translation inverse translation легко выходит за [-1e7, 1e7], после чего point hit/context hit/path hit/eraser path могут бросить CanvasDataException вместо корректного hit/miss.

Доказательство в коде:
lib/src/contracts/public/canvas_geometry.dart:14-26 — публичный CanvasTransform factory вызывает _validateCanvasTransform(...).
lib/src/contracts/public/canvas_geometry.dart:144-162 — CanvasTransform.invert() возвращает CanvasTransform(...), то есть проходит через тот же валидирующий public factory.
lib/src/contracts/public/canvas_geometry.dart:214-217 — _validateCanvasTransform(...) валидирует translation через validateOffset(...).
lib/src/contracts/public/canvas_value_validators.dart:179-191 — validateOffset(...) ограничивает dx/dy диапазоном coordinate limits.
lib/src/contracts/public/canvas_contract_limits.dart:18-25 — coordinate limit равен [-1e7, 1e7], transform singular-value limits допускают min scale 1e-4.
lib/src/geometry/hit_test_policy.dart:193-214 — _hitBox(...) вызывает facts.transform.invert() без catch.
lib/src/geometry/hit_test_policy.dart:513-524 — _hitPath(...) вызывает facts.transform.invert() без catch.
lib/src/geometry/hit_test_policy.dart:462-478 — _eraserHitsPath(...) вызывает facts.transform.invert() без catch.

Пользовательский или инженерный сценарий проявления:
Создать валидный rect/text/path с transform:
CanvasTransform(a: 1e-4, b: 0, c: 0, d: 1e-4, tx: 2000, ty: 0)
Такой transform проходит admission: scale == 1e-4 находится на нижней разрешённой границе, translation 2000 находится внутри coordinate limit. При клике в точке Offset(2000, 0) hit-test вызывает invert(). Inverse имеет tx = -2000 / 1e-4 = -20_000_000, что выходит за public coordinate limit, поэтому CanvasTransform(...) внутри invert() бросает исключение.

Почему это не теоретический edge case:
Сценарий использует только разрешённые контрактом значения: scale 1e-4 и координату 2000. Это не экстремальная координата и не повреждённый документ. Пользовательский эффект — невозможность выбрать или вызвать context action для валидного элемента на canvas.

Рекомендуемое исправление:
Не использовать публичный валидирующий CanvasTransform factory для внутренних geometry inverse-вычислений. Добавить внутренний unchecked/geometry-only inverse helper, например:
- tryInvertForGeometry(CanvasTransform) -> nullable private affine coefficients/record;
- applyInverseToPointForGeometry(transform, point);
- local scene-padding mapping на основе этих coefficients.
Проверять только finite determinant, determinant != 0 и finite derived coefficients. Public element transform admission при этом оставить строгим.

Минимальная проверка после исправления:
Добавить geometry test:
1. Создать FrameElementFacts rect size 10x10 с transform CanvasTransform(a: 1e-4, b: 0, c: 0, d: 1e-4, tx: 2000, ty: 0).
2. Проверить, что HitTestPolicy().exactHit(point: Offset(2000, 0), facts: rect) не бросает exception и возвращает true.
3. Повторить для exactContextHit и для path/text, где inverse используется тем же путём.

ID: GEOMETRY-003
Этап: Этап 6. Geometry, transforms, hit-testing и spatial index
Название проблемы: Invalid-index fallback обходит query tile budget
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
Для валидного индекса query tile budget применяется в TileIndex.query. Но если SpatialKernelQueryState.isInvalid == true, runQuery сразу уходит в invalid fallback и проверяет только indexedEntryCount против kCanvasMaxFallbackCandidates. Размер query window и kCanvasMaxQueryCells в этой ветке не проверяются. В результате over-budget spatial window может вернуть fallback candidates или invalid-index result вместо SpatialBudgetExceededResult(queryTileBudgetExceeded).

Доказательство в коде:
lib/src/geometry/tile_index.dart:52-60 — валидный TileIndex.query возвращает SpatialBudgetExceededResult при queryTileCount > kCanvasMaxQueryCells.
lib/src/geometry/spatial_kernel_query_state.dart:36-50 — invalid branch выполняется до обычного query и проверяет только context.indexedEntryCount > kCanvasMaxFallbackCandidates.
lib/src/geometry/spatial_kernel_query_state.dart:76-95 — _invalidFallbackResult(...) может вернуть SpatialCandidatesResult из fallbackCandidates, не проверяя spatialTileCountFor(context.window.boundsWorld).
docs/contracts/spatial_kernel.md:98-105 — hot path contract требует typed budget-exceeded result при query tile count > 50000, без partial candidates и без mutation.

Пользовательский или инженерный сценарий проявления:
После failed spatial touched update или lazy document replacement index находится в invalid/rebuildNeeded состоянии. Следующий paint/marquee query приходит с очень большим viewport/query rect, покрывающим больше 50000 spatial cells. Вместо queryTileBudgetExceeded kernel может вернуть fallback candidates, если entryCount <= 4096.

Почему это не теоретический edge case:
Invalid index — documented recovery path и покрывается test/spatial/fixtures/invalid_index_fallback_fixture.dart. Большой viewport или большой marquee/corridor также является реальным canvas-сценарием. Нарушается именно заявленный spatial query budget contract.

Рекомендуемое исправление:
В SpatialKernelQueryState.runQuery либо перед вызовом runQuery в SpatialKernel._queryIndex добавить общий preflight:
- вычислить spatialTileCountFor(context.window.boundsWorld);
- если count > kCanvasMaxQueryCells, записать non-hub budget counter и вернуть SpatialBudgetExceededResult(reason: queryTileBudgetExceeded);
- выполнить это до invalid fallback и до выдачи fallback candidates.
При этом не мутировать indexes.

Минимальная проверка после исправления:
Добавить spatial test:
1. Создать SpatialKernel с <= 4096 entries.
2. Перевести его в invalid state через failed touched update.
3. Выполнить queryHit/queryPaint с Rect.fromLTWH(0, 0, kCanvasSpatialCellSize * 225, kCanvasSpatialCellSize * 225).
4. Проверить SpatialBudgetExceededResult с reason == queryTileBudgetExceeded и queryTileBudgetExceededCount == 1.
5. Проверить, что SpatialCandidatesResult не возвращается.
```

```text
ID: FRAME-001
Этап: Этап 7. Frame rendering, paint planning и cache invalidation
Название проблемы: Overlay frame захватывает full main-frame snapshot вместо минимальных overlay facts
Приоритет: P1
Вероятность проявления: R3
Краткое описание:
Overlay path построен через тот же CapturedFrameSnapshot, что и main frame. Из-за этого overlay-only repaint для marquee/pencil/line/eraser preview выполняет spatial query, читает selection facts, background, committed element facts, resource descriptors и потенциально инициирует text layout measurement. Это нарушает контракт разделения main/overlay frame и переносит main-scene работу в горячий overlay-путь.

Доказательство в коде:
docs/contracts/frame_rendering.md:85-94 описывает CapturedOverlayFrame только как previewRevision, viewCameraRevision, viewCameraOffset, previewState, selectionStyle.
docs/contracts/frame_rendering.md:152-160 указывает, что OverlayPreviewPlanner владеет immutable overlay primitives и не должен владеть resource resolver reads, cache invalidation или selected-move rendering.
docs/contracts/frame_rendering.md:175-178 отдельно фиксирует, что overlay preview primitives admitted from CapturedOverlayFrame и painter не перечитывает live style state.
lib/src/frame/frame_capture_service.dart:40-49 captureOverlayFrame(...) вызывает _captureSnapshot(inputs).
lib/src/frame/frame_capture_service.dart:52-81 _captureSnapshot(...) читает frameRevisions, selectionFacts, выполняет _queryPaint(...), собирает capturedHandles, elements, resourceDescriptors, background и spatialPaintCandidates.
lib/src/frame/frame_capture_service.dart:109-145 _resolvedElementsAndDescriptors(...) вызывает _frameFacts.resolveElement(...) и _frameFacts.resourceDescriptor(...).
lib/src/runtime/runtime_root.dart:545-604 RuntimeRoot.resolveElement(...) собирает FrameElementFacts, включая measuredTextLayout.
lib/src/runtime/runtime_root.dart:688-715 _measuredTextLayoutFor(...) выполняет text layout measurement для text elements.
test/frame/fixtures/main_overlay_capture_fixture.dart:76-77 строит main и overlay capture, а затем test/frame/fixtures/main_overlay_capture_fixture.dart:115-132 ожидает, что overlay.snapshot содержит spatialPaintCandidates и что frameFacts/background/resource/selection/spatial reads выполнены дважды.

Пользовательский или инженерный сценарий проявления:
Пользователь ведёт marquee selection, pencil stroke, marker stroke, line preview или eraser preview поверх большого документа. Каждый overlay frame, который визуально должен зависеть только от preview и captured selection style, дополнительно проходит spatial query и resolve committed rows. Если в viewport есть text elements, overlay path может также вызвать text layout measurement. Если есть image elements, overlay capture читает resource descriptors, хотя overlay painter эти ресурсы не использует.

Почему это не теоретический edge case:
Overlay preview обновляется на обычных pointer move событиях. Это не редкий импортный или ошибочный сценарий, а основной интерактивный hot path. В репозитории текущий тест уже закрепляет поведение с двумя spatial queries и двумя resourceDescriptor reads для main+overlay capture, то есть проблема не гипотетическая — она является текущей архитектурной формой overlay rendering.

Рекомендуемое исправление:
Разделить capture-модели. captureOverlayFrame(...) не должен вызывать _captureSnapshot(...). Ввести отдельный минимальный overlay snapshot/inputs, например CapturedOverlayFrame с полями previewRevision, viewCameraRevision/viewCameraOffset, overlayPreview и captured selectionStyle. Overlay capture не должен обращаться к FrameFactsPort.resolveElement, FrameFactsPort.resourceDescriptor, background, selection facts и spatial query. Если marquee нужен selectionStyle, брать его из FrameCaptureInputs как immutable captured style. Main-frame capture оставить full snapshot.

Минимальная проверка после исправления:
Добавить тест с fake FrameFactsPort, SelectionFactsPort и SpatialPaintQuery counters:
1. вызвать captureOverlayFrame(...) с CanvasMarqueePreview;
2. проверить, что overlayPreview построен и style captured;
3. проверить, что spatialQueries == 0, resolveElementReads == 0, resourceDescriptorReads == 0, backgroundReads == 0, selectionFacts.reads == 0;
4. проверить, что captureMainFrame(...) по-прежнему выполняет full main capture.


ID: FRAME-002
Этап: Этап 7. Frame rendering, paint planning и cache invalidation
Название проблемы: MainFramePainter и OverlayFramePainter не ограничивают paint output границами surface
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
Main и overlay painters рисуют в translated world-space без clipRect по размеру CustomPaint. Selection decoration, marquee, stroke/line/eraser preview или selected chrome, выходящие за viewport, могут попасть за пределы CanvasSurface и визуально загрязнить соседние Flutter widgets, если родитель явно не клиппит child.

Доказательство в коде:
lib/src/surface/main_painter.dart:15-26 MainFramePainter.paint(...) рисует прозрачный rect в размере surface, затем делает canvas.save(), canvas.translate(...), drawPicture(...), paintMainFrameRecordsAndSelectionDecorations(...), canvas.restore(); clipRect отсутствует.
lib/src/surface/overlay_painter.dart:15-23 OverlayFramePainter.paint(...) делает canvas.save(), canvas.translate(...), рисует overlay primitives и restore; clipRect отсутствует.
lib/src/surface/canvas_surface_widget.dart:198-203 CanvasSurfaceWidget создаёт CustomPaint с MainFramePainter и OverlayFramePainter, но не оборачивает paintHost в ClipRect.
lib/src/frame/frame_capture_service.dart:84-107 _capturedHandles(...) добавляет selectedIds к captured handles даже если selected element не пришёл из spatialCandidates viewport.
lib/src/frame/selection_decoration_planner.dart:149-203 SelectionDecorationPlanner строит chrome из всех selected records, присутствующих в snapshot, без viewport clipping.
lib/src/frame/overlay_preview_planner.dart:142-167 overlay primitives берут preview rect/points/start/end/corridor как есть, без clipping.

Пользовательский или инженерный сценарий проявления:
CanvasSurface находится в Row, Stack или рядом с toolbar/sidebar. Пользователь выделяет объект около края или тянет marquee/stroke/eraser за пределы видимого canvas. Painter переводит world coordinates в surface coordinates, но не клиппит вывод к Offset.zero & size. В результате stroke halo, selection decoration или overlay preview может быть отрисован поверх соседнего UI.

Почему это не теоретический edge case:
Жесты, выходящие за границы viewport, и selection chrome около края — обычные canvas-сценарии. Код уже допускает primitives с boundsWorld вне viewport: selected IDs специально добавляются в frame snapshot независимо от spatial candidates, а overlay preview берёт live preview geometry напрямую. Без clip на painter/surface boundary корректность зависит от внешнего родителя, который не является частью frame contract.

Рекомендуемое исправление:
Добавить clipping на surface paint boundary:
- в MainFramePainter.paint(...) после canvas.save() выполнить canvas.clipRect(Offset.zero & size), затем canvas.translate(...);
- в OverlayFramePainter.paint(...) аналогично clipRect до translate;
- либо гарантированно обернуть paintHost в ClipRect внутри CanvasSurfaceWidget, но painter-level clip предпочтительнее как локальная защита frame/surface paint output.
Нужно проверить порядок: clip должен применяться в surface coordinates до translate, чтобы world-space painting ограничивался видимой областью CustomPaint.

Минимальная проверка после исправления:
Добавить widget/pixel test:
1. разместить CanvasSurface/CustomPaint размером 100x100 внутри parent 200x100 без внешнего ClipRect;
2. создать selection decoration или overlay marquee/stroke, который выходит за x=100;
3. проверить, что пиксели в parent area x>100 остаются неизменными;
4. отдельно проверить, что внутри 0..100 visible portion продолжает рисоваться.


ID: FRAME-003
Этап: Этап 7. Frame rendering, paint planning и cache invalidation
Название проблемы: Fallback bounds для path/text/stroke рисуются в неправильной системе координат
Приоритет: P2
Вероятность проявления: R1
Краткое описание:
main_frame_record_painter.dart применяет record.transform, а затем в fallback branches для path, text и stroke рисует record.paintBoundsWorld. paintBoundsWorld уже находится в world coordinates, поэтому внутри локального transform fallback rect может быть трансформирован повторно или смещён неверно. Image fallback использует localBounds и тем самым демонстрирует правильную модель.

Доказательство в коде:
lib/src/frame/main_frame_record_painter.dart:96-131 _paintPathRecord(...) вызывает _withRecordTransform(...), а при path == null рисует _paintFallbackBounds(canvas, record.paintBoundsWorld, ...).
lib/src/frame/main_frame_record_painter.dart:133-152 _paintTextRecord(...) вызывает _withRecordTransform(...), а при entry == null рисует _paintFallbackBounds(canvas, record.paintBoundsWorld, ...).
lib/src/frame/main_frame_record_painter.dart:154-181 _paintStrokeRecord(...) вызывает _withRecordTransform(...), а при !painted рисует _paintFallbackBounds(canvas, record.paintBoundsWorld, ...).
lib/src/frame/main_frame_record_painter.dart:220-229 _withRecordTransform(...) применяет record.transform.toCanvasTransform() до paintLocalRecord().
lib/src/frame/main_frame_record_painter.dart:45-67 _paintImageRecord(...) в аналогичной fallback ветке рисует localBounds, рассчитанный из row.size, уже внутри _withRecordTransform(...).
lib/src/frame/render_element_record.dart:148-149 хранит paintBoundsWorld и hitBoundsWorld как world-space bounds, а не local bounds.

Пользовательский или инженерный сценарий проявления:
Для transformed text/path/stroke record render primitive snapshot не содержит нужный TextLayoutCacheEntry, PathGeometryCacheEntry или StrokePathCacheEntry. Painter должен показать degraded fallback bounds, но вместо bounds элемента рисует rect в world coordinates под уже применённым transform. Пользователь видит placeholder не там, где находится элемент, либо placeholder с неверным масштабом/поворотом.

Почему это не теоретический edge case:
Fallback branches являются production paint code, а не test-only assert. Они существуют именно для degraded rendering при отсутствующей primitive cache entry. Для path это достижимо при null normalizedPath/cache entry; для text/stroke это может проявиться при неполном RenderPrimitiveCacheSnapshot, ручном использовании painter boundary в тестах/tools или будущем partial frame output. Даже если нормальный FrameEngine обычно bindAll(...) заполняет snapshot, fallback-политика должна быть пространственно корректной.

Рекомендуемое исправление:
Унифицировать fallback coordinate model:
- либо добавить в RenderElementRecord локальные paint bounds, например paintBoundsLocal, и использовать их во всех fallback ветках внутри _withRecordTransform(...);
- либо рисовать record.paintBoundsWorld вне _withRecordTransform(...), если fallback intentionally world-space;
- для image/rect/path/text/stroke fallback явно зафиксировать одну политику: local geometry под transform или world geometry без transform.
Предпочтительно хранить local fallback bounds вместе с row-specific render data, чтобы painter не восстанавливал геометрию формулами.

Минимальная проверка после исправления:
Добавить painter test:
1. создать transformed TextRenderRow/PathRenderRow/StrokeRenderRow с non-identity transform и paintBoundsWorld;
2. передать RenderPrimitiveCacheSnapshot.empty;
3. отрисовать в PictureRecorder;
4. проверить, что fallback rect совпадает с ожидаемым world-space положением элемента после одного применения transform, а не с повторно transformed paintBoundsWorld.


Ограничение проверки:
Ревью выполнено статически по файлам этапа 7. Dart/Flutter test suite не запускался, потому что в контейнере отсутствуют команды dart и flutter.
```

```text
Этап 8. Resources, resolver lifecycle и asset consistency

Основание области проверки: этап 8 стратегии код-ревью — resources, resolver lifecycle, asset consistency; область включает `lib/src/resources/**`, `lib/src/store/resource_table.dart`, resource-facing части frame/surface bridge, `docs/contracts/resources.md`, `docs/contracts/cache_policy.md`, `test/resources/**`. fileciteturn3file2

Проверенная область:
- `docs/contracts/resources.md`
- `docs/contracts/cache_policy.md`
- `docs/diagrams/dfd_cache_invalidation.mmd`
- `docs/diagrams/seq_resource_resolution.mmd`
- `lib/src/resources/resource_cache.dart`
- `lib/src/resources/resource_kernel.dart`
- `lib/src/resources/resource_resolver_adapter.dart`
- `lib/src/resources/surface_resource_session.dart`
- `lib/src/store/resource_table.dart`
- `lib/src/store/document_store_kernel.dart`
- `lib/src/store/schema_v1_store_import.dart`
- `lib/src/store/committed_document.dart`
- `lib/src/store/store_revision_delta.dart`
- `lib/src/edit/commit_compiler.dart`
- `lib/src/edit/commit_applier.dart`
- `lib/src/edit/draft_document.dart`
- `lib/src/edit/edit_kernel.dart`
- `lib/src/edit/edit_session.dart`
- `lib/src/edit/touched_set_builder.dart`
- `lib/src/runtime/runtime_root.dart`
- `lib/src/frame/paint_asset_binding_service.dart`
- `lib/src/frame/main_frame_asset_images.dart`
- `lib/src/frame/frame_engine.dart`
- `lib/src/frame/frame_capture_service.dart`
- `lib/src/frame/captured_frame.dart`
- `lib/src/surface/image_bridge.dart`
- `lib/src/surface/canvas_surface_widget.dart`
- `test/resources/**`
- resource-related runtime/surface tests

Найдено проблем: 1.


ID: RESOURCE-002
Этап: Этап 8. Resources, resolver lifecycle и asset consistency
Название проблемы: Materialized document replacement записывает resource descriptors с resourceRevision 0, ломая cache key identity
Приоритет: P1
Вероятность проявления: R2
Краткое описание:
`ImageResolveCache` использует ключ `resolverGeneration + resourceId + resourceRevision`. Для sparse resource edits и schema import descriptor получает актуальный accepted resource revision. Но materialized commit path создаёт `CommittedDocument(document)` без явных revisions; внутри используется default `RevisionState()`, поэтому `ResourceTable` строит descriptors с `resourceRevision == 0`. После этого `DocumentStoreKernel` обновляет aggregate `RevisionState`, но уже созданные descriptor facts не пересобираются. В результате frame/resource binding может передать в resolver устаревший `descriptor.resourceRevision`, и cache key перестаёт отражать фактическое изменение resource table.

Доказательство в коде:
- `docs/contracts/resources.md:132-135`: cache key должен включать `resolverGeneration`, `resourceId`, `resourceRevision`; descriptor change должен инвалидировать cache.
- `lib/src/resources/resource_cache.dart:13-18`: cache key действительно содержит `resolverGeneration`, `resourceId`, `resourceRevision`.
- `lib/src/resources/surface_resource_session.dart:81-88`: session читает cache по `resolverGeneration`, `resourceId`, `resourceRevision`.
- `lib/src/store/resource_table.dart:15-25`: `ResourceTable(...)` создаёт descriptors с переданным `resourceRevision`.
- `lib/src/store/resource_table.dart:120-137`: `descriptorFor(...)` хранит `resourceRevision` внутри descriptor facts.
- `lib/src/store/schema_v1_store_import.dart:101-104`: schema import корректно создаёт resource descriptors с accepted revisions.
- `lib/src/store/document_store_kernel.dart:583-596`: sparse upsert resource использует `acceptedRevisions.resourceRevision`.
- `lib/src/edit/commit_applier.dart:118-123`: materialized accepted commit создаёт `CommittedDocument(document)` без явных revisions.
- `lib/src/store/committed_document.dart:24-38`: `CommittedDocument(CanvasDocument)` по умолчанию использует `RevisionState()`, то есть нулевые revisions.
- `lib/src/store/document_store_kernel.dart:256-274` и `lib/src/store/document_store_kernel.dart:289-298`: materialized install/replace обновляет aggregate revisions через `revisionDelta.advance(...)`, но не пересобирает `ResourceTable` descriptor revisions.
- `lib/src/edit/edit_session.dart:749-750`: публичный `replaceDraftDocument(...)` идёт через materialized replacement.
- `lib/src/edit/edit_session.dart`: `readDraftDocument()` может материализовать draft перед последующими правками.
- `lib/src/frame/paint_asset_binding_service.dart:66-74`: asset binding передаёт в request именно `descriptor.resourceRevision`.

Пользовательский или инженерный сценарий проявления:
Внешний потребитель через публичный edit API вызывает `replaceDraftDocument(...)` с документом, где есть resource `r1` и appKey `asset-a`. Surface резолвит image A и кладёт её в cache с key `r1 + revision 0`. Затем потребитель снова вызывает `replaceDraftDocument(...)` с тем же `resourceId = r1`, но с другим appKey `asset-b`. Новый descriptor снова получает `resourceRevision == 0`. Cache identity перестаёт отражать фактическую замену resource table, поэтому stale image A может быть переиспользован там, где lookup опирается на descriptor revision вместо принятой store revision.

Почему это не теоретический edge case:
`replaceDraftDocument(...)` — публичный путь массовой замены документа. Сохранение стабильных resource IDs при смене appKey/asset — нормальный сценарий синхронизации внешнего asset store. Проблема не требует экстремальных данных: достаточно одного resource ID и двух последовательных materialized replacements.

Рекомендуемое исправление:
Исправить materialized install/replace так, чтобы resource descriptor facts строились с accepted revisions:
- не создавать committed resource table через `CommittedDocument(document)` с default `RevisionState()`;
- добавить store-owned prepare/install path, который получает accepted `RevisionState`;
- если materialized replacement меняет resource table, назначать descriptors accepted `resourceRevision`;
- если materialized edit не меняет resources, сохранять прежние descriptor revisions для unchanged resources;
- targeted/all cache invalidation должна оставаться независимой защитой, потому что revision-correctness и invalidation — разные уровни консистентности.

Минимальная проверка после исправления:
Добавить tests:
1. Загрузить документ с resource revision 1.
2. Выполнить materialized non-resource edit после `readDraftDocument()`.
3. Проверить, что `frame.resourceDescriptor(id).resourceRevision` не сброшен в 0.
4. Выполнить `replaceDraftDocument(...)` или materialized resource replacement с тем же resource ID и другим appKey.
5. Проверить, что descriptor revision соответствует accepted store resource revision.
6. С активной `SurfaceResourceSession` проверить, что повторная замена same resource ID не возвращает старый cached image.



Проверено без отдельной проблемы:
- Missing/null resolver result path реализован как degraded behavior через placeholders и same-frame null suppression в `SurfaceResourceSession`.
- Resolver replacement и drop очищают generation/cache/null suppression/pending flag.
- `ImageResolveCache` имеет LRU capacity 1024, поэтому отдельного неограниченного роста cache в базовом implementation не найдено.

Оставшиеся неопределённости:
- Полный `flutter test` не запускался в рамках этого ответа; вывод основан на статическом чтении кода, контрактов и тестовых fixtures.
- Визуальная корректность всего frame, schema parsing ресурсов на JSON boundary и общий Flutter widget lifecycle вне resource bridge не оценивались, так как они исключены из области этапа 8.
```

fileciteturn0file0

```text
Этап 9. Diagnostics, errors и публичная наблюдаемость отказов

Проверенная область:
lib/src/diagnostics/**
lib/src/api/canvas_diagnostics.dart
lib/src/api/canvas_errors.dart
lib/src/api/canvas_error_details_sanitizer.dart
lib/src/contracts/public/canvas_diagnostics.dart
lib/src/contracts/public/canvas_errors.dart
lib/src/contracts/public/canvas_error_details_sanitizer.dart
lib/src/codec/schema_v1_diagnostics.dart
lib/src/codec/schema_v1_decoder.dart
lib/src/codec/schema_v1_import_emitter.dart
lib/src/edit/staged_document_load.dart
lib/src/runtime/runtime_root.dart
lib/src/runtime/runtime_interaction_diagnostics_adapter.dart
test/diagnostics/**
test/codec/schema_v1/diagnostics_routing_test.dart
test/edit/fixtures/staged_document_load_success_failure_fixture.dart

Ограничение проверки:
Статический анализ. Dart/Flutter toolchain в среде недоступен, поэтому тесты не запускались.

Найдено проблем: 2

ID: DIAG-002
Этап: Этап 9. Diagnostics, errors и публичная наблюдаемость отказов
Название проблемы: RuntimeRoot и LoadDocumentPipeline создают разные DiagnosticsHub, поэтому load diagnostics фрагментируются
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
RuntimeRoot создаёт свой DiagnosticsHub из `CanvasRuntimeConfig.diagnosticPolicy`, но LoadDocumentPipeline создаёт второй независимый DiagnosticsHub из той же policy. Codec/load failures записываются в hub внутри LoadDocumentPipeline, а interaction diagnostics — в hub RuntimeRoot. В результате runtime-level diagnostic sink не видит load failures, и diagnostic history одного runtime оказывается разделена между двумя владельцами.

Доказательство в коде:
docs/architecture/01_runtime_ownership.md:67-68:
CodecBoundary отвечает за schema v1 diagnostics, DiagnosticsHub — за internal diagnostic records/public error projection.

docs/architecture/01_runtime_ownership.md:209:
Runtime composition tree включает `DiagnosticsHub` как runtime-owned collaborator.

lib/src/runtime/runtime_root.dart:101-102:
RuntimeRoot создаёт `diagnostics: diagnosticsHubForPolicy(config.diagnosticPolicy)`.

lib/src/runtime/runtime_root.dart:141:
этот hub сохраняется в `_diagnostics`.

lib/src/runtime/runtime_root.dart:145-148:
LoadDocumentPipeline получает не hub, а только `diagnosticPolicy`.

lib/src/edit/staged_document_load.dart:107-113:
LoadDocumentPipeline создаёт собственный `_diagnostics = _diagnosticsHubFor(diagnosticPolicy)`.

lib/src/edit/staged_document_load.dart:125-131:
`prepareFromJson` передаёт в codec/import emitter именно pipeline `_diagnostics`.

lib/src/runtime/runtime_root.dart:300-302:
runtime test/internal diagnostic projection возвращает только `_diagnostics?.records`, то есть записи из pipeline hub сюда не попадают.

lib/src/runtime/runtime_root.dart:1525-1527:
public runtime load path вызывает `_loadPipeline.prepareFromJson(json)`, поэтому invalid load уходит в pipeline diagnostics.

Пользовательский или инженерный сценарий проявления:
Создать runtime с `CanvasRuntimeConfig(diagnosticPolicy: CanvasDiagnosticPolicy.summary())`, вызвать `runtime.edits.loadDocumentFromJson` с невалидным schema v1 JSON. Операция выбросит CanvasDataException, а codec diagnostic будет записан в private hub LoadDocumentPipeline. RuntimeRoot.diagnosticRecords, где уже появляются interaction diagnostics, останется без этой load failure записи.

Почему это не теоретический edge case:
Невалидный импорт документа — основной диагностируемый failure path. В проекте уже есть тесты на diagnostics routing для LoadDocumentPipeline отдельно, но runtime composition route остаётся незафиксированным: `test/edit/fixtures/staged_document_load_success_failure_fixture.dart` проверяет pipeline records напрямую, а не RuntimeRoot records.

Рекомендуемое исправление:
Сделать DiagnosticsHub single-owner dependency:
- RuntimeRoot создаёт один `DiagnosticsHub?`.
- LoadDocumentPipeline принимает `DiagnosticsHub? diagnostics` вместо `CanvasDiagnosticPolicy diagnosticPolicy`.
- `diagnosticsHubForPolicy` оставить в одном месте, убрать дублирующий `_diagnosticsHubFor`.
- Pipeline test surface может читать shared hub или получать injected test hub.

Минимальная проверка после исправления:
Добавить runtime-level test:
1. `RuntimeRoot.test(config: CanvasRuntimeConfig(diagnosticPolicy: CanvasDiagnosticPolicy.summary()))`.
2. Вызвать `root.edits.loadDocumentFromJson` с invalid JSON/schema.
3. Поймать CanvasDataException.
4. Проверить, что `root.diagnosticRecords.single.code == DiagnosticCode.data(<expected CanvasDataErrorCode>)`.
5. Затем вызвать interaction diagnostic path и проверить, что обе записи находятся в одном ordered records list.


ID: DIAG-003
Этап: Этап 9. Diagnostics, errors и публичная наблюдаемость отказов
Название проблемы: schema_v1_import_emitter может записывать один failure в DiagnosticsHub дважды
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
В runtime import emitter часть `_materialize(...)` closures вызывает `_read*` helpers, которые при ошибке уже записывают diagnostic через `_fail(...)`. Затем `_materialize(...)` ловит тот же CanvasDataException и снова вызывает `recordSchemaV1FailureDiagnostic(...)`. Для одного schema failure можно получить две diagnostic records с одним и тем же code/path/message.

Доказательство в коде:
lib/src/codec/schema_v1_import_emitter.dart:1352-1368:
`_readTransform` вызывает `_materialize(diagnostics, () { ... _readDouble(... diagnostics: diagnostics) ... })`.

lib/src/codec/schema_v1_import_emitter.dart:1149-1165:
`_readDouble` при неверном типе вызывает `_fail(...)`.

lib/src/codec/schema_v1_import_emitter.dart:1643-1658:
`_fail(...)` сразу бросает `recordSchemaV1FailureDiagnostic(diagnostics, CanvasDataException(...))`, то есть diagnostic уже записан.

lib/src/codec/schema_v1_import_emitter.dart:1629-1636:
`_materialize(...)` ловит любой CanvasDataException и повторно вызывает `recordSchemaV1FailureDiagnostic(diagnostics, exception)`.

Дополнительные места с тем же паттерном:
lib/src/codec/schema_v1_import_emitter.dart:392-399 — `_readCamera` materialize closure вызывает `_readOffsetDefault`.
lib/src/codec/schema_v1_import_emitter.dart:441-456 — `_readGrid` materialize closure вызывает `_readBoolDefault` / `_readDoubleDefault` / `_readColorDefault`.
lib/src/codec/schema_v1_import_emitter.dart:480-499 — `_readPalette` materialize closure вызывает `_readColorList` / `_readDoubleList`.
lib/src/codec/schema_v1_import_emitter.dart:702-771 — `_readElementCommon` materialize closure вызывает `_readString`, `_validated*`, `_readTransformDefault`.
lib/src/codec/schema_v1_import_emitter.dart:782-800 — `_readImageElement` materialize closure вызывает `_readSize`, `_readNullableSize`, `_readString`.

Пользовательский или инженерный сценарий проявления:
Runtime load получает schema v1 JSON, где `transform.a` — строка вместо числа. `_readDouble` записывает diagnostic `invalidFieldType` по path `transform.a`; затем `_materialize` ловит этот же CanvasDataException и пишет вторую такую же запись. Потребитель диагностик или тестовый harness видит два отказа, хотя была одна причина.

Почему это не теоретический edge case:
Ошибки типа в JSON — нормальный импортный failure path. Этот путь используется именно runtime load pipeline через `importSchemaV1DocumentFromJsonIntoIsolatedSink`, а не только internal helper.

Рекомендуемое исправление:
Развести два типа failures:
1. Codec read failures, которые уже записаны `_fail`.
2. Public DTO/materialization failures, которые ещё не записаны и должны быть записаны `_materialize`.

Практические варианты:
- вынести все `_read*` вызовы из `_materialize` closures и оставлять внутри только public DTO constructors/validators;
- или добавить internal marker/wrapper для already-recorded CanvasDataException;
- или сделать `_materialize` принимать флаг/variant, который не re-records exceptions, пришедшие из codec read helpers.

Минимальная проверка после исправления:
Добавить тест через LoadDocumentPipeline с enabled diagnostics:
1. JSON с `transform.a: "bad"`.
2. `prepareFromJson` должен бросить CanvasDataException.
3. `diagnosticRecordCount == 1`.
4. Единственная запись имеет code `DiagnosticCode.data(CanvasDataErrorCode.invalidFieldType)` и path `transform.a`.
5. Отдельно проверить constructor-only failure, например non-invertible transform, тоже записывается ровно один раз.
```

```text
Источник стратегии: fileciteturn0file0

Этап: Этап 10. Flutter surface, widget lifecycle и platform integration

Проверенная область:
- lib/src/surface/canvas_surface_widget.dart
- lib/src/surface/pointer_adapter.dart
- lib/src/surface/main_painter.dart
- lib/src/surface/overlay_painter.dart
- lib/src/surface/text_editing_overlay.dart
- lib/src/surface/image_bridge.dart
- lib/src/api/canvas_surface.dart
- lib/src/api/canvas_text_editing.dart
- example/lib/**
- test/surface/**

Ограничение проверки:
Автотесты не запускались: в доступной среде нет dart/flutter. Выводы ниже основаны на статическом чтении кода, контрактов и surface/widget fixtures.

Найдено проблем: 1.

ID: SURFACE-002
Этап: Этап 10. Flutter surface, widget lifecycle и platform integration
Название проблемы: PointerAdapter отбрасывает invalid terminal Flutter events вместо cleanup-routing активной pointer session
Приоритет: P1
Вероятность проявления: R1
Краткое описание:
CanvasSurfacePointerAdapter отбрасывает любой PointerEvent с non-finite localPosition до учёта phase. Это безопасно для down/move, но для up/cancel нарушает terminal cleanup semantics: если active pointer session уже создана конечным finite down/move, а terminal event пришёл с NaN/Infinity localPosition, runtime не получает никакого terminal signal. Preview/session могут остаться активными до следующего внешнего cleanup: tool switch, runtime reset, dispose или interactive=false.

Доказательство в коде:
- docs/contracts/public_api_v1.md:1778-1782 фиксирует различие: pointer position finite для down/move, а invalid terminal samples должны маршрутизироваться в cleanup logic.
- lib/src/surface/pointer_adapter.dart:25-30 route вызывается для onPointerUp и onPointerCancel.
- lib/src/surface/pointer_adapter.dart:35-39 сразу возвращает управление при non-finite event.localPosition, не различая down/move и up/cancel.
- lib/src/contracts/public/canvas_pointer.dart:92-101 CanvasPointerSample требует position и валидирует validateOffset(position), то есть текущий public sample shape не позволяет surface передать terminal cleanup sample с invalid position.
- test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart покрывает non-finite down/move как no-effect, но не покрывает сценарий finite down -> non-finite up/cancel при active pointer session.

Пользовательский или инженерный сценарий проявления:
Пользователь начинает stroke/move/eraser gesture: finite pointer down создаёт active pointer session и preview. Затем Flutter присылает PointerCancelEvent или PointerUpEvent с non-finite localPosition, например из-за временно некорректной transform/hit-test геометрии, platform-view/desktop edge case, test harness или ancestor transform. Adapter silently drops terminal event. Engine не выполняет cleanup, а пользователь видит зависший preview или незавершённое интерактивное состояние.

Почему это не теоретический edge case:
Репозиторий уже содержит surface fixture, который вручную создаёт PointerEvent с NaN/Infinity localPosition, значит такой boundary case признан релевантным для surface. Контракт отдельно выделяет invalid terminal cleanup. Повреждённый terminal event опаснее повреждённого move: он закрывает session, и его потеря оставляет runtime в visible stale interaction state.

Рекомендуемое исправление:
Не пытаться превращать invalid terminal в обычный CanvasPointerSample с фиктивной позицией, потому что это может привести к commit по неверной координате. Нужен отдельный cleanup-only path на surface/runtime boundary:
- либо добавить internal/public terminal cleanup sample, несущий pointerId, phase up/cancel, kind, timestampMs и признак invalidPosition без position;
- либо добавить в CanvasRuntimeSurfacePort метод handleInvalidPointerTerminal(token, pointerId, phase, kind, timestampMs), который вызывает interaction cleanup-only path без commit intent;
- down/move с non-finite localPosition по-прежнему должны игнорироваться без runtime effects;
- up/cancel с non-finite localPosition должны выполнять cleanup-only для matching active pointer session и не создавать edit/action commit.

Минимальная проверка после исправления:
Добавить widget test:
1. Mount CanvasSurface(interactive: true), включить draw mode.
2. Синтетически отправить finite PointerDownEvent через Listener, убедиться, что runtime.preview стал CanvasPencilStrokePreview.
3. Отправить PointerUpEvent или PointerCancelEvent с тем же pointerId и Offset(double.nan, 1) / Offset(1, double.infinity).
4. Проверить, что runtime.preview стал CanvasNoPreview, active session очищена, document не изменился, actions пустой или нет commit action.
5. Отдельно сохранить существующую проверку: non-finite down/move без active session не должны создавать runtime effects.

Что дополнительно проверено и не вынесено как проблема:
- CanvasSurface attach/detach/runtime swap/session drop в целом реализованы явно: attachSurface -> SurfaceResourceSession -> installSurfaceResourceSession, rollback при ошибке, detach/drop при dispose/runtime swap.
- Rebuild с новым runtime очищает старый surface binding и подключает новый runtime через CanvasRuntimeSurfacePort.
- MainFramePainter и OverlayFramePainter читают immutable paint outputs и не импортируют CanvasRuntime/DocumentStore/SurfaceResourceSession.
- CanvasTextEditingOverlay использует public CanvasTextEditingPort.activeSession, EditableText, runtime-owned session commit/dismiss и не дублирует TextPainter measurement.
- Example app использует package barrel package:iwb_canvas_engine/iwb_canvas_engine.dart в example/lib/** и не импортирует package:iwb_canvas_engine/src/**.
```

```text
Источник стратегии этапа 11: fileciteturn0file0

ID: ARCH-002
Этап: Этап 11. Архитектурные границы, dependency graph и guardrails
Название проблемы: API boundary contract запрещает contracts/internal imports, но production bridge и guardrails явно разрешают их
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
Документация package boundary утверждает, что lib/src/api/** не должен import/export contracts/internal. Однако lib/src/api/canvas_runtime_surface_bridge.dart импортирует два internal seam-файла, а core boundary и owner DAG специально allowlist-ят эти импорты. Это не обязательно функциональная ошибка runtime, но это незамкнутый архитектурный контракт: документация, фактический код и guardrails описывают разные правила.

Доказательство в коде:
docs/architecture/02_package_boundaries.md говорит, что api-файлы являются facade/wrapper-export files, а non-exported cross-owner seams живут под contracts/internal:
- docs/architecture/02_package_boundaries.md:185-188

Там же forbidden imports формулируют прямой запрет:
- docs/architecture/02_package_boundaries.md:279-280

Фактический bridge нарушает буквальное правило:
- lib/src/api/canvas_runtime_surface_bridge.dart:5-6
  import '../contracts/internal/resolver_mutation_guard.dart';
  import '../contracts/internal/surface_resource_session_lifecycle.dart';

Guardrails при этом делают для этого файла исключение:
- tool/guardrails/src/core_boundary_checks.dart:1065-1071
- tool/guardrails/src/owner_dag_import_checks.dart:365-377

Architecture graph одновременно описывает surface bridge как expected route:
- docs/architecture/architecture_graph.yaml:785-797

Пользовательский или инженерный сценарий проявления:
Разработчик, ориентируясь на production bridge и allowlist, начинает размещать не-exported API-adjacent bridge logic в lib/src/api/** и импортировать contracts/internal. Другой разработчик, ориентируясь на docs/architecture/02_package_boundaries.md, считает это нарушением. В результате review и guardrails дают разные ответы на один и тот же boundary вопрос.

Почему это не теоретический edge case:
Нарушающий пример уже находится в production code. Guardrails не просто пропускают его случайно, а явно allowlist-ят конкретные internal imports для canvas_runtime_surface_bridge.dart.

Рекомендуемое исправление:
Выбрать один архитектурный вариант и зафиксировать его во всех местах.

Вариант A, если bridge допустим:
- Явно описать в docs/architecture/02_package_boundaries.md исключение для lib/src/api/canvas_runtime_surface_bridge.dart.
- Переформулировать “lib/src/api/** may not import/export contracts/internal” в “кроме перечисленных non-public bridge seams”.
- В guardrail tests добавить проверку, что только canvas_runtime_surface_bridge.dart может импортировать только эти два contracts/internal файла, а любые другие api -> contracts/internal imports остаются forbidden.

Вариант B, если docs являются источником истины:
- Перенести runtime-surface bridge из lib/src/api/** в отдельный internal bridge owner, например lib/src/surface/runtime_surface_bridge.dart или lib/src/contracts/internal/runtime_surface_port.dart.
- Обновить architecture_graph.yaml, ownerDagAllowedEdges, core boundary allowlist и surface imports.
- Убрать api -> contracts/internal exception из core_boundary_checks.dart и owner_dag_import_checks.dart.

Минимальная проверка после исправления:
Тест должен различать:
1. lib/src/api/canvas_runtime_surface_bridge.dart импортирует только утверждённые internal seam-файлы — pass, если выбран вариант A.
2. любой другой lib/src/api/*.dart import '../contracts/internal/...' — fail.
3. docs/architecture/02_package_boundaries.md и guardrail allowlist больше не противоречат друг другу.


ID: ARCH-003
Этап: Этап 11. Архитектурные границы, dependency graph и guardrails
Название проблемы: В graph/docs/guardrails остался несуществующий owner lib/src/tools/**
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
Architecture graph coverage, documentation и owner DAG всё ещё содержат отдельный owner path lib/src/tools/**, но такого production directory в репозитории нет. Реальные DrawStrokeMachine и LineMachine живут в lib/src/interaction/**, а node draw.tools в architecture_graph.yaml имеет owner: interaction. Это stale architecture owner: graph/guardrails создают видимость отдельного tools layer, которого фактически нет.

Доказательство в коде:
architecture_graph.yaml включает несуществующий coverage path:
- docs/architecture/architecture_graph.yaml:6-21

current_closure.dart содержит owner prefix для tools:
- tool/architecture_graph/src/current_closure.dart:4-21

owner_dag_import_checks.dart содержит toolsOwner с prefixes: ['lib/src/tools/']:
- tool/guardrails/src/owner_dag_import_checks.dart:313-320

docs/architecture/02_package_boundaries.md продолжает описывать rule для lib/src/tools/**:
- docs/architecture/02_package_boundaries.md:296-300

При этом фактический graph node draw.tools указывает owner: interaction:
- docs/architecture/architecture_graph.yaml:308-321

Фактические tool machine declarations находятся в interaction:
- lib/src/interaction/draw_stroke_machine.dart:9-10
- lib/src/interaction/line_machine.dart:8-9

Дополнительная статическая проверка дерева показала: lib/src/tools отсутствует, coverage pattern lib/src/tools/** раскрывается в 0 Dart-файлов.

Пользовательский или инженерный сценарий проявления:
Разработчик добавляет новый lib/src/tools/draw_tool_kernel.dart, ориентируясь на docs package layout и существующий toolsOwner. Guardrails начинают классифицировать этот файл как отдельный tools owner, но architecture_graph фактически уже моделирует draw tools как часть interaction owner. Это может привести к расщеплению ownership: часть tool lifecycle в interaction, часть в tools, без явного composition/edge решения.

Почему это не теоретический edge case:
Старый путь lib/src/tools/** упомянут сразу в четырёх местах: docs, architecture_graph coverage, architecture graph closure owner prefixes и owner DAG. Это не единичный комментарий, а активная часть guardrail model. При этом actual implementation уже находится в другом owner.

Рекомендуемое исправление:
Если отдельный tools owner больше не нужен:
- Удалить lib/src/tools/** из docs/architecture/architecture_graph.yaml coverage.
- Удалить tools owner prefix из tool/architecture_graph/src/current_closure.dart.
- Удалить toolsOwner из ownerDagOwners/ownerDagAllowedEdges или перевести tools.public_port_behavior в interaction/tools terminology.
- Обновить docs/architecture/02_package_boundaries.md и generated diagrams.

Если отдельный tools owner нужен:
- Создать реальный lib/src/tools/** owner и перенести туда DrawStrokeMachine/LineMachine или только lifecycle-neutral tool collaborators.
- Добавить explicit graph edges interaction.engine -> tools owner.
- Согласовать owner DAG и tests.

Минимальная проверка после исправления:
Добавить architecture_graph validation: каждый coverage glob без status: future/allowEmpty должен раскрывать минимум один production Dart-файл. Для текущего graph это должно падать на lib/src/tools/** до исправления.


ID: ARCH-004
Этап: Этап 11. Архитектурные границы, dependency graph и guardrails
Название проблемы: Owner DAG содержит path-specific allowlist entries, которых нет в текущих production imports
Приоритет: P2
Вероятность проявления: R1
Краткое описание:
В ownerDagAllowedEdges есть конкретные sourcePath/targetPath разрешения, которые не соответствуют текущим import/export directives. Такие stale allowlist entries ослабляют архитектурный guardrail: будущий import по уже разрешённому, но сейчас неиспользуемому маршруту пройдёт CI без нового review архитектурного решения.

Доказательство в коде:
Примеры stale path-specific allowlist entries:
- tool/guardrails/src/owner_dag_import_checks.dart:410-415
  api canvas_codec.dart -> codec schema_v1_decoder.dart
- tool/guardrails/src/owner_dag_import_checks.dart:480-484
  runtime_interaction_read_adapter.dart -> spatial_query_result.dart
- tool/guardrails/src/owner_dag_import_checks.dart:637-640
  ordinary_paint_planner.dart -> spatial_query_result.dart
- tool/guardrails/src/owner_dag_import_checks.dart:660-664
  frame_paint_output.dart -> resource_resolver_adapter.dart

Текущие файлы этих импортов не содержат:
- lib/src/api/canvas_codec.dart импортирует schema_v1_encoder.dart, но не schema_v1_decoder.dart: lib/src/api/canvas_codec.dart:1-4
- lib/src/runtime/runtime_interaction_read_adapter.dart импортирует hit_test_policy, spatial_kernel и spatial_query_policy, но не spatial_query_result: lib/src/runtime/runtime_interaction_read_adapter.dart:1-10
- lib/src/frame/ordinary_paint_planner.dart импортирует geometry_policy, но не spatial_query_result: lib/src/frame/ordinary_paint_planner.dart:1-10
- lib/src/frame/frame_paint_output.dart импортирует frame-local planners/bindings, но не resource_resolver_adapter: lib/src/frame/frame_paint_output.dart:1-10

Тест owner DAG сравнивает allowlist с independent static policy table, а не с actual production imports:
- test/guardrails/owner_dag_import_boundaries_test.dart:186-204

Пользовательский или инженерный сценарий проявления:
Разработчик добавляет import '../codec/schema_v1_decoder.dart' в lib/src/api/canvas_codec.dart или import '../geometry/spatial_query_result.dart' в ordinary_paint_planner.dart. Даже если текущая architecture intent уже ушла от этих зависимостей, owner DAG не потребует обновления graph/docs/registry, потому что маршрут заранее разрешён.

Почему это не теоретический edge case:
Статический allowlist уже содержит неиспользуемые разрешения. Path-specific allowlists обычно должны быть минимальными: каждое разрешение либо отражает текущий import, либо имеет явно документированный future/temporary reason. Здесь таких reason/removal condition рядом с entries нет.

Рекомендуемое исправление:
Для path-specific OwnerEdge в ownerDagAllowedEdges ввести одно из правил:
1. edge должен соответствовать фактическому import/export в production; или
2. edge должен иметь явный status/reason/removalCondition/future marker и отдельный тест, что это осознанное временное разрешение.

Удалить stale entries, если они больше не нужны:
- api canvas_codec.dart -> schema_v1_decoder.dart
- runtime_interaction_read_adapter.dart -> spatial_query_result.dart
- ordinary_paint_planner.dart -> spatial_query_result.dart
- frame_paint_output.dart -> resource_resolver_adapter.dart

Минимальная проверка после исправления:
Добавить тест в test/guardrails/owner_dag_import_boundaries_test.dart:
для каждого OwnerEdge с sourcePath и targetPath без explicit future marker существует текущий production import/export с тем же sourcePath, targetPath и directiveKind. Тест должен падать на перечисленных четырёх entries до очистки allowlist.


Проверенная область:
- docs/architecture/**
- docs/architecture/architecture_graph.yaml
- lib/src/** imports/declarations
- tool/architecture_graph/**
- tool/guardrails/**
- test/architecture_graph/**
- test/guardrails/**
- .github/workflows/**
- analysis_options.yaml

Что именно было проверено:
- Фактические production import/export edges между lib/src owners.
- Наличие reverse dependencies вроде frame -> interaction, geometry -> runtime, store -> surface.
- Соответствие coverage paths фактическому дереву lib/src.
- Наличие architecture_graph/check и guardrails в root CI workflow.
- Наличие broad analyzer excludes для production paths.
- Guardrail runner routing и owner DAG policy shape.
- Declaration-only direction для contracts/public и contracts/internal на уровне imports.

Оставшиеся неопределённости:
- В текущей среде не установлен dart/flutter, поэтому я не запускал dart analyze, dart test, tool/architecture_graph/check.dart или tool/guardrails/run.dart. Вывод основан на статическом чтении файлов и собственном скане import/export directives.
```

```text
Этап 12. Тестовая стратегия, CI, benchmarks и release readiness

ID: TEST-001
Этап: Этап 12. Тестовая стратегия, CI, benchmarks и release readiness
Название проблемы: Release benchmark gate сейчас гарантированно fail-closed из-за неинициализированного approved baseline
Приоритет: P1
Вероятность проявления: R3
Краткое описание:
В репозитории committed approved release baseline является placeholder со статусом `unapproved`. При этом release benchmark workflow безусловно запускает `tool/bench/diff.dart` против этого baseline. Код diff явно трактует `status: unapproved` как failure, поэтому текущий release benchmark gate не может стать зелёным до принятия реального baseline.
Доказательство в коде:
tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:1-5 содержит:
- `"status": "unapproved"`
- сообщение `No measured release baseline has been approved yet...`

.github/workflows/release_benchmarks.yml:30-34:
- запускает `dart run tool/bench/run.dart --profile=release`
- затем запускает `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json ...`

tool/bench/src/benchmark_diff.dart:168-174:
- `status == 'unapproved'` возвращает failure `approved baseline is not initialized...`

tool/bench/src/benchmark_diff.dart:235-240:
- при непрошедшем diff CLI возвращает exit code `1`.

docs/verification/release_gates.md:172-174 требует, чтобы benchmark gates проходили через pinned release workflow, включая read-only release diff.
Пользовательский или инженерный сценарий проявления:
Команда запускает release benchmark workflow перед релизом. Benchmark run может выполниться, но diff падает из-за placeholder baseline. Релизный performance gate не подтверждает regression status и блокирует release readiness.
Почему это не теоретический edge case:
Это текущее committed состояние репозитория. Workflow scheduled/manual, baseline path и diff logic уже связаны между собой, а placeholder находится именно по approved baseline path.
Рекомендуемое исправление:
Провести first-baseline acceptance на pinned contour через `update_benchmark_baseline.yml`, получить accepted baseline artifact, review результата и закоммитить реальный `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`. Placeholder должен оставаться только до момента первой baseline acceptance.
Минимальная проверка после исправления:
Запустить:
1. `dart run tool/bench/run.dart --profile=release`
2. `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json --current=build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json --output=build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`
Ожидаемый результат: diff не падает из-за `approved baseline is not initialized`.


ID: TEST-002
Этап: Этап 12. Тестовая стратегия, CI, benchmarks и release readiness
Название проблемы: Root CI исключает часть существующих benchmark-тестов
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
В `test/benchmarks` есть семь `*_test.dart`, но root CI вручную запускает только четыре из них, а затем исключает весь каталог `test/benchmarks` из общего `flutter test`. В результате `benchmark_case_adapter_test.dart`, `manual_benchmark_history_test.dart` и `manual_benchmark_reference_test.dart` не попадают в ordinary CI.
Доказательство в коде:
.github/workflows/root_package.yml:37-50:
- вручную запускаются только:
  - `benchmark_manifest_test.dart`
  - `required_cases_test.dart`
  - `benchmark_diff_test.dart`
  - `benchmark_runner_test.dart`
- общий test step использует:
  `flutter test --concurrency=1 $(find test -path test/benchmarks -prune -o -name '*_test.dart' -print)`

Фактически существующие benchmark tests:
- test/benchmarks/benchmark_case_adapter_test.dart
- test/benchmarks/benchmark_diff_test.dart
- test/benchmarks/benchmark_manifest_test.dart
- test/benchmarks/benchmark_runner_test.dart
- test/benchmarks/manual_benchmark_history_test.dart
- test/benchmarks/manual_benchmark_reference_test.dart
- test/benchmarks/required_cases_test.dart

test/benchmarks/benchmark_case_adapter_test.dart:15-28 проверяет decode нового probe payload, rejection старого `elapsedUsSamples`, setup-scope none и mismatched profile id.
test/benchmarks/manual_benchmark_history_test.dart:26-39 проверяет archive full report, single-case probe log и history index.
test/benchmarks/manual_benchmark_reference_test.dart:33-43 и 160-169 проверяет bootstrap/stable manual reference policy и boundary rejection.
test/guardrails/root_ci_target_test.dart:94-128 закрепляет тот же ручной список из четырёх benchmark-тестов, поэтому структурный CI-test тоже не ловит появление/исключение дополнительных benchmark tests.
Пользовательский или инженерный сценарий проявления:
Разработчик меняет manual benchmark history/reference или probe adapter schema. Локально забывает запустить соответствующий test. PR CI проходит, потому что эти файлы не входят ни в ручной benchmark list, ни в bulk test step.
Почему это не теоретический edge case:
Омитированные тесты уже существуют и покрывают release benchmark tooling, baseline/reference governance и probe schema boundary. Это не гипотетический будущий test; это текущий test coverage, который CI не запускает.
Рекомендуемое исправление:
Заменить ручной список benchmark tests на автоматический запуск всех `test/benchmarks/*_test.dart`, либо явно добавить три пропущенных файла в workflow и в `root_ci_target_test.dart`. Более устойчивый вариант:
`dart test $(find test/benchmarks -maxdepth 1 -name '*_test.dart' -print)`
Минимальная проверка после исправления:
В CI/logs должен быть запуск всех семи benchmark test files, включая:
- `test/benchmarks/benchmark_case_adapter_test.dart`
- `test/benchmarks/manual_benchmark_history_test.dart`
- `test/benchmarks/manual_benchmark_reference_test.dart`


ID: TEST-003
Этап: Этап 12. Тестовая стратегия, CI, benchmarks и release readiness
Название проблемы: Required test inventory ссылается на несуществующие test files
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
Документация и registry объявляют required tests, которых нет в дереве `test/**`. Это делает release/test inventory недостоверным: reviewer видит заявленную защиту, но CI физически не может выполнить указанный файл.
Доказательство в коде:
docs/verification/tests.md:248 указывает `test/runtime/interaction_settings_state_test.dart`, но такого файла нет.
docs/verification/tests.md:629-635 описывает expected coverage этого файла: публикация `state.revisions.interaction` при изменениях mode/draw tool/draw style/draw color/pointer policy.

docs/verification/tests.md:316 указывает `test/guardrails/selection_boundary_imports_test.dart`, но такого файла нет.
docs/verification/tests.md:954-958 описывает expected coverage этого файла: запрет concrete SelectionKernel/DocumentStoreKernel imports и routing через immutable query ports.

docs/_registry/sections.yaml:150, 462, 880 ссылается на `test.runtime.interaction_settings_state`.
docs/_registry/sections.yaml:477 ссылается на `test.guardrails.selection_boundary_imports`.

В дереве есть похожий файл `test/guardrails/selection_boundary_checks_test.dart`, но registry/docs называют другой test id/path. Для runtime interaction settings отдельного `test/runtime/interaction_settings_state_test.dart` нет; часть поведения, похоже, покрывается `test/api/tool_port_settings_test.dart` и fixture `test/api/fixtures/tool_port_settings_fixture.dart`, но registry этого не отражает.
Пользовательский или инженерный сценарий проявления:
Перед релизом reviewer сверяет `docs/verification/tests.md` и registry, считает interaction settings / selection boundary coverage обязательной и присутствующей. Фактически named tests не существуют, а docs tooling не падает на такой drift.
Почему это не теоретический edge case:
Два несуществующих path уже находятся в committed verification docs/registry. Это текущий drift между release inventory и test tree.
Рекомендуемое исправление:
Либо создать отсутствующие test files с указанным покрытием, либо переименовать docs/registry entries на фактические test files, которые реально владеют этим coverage. Дополнительно добавить docs/tool check, который проверяет, что каждый backticked `test/..._test.dart` из `docs/verification/tests.md` существует.
Минимальная проверка после исправления:
Запустить проверку вида:
`grep`/script по `docs/verification/tests.md` → все `test/..._test.dart` существуют.
Затем `dart run docs/tool/check_docs.dart` должен падать при добавлении ссылки на несуществующий `test/..._test.dart`.


ID: TEST-004
Этап: Этап 12. Тестовая стратегия, CI, benchmarks и release readiness
Название проблемы: Example package tests не запускаются в root CI
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
В `example/test/**` есть полноценные Flutter/widget tests внешнего consumer-приложения, но root workflow не делает `flutter pub get`, `flutter test` или analyze внутри `example/`. В CI запускаются только root package checks и `test/**`, поэтому regressions в example app, sample asset/resource path, UI import/export и реальном CanvasSurface mounting могут пройти незамеченными.
Доказательство в коде:
.github/workflows/root_package.yml:22-56:
- `flutter pub get` выполняется только в root.
- tests запускаются по root `test/**`.
- нет step вида `cd example && flutter pub get`.
- нет step вида `cd example && flutter test`.
- нет analyze для `example`.

example/test/canvas_example_startup_test.dart:21-30 проверяет, что real example app стартует с public `CanvasSurface`.
example/test/canvas_example_screen_test.dart:43-60 проверяет, что screen монтирует `CanvasSurface` и routes pointer drawing.
example/test/canvas_example_screen_test.dart:506-526 проверяет JSON export dialog и clipboard.
example/test/canvas_example_screen_test.dart:542-591 проверяет valid/invalid JSON import через UI.
example/test/canvas_example_sample_test.dart:156-173 проверяет imported sample-cat JSON и app-owned image resource.
example/test/canvas_example_sample_test.dart:191-218 проверяет, что `CanvasSurface` запрашивает sample-cat descriptor у resolver.
Пользовательский или инженерный сценарий проявления:
Изменяется public API, CanvasSurface constructor, example view model, asset resolver или JSON dialog. Root tests проходят, но example package перестаёт собираться или ломает user-facing demo path.
Почему это не теоретический edge case:
Example tests уже существуют и покрывают реальные consumer paths, которых нет в root workflow. Это обычный PR workflow risk, а не редкий runtime edge case.
Рекомендуемое исправление:
Добавить отдельный CI job или steps:
1. `cd example && flutter pub get`
2. `cd example && flutter test`
3. желательно `cd example && dart analyze` или `flutter analyze`
Минимальная проверка после исправления:
PR CI должен явно показывать выполнение пяти файлов из `example/test/**`. Для negative check можно временно сломать `example/lib/src/canvas_example_screen.dart` или asset declaration и убедиться, что CI падает именно на example job.


ID: TEST-005
Этап: Этап 12. Тестовая стратегия, CI, benchmarks и release readiness
Название проблемы: Diff-sensitive example boundary test фактически skip-ится в обычном clean CI
Приоритет: P2
Вероятность проявления: R3
Краткое описание:
`example_public_boundary_test.dart` содержит проверку, что example step diff не меняет production `lib/**`, но эта проверка требует env `EXAMPLE_BOUNDARY_DIFF_BASE`/`EXAMPLE_BOUNDARY_DIFF_HEAD`. Если env не задан и рабочее дерево clean, test вызывает `markTestSkipped`. GitHub Actions checkout обычно clean, а workflow env не задаёт, поэтому эта часть guardrail не защищает PR diff.
Доказательство в коде:
test/api_contract/example_public_boundary_test.dart:98-124:
- `_registerNoProductionLibDiffTest` берёт diff range или текущие changed paths.
- если diff range отсутствует и changed paths не содержат example boundary path, вызывается `markTestSkipped`.

test/api_contract/example_public_boundary_test.dart:127-134:
- diff range читается только из `EXAMPLE_BOUNDARY_DIFF_BASE` и `EXAMPLE_BOUNDARY_DIFF_HEAD`.

test/api_contract/example_public_boundary_test.dart:137-143:
- fallback смотрит `git diff`, `git diff --cached`, `git ls-files --others`, то есть clean checkout в CI даёт пустой список.

.github/workflows/root_package.yml:1-56 не задаёт `EXAMPLE_BOUNDARY_DIFF_BASE` или `EXAMPLE_BOUNDARY_DIFF_HEAD`.
Пользовательский или инженерный сценарий проявления:
PR одновременно меняет `example/**` и `lib/**`, хотя intended example-boundary policy требует separate engine contract для production changes. В CI checkout нет uncommitted diff, env base/head не задан, test пропускается и не классифицирует PR diff.
Почему это не теоретический edge case:
Тест уже содержит skip path с прямым текстом о необходимости env. Workflow этот env не передаёт. Это означает, что в обычном PR CI проверка не имеет входных данных.
Рекомендуемое исправление:
В PR workflow передавать base/head:
- `EXAMPLE_BOUNDARY_DIFF_BASE: ${{ github.event.pull_request.base.sha }}`
- `EXAMPLE_BOUNDARY_DIFF_HEAD: ${{ github.event.pull_request.head.sha }}`
и убедиться, что checkout имеет достаточную history depth для `git diff base..head`.
Для push workflow определить сопоставимый range либо не запускать diff-sensitive part вне PR.
Минимальная проверка после исправления:
Создать test PR/dummy branch, где меняются `example/**` и `lib/**`. CI должен не skip-ить `_registerNoProductionLibDiffTest` и должен упасть с причиной `Production lib/** changes require a separate engine contract.`


ID: TEST-006
Этап: Этап 12. Тестовая стратегия, CI, benchmarks и release readiness
Название проблемы: DCM verification объявлена как обязательная локальная проверка, но CI явно запрещает её запуск
Приоритет: P2
Вероятность проявления: R2
Краткое описание:
Repository policy требует после каждого Dart code change запускать `dcm analyze .` и `dcm calculate-metrics`, а `analysis_options.yaml` содержит DCM rules/metrics, включая `missing-test-assertion`. Но CI не только не запускает DCM, а `root_ci_target_test.dart` прямо проверяет, что workflows не содержат `dcm analyze` и `dcm calculate-metrics`. В результате часть заявленной test/assertion/complexity verification остаётся ручной и не является release-grade automated gate.
Доказательство в коде:
AGENTS.md:48-55:
- после каждого Dart code change требуется:
  - `dart analyze`
  - `dcm analyze .`
  - `dcm calculate-metrics ...`

analysis_options.yaml:79-124:
- объявлен блок `dcm`.
- среди rules есть `missing-test-assertion`.

analysis_options.yaml:125-151:
- объявлены DCM metrics thresholds.

test/guardrails/root_ci_target_test.dart:244-252:
- `_expectNoDcmCommandsInCi` проверяет, что каждый workflow не содержит `dcm analyze` и `dcm calculate-metrics`.

.github/workflows/root_package.yml:52-56:
- запускает только `dart analyze` и `dart run tool/guardrails/run.dart`, без DCM.
Пользовательский или инженерный сценарий проявления:
Разработчик добавляет weak test без assertions или чрезмерно сложный tool/test helper. Локально DCM не запускается или tool не установлен. PR CI проходит, потому что DCM rules не являются automated gate.
Почему это не теоретический edge case:
В репозитории уже есть DCM config и policy, а CI-тест прямо запрещает DCM commands в workflows. Это текущий reproducibility gap между declared verification и automated verification.
Рекомендуемое исправление:
Выбрать один устойчивый contract:
1. либо сделать DCM официальным CI gate, добавив установку/запуск DCM в workflows и обновив `root_ci_target_test.dart`;
2. либо удалить/понизить DCM из mandatory verification policy и перенести critical checks вроде `missing-test-assertion` в обычные Dart tests/guardrails.
Минимальная проверка после исправления:
Если DCM остаётся mandatory: PR CI должен запускать `dcm analyze .` и targeted `dcm calculate-metrics`, а временное нарушение `missing-test-assertion` должно валить CI.
Если DCM становится advisory: AGENTS/docs должны прямо сказать, что DCM не является release gate, а critical assertion checks должны быть покрыты Dart guardrail tests.


Примечание по выполнению:
Проверка была статической по архиву: `test/**`, `dart_test.yaml`, `analysis_options.yaml`, `.github/workflows/**`, `tool/bench/**`, `tool/guardrails/**`, `docs/_registry/benchmarks.yaml`, `docs/verification/**`, `example/test/**`.
Suite не запускался, потому что в доступной среде отсутствуют `dart` и `flutter`; найденные проблемы основаны на связях файлов, workflow-командах и committed configuration.
