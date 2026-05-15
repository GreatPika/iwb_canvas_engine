# Docs Architecture Audit Fix List

Дата: 2026-05-14  
Область: `/Users/blackpika/iwb_canvas_engine/docs`

## Нужно исправить

### A08. Исправить README/index drift

Приоритет: P3 docs cleanup.

Проблема:

- `docs/README.md` обещает phase index, но `docs/indexes/by_phase.md` отсутствует;
- `docs/README.md` перечисляет `plan/` как часть docs layout, хотя `plan/` лежит в root.

Исправление:

- добавить `docs/indexes/by_phase.md` или убрать обещание phase index;
- заменить `plan/` wording на `root plan/`.
