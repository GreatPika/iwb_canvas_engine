language: russian

# Шаг 13.5. Закрыть coverage gate для реальной логики и отрицательную regression-матрицу tooling

## Цель шага

После `13.4` все правила уже должны иметь owner-ов, но шаг `13` всё ещё не
будет закрыт, если CI не гарантирует их невозврат:

- `tool/check_coverage.dart` пока допускает исключения для файла с реальной
  логикой;
- coverage policy для критичных файлов недостаточно жёсткая;
- не у каждого guardrail-а есть отрицательный regression test, который падает
  при возврате drift-а.

Задача подшага: замкнуть line-coverage gate для `lib/src/**` и собрать
обязательную negative regression matrix в `test/tool/**` на каждый новый или
ужесточённый guardrail шага `13`.

## Что уже подтверждено по текущему состоянию

1. [check_coverage.dart](/Users/blackpika/iwb_canvas_engine/tool/check_coverage.dart)
   уже является owner-ом line coverage gate для `lib/src/**`.
2. Там же есть `excludedFromLcov`, и исходный шаг прямо требует убрать
   исключение для файла с реальной логикой.
3. `test/tool/**` уже содержит tooling regression surface, но исходный шаг
   требует дополнить его отрицательными сценариями на конкретные новые
   guardrails.
4. Этот подшаг замыкает acceptance предыдущих `13.1-13.4`, но не владеет их
   policy semantics.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `tool/check_coverage.dart` остаётся единственным owner-ом line coverage
   allow-list для `lib/src/**`.
2. Исключение для файла с реальной логикой удаляется именно здесь.
   После этого в allow-list могут оставаться только declaration-only или
   export-only units.
3. Ужесточение coverage policy для критичных файлов фиксируется в одном месте:
   `tool/check_coverage.dart`.
4. Каждый новый или ужесточённый guardrail шага `13` обязан иметь
   отрицательный regression scenario в `test/tool/**`.
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
  - ownership import/public/AST checks.

## Точная реализация, которую должен описывать код

1. `excludedFromLcov` больше не содержит файл с реальной логикой.
2. Coverage allow-list после подшага ограничен только declaration-only и
   export-only units.
3. Для критичных файлов, затронутых этим шагом, coverage policy становится
   явной и проверяемой одним owner-ом.
4. `test/tool/**` содержит отрицательные сценарии на:
   - `Link`
   - `part`
   - `part of`
   - утечку `Scene`
   - fake `controllerEpoch`
   - мутирующий метод с нейтральным именем
   - формальное `INV:` без реальной проверки
5. Regression matrix не дублирует policy owner-ов. Тесты только доказывают,
   что tooling-проверка действительно падает на нарушение.

## Последовательность реализации (только действия)

- [ ] Убрать из `tool/check_coverage.dart` исключение для файла с реальной
      логикой.
- [ ] Зафиксировать минимальный allow-list только для declaration-only и
      export-only units.
- [ ] Ужесточить coverage gate для критичных файлов шага `13`.
- [ ] Добавить отрицательные tool regression-сценарии на каждый guardrail
      исходного шага.
- [ ] Убедиться, что regression tests доказывают падение tooling, а не
      становятся вторым owner-ом policy.

## Критерии приёмки

- [ ] В `tool/check_coverage.dart` не остаётся исключения для файла с реальной
      логикой.
- [ ] Coverage allow-list ограничен только declaration-only/export-only units.
- [ ] Критичные файлы шага `13` проходят coverage gate без специальных
      необоснованных исключений.
- [ ] Для каждого guardrail-а исходного шага `13` есть отрицательный
      regression scenario в `test/tool/**`.
- [ ] Regression tests валидируют именно tool failure, а не дублируют policy
      owner-ов в отдельной логике.
- [ ] Повторная диагностика
      `dcm calculate-metrics tool/check_coverage.dart test/tool/coverage_tool_test.dart test/tool/import_boundaries_layers_tool_test.dart test/tool/guardrails_public_contracts_tool_test.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [ ] `test/tool/coverage_tool_test.dart` с отрицательным сценарием на файл с
      реальной логикой, ошибочно оставленный вне lcov
- [ ] `test/tool/import_boundaries_layers_tool_test.dart` с отрицательными
      сценариями `Link`, `part`, `part of`
- [ ] `test/tool/guardrails_public_contracts_tool_test.dart` с отрицательными
      сценариями:
      - утечка `Scene`
      - fake `controllerEpoch`
      - мутирующий метод с нейтральным именем
      - формальное `INV:` без реальной проверки
- [ ] Дополнительные existing tool tests обновляются только как regression
      harness, а не как второй policy owner

## Диагностика шага

- [ ] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      `tool/check_coverage.dart` и step-owned tool tests.
- [ ] Новые helper-ы test harness-а и coverage policy укладываются в предел
      `10 / 4 / 40`.
- [ ] Ни один hotspot в negative regression matrix не остаётся без owner-а:
      test support, расширенный ради `13.5`, закреплён именно за этим
      подшагом.
