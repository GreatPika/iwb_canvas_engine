
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

Найдено проблем: 0


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
