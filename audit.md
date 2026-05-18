# Architecture Audit Checklist

Этот файл оставляет только дыры, которые нужно закрыть, чтобы архитектуру можно
было выполнять и проверять. Закрытие пункта означает, что исправлен контракт,
добавлено исполнимое доказательство и обновлены связанные plan/step документы,
если пункт входит в текущий плановый шаг.

## Порядок выполнения

- [ ] P1: закрыть публичный API до freeze: HOLE-007 и HOLE-008.
- [ ] P2: расширить operation matrix до полного покрытия публичного API:
      HOLE-002.
- [ ] P3: уточнить resources/surface lifecycle до реализации P7/P13-зон:
      HOLE-004.
- [ ] P4: сделать guardrails исполнимыми: HOLE-008 и DIAG-PROOF.
- [ ] P5: закрыть release-readiness proof: HOLE-009, HOLE-010 и HOLE-011.

## Блокеры API freeze

- [ ] HOLE-002: `operation_matrix.md` покрывает все публичные state/effect операции.
- [ ] HOLE-007: имена публичных error codes совпадают между prose и enum.
- [ ] HOLE-008: `api.integration_surface_complete` доказан внешним compile fixture.

## Блокеры resources/surface lifecycle

- [ ] HOLE-004: `interactive=false` имеет однозначную preview/cancel semantics.

## Блокеры release readiness

- [ ] HOLE-002: operation matrix покрывает весь публичный state/event/effect surface.
- [ ] HOLE-008: integration surface proof исполнимый, а не субъективный.
- [ ] HOLE-009: benchmark gates имеют численные thresholds и baseline policy.
- [ ] HOLE-010: monotonic runtime-created timestamps имеют contract/test/release-gate mapping.
- [ ] HOLE-011: `docs/tool/check_docs.dart` и наличие `plan/` согласованы.
- [ ] DIAG-PROOF: disabled diagnostics не allocation-ят records в successful hot paths.

## HOLE-002 — Operation matrix не покрывает все публичные операции

Статус: Red/Yellow.

Почему это дыра: operation matrix должна доказывать revisions, repaint, spatial,
projection, resource effects, action events, no-op и rollback semantics. Если
публичной операции нет в матрице, у неё нет проверяемого архитектурного поведения.

Нужно закрыть:

- [ ] Добавить строки или явные alias-строки для `removeUnusedResource`.
- [ ] Добавить строки или явные alias-строки для `replaceDraftDocument`.
- [ ] Добавить строки или явные alias-строки для `toggleSelection`.
- [ ] Добавить строки или явные alias-строки для `clearSelection`.
- [ ] Добавить строки или явные alias-строки для `selectAll`.
- [ ] Добавить строки или явные alias-строки для `setMode`.
- [ ] Добавить строки или явные alias-строки для `setDrawStyle`.
- [ ] Добавить строки или явные alias-строки для `setDrawTool`.
- [ ] Добавить строки или явные alias-строки для `setDrawColor`.
- [ ] Добавить строки или явные alias-строки для `setPointerPolicy`.
- [ ] Добавить строки или явные alias-строки для `markAllResourcesDirty`.
- [x] Добавить строки или явные alias-строки для text double-tap / text edit request
      и guarded `commitTextEdit`.
- [ ] Для каждой строки указать touched state.
- [ ] Для каждой строки указать public `CanvasRuntimeState` revision effects.
- [ ] Для document-owned строк указать `documentRevision`.
- [ ] Для каждой строки указать `boundsRevision`.
- [ ] Для preview-owned строк указать `previewRevision`.
- [ ] Для каждой строки указать spatial effect.
- [ ] Для каждой строки указать projection effect.
- [ ] Для каждой строки указать resource effect.
- [ ] Для каждой строки указать repaint target.
- [ ] Для каждой строки указать action event.
- [ ] Для каждой строки указать no-op behavior.
- [ ] Для каждой строки указать rollback behavior.
- [ ] Добавить или обновить guardrail/test mapping, чтобы новые matrix rows были проверяемыми.

Принято в Step 6: `CanvasCameraPort.setOffset` и `panBy` покрыты как runtime
view camera операции через public `state.revisions.viewCamera`; они не являются
document edits. Persisted camera changes remain on `CanvasEdit.setCameraOffset`.

---

## HOLE-004 — Противоречие в `interactive=false`

Статус: Yellow.

Почему это дыра: контракт одновременно говорит, что `interactive=false` не мутирует
preview, и что переключение `true -> false` во время active pointer session делает
cancel cleanup. Active pointer cancel почти наверняка должен менять или очищать
pointer-owned preview, поэтому текущий текст допускает два несовместимых поведения.

Нужно закрыть:

- [ ] Переписать правило так, чтобы `interactive=false` не мутировал committed document, selection, resources и runtime mode.
- [ ] Явно разрешить cancel cleanup для состояния, принадлежащего active routed pointer session.
- [ ] Явно сохранить pending preview state, который не принадлежит active routed pointer.
- [ ] Обновить `docs/contracts/public_api_v1.md`.
- [ ] Добавить тест `surface.interactive_false_cancels_active_pointer_preview`.
- [ ] Добавить тест `surface.interactive_false_preserves_non_active_pending_line`.
- [ ] Добавить тест `surface.interactive_false_does_not_mutate_committed_document_selection_resources`.

---

## HOLE-007 — Несовпадение имён error codes

Статус: Yellow.

Почему это дыра: prose использует имена вроде `duplicateId` и
`missingReference`, а public enum содержит более конкретные
`duplicateElementId`, `duplicateLayerId`, `duplicateResourceId`,
`missingResourceReference`. Error codes являются частью публичного контракта,
поэтому prose и enum не должны расходиться.

Нужно закрыть:

- [ ] Выровнять prose и enum в `docs/contracts/public_api_v1.md`.
- [ ] Заменить `duplicateId` на конкретные public enum values.
- [ ] Заменить `missingReference` на `missingResourceReference` или другой точный public enum value.
- [ ] Проверить, что tests/guardrails ссылаются только на стабильные public enum values.
- [ ] Добавить тест `api.public_error_codes_match_contract_prose`.

---

## HOLE-008 — Guardrail `api.integration_surface_complete` слишком субъективен

Статус: Yellow.

Почему это дыра: guardrail должен доказывать, что публичного API достаточно для
app-level `NextEngineAdapter`, но без конкретного external fixture это легко
становится субъективной проверкой наличия типов. Ранее найденная
resource-source readability дыра показала, что типы могут существовать, но
внешний adapter всё равно не сможет выполнить роль.

Нужно закрыть:

- [ ] Добавить внешний compile fixture, например `test/fixtures/app_next_engine_adapter_compile_fixture.dart`.
- [ ] Fixture должен импортировать только `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- [ ] Fixture не должен импортировать `src/**`.
- [ ] Fixture не должен импортировать legacy symbols.
- [ ] Fixture не должен использовать internal runtime classes.
- [ ] Fixture должен компилироваться.
- [ ] Fixture должен реализовать required app adapter operations.
- [ ] Guardrail `api.integration_surface_complete` должен проверять compile fixture, а не абстрактную полноту.
- [ ] Добавить forbidden import check для fixture.
- [ ] Подключить guardrail к конкретному runner/fixture, чтобы он не был prose-only.

---

## HOLE-009 — Benchmark gates недостаточно численные

Статус: Yellow.

Почему это дыра: release gate “benchmark gates pass” не является исполнимым без
baseline source, allowed delta, P95/max thresholds, memory thresholds,
failure policy и hardware/runtime assumptions.

Нужно закрыть:

- [ ] Добавить machine-readable benchmark spec.
- [ ] Для каждого hot path benchmark указать avg threshold.
- [ ] Для каждого hot path benchmark указать P95 threshold.
- [ ] Для каждого hot path benchmark указать max threshold.
- [ ] Для memory-sensitive paths указать allocation/memory threshold.
- [ ] Указать baseline source.
- [ ] Указать allowed regression percentage.
- [ ] Указать benchmark artifact format.
- [ ] Указать CI command.
- [ ] Указать failure threshold.
- [ ] Указать failure policy.
- [ ] Указать hardware/runtime assumptions.
- [ ] Указать approval process для accepted regression.
- [ ] Покрыть как минимум pointer move, hit-test, paint, spatial query, resource resolving, cache miss/hit и projection avoidance.

---

## HOLE-010 — Monotonic runtime-created timestamps не имеют явного proof mapping

Статус: Yellow.

Почему это дыра: legacy capability inventory содержит monotonic runtime-created
timestamps, но поведение не привязано достаточно явно к public contract,
operation matrix, tests и release gates. Если это часть functional compatibility,
новый runtime должен доказать её явно.

Нужно закрыть:

- [ ] Добавить contract/test mapping `runtime_created_timestamps_monotonic`.
- [ ] Определить, что именно считается timestamp.
- [ ] Определить, где timestamp создаётся.
- [ ] Определить источник времени.
- [ ] Определить scope монотонности: внутри runtime или глобально.
- [ ] Определить поведение при wall-clock rollback.
- [ ] Определить, какие events получают timestamp.
- [ ] Добавить operation matrix linkage для операций/events, создающих timestamps.
- [ ] Добавить release gate linkage.
- [ ] Добавить тест на monotonic order.

---

## HOLE-011 — Структурный checker ожидает `plan/`, но в пакете его нет

Статус: Grey/Yellow.

Почему это дыра: `docs/tool/check_docs.dart` включает `plan` в required dirs, но
в текущем пакете виден `PLAN.md`, а директории `plan/` нет. Если checker должен
запускаться из этого корня, документационная проверка должна падать. Если zip
или docs package намеренно частичный, это нужно явно зафиксировать.

Нужно закрыть одним из вариантов:

- [ ] Добавить `plan/`, если он действительно обязателен.
- [ ] Убрать `plan` из `requiredDirs`, если canonical roadmap теперь `PLAN.md`.
- [ ] Документировать, что этот docs package частичный, а `check_docs.dart`
      запускается из другого полного корня.
- [ ] Добавить или обновить проверку, которая доказывает выбранное правило.

---

## DIAG-PROOF — Disabled diagnostics allocation proof

Статус: Green/Yellow.

Почему это дыра: diagnostics contract говорит, что disabled diagnostics не должны
создавать diagnostic records в successful hot paths. Это трудно доказать одним
текстом, поэтому нужен исполнимый proof через tests или benchmarks.

Нужно закрыть:

- [ ] Добавить executable test или benchmark для disabled diagnostics successful hot paths.
- [ ] Доказать, что diagnostic records не создаются в этих hot paths.
- [ ] Сохранить ограничения на bounded details, sanitizer и запрет runtime objects/images/closures/full scene dumps.
- [ ] Связать proof с guardrail/test/release-gate mapping, если diagnostics входят в release criteria.
