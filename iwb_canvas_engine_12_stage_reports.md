
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
Найдено 1 проблема.


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

Найдено проблем: 0.

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
