
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
