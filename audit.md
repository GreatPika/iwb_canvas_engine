
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
