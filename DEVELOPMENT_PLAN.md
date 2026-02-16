language: russian

# Этап 5 (интерактив) — чеклист исправлений по ревью

## P0 (обязательно перед закрытием этапа)

1. [x] Ранняя валидация входных координат указателя и double-tap позиции
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart` (`handlePointer`, `handleDoubleTap`), при необходимости `/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart` (дополнительная фильтрация на границе UI).
Почему: `NaN/Infinity` может попасть в `Rect.fromPoints`, обработку сегментов, hit-test probe и промежуточные буферы; это создаёт нестабильное поведение и потенциальные исключения в горячем пути ввода.
Как: добавить guard в самом начале `handlePointer`/`handleDoubleTap`: если `position.dx/dy` не конечные, событие игнорируется без изменения состояния жеста.
Проверка: добавить негативные тесты в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart` (invalid pointer input + invalid double-tap position => no throw, no side effects).

2. [x] Зафиксировать и реализовать единую семантику порога начала drag
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart`, `/Users/blackpika/iwb_canvas_engine/lib/src/core/interaction_types.dart`, docs (`README/API_GUIDE` при изменении публичного поведения).
Почему: сейчас `tapSlop` используется для move-режима, а `dragStartSlop` влияет только на line-tool; это создаёт неоднозначность настройки и неожиданные UX-различия.
Как: выбрать и закрепить один из вариантов:
1) использовать `dragStartSlop` для всех drag-жестов (move + line),
2) переименовать параметр в `lineDragStartSlop` и явно ограничить область его действия.
Рекомендация: вариант 1 как более консистентный для всей интерактивной модели.
Проверка: обновить unit-тесты порогов в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart`.

3. [x] Ограничить рост буферов точек во время активного жеста (не только на commit)
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart` (`_activeStrokePoints`, `_activeEraserPoints`), логика ресемплинга в `/Users/blackpika/iwb_canvas_engine/lib/src/core/input_sampling.dart`.
Почему: очень длинные жесты накапливают большие массивы до `up`; риск по памяти и по времени обработки, особенно для eraser.
Как: ввести промежуточное прореживание/ограничение при превышении soft-limit в ходе move; сохранить инвариант визуальной формы (концы/ключевые точки не теряются).
Проверка: добавить стресс-тесты длинного pen/eraser-жеста в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart`.
3.1 [x] Fail-fast validation for gesture soft-limit config + direct eraser-buffer cap test
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart`, `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart`.
Почему: без валидации конфигурации лимитов возможна тихая деградация; косвенных тестов недостаточно для фиксации bounded-поведения eraser-буфера.
Как: добавить runtime fail-fast проверки для `softLimit/trimTo` и прямой тест лимита `_activeEraserPoints` во время длинного `move`.
Проверка: unit-тесты `invalid soft-limit config throws ArgumentError` и `eraser active buffer is capped during long move`.

## P1 (нужно сделать в рамках стабилизации интерактива)

4. [x] Формально определить поведение `pendingLineStart` при `PointerPhase.cancel`
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart` (ветка draw/line cancel), docs контракта интерактива.
Почему: текущая семантика неочевидна — pending state может сохраняться после cancel до таймера/смены режима.
Как: выбрать и зафиксировать поведение.
Рекомендация: очищать `pendingLineStart` на cancel как более безопасный и предсказуемый вариант.
Проверка: тест в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart` на cancel при активном pending-line.

5. [х] Снизить вычислительную стоимость ластика на длинных траекториях
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart` (коммит eraser), при необходимости `/Users/blackpika/iwb_canvas_engine/lib/src/core/hit_test.dart`.
Почему: пересечения по большому числу сегментов могут деградировать до тяжёлых сценариев в реальном времени.
Как: минимум — лимит/ресемплинг eraser-сегментов; желательно — coarse prefilter (AABB по батчам сегментов) до точной проверки.
Проверка: нагрузочный тест на длинный eraser-жест + замер времени выполнения в unit-тесте с разумным upper bound.

6. [x] Документировать контракт асинхронности событий интерактива
Где: `/Users/blackpika/iwb_canvas_engine/API_GUIDE.md`, `/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md`.
Почему: порядок `actions`/`editTextRequests` и `notifyListeners` важен для интеграторов; сейчас это поведение есть в коде и тестах, но не оформлено как явный контракт.
Как: явно описать гарантии (асинхронная доставка, коалесцирование notify) и что не гарантируется (строгий относительный порядок, если он не фиксируется).
Проверка: добавить/уточнить тест-кейсы на порядок доставки в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart`.

7. [x] Зафиксировать политику multi-touch (single-active-pointer) и покрыть её тестами
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart`, docs (`API_GUIDE`/`ARCHITECTURE`).
Почему: фактически поддерживается только один активный указатель, но это должно быть явным контрактом, иначе высок риск регрессий при изменениях ввода.
Как: явно задокументировать правило "второй/параллельный pointer игнорируется до завершения активного" в move/draw и сохранить текущее поведение в коде.
Проверка: добавить тесты в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart` на конкурентные pointer-события в move и draw.

8. [x] Зафиксировать и проверить семантику интерактивных API после dispose
Где: `/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart`.
Почему: для core есть fail-fast инвариант после dispose; интерактивный слой тоже должен иметь предсказуемый контракт (throws/no-op) для `handlePointer`, `handleDoubleTap`, mutating setters.
Как: выбрать единый контракт и привести поведение к нему без скрытых сайд-эффектов; согласовать с существующим `INV-ENG-DISPOSE-FAIL-FAST` (без дублирования смысла в новом ID).
Проверка: добавить тесты в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart` на вызовы после dispose и отметить enforcement-маркером `// INV:INV-ENG-DISPOSE-FAIL-FAST`.

## P2 (укрепление качества и регрессионная защита)

9. [x] Расширить набор негативных/граничных тестов по интерактиву
Где: `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart`, `/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart`.
Почему: текущие тесты покрывают базовые сценарии, но остаются дыры, указанные в ревью (invalid input, длинные жесты, cancel+pending line).
Как: добавить отдельные группы тестов `invalid pointer data`, `long gesture guardrails`, `line pending cancel semantics`, `single-active-pointer semantics`.
Проверка: стабильное прохождение `flutter test` без флаки.

10. [x] Привести guardrails интерактива к явному и проверяемому контракту
Где: `/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart`, ссылки `// INV:<id>` в тестах/утилитах.
Почему: ключевые ограничения (валидность pointer input, лимиты буферов, правила cancel) должны быть формализованы как инварианты, иначе высокий риск “тихой” регрессии.
Как: добавить/обновить инварианты и enforcement-ссылки в соответствующих тестах; добавлены `INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP`, `INV-ENG-INTERACTIVE-CANCEL-STATE-RESET`, `INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE`, `INV-ENG-VIEW-ACTIVE-POINTER-GATE`.
Проверка: `dart run tool/check_invariant_coverage.dart` зелёный.

## Предлагаемые новые инварианты для интерактива

11. [x] Добавить инвариант валидности pointer-координат
Где: `/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart` + `// INV:*` в `/Users/blackpika/iwb_canvas_engine/test/interactive/scene_controller_interactive_unit_test.dart`.
Почему: non-finite координаты должны отбрасываться на входе интерактива, не влияя на состояние.
Как: добавить `INV-ENG-INTERACTIVE-POINTER-FINITE` (или эквивалентный ID по принятому неймингу).
Проверка: `dart run tool/check_invariant_coverage.dart`.

12. [x] Добавить инвариант single-active-pointer для жеста
Где: `/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart` + тесты интерактива.
Почему: отсутствие формализации упрощает случайную поломку поведения multi-touch.
Как: добавить `INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER`.
Проверка: тесты на игнор параллельного pointer + `dart run tool/check_invariant_coverage.dart`.

13. [x] Добавить инвариант "preview не мутирует сцену до commit"
Где: `/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart` + тесты move/draw preview.
Почему: это ключевая гарантия производительности и корректности undo/redo модели.
Как: добавить `INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP`.
Проверка: тесты на отсутствие изменения snapshot до `up` + `dart run tool/check_invariant_coverage.dart`.
