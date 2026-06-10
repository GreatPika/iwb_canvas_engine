
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
Найдено 0 проблем.
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
Что дополнительно проверено и не вынесено как проблема:
- CanvasSurface attach/detach/runtime swap/session drop в целом реализованы явно: attachSurface -> SurfaceResourceSession -> installSurfaceResourceSession, rollback при ошибке, detach/drop при dispose/runtime swap.
- Rebuild с новым runtime очищает старый surface binding и подключает новый runtime через CanvasRuntimeSurfacePort.
- MainFramePainter и OverlayFramePainter читают immutable paint outputs и не импортируют CanvasRuntime/DocumentStore/SurfaceResourceSession.
- CanvasTextEditingOverlay использует public CanvasTextEditingPort.activeSession, EditableText, runtime-owned session commit/dismiss и не дублирует TextPainter measurement.
- Example app использует package barrel package:iwb_canvas_engine/iwb_canvas_engine.dart в example/lib/** и не импортирует package:iwb_canvas_engine/src/**.
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
