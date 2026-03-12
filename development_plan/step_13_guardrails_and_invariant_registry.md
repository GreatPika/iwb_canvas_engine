language: russian

# Шаг 13. Ужесточить guardrails и реестр инвариантов через подшаги 13.1-13.6

## Диагностические метрики

Этот блок остаётся диагностическим радаром шага, но для `13.x` он также
обязан быть отражён в критериях приёмки каждого подшага: новые owner-ы и
step-owned методы не должны пробивать пороги из
[analysis_options.yaml](/Users/blackpika/iwb_canvas_engine/analysis_options.yaml).

- Смотреть в первую очередь `cyclomatic-complexity`,
  `maximum-nesting-level` и `source-lines-of-code`.
- Пороговые значения для новых owner-ов и step-owned методов:
  - `cyclomatic-complexity <= 10`
  - `maximum-nesting-level <= 4`
  - `source-lines-of-code <= 40`
- Контрольные файлы:
  - `tool/check_import_boundaries.dart`
  - `tool/src/layer_guardrails.dart`
  - `tool/check_guardrails.dart`
  - `tool/check_invariant_coverage.dart`
  - `tool/check_coverage.dart`
  - `tool/invariant_registry.dart`
  - `test/tool/import_boundaries_layers_tool_test.dart`
  - `test/tool/import_boundaries_controller_structure_tool_test.dart`
  - `test/tool/guardrails_layout_and_entrypoints_tool_test.dart`
  - `test/tool/guardrails_public_contracts_tool_test.dart`
  - `test/tool/guardrails_interactive_api_tool_test.dart`
  - `test/tool/coverage_tool_test.dart`
  - `test/tool/support/guardrails_tool_test_support.dart`
  - `test/tool/support/public_entrypoint_contract.dart`
- Acceptance gate ставится и на новые owner-ы, и на целевые файлы этого шага.
  Если в контрольном файле есть hotspot, он обязан быть явно закреплён за
  одним из подшагов `13.x`, чтобы к концу шага `13` в перечисленных файлах не
  оставалось `HIGH`/`VERY HIGH` по этим трём метрикам.
- Полезный сигнал после шага: import topology, public/export guardrails,
  semantic AST-guardrails, invariant registry и coverage gates держатся на
  одном наборе tool-owned источников истины, а не на смеси regex-ов,
  комментариев и тестовых соглашений.

## Цель шага

После шагов `11.x` и `12.x` runtime/interactive/render semantics уже должны
быть приведены к одному owner-у, но сами гарантии невозврата всё ещё
недостаточно жёсткие:

- `check_import_boundaries.dart` и `layer_guardrails.dart` не закрывают все
  обходы layer DAG через `part`/`part of` как boundary surface, `Link`,
  top-level `lib/src/*.dart`
  и `lib/*.dart`;
- `check_guardrails.dart` пока не покрывает весь нужный semantic surface для
  mutable type leak-ов, write-only mutation, epoch invalidation, public
  entrypoint discipline и factory-only `SceneDataException`;
- `check_invariant_coverage.dart` засчитывает формальные `INV:` marker-ы даже
  без реальной точки доказательства;
- `check_coverage.dart` всё ещё допускает исключения для реальной логики;
- `tool/invariant_registry.dart` не фиксирует весь набор invariants, на
  которых уже держатся serialization/runtime contracts;
- отрицательные tool-regression сценарии покрывают не все правила, поэтому
  часть drift-а можно вернуть без явного CI-провала.

Исходный шаг `13` перечислял правильные задачи, но смешивал пять разных
ownership-областей: import topology, public/export guardrails, semantic
mutation/epoch guardrails, invariant registry/coverage и coverage/tool-test
closure. Без разведения этих обязанностей реализация почти неизбежно либо
размажет policy между несколькими tool-файлами, либо оставит часть правил
«проверяемыми только по договорённости».

## Как разбит этап

### Шаг 13.1

`development_plan/step_13_1_import_boundaries_and_layer_topology_guardrails.md`

Владелец решения по:

- `tool/check_import_boundaries.dart` как одному owner-у import topology;
- `tool/src/layer_guardrails.dart` как single source of truth для top-level
  `lib/src` layout;
- запрету boundary-bypassing `Link`, анализу `part`/`part of` как boundary
  surface, запрету новых `lib/src/*.dart` и bypass path через `lib/*.dart`;
- layer-scoped policy для внешних пакетов.

### Шаг 13.2

`development_plan/step_13_2_public_surface_and_mutable_type_guardrails.md`

Владелец решения по:

- public/export guardrails в `tool/check_guardrails.dart`;
- снятию `skip` для `interactive` и `view` там, где нужен реальный scan;
- guardrail-у mutable type leak-ов в exported/runtime signatures;
- правилу «один публичный вход» без обходов через дополнительные public
  entrypoints.

### Шаг 13.3

`development_plan/step_13_3_guardrail_tooling_decomposition.md`

Владелец решения по:

- декомпозиции `tool/check_import_boundaries.dart` и
  `tool/check_guardrails.dart` на доменные модули;
- выносу общего analyzer/path/AST support в одну shared-зону;
- добавлению понятных подпапок под `tool/src/**` и `test/tool/**`;
- зеркальной нарезке tool-тестов без смены CLI contract и без новых правил.

### Шаг 13.4

`development_plan/step_13_4_semantic_ast_guardrails_for_mutation_epoch_and_boundary_errors.md`

Владелец решения по:

- semantic AST-guardrails в `tool/check_guardrails.dart` для write-only
  mutation;
- semantic проверке `epoch invalidation`;
- запрету прямого `throw SceneDataException` вне централизованного
  boundary-error factory;
- разграничению между public/export checks из `13.2` и semantic runtime/tool
  checks этого подшага.

### Шаг 13.5

`development_plan/step_13_5_invariant_registry_and_proof_coverage_contract.md`

Владелец решения по:

- `tool/invariant_registry.dart` как canonical registry;
- `tool/check_invariant_coverage.dart` как owner-у proof-based coverage;
- добавлению недостающих invariant ids и унификации naming contract;
- запрету comment-only coverage и `_` в новых invariant ids.

### Шаг 13.6

`development_plan/step_13_6_coverage_gate_and_negative_tool_regression_matrix.md`

Владелец решения по:

- `tool/check_coverage.dart` как owner-у line-coverage gate для `lib/src/**`;
- снятию исключений для реальной логики и ужесточению policy по критичным
  файлам;
- отрицательной regression-матрице в `test/tool/**` на каждый новый или
  ужесточённый guardrail этого шага.

## Карта переноса деталей из исходного шага 13

1. boundary-bypassing `Link` внутри `lib/src/**`, анализ `part`/`part of`, запрет новых
   `lib/src/*.dart`, policy внешних пакетов по слоям, фиксация white list
   top-level слоёв, запрещённых/удалённых слоёв и перекрытие обходов через
   `lib/*.dart` переносятся в `13.1`.
2. Снятие `skip` для `interactive/view`, проверка утечки изменяемых типов в
   сигнатуры и защита правила «один публичный вход» переносятся в `13.2`.
3. Декомпозиция `check_import_boundaries.dart`, `check_guardrails.dart` и
   зеркальная нарезка `test/tool/**` без смены CLI contract переносятся в
   `13.3`.
4. Семантическая проверка write-only mutation по AST и опасным операциям,
   semantic проверка `epoch invalidation` и запрет прямого
   `throw SceneDataException` вне boundary factory переносятся в `13.4`.
5. Новый invariant-пакет:
   - `INV-SER-SCHEMA-VERSION-CONTRACT`
   - invariant монотонности `timestampMs`
   - invariant invalidation `PathNode` cache
   - invariant неизменяемости `ClearSceneResult.removedNodeIds`
   - invariant корректного `code` для unsupported schema version
   а также rename legacy ids с `_`, запрет `_` в новых id и proof-based
   coverage вместо comment-only marker-ов переносятся в `13.5`.
6. Снятие исключения coverage для файла с реальной логикой, ужесточение
   coverage policy для критичных файлов и отрицательные tool-test сценарии на:
   - boundary-bypassing `Link`
   - `part` как обход boundary-rule
   - `part of` как обход boundary-rule
   - утечку `Scene`
   - fake `controllerEpoch`
   - мутирующий метод с нейтральным именем
   - формальное `INV:` без реальной проверки
   переносятся в `13.6`.
7. Ничего из исходного шага не теряется:
   - `## Диагностические метрики` остаются обязательной частью acceptance gate
     каждого подшага;
   - целевые файлы не имеют права пробивать пороги;
   - каждый guardrail получает либо owner-level tool enforcement, либо
     обязательный отрицательный regression test, либо оба механизма сразу.

## Уже принятые архитектурные решения

1. `tool/src/layer_guardrails.dart` остаётся single source of truth для
   допустимого top-level layout под `lib/src/**`.
   `tool/check_import_boundaries.dart` только потребляет этот contract и не
   дублирует его вторым списком.
2. `Link` внутри engine-owned runtime/controller surface запрещён как
   structural boundary-rule. `part`/`part of` для `lib/src/**` после шага `13`
   обязаны анализироваться как полноценный directive surface:
   tooling должен видеть их в boundary-модели и уметь запрещать там, где это
   уже запрещено policy, а не игнорировать как «не import».
3. Policy внешних пакетов фиксируется по слоям в одном owner-е import
   guardrails и не размазывается между `check_import_boundaries.dart` и
   `check_guardrails.dart`.
4. Public/export guardrails и semantic AST-guardrails остаются разными
   ownership-областями, даже если реализуются в одном файле
   `tool/check_guardrails.dart`.
   Это нужно, чтобы не смешивать signature-scan и behavioral AST-detection в
   один «бог-сканер».
5. Write-only mutation и epoch invalidation должны определяться по смыслу:
   по AST shape, опасным операциям и реальному invalidation path, а не по
   одному имени метода или наличию слова `controllerEpoch`.
6. `SceneDataException` остаётся boundary-owned error type.
   Прямой `throw SceneDataException(...)` вне централизованной factory
   запрещён, кроме явного allow-list для самой factory и тестов, которые
   проверяют этот boundary.
7. `tool/invariant_registry.dart` остаётся canonical registry, а
   `tool/check_invariant_coverage.dart` считает покрытием только реальные
   proof points:
   - тестовую точку с наблюдаемым assertion surface;
   - инструментальную проверку;
   - явный механизм доказательства.
8. Invariant ids используют только `UPPER-KEBAB-CASE`.
   Legacy ids с `_` должны быть переименованы в рамках `13.5`; после этого
   новые ids с `_` не допускаются.
9. `tool/check_coverage.dart` может исключать только declaration-only или
   export-only units. Файл с реальной логикой не имеет права оставаться в
   allow-list.
10. Негативный regression test обязателен для каждого guardrail-а, который
    этот шаг добавляет или делает строже. Tooling без regression matrix не
    считается завершённым.

## Общие правила для всех подшагов

1. Один owner отвечает за один тип policy:
   - import topology;
   - public/export surface;
   - semantic AST guardrails;
   - invariant registry/coverage;
   - coverage gate и negative regression matrix.
   Нельзя дублировать одну и ту же policy в двух tool-файлах.
2. Подшаги `13.2` и `13.4` не имеют права конкурировать за одну и ту же
   проверку в `tool/check_guardrails.dart`:
   - `13.2` владеет signature/public surface checks;
   - `13.4` владеет semantic AST/runtime boundary checks.
3. Comment marker `// INV:<id>` сам по себе не является доказательством
   invariants после шага `13`. Если marker остаётся, он должен быть привязан к
   реальной проверке.
4. Любой новый allow-list должен быть минимальным, явно мотивированным и
   принадлежащим ровно одному owner-у. «Временные» исключения без owner-а
   запрещены.
5. Если в рамках подшага меняется `tool/invariant_registry.dart`, этот подшаг
   обязан прогонять `dart run tool/check_invariant_coverage.dart`.

## Ownership Matrix

- `13.1` владеет только import topology, layout registry и layer/external
  package boundaries.
- `13.2` владеет только public/export surface guardrails, mutable type leak
  detection в signatures и single-public-entrypoint discipline.
- `13.3` владеет только структурной декомпозицией tooling-файлов и
  зеркальной декомпозицией tool-тестов без изменения policy.
- `13.4` владеет только semantic AST-guardrails для mutation/epoch/boundary
  errors.
- `13.5` владеет только canonical invariant registry и criteria того, что
  считается доказательством invariant-а.
- `13.6` владеет только coverage gate для `lib/src/**` и negative regression
  matrix для tooling этого шага.
- Ни один подшаг не должен одновременно владеть и определением invariant id,
  и line-coverage allow-list, и import topology одного и того же файла.

## Критерии готовности umbrella-шага

1. Для шагов `13.1`, `13.2`, `13.3`, `13.4`, `13.5`, `13.6` существуют отдельные
   step-файлы с собственной целью, границей ответственности, критериями
   приёмки и тестовым контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `13.1` отвечает только за import topology и layer layout;
   - `13.2` отвечает только за public/export guardrails;
   - `13.3` отвечает только за structural decomposition tool-файлов и
     зеркальную декомпозицию tool-тестов;
   - `13.4` отвечает только за semantic AST guardrails;
   - `13.5` отвечает только за invariant registry и proof coverage contract;
   - `13.6` отвечает только за coverage gate и negative tool regression
     matrix.
3. Ни один пункт исходного шага `13` не потерян при переносе, включая блок
   диагностических метрик и требование не пробивать пороги `10 / 4 / 40`.
4. Между подшагами зафиксирована жёсткая граница:
   - `13.1` не проверяет public signature semantics;
   - `13.2` не определяет AST semantics write-only mutation;
   - `13.3` не меняет policy semantics, а только декомпозирует tooling;
   - `13.4` не вводит новые invariant ids;
   - `13.5` не меняет coverage allow-list `lib/src/**`;
   - `13.6` не становится вторым owner-ом import/public/invariant policy.
5. Шаг готов к имплементации только если для каждого из шести подшагов уже
   однозначно определены:
   - owner;
   - целевые файлы;
   - out-of-scope;
   - acceptance gate;
   - отрицательный regression surface, который не даст drift-у вернуться.
