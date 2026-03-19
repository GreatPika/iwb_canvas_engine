language: russian

# Шаг 13.5. Довести invariant registry до canonical ids и proof-based coverage

## Цель шага

После `13.4` tooling уже должен ловить structural и semantic drift, но сами
invariants всё ещё останутся неполноценными, если registry и coverage policy
не отделяют реальное доказательство от формального маркера:

- `tool/invariant_registry.dart` пока не содержит весь набор уже принятых
  invariants;
- comment `// INV:...` сейчас сам по себе считается покрытием;
- naming contract для ids ещё не доведён до жёсткого `UPPER-KEBAB-CASE`.

Задача подшага: сделать `tool/invariant_registry.dart` canonical registry, а
`tool/check_invariant_coverage.dart` owner-ом proof-based coverage, где
comment marker без реальной enforcement-точки больше не засчитывается.

## Что уже подтверждено по текущему состоянию

1. [invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart)
   уже описывает machine-readable список invariants и прямо фиксирует запрет
   `_` в ids на уровне комментария-документации.
2. [check_invariant_coverage.dart](/Users/blackpika/iwb_canvas_engine/tool/check_invariant_coverage.dart)
   сейчас собирает любые `INV:<id>` references в `tool/**` и `test/**`, не
   различая proof point и формальный комментарий.
3. Исходный шаг требует добавить пять новых invariant ids и привести legacy
   ids к единому naming contract без `_`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `tool/invariant_registry.dart` остаётся единственным canonical registry для
   active project invariants.
2. `tool/check_invariant_coverage.dart` считает покрытием только один из трёх
   типов proof point:
   - реальную тестовую точку с assertion surface;
   - инструментальную проверку;
   - явный механизм доказательства.
3. Comment marker без доказательства не считается coverage.
4. В `13.5` добавляются и фиксируются следующие invariants:
   - `INV-SER-SCHEMA-VERSION-CONTRACT`
   - invariant монотонности `timestampMs`
   - invariant invalidation `PathNode` cache
   - invariant неизменяемости `ClearSceneResult.removedNodeIds`
   - invariant корректного `code` для unsupported schema version
5. Legacy invariant ids с `_` должны быть переименованы в `UPPER-KEBAB-CASE`
   в рамках этого подшага; новые ids с `_` после шага запрещены tooling-ом.
6. Этот подшаг не меняет line coverage allow-list и не владеет import/public
   guardrails.

## Граница шага

- In:
  - `tool/invariant_registry.dart`;
  - `tool/check_invariant_coverage.dart`;
  - naming contract invariant ids;
  - proof-based definition invariant coverage.
- Out:
  - line coverage gate;
  - import topology;
  - exported signature scans;
  - semantic mutation/epoch AST detection.

## Точная реализация, которую должен описывать код

1. Registry хранит только canonical ids без `_`.
2. Coverage tool умеет отличать формальный marker от реальной proof point.
3. Неизвестный или legacy id с `_` даёт явный tool failure.
4. Missing proof coverage для invariant-а даёт failure даже если в кодовой
   базе есть формальный `INV:` marker без enforcement surface.
5. Для новых invariants сразу определён их enforcement surface:
   test/tool, runtime tests или tool checks.

## Последовательность реализации (только действия)

- [ ] Добавить недостающие invariant ids в `tool/invariant_registry.dart`.
- [ ] Переименовать legacy ids с `_` в `UPPER-KEBAB-CASE`.
- [ ] Добавить tool guardrail, который запрещает новые ids с `_`.
- [ ] Перевести `check_invariant_coverage.dart` на proof-based coverage
      вместо comment-only recognition.
- [ ] Обновить marker/coverage contract в test/tool surface там, где это
      требуется для новых invariants.

## Критерии приёмки

- [ ] `tool/invariant_registry.dart` содержит все новые invariants из исходного
      шага `13`.
- [ ] После завершения подшага в registry не остаётся active ids с `_`.
- [ ] Новый invariant id с `_` приводит к tool failure.
- [ ] Comment-only `INV:` marker без реального proof point больше не
      засчитывается coverage.
- [ ] Coverage tool различает proof point и формальный комментарий.
- [ ] Для invariants schema-version contract, `timestampMs`, `PathNode` cache,
      `ClearSceneResult.removedNodeIds` и unsupported schema version `code`
      существуют явные enforcement surfaces.
- [ ] Повторная диагностика
      `dcm calculate-metrics tool/invariant_registry.dart tool/check_invariant_coverage.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [ ] `test/tool/guardrails/guardrails_controller_api_tool_test.dart` или отдельный
      targeted tool test с отрицательным сценарием на формальный `INV:` без
      реальной проверки
- [ ] Обновлённые targeted tests/tool fixtures на:
      - unsupported schema version `code`
      - монотонность `timestampMs`
      - invalidation `PathNode` cache
      - неизменяемость `ClearSceneResult.removedNodeIds`
- [ ] `dart run tool/check_invariant_coverage.dart` становится обязательным
      gate-ом этого подшага

## Диагностика шага

- [ ] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      `tool/invariant_registry.dart` и `tool/check_invariant_coverage.dart`.
- [ ] Любые новые parsing/proof-classification helper-ы укладываются в предел
      `10 / 4 / 40`.
- [ ] Если hotspot останется в coverage tool, он закреплён за этим подшагом и
      не переносится в `13.6`.
