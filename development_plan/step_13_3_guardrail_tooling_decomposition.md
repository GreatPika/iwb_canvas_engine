language: russian

# Шаг 13.3. Разрезать guardrail tooling на доменные модули без смены CLI contract

## Цель шага

`tool/check_import_boundaries.dart` и `tool/check_guardrails.dart` стали
слишком большими и смешивают несколько owner-областей в одном файле. Задача
этого подшага: разрезать оба tool entrypoint-а на фиксированный набор
внутренних модулей, не меняя:

- CLI path;
- CLI contract;
- набор проверок;
- порядок запуска в обязательном списке команд из `AGENTS.md`.

Подшаг не добавляет новые guardrail-правила и не меняет ownership правил из
`13.1`, `13.2`, `13.5`, `13.6`. Он только делает текущую tooling
структуру читаемой, однозначной и поддерживаемой.

После пересмотра umbrella-step этот подшаг считается закрытым. Его задача
была именно structural decomposition. Он не должен заново активировать
behavioral scope бывшего `13.4`, даже если соответствующие legacy-модули
остались в текущем дереве tooling.

## Граница подшага

- In:
  - структурная декомпозиция `tool/check_import_boundaries.dart`;
  - структурная декомпозиция `tool/check_guardrails.dart`;
  - вынос общего infrastructure-level support;
  - зеркальная декомпозиция `test/tool/**`.
- Out:
  - новые import-boundary rules;
  - новые public/export rules;
  - новые semantic AST-rules;
  - новые invariant ids;
  - новые coverage gates;
  - перенос layout registry из `tool/src/layer_guardrails.dart` в другой файл.

## Обязательная структура после шага

После завершения подшага структура должна быть именно такой.

### Tool entrypoint-ы

- `tool/check_import_boundaries.dart`
- `tool/check_guardrails.dart`

Эти два файла остаются на прежних путях и становятся thin runner-ами:

- содержат только `main(...)`;
- `tool/check_import_boundaries.dart` импортирует только
  `tool/src/import_boundaries/import_boundaries_runner.dart`;
- `tool/check_guardrails.dart` импортирует только
  `tool/src/guardrails/guardrails_runner.dart`;
- не содержат domain logic, AST traversal, policy tables, path helpers и
  diagnostic formatting.

### Общая support-зона

Нужно создать папку:

- `tool/src/guardrail_support/`

В ней должны появиться файлы:

- `tool/src/guardrail_support/guardrail_context.dart`
- `tool/src/guardrail_support/guardrail_path_utils.dart`
- `tool/src/guardrail_support/guardrail_ast_utils.dart`

Распределение ответственности фиксированное:

- `guardrail_context.dart`
  - создаёт и хранит один `AnalysisContextCollection` на один tool run;
  - предоставляет shared parse access;
  - хранит parse cache по absolute path;
  - не содержит policy и не знает о конкретных guardrail-правилах.
- `guardrail_path_utils.dart`
  - содержит нормализацию POSIX-path;
  - содержит repo-relative path conversion;
  - содержит package-name resolution;
  - не содержит import policy и не содержит проверок exported API.
- `guardrail_ast_utils.dart`
  - содержит общие helper-ы для `UriBasedDirective`, `part`, `part of`,
    line lookup и parse-or-fail;
  - не содержит import-boundary policy;
  - не содержит mutable-type policy.

Общие helper-ы из двух текущих giant-файлов должны быть вынесены именно сюда,
а не продублированы второй раз:

- сбор URI refs из directives;
- path normalization / dirname / join / repo-rel conversion;
- package name resolution;
- parse unit access;
- line lookup.

### Import-boundaries зона

Нужно создать папку:

- `tool/src/import_boundaries/`

Существующий файл

- `tool/src/layer_guardrails.dart`

остаётся на месте и продолжает быть single source of truth для top-level
`lib/src` layout из ownership `13.1`. Этот подшаг не переносит layout registry
в `import_boundary_policy.dart` и не создаёт для него второй owner.

В ней должны появиться файлы:

- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/import_boundaries/public_export_boundary_resolver.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`
- `tool/src/import_boundaries/import_boundaries_runner.dart`

Распределение ответственности фиксированное:

- `import_boundary_policy.dart`
  - содержит layer model этого tool owner-а;
  - содержит layer DAG;
  - содержит allow-list внешних пакетов по слоям;
  - содержит policy для `commands/**` и `internal/**`;
  - не делает AST traversal;
  - не читает файлы напрямую.
- `public_export_boundary_resolver.dart`
  - раскрывает import target через `lib/*.dart` export surface;
  - отвечает за re-export bypass resolution;
  - не проверяет policy сам по себе;
  - не пишет violations.
- `directive_boundary_checker.dart`
  - обходит directives и doc import links;
  - превращает directive target в resolved boundary target;
  - применяет policy из `import_boundary_policy.dart`;
  - формирует import-boundary violations.
- `import_boundaries_runner.dart`
  - обходит `lib/src/**`;
  - собирает top-level layout violations;
  - запускает checker для каждого файла;
  - использует `tool/src/layer_guardrails.dart` как owner layout contract;
  - печатает итоговый `OK/FAIL` для `check_import_boundaries.dart`.

### Guardrails зона

Нужно создать папку:

- `tool/src/guardrails/`

В ней должны появиться файлы:

- `tool/src/guardrails/public_surface_guardrails.dart`
- `tool/src/guardrails/mutable_type_leak_guardrails.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/src/guardrails/controller_api_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`

Распределение ответственности фиксированное:

- `public_surface_guardrails.dart`
  - проверяет root public entrypoint;
  - проверяет export-only contract для `lib/*.dart`;
  - проверяет exported API import restrictions;
  - проверяет `SceneWriteTxn` public surface contract;
  - содержит exported-surface collection и exported-scan policy;
  - не содержит mutable-type AST visitor.
- `mutable_type_leak_guardrails.dart`
  - содержит visitor и helpers для mutable type leak scan;
  - проверяет только leakage в exported signatures;
  - не проверяет controller semantics;
  - не проверяет interactive purity.
- `interactive_api_guardrails.dart`
  - остаётся отдельным модулем в текущем дереве `tool/src/guardrails/`;
  - инкапсулирует уже существующие interactive-focused checks без расширения
    их scope в рамках этого подшага;
  - не становится owner-ом public/export policy, invariant registry или
    coverage gates.
- `controller_api_guardrails.dart`
  - остаётся отдельным модулем в текущем дереве `tool/src/guardrails/`;
  - инкапсулирует уже существующие controller-focused checks, которые были
    разрезаны вместе с giant-файлом;
  - не делает behavioral/controller semantics частью active scope шага `13`
    после удаления бывшего `13.4`.
- `guardrails_runner.dart`
  - создаёт общий runtime для `check_guardrails.dart`;
  - запускает четыре доменных блока строго в таком порядке:
    `public_surface_guardrails`,
    `mutable_type_leak_guardrails`,
    `interactive_api_guardrails`,
    `controller_api_guardrails`;
  - печатает итоговый `OK/FAIL`.

## Обязательная структура тестов после шага

Нужно создать папки:

- `test/tool/import_boundaries/`
- `test/tool/guardrails/`

Нужно получить такую структуру test owner-ов.

### Import-boundaries tests

- `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`

### Guardrails tests

- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

Трактовка путей фиксированная:

- `import_boundaries_controller_structure_tool_test.dart` сохраняется по тому
  же пути и переводится из giant file в узкий owner-level test file;
- `guardrails_layout_and_entrypoints_tool_test.dart` сохраняется по тому же
  пути и переводится из giant file в узкий owner-level test file;
- остальные giant test files, которые не входят в финальную структуру этого
  шага, удаляются полностью.

### Shared test support

Папка:

- `test/tool/support/`

остаётся общей и не переносится.

Файлы поддержки:

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/tool_process_test_support.dart`

остаются в `test/tool/support/` и не становятся owner-ами policy.

## Жёсткие правила декомпозиции

1. Нельзя разбивать один logical tool на несколько CLI-команд.
2. Нельзя создавать второй `AnalysisContextCollection` внутри одного tool run.
3. Нельзя оставлять дубли path/AST helper-ов в `check_guardrails.dart` и
   `check_import_boundaries.dart` после выноса support.
4. Нельзя переносить policy из `13.1` в shared support.
5. Нельзя переносить policy из `13.2` в shared support.
6. Нельзя смешивать import-boundary policy и public-surface policy в одном
   новом модуле.
7. Нельзя оставлять giant test file, если его домен уже выделен в отдельный
   test owner.
8. Нельзя менять user-facing success/failure messages только ради рефакторинга.
9. Нельзя менять список обязательных команд из `AGENTS.md`.
10. Нельзя оставлять новую структуру наполовину собранной:
    если папка введена, её owner-файлы должны быть реально созданы в том же
    change-set.

## Требования по дедупликации

Дедупликация является обязательной частью этого подшага. Она касается только
тех мест, где сейчас есть общий infrastructure-level код у двух tool entrypoint-ов
или второй source of truth для одной и той же технической операции.

Обязательно дедуплицировать через `tool/src/guardrail_support/`:

- сбор URI refs из `import`, `export`, `part`, `part of`;
- line lookup по AST offset;
- parse-or-fail helper и доступ к parsed unit;
- path normalization;
- POSIX join / dirname;
- absolute-to-repo-relative path conversion;
- package name resolution;
- target path resolution для package/import targets.

Нельзя оставлять две независимые реализации этих helper-ов в:

- `tool/check_import_boundaries.dart`;
- `tool/check_guardrails.dart`;
- новых runner/module-файлах после разрезки.

Не требуется и не допускается делать «силовую» дедупликацию там, где общий
helper ухудшает domain readability:

- mutable-type leak traversal;
- legacy controller-focused checks;
- legacy interactive-focused checks;
- import-boundary policy tables;
- public-surface policy tables.

Для этих зон приоритетом остаётся ясный owner модуля, а не минимальное число
строк любой ценой.

`tool/analysis/find_similar_clones.dart` используется в этом подшаге как
диагностический инструмент для поиска infrastructure-level duplication перед
переносом и после переноса. Он не вводится как новый обязательный CI gate и не
заменяет архитектурное решение о том, что должно жить в shared support, а что
должно оставаться domain-local.

## Фиксированный порядок выполнения

Делать строго в таком порядке.

1. Создать `tool/src/guardrail_support/`.
2. Перенести туда все общие path/analyzer/AST helper-ы из двух entrypoint-ов.
3. Создать `tool/src/import_boundaries/`.
4. Перенести import-boundary logic в четыре фиксированных файла этой папки.
5. Убедиться, что `tool/src/layer_guardrails.dart` не дублируется и
   продолжает использоваться как единственный layout registry.
6. Свести `tool/check_import_boundaries.dart` к thin runner-у.
7. Создать `tool/src/guardrails/`.
8. Перенести guardrails logic в пять фиксированных файлов этой папки.
9. Свести `tool/check_guardrails.dart` к thin runner-у.
10. Создать `test/tool/import_boundaries/`.
11. Разрезать import-boundaries tool tests по новой структуре.
12. Создать `test/tool/guardrails/`.
13. Разрезать guardrails tool tests по новой структуре.
14. Удалить старые giant test files после переноса сценариев в новые owner-файлы.

## Что именно должно исчезнуть из текущих giant-файлов

После завершения подшага в:

- `tool/check_import_boundaries.dart`
- `tool/check_guardrails.dart`

не должно оставаться:

- длинных helper-цепочек path normalization;
- internal AST utility functions;
- policy maps;
- AST visitor implementations;
- domain-specific checker classes;
- file traversal orchestration;
- test-like fixture tables.

В этих двух файлах должен остаться только wiring к runner-ам.

## Критерии приёмки

- [x] `tool/check_import_boundaries.dart` является thin runner-ом.
- [x] `tool/check_guardrails.dart` является thin runner-ом.
- [x] Папка `tool/src/guardrail_support/` создана и содержит ровно три owner-файла:
      `guardrail_context.dart`, `guardrail_path_utils.dart`,
      `guardrail_ast_utils.dart`.
- [x] Папка `tool/src/import_boundaries/` создана и содержит ровно четыре
      owner-файла:
      `import_boundary_policy.dart`,
      `public_export_boundary_resolver.dart`,
      `directive_boundary_checker.dart`,
      `import_boundaries_runner.dart`.
- [x] Папка `tool/src/guardrails/` создана и содержит ровно пять owner-файлов:
      `public_surface_guardrails.dart`,
      `mutable_type_leak_guardrails.dart`,
      `interactive_api_guardrails.dart`,
      `controller_api_guardrails.dart`,
      `guardrails_runner.dart`.
- [x] Общие helper-ы path/analyzer/AST больше не дублируются между двумя
      entrypoint-ами.
- [x] Папки `test/tool/import_boundaries/` и `test/tool/guardrails/`
      созданы и содержат owner-level tool tests по фиксированным именам из
      этого шага.
- [x] Giant-content удалён из всех исходных test owner-ов.
- [x] Файлы
      `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
      и
      `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
      сохранены по тем же путям, но больше не являются giant file.
- [x] Файлы
      `test/tool/import_boundaries_layers_tool_test.dart`,
      `test/tool/guardrails_public_contracts_tool_test.dart`
      удалены полностью после переноса сценариев.
- [x] Все сценарии из исходных giant test files перенесены в финальные
      owner-level test files; thin shim files не допускаются.
- [x] CLI path, CLI contract, success/failure format и список обязательных
      команд остаются прежними.

## Проверки подшага

Так как шаг меняет production tooling и tool tests, после реализации должны
быть прогнаны те же обязательные команды, которые уже требуются для code
changes в `AGENTS.md`, включая tool checks и `test/tool` file-by-file.
