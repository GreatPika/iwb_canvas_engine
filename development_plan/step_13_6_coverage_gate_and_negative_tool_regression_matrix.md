language: russian

# Шаг 13.6. Закрыть coverage gate для реальной логики и отрицательную regression-матрицу tooling

## Цель шага

После `13.5` все правила уже должны иметь owner-ов, но шаг `13` всё ещё не
будет закрыт, если CI не гарантирует их невозврат:

- `tool/check_coverage.dart` пока допускает исключения для файла с реальной
  логикой;
- coverage policy для критичных файлов недостаточно жёсткая;
- не у каждого guardrail-а есть отрицательный regression test, который падает
  при возврате drift-а.

Задача подшага: замкнуть line-coverage gate для `lib/src/**` и добить только
тот остаток negative regression matrix в `test/tool/**`, который ещё не
закрыт после завершённых `13.1-13.3`.

## Что уже подтверждено по текущему состоянию

1. [check_coverage.dart](/Users/blackpika/iwb_canvas_engine/tool/check_coverage.dart)
   уже является owner-ом line coverage gate для `lib/src/**`.
2. Там же есть declaration-only allow-list, а после декомпозиции
   `scene_value_validation.dart` исполняемая логика уже живёт в
   `scene_value_validation_*.part.dart`, а не в root-unit.
3. `test/tool/**` уже содержит отрицательные сценарии на `Link`, `part`,
   `part of` и mutable-type leak `Scene`; незакрытый остаток этого подшага
   теперь сосредоточен в honest coverage allow-list.
4. Этот подшаг замыкает acceptance предыдущих `13.1-13.5`, но не владеет их
   policy semantics.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `tool/check_coverage.dart` остаётся единственным owner-ом line coverage
   allow-list для `lib/src/**`.
2. Declaration-only root-unit может оставаться в allow-list только если он
   реально не содержит исполняемой логики, а покрытие для связанной логики
   обеспечивается через `*.part.dart` без скрытых исключений.
   После этого в allow-list могут оставаться только declaration-only или
   export-only units.
3. Ужесточение coverage policy для критичных файлов фиксируется в одном месте:
   `tool/check_coverage.dart`.
4. Этот подшаг не переигрывает уже закрытые regression-сценарии `13.1-13.3`.
   Он добавляет только те negative tests, которых реально не хватает после
   пересмотра scope шага `13`.
5. Этот подшаг не вводит новые import/public/invariant policies; он только
   замыкает их на CI-level невозврат.

## Граница шага

- In:
  - `tool/check_coverage.dart`;
  - `test/tool/**` negative regression matrix;
  - allow-list cleanup для coverage по `lib/src/**`.
- Out:
  - новые semantic rules для import/public/invariants;
  - изменение invariant ids;
  - ownership import/public/behavioral checks.

## Точная реализация, которую должен описывать код

1. Declaration-only allow-list не содержит исполняемые `*.part.dart` или
   другой реальный logic-bearing unit.
2. Coverage allow-list после подшага ограничен только declaration-only и
   export-only units.
3. Для критичных файлов, затронутых этим шагом, coverage policy становится
   явной и проверяемой одним owner-ом.
4. `test/tool/**` уже содержит отрицательные сценарии на:
   - `Link`
   - `part`
   - `part of`
   - утечку `Scene`
   - формальный `INV:` без явной proof-связи
   и должен быть дополнен только coverage-сценарием на logic-bearing
   `scene_value_validation_*.part.dart`, ошибочно оставленный вне lcov.
5. Regression matrix не дублирует policy owner-ов. Тесты только доказывают,
   что tooling-проверка действительно падает на нарушение.

## Последовательность реализации (только действия)

- [x] Уточнить declaration-only allow-list в `tool/check_coverage.dart` под
      фактическую структуру `scene_value_validation`.
- [x] Зафиксировать минимальный allow-list только для declaration-only и
      export-only units.
- [x] Ужесточить coverage gate для критичных файлов шага `13`.
- [x] Добавить только недостающий coverage regression-сценарий для активного
      остатка шага `13`.
- [x] Убедиться, что regression tests доказывают падение tooling, а не
      становятся вторым owner-ом policy.

## Критерии приёмки

- [x] В `tool/check_coverage.dart` allow-list не скрывает logic-bearing
      `scene_value_validation_*.part.dart` или другой исполняемый unit.
- [x] Coverage allow-list ограничен только declaration-only/export-only units.
- [x] Критичные файлы шага `13` проходят coverage gate без специальных
      необоснованных исключений.
- [x] Для активного остатка шага `13` coverage gate имеет нужный regression
      scenario в `test/tool/**`, а остальные negative scenarios уже закрыты.
- [x] Regression tests валидируют именно tool failure, а не дублируют policy
      owner-ов в отдельной логике.
- [x] Повторная диагностика
      `dcm calculate-metrics tool/check_coverage.dart test/tool/coverage_tool_test.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [x] `test/tool/coverage_tool_test.dart` с отрицательным сценарием на
      logic-bearing `scene_value_validation_*.part.dart`, ошибочно оставленный
      вне lcov
- [x] `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
      уже содержит отрицательные сценарии `Link`, `part`, `part of`
- [x] `test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart`
      уже содержит отрицательный сценарий на утечку `Scene`
- [x] `test/tool/invariant_coverage_tool_test.dart` уже содержит targeted
      negative scenario на формальный `INV:` без явной proof-связи
- [x] Дополнительные existing tool tests обновляются только как regression
      harness, а не как второй policy owner

## Диагностика шага

- [x] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      `tool/check_coverage.dart` и step-owned tool tests.
- [x] Новые helper-ы test harness-а и coverage policy укладываются в предел
      `10 / 4 / 40`.
- [x] Ни один hotspot в negative regression matrix не остаётся без owner-а:
      coverage regression harness, расширенный ради `13.6`, закреплён именно
      за этим подшагом.
