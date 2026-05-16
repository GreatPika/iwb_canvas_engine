# Architecture Audit Checklist

Этот файл оставляет только дыры, которые нужно закрыть, чтобы архитектуру можно
было выполнять и проверять. Закрытие пункта означает, что исправлен контракт,
добавлено исполнимое доказательство и обновлены связанные plan/step документы,
если пункт входит в текущий плановый шаг.

## Порядок выполнения

- [ ] P1: закрыть публичный API до freeze: HOLE-001, HOLE-005, HOLE-006,
      HOLE-007 и HOLE-008.
- [ ] P2: расширить operation matrix до полного покрытия публичного API:
      HOLE-002.
- [ ] P3: уточнить resources/surface lifecycle до реализации P7/P13-зон:
      HOLE-001, HOLE-003 и HOLE-004.
- [ ] P4: сделать guardrails исполнимыми: HOLE-008 и DIAG-PROOF.
- [ ] P5: закрыть release-readiness proof: HOLE-009, HOLE-010 и HOLE-011.

## Блокеры API freeze

- [ ] HOLE-001: `CanvasResourceSource.appKey` публично доступен app resolver.
- [ ] HOLE-002: `operation_matrix.md` покрывает все публичные state/effect операции.
- [ ] HOLE-005: `CanvasOptional.value(null)` имеет однозначную запрещённую или каноническую семантику.
- [ ] HOLE-006: публичные DTO совместимы с validation, `const` и defensive copy policy.
- [ ] HOLE-007: имена публичных error codes совпадают между prose и enum.
- [ ] HOLE-008: `api.integration_surface_complete` доказан внешним compile fixture.

## Блокеры resources/surface lifecycle

- [ ] HOLE-001: app resolver может прочитать source key через публичный API.
- [ ] HOLE-003: resolved image cache не переживает смену resolver/surface некорректно.
- [ ] HOLE-004: `interactive=false` имеет однозначную preview/cancel semantics.

## Блокеры release readiness

- [ ] HOLE-002: operation matrix покрывает весь публичный state/event/effect surface.
- [ ] HOLE-008: integration surface proof исполнимый, а не субъективный.
- [ ] HOLE-009: benchmark gates имеют численные thresholds и baseline policy.
- [ ] HOLE-010: monotonic runtime-created timestamps имеют contract/test/release-gate mapping.
- [ ] HOLE-011: `docs/tool/check_docs.dart` и наличие `plan/` согласованы.
- [ ] DIAG-PROOF: disabled diagnostics не allocation-ят records в successful hot paths.

---

## HOLE-001 — `CanvasResourceSource.appKey` недоступен публичному resolver

Статус: Red.

Почему это дыра: app-owned `CanvasResourceResolver` получает `CanvasImageResource`,
но `appKey` находится в приватном `_CanvasAppKeyResourceSource`. Если внешний код
не может прочитать ключ без доступа к `src/**` и приватным классам, приложение не
сможет реализовать обязательную роль resolver.

Нужно закрыть:

- [ ] Сделать source key публично читаемым через стабильный public API.
- [ ] Выбрать форму API:
  - публичный subtype, например `CanvasAppKeyResourceSource.key`;
  - или публичный discriminator + accessor;
  - или другой явно проверяемый pattern matching API.
- [ ] Запретить решение, при котором app resolver должен импортировать `src/**`.
- [ ] Обновить `docs/contracts/public_api_v1.md`.
- [ ] Обновить resource contract, если меняется shape source descriptor.
- [ ] Добавить тест `api.resource_source_app_key_publicly_readable`.
- [ ] Тест должен компилировать внешний resolver, который импортирует только
      `package:iwb_canvas_engine/iwb_canvas_engine.dart` и читает `appKey`.

---

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
- [ ] Добавить строки или явные alias-строки для `setOffset`.
- [ ] Добавить строки или явные alias-строки для `panBy`.
- [ ] Добавить строки или явные alias-строки для `markAllResourcesDirty`.
- [ ] Добавить строки или явные alias-строки для text double-tap / text edit request.
- [ ] Для каждой строки указать touched state.
- [ ] Для каждой строки указать `documentRevision`.
- [ ] Для каждой строки указать `boundsRevision`.
- [ ] Для каждой строки указать `frameMetaRevision`.
- [ ] Для каждой строки указать `previewRevision`.
- [ ] Для каждой строки указать spatial effect.
- [ ] Для каждой строки указать projection effect.
- [ ] Для каждой строки указать resource effect.
- [ ] Для каждой строки указать repaint target.
- [ ] Для каждой строки указать action event.
- [ ] Для каждой строки указать no-op behavior.
- [ ] Для каждой строки указать rollback behavior.
- [ ] Добавить или обновить guardrail/test mapping, чтобы новые matrix rows были проверяемыми.

---

## HOLE-003 — Resource cache не учитывает смену resolver/surface

Статус: Red/Yellow.

Почему это дыра: resolved image cache описан как cache по
`resourceId/resourceRevision`. Если runtime переподключается с surface/resolver A
на surface/resolver B, cache может вернуть image, полученный от старого resolver.
Это особенно опасно, если одинаковые `appKey` в разных app contexts означают
разные изображения.

Нужно закрыть:

- [ ] Выбрать одно правило invalidation:
  - cache key включает `resolverGeneration` или `surfaceGeneration`;
  - или resolved image cache полностью очищается при attach/detach/swap resolver.
- [ ] Зафиксировать правило в `docs/contracts/resources.md`.
- [ ] Зафиксировать surface lifecycle implication в public/surface contract.
- [ ] Добавить тест `resource.resolver_swap_invalidates_resolved_image_cache`.
- [ ] Тест должен доказать, что image A от resolver A не возвращается после swap на resolver B.
- [ ] Тест должен доказать, что resolver B вызывается заново или cache очищен.
- [ ] Добавить executable proof для resolver reentrancy policy.
- [ ] Добавить executable proof для resolver budget.
- [ ] Добавить executable proof для no retry in same frame.

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

## HOLE-005 — `CanvasOptional.value(null)` неоднозначен

Статус: Yellow.

Почему это дыра: для nullable `T` технически возможно
`CanvasOptional<Size?>.value(null)`. Контракт различает `absent`, `value(x)` и
`nullValue()`, но явно не говорит, является ли `value(null)` запрещённым,
эквивалентом `nullValue()` или отдельным состоянием.

Нужно закрыть:

- [ ] Выбрать одно правило:
  - предпочтительно запретить `CanvasOptional.value(null)` всегда;
  - или канонизировать `CanvasOptional.value(null)` в `CanvasOptional.nullValue()`.
- [ ] Зафиксировать правило в `docs/contracts/public_api_v1.md`.
- [ ] Зафиксировать update compiler behavior для nullable fields.
- [ ] Добавить тест `api.canvas_optional_value_null_rejected`, если выбран запрет.
- [ ] Добавить тест `api.canvas_optional_null_value_only_for_nullable_fields`.
- [ ] Добавить тест `edit.optional_nullable_field_update_semantics`.

---

## HOLE-006 — Риск вокруг `const` DTO, validation и defensive copy

Статус: Yellow.

Почему это дыра: публичные DTO требуют runtime validation, collection limits,
immutability и defensive copy, но часть API описана через `const` constructors.
В Dart `const` constructor не может сделать ordinary defensive copy arbitrary
`Iterable`, а validation внутри `const` ограничена.

Нужно закрыть:

- [ ] Проверить public DTO construction boundaries.
- [ ] Проверить update DTO construction boundaries.
- [ ] Проверить runtime config construction boundaries.
- [ ] Проверить pointer sample routing boundaries.
- [ ] Зафиксировать runtime validation для finite numbers.
- [ ] Зафиксировать runtime validation для limits.
- [ ] Зафиксировать runtime validation для collection length.
- [ ] Зафиксировать runtime validation для allowed values.
- [ ] Пройти все публичные DTO и разделить их на безопасные `const` DTO и DTO,
      которым нужен non-const constructor/factory.
- [ ] Оставить `const` только там, где поля scalar/final и не требуется defensive copy.
- [ ] Оставить `const` только там, где не требуется runtime validation beyond assert-like checks.
- [ ] Для DTO с `Iterable`, `List`, `Set` или `Map` обеспечить defensive copy.
- [ ] Для DTO с коллекциями обеспечить unmodifiable stored collections.
- [ ] Для DTO со сложными constraints обеспечить runtime validation at construction boundary.
- [ ] Проверить `CanvasPalette` как конкретный `Iterable<Color>` case.
- [ ] Исправить policy wording с `List or Map` на `Iterable, List, Set, or Map`.
- [ ] Обновить `docs/contracts/public_api_v1.md`.
- [ ] Обновить `docs/contracts/validation_limits.md`.
- [ ] Добавить тест `api.dto_collection_inputs_are_defensively_copied`.
- [ ] Добавить тест `api.dto_collections_are_unmodifiable`.
- [ ] Добавить тест `api.invalid_public_dto_construction_rejected`.

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
становится субъективной проверкой наличия типов. HOLE-001 показывает, что типы
могут существовать, но внешний adapter всё равно не сможет выполнить роль.

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
