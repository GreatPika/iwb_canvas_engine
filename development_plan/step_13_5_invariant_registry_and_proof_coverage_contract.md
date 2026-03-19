language: russian

# Шаг 13.5. Довести invariant registry до canonical ids и explicit proof coverage contract

## Цель шага

После `13.1-13.3` structural и public guardrails уже должны быть
зафиксированы, но сами invariants всё ещё останутся неполноценными, если
registry и coverage policy не отделяют явное доказательство от формального
комментария:

- `tool/invariant_registry.dart` пока не содержит весь набор уже принятых
  invariants;
- comment `// INV:...` сейчас сам по себе считается покрытием;
- naming contract для ids ещё не доведён до жёсткого `UPPER-KEBAB-CASE`.

Задача подшага: сделать `tool/invariant_registry.dart` canonical registry, а
`tool/check_invariant_coverage.dart` owner-ом explicit proof coverage, где
comment marker без явной proof-связи больше не засчитывается.

## Что уже подтверждено по текущему состоянию

1. [invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart)
   уже описывает machine-readable список invariants и прямо фиксирует запрет
   `_` в ids на уровне комментария-документации.
2. [check_invariant_coverage.dart](/Users/blackpika/iwb_canvas_engine/tool/check_invariant_coverage.dart)
   сейчас собирает любые `INV:<id>` references в `tool/**` и `test/**`, не
   различая proof point и формальный комментарий.
3. Исходный шаг требует добавить пять новых invariant ids и привести legacy
   ids к единому naming contract без `_`.
4. Зелёный статус `dart run tool/check_invariant_coverage.dart` в текущем коде
   не означает завершённость подшага: он подтверждает только marker presence,
   а не explicit proof contract.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `tool/invariant_registry.dart` остаётся единственным canonical registry для
   active project invariants.
2. `tool/check_invariant_coverage.dart` должен опираться на один явный proof
   contract, а не пытаться угадывать доказательство по произвольным
   комментариям.
3. Comment marker может оставаться навигационной меткой, но сам по себе не
   считается coverage.
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
  - explicit proof definition invariant coverage.
- Out:
  - line coverage gate;
  - import topology;
  - exported signature scans;
  - behavioral semantic checks для mutation или epoch.

## Точная реализация, которую должен описывать код

1. Registry хранит только canonical ids без `_`.
2. Для каждого active invariant существует явная proof-связь с конкретным
   test/tool enforcement surface.
3. Coverage tool валидирует именно explicit proof contract и существование
   указанного enforcement surface.
4. Неизвестный или legacy id с `_` даёт явный tool failure.
5. Missing explicit proof coverage для invariant-а даёт failure даже если в
   кодовой базе есть формальный `INV:` marker без привязки к proof contract.
6. Для новых invariants сразу определён их enforcement surface:
   test/tool, runtime tests или tool checks.

## Последовательность реализации (только действия)

- [x] Добавить недостающие invariant ids в `tool/invariant_registry.dart`.
- [x] Переименовать legacy ids с `_` в `UPPER-KEBAB-CASE`.
- [x] Добавить tool guardrail, который запрещает новые ids с `_`.
- [x] Перевести `check_invariant_coverage.dart` с comment-only recognition на
      explicit proof coverage contract.
- [x] Обновить registry/coverage contract в test/tool surface там, где это
      требуется для новых invariants.

## Критерии приёмки

- [x] `tool/invariant_registry.dart` содержит все новые invariants из
      активного шага `13`.
- [x] После завершения подшага в registry не остаётся active ids с `_`.
- [x] Новый invariant id с `_` приводит к tool failure.
- [x] Comment-only `INV:` marker без явной proof-связи больше не
      засчитывается coverage.
- [x] Coverage tool валидирует explicit proof contract, а не произвольные
      комментарии.
- [x] Для invariants schema-version contract, `timestampMs`, `PathNode` cache,
      `ClearSceneResult.removedNodeIds` и unsupported schema version `code`
      существуют явные enforcement surfaces.
- [x] Повторная диагностика
      `dcm calculate-metrics tool/invariant_registry.dart tool/check_invariant_coverage.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [x] Отдельный targeted invariant coverage test с отрицательным сценарием на
      формальный `INV:` без явной proof-связи
- [x] Обновлённые targeted tests/tool fixtures на:
      - unsupported schema version `code`
      - монотонность `timestampMs`
      - invalidation `PathNode` cache
      - неизменяемость `ClearSceneResult.removedNodeIds`
- [x] `dart run tool/check_invariant_coverage.dart` становится обязательным
      gate-ом этого подшага

## Диагностика шага

- [x] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      `tool/invariant_registry.dart` и `tool/check_invariant_coverage.dart`.
- [x] Любые новые parsing/proof-classification helper-ы укладываются в предел
      `10 / 4 / 40`.
- [x] Если hotspot останется в coverage tool, он закреплён за этим подшагом и
      не переносится в `13.6`.
