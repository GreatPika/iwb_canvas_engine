language: russian

# Шаг 13.1. Замкнуть import topology, layer layout и package-boundary guardrails

## Цель шага

Сначала нужно закрыть structural import surface. Пока
`tool/check_import_boundaries.dart` и `tool/src/layer_guardrails.dart` не
фиксируют полный topology contract, любой следующий guardrail остаётся
обходным:

- `Link` внутри `lib/src/**` всё ещё может протащить runtime coupling через
  слой, который tooling не видит как обычный import;
- `part` и `part of` позволяют обойти import-boundary policy вообще;
- новые `lib/src/*.dart` и re-export path через `lib/*.dart` размывают
  границу между public surface и internal layer topology;
- policy внешних пакетов пока не описана по слоям как один owner contract.

Задача подшага: сделать `tool/check_import_boundaries.dart` и
`tool/src/layer_guardrails.dart` одним архитектурным owner-ом import topology
с точной фиксацией layout, import-directive surface и package-boundary policy.

## Что уже подтверждено по текущему состоянию

1. [check_import_boundaries.dart](/Users/blackpika/iwb_canvas_engine/tool/check_import_boundaries.dart)
   уже читает AST import/export directives и использует
   [layer_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/layer_guardrails.dart)
   как helper для top-level `lib/src` layout.
2. Там же уже есть enforcement layer DAG и controller-structure guardrails, но
   из исходного шага ещё не закрыты `Link`, `part`, `part of`, top-level
   `lib/src/*.dart`, bypass path через `lib/*.dart` и внешние пакеты по слоям.
3. [layer_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/layer_guardrails.dart)
   уже содержит `approvedTopLevelLibSrcLayers` и `deletedTopLevelLibSrcLayers`,
   но это ещё не описано как полный layout registry для всех import-boundary
   решений.
4. Import topology и layer registry уже логически связаны, поэтому разносить
   их по разным подшагам означало бы создать два competing source of truth.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `tool/src/layer_guardrails.dart` является единственным owner-ом:
   - approved top-level `lib/src` layers;
   - deleted/forbidden layers;
   - helper-ов, по которым `check_import_boundaries.dart` определяет layout
     validity.
2. `tool/check_import_boundaries.dart` является единственным owner-ом
   structural import-boundary enforcement для:
   - `import`
   - `export`
   - `part`
   - `part of`
   - `Link` внутри `lib/src/**`
3. Запрет `part`/`part of` и запрет `Link` под `lib/src/**` входят именно в
   этот подшаг и не делегируются `check_guardrails.dart`.
4. Новые `lib/src/*.dart` запрещены по умолчанию. Разрешены только явно
   перечисленные whitelist-ом единицы, если они действительно являются
   sanctioned top-level entry leaf-ами.
5. Обход layer policy через `lib/*.dart` запрещён: internal layer import не
   может маскироваться под package import через public re-export surface.
6. Policy внешних пакетов задаётся по слоям внутри import-boundary owner-а, а
   не scattered regex-ами в других tool-файлах.
7. Этот подшаг не решает:
   - mutable type leak в exported signatures;
   - semantic AST-check для mutation/epoch;
   - invariant registry/coverage.

## Граница шага

- In:
  - `tool/check_import_boundaries.dart`;
  - `tool/src/layer_guardrails.dart`;
  - import/export/part/link topology;
  - top-level `lib/src` layout registry;
  - package-by-layer policy для внешних зависимостей;
  - bypass path через `lib/*.dart`.
- Out:
  - public signature scan;
  - semantic AST guardrails;
  - invariant registry;
  - line coverage policy;
  - отрицательные regression-сценарии на правила, которые принадлежат не этому
    owner-у.

## Точная реализация, которую должен описывать код

1. `check_import_boundaries.dart` анализирует не только `import`/`export`, но
   и `part`/`part of` directives как полноценный boundary surface.
2. Любой `Link` внутри `lib/src/**` трактуется как import-boundary violation.
3. `layer_guardrails.dart` явно различает:
   - approved top-level layers;
   - deleted layers;
   - любые новые/unapproved layers.
4. Проверка top-level `lib/src/*.dart` запрещает новые leaf-файлы вне
   whitelist-а и делает это через один owner contract, а не ad hoc в тестах.
5. Import через `package:iwb_canvas_engine/...` или `lib/*.dart` не может
   использоваться как обход запрета на доступ к internal layer, если реальный
   target нарушает layer policy.
6. Внешние packages получают одну layer-scoped policy-модель: разрешение или
   запрет определяется из layer owner contract, а не из разбросанных исключений
   по отдельным файлам.

## Последовательность реализации (только действия)

- [ ] Зафиксировать в `layer_guardrails.dart` полный registry approved и
      deleted top-level layers.
- [ ] Перевести `check_import_boundaries.dart` на анализ `part` и `part of`.
- [ ] Добавить guardrail для `Link` внутри `lib/src/**`.
- [ ] Запретить новые `lib/src/*.dart` вне минимального whitelist-а.
- [ ] Перекрыть обход layer policy через `lib/*.dart` и package re-export path.
- [ ] Ввести layer-scoped policy для внешних packages без второго owner-а.

## Критерии приёмки

- [ ] `tool/src/layer_guardrails.dart` является единственным source of truth
      для top-level `lib/src` layout.
- [ ] `tool/check_import_boundaries.dart` обнаруживает нарушения в `import`,
      `export`, `part`, `part of` и `Link` под `lib/src/**`.
- [ ] Новый `lib/src/*.dart` вне whitelist-а приводит к tool failure.
- [ ] Deleted/unapproved top-level layer не проходит import-boundary check.
- [ ] Обход через `lib/*.dart` или package re-export не позволяет импортировать
      запрещённый internal target.
- [ ] Policy внешних packages определяется по layer owner contract и не
      дублируется в другом tool-файле.
- [ ] Подшаг не вводит mutable-signature scans, semantic mutation checks или
      invariant coverage logic.
- [ ] Повторная диагностика
      `dcm calculate-metrics tool/check_import_boundaries.dart tool/src/layer_guardrails.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [ ] `test/tool/import_boundaries_layers_tool_test.dart` с отрицательными
      сценариями:
      - `Link` в `lib/src/**`
      - `part`
      - `part of`
      - новый `lib/src/*.dart` вне whitelist-а
      - deleted/unapproved top-level layer
- [ ] `test/tool/import_boundaries_controller_structure_tool_test.dart`
      как regression guard на bypass path через `lib/*.dart` и package re-export
      в controller-related structure tests
- [ ] При необходимости расширение
      `test/tool/support/guardrails_tool_test_support.dart` только как test
      harness, а не как второй owner policy

## Диагностика шага

- [ ] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      `tool/check_import_boundaries.dart` и `tool/src/layer_guardrails.dart`.
- [ ] Все новые owner-level helper-ы для layout/import rules укладываются в
      предел `10 / 4 / 40`.
- [ ] Если hotspot останется в одном из целевых файлов, он обязан быть явно
      отнесён к ownership этого подшага и закрыт в рамках реализации, а не
      перенесён молча в `13.2+`.
