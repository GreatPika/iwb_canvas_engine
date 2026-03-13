language: russian

# Шаг 13.4. Закрыть mutation routing и epoch invalidation через owner-level AST guardrails

## Цель шага

После `13.2` и `13.3` public surface и структура tooling уже выровнены, но
behavioral drift всё ещё остаётся возможным, потому что controller guardrails
пока опираются на слабые name-based признаки вместо проверки реальных
owner-level chokepoint-ов:

- write-only mutation сейчас можно обойти нейтральным именем метода;
- `epoch invalidation` сейчас можно формально «изобразить» словом
  `controllerEpoch`, не сохранив canonical commit path;
- предыдущая постановка пыталась доказать произвольную runtime-семантику по
  AST-фрагментам и из-за этого трижды уводила реализацию в хрупкий,
  легко-обходной tooling.

Задача подшага: отказаться от псевдо-semantic сканирования «любых опасных
операций» и перевести `controller_api_guardrails.dart` на owner-level AST
guardrails, которые проверяют фиксированные mutation/epoch chokepoint-ы и не
пытаются заново доказать всю runtime-семантику контроллера.

## Почему прежняя стратегия неверна

1. Полноценно определить «мутацию» по произвольному AST без alias/data-flow
   анализа нельзя: tooling либо начинает пропускать обходы, либо даёт ложные
   срабатывания на легитимные internal mutation zones.
2. `epoch invalidation` в проекте выражен не символом `controllerEpoch`, а
   canonical ownership path:
   `writeReplaceScene/writeDocumentReplace -> changeSet.documentReplaced -> resolveNextControllerEpoch(...) -> spatial/store commit`.
   Проверять наличие одного слова бессмысленно.
3. Глобальный запрет прямого `throw SceneDataException(...)` конфликтует с уже
   зафиксированной архитектурой шагов `6.1-6.4`: sanitization и contract
   shape централизованы в
   [scene_data_exception.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_data_exception.dart),
   но code/path ownership остаётся у локальных boundary helper-ов в
   `model/` и `serialization/`.
   `13.4` не должен становиться вторым owner-ом error boundary.

## Что уже подтверждено по текущему состоянию

1. [check_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/check_guardrails.dart)
   уже сведён к thin runner-у, а текущая controller/boundary логика живёт в
   [controller_api_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/guardrails/controller_api_guardrails.dart).
2. Текущая реализация уже ловит часть drift-а, но всё ещё остаётся
   синтаксической и name-based:
   - mutation определяется по имени символа и набору префиксов;
   - `epoch invalidation` засчитывается по самому символу;
   - canonical owner/chokepoint path сейчас tooling-ом не защищён.
3. Runtime-инвариант `INV-ENG-EPOCH-INVALIDATION` уже доказан через
   controller/view/render tests; tooling этого шага должен защищать
   structural owner-path, а не дублировать runtime proof.
4. Шаги `6.1-6.4` уже зафиксировали, что `SceneDataException` contract и
   sanitization централизованы в `contract/`, но boundary classification не
   собрана в один throw-site owner.
5. Эти проверки концептуально отличаются от public signature scan и поэтому
   не должны смешиваться с ownership `13.2`.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `13.4` владеет только owner-level controller AST-guardrails в
   `tool/src/guardrails/controller_api_guardrails.dart` под runner-ом
   `tool/check_guardrails.dart`.
2. Write-only mutation проверяется через canonical routing seams, а не через
   универсальный поиск «опасных операций»:
   tooling должен смотреть на candidate entrypoints во всём
   `lib/src/controller/**` и на их делегацию в
   `_core.write(...)`, `_core.writeReplaceScene(...)`,
   `_core.commands.write*` или `_writeRunner(...)`.
3. Public interactive методы, которые мутируют только interactive-local state
   и не трогают committed scene / controller transaction state, не считаются
   нарушением routing contract.
4. Controller/transaction-owned mutation допускается только в узких
   owner-level zones с минимальным declaration-level allow-list-ом;
   произвольные mutation к `_store`, `TxnContext`, mutable scene/selection и
   allocator state вне этих зон считаются bypass-ом, даже если mutation
   спрятана через локальный alias, cascade или local helper.
5. `epoch invalidation` считается сохранённым только если удержан canonical
   path для **state-commit** ветки:
   `writeDocumentReplace/ReplaceSceneOp -> documentReplaced -> resolveNextControllerEpoch(...) -> (invariant assert + spatial prepare + committed store apply) с одним и тем же resolved nextEpoch`.
   Effects-only commit branch не должна принудительно «притворяться» state
   commit-ом и вычислять `nextEpoch`.
6. Current private helper names/layout в epoch pipeline являются reference
   shape, а не жёстким syntactic contract: безопасная внутренняя декомпозиция
   допустима, если owner-level stages и единый epoch value сохраняются.
7. Глобальный direct-throw policy для `SceneDataException` выводится из scope
   этого подшага как неверный owner. Если когда-либо понадобится новый tool
   contract для error boundary, он должен жить отдельным owner-ом поверх
   шагов `6.1-6.4`, а не внутри controller guardrails.
8. Этот подшаг не решает:
   - mutable type leak signatures;
   - import topology;
   - invariant registry/coverage;
   - line coverage gate;
   - global `SceneDataException` constructor policy.

## Граница шага

- In:
  - owner-level AST checks для mutation routing surface;
  - явная граница между scene mutation и interactive-local mutation;
  - owner-level проверка canonical `epoch invalidation` path;
  - минимальный allow-list owner-level mutation zones.
- Out:
  - public/export signature scan;
  - invariant ids и proof coverage;
  - import/link/part boundaries;
  - coverage exclusions;
  - глобальный запрет direct `throw SceneDataException(...)`.

## Точная реализация, которую должен описывать код

1. Guardrail mutation routing сканирует candidate declaration-ы во всём
   controller scan root, но сверяет их с фиксированными chokepoint-символами и
   declaration-level allow-list-ом, а не пытается классифицировать любой AST
   как «опасный» или «безопасный».
2. Public scene-mutating entrypoint с нейтральным именем не может обойти
   guardrail, если не делегирует в canonical write seam напрямую; локальные
   helper-ы, alias-ы и промежуточные mutation-capable операции не считаются
   safe route.
3. Public interactive entrypoint, который меняет только interactive-local
   state и не трогает committed scene / controller-owned mutation surface, не
   должен сам по себе считаться нарушением.
4. Guardrail owner-state mutation ловит не только прямые `_store.* = ...`, но
   и bypass к `_store`, `TxnContext`, mutable scene/selection, allocator state
   и commit bookkeeping через alias/cascade/local helper вне явного owner-level
   allow-list-а.
5. Guardrail `epoch invalidation` валидирует не символ `controllerEpoch`, а
   сохранение canonical epoch stages и единого resolved epoch value между
   `resolveNextControllerEpoch(...)`, invariant assert, spatial prepare и
   committed store apply, не опираясь на `toSource()` и exact-text сравнение
   локальных имён или жёсткую привязку к одному private helper layout.
6. `writeReplaceScene(...)` остаётся owner-level частью этого контракта:
   он не может обойти write pipeline прямой заменой committed store.
7. Подшаг не меняет exported API scan policy, не вводит новые invariant ids и
   не владеет `SceneDataException` throw policy.

## Blueprint реализации

### 1. Scope scan-а

- Scan всегда охватывает весь `lib/src/controller/**`.
- Дополнительно scan охватывает
  [scene_controller_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interactive.dart),
  потому что публичный mutation routing начинается именно там.
- Нельзя сужать scan до «главных» файлов вроде `scene_controller.dart` или
  `commands/**`: если в controller tree появляется новый neutral mutator, он
  обязан попасть в ту же проверку автоматически.

### 2. Candidate declarations (что именно проверяем)

Guardrail строится не как «поиск опасных операций по всему проекту», а как
проверка того, что **весь публичный controller surface**:

1. либо является чистым (interactive-local-only / read-only),
2. либо маршрутизирует mutation через canonical write seams,
3. либо находится внутри явной allow-list mutation zone.

Минимальный контракт по candidate декларациям:

- Candidate entrypoints: любые **public** top-level функции и public методы
  классов, объявленные в scope scan-а (см. выше), включая getters/setters и
  operator methods.
- Внутренние helper-ы (private methods / private top-level helpers / local
  functions) участвуют в анализе только как зависимость candidate entrypoint-ов
  и как потенциальный способ спрятать mutation (local helper/alias/cascade).
- Public методы `SceneControllerInteractive`, которые меняют только
  interactive-local state (например `_mode`, `_drawTool`, `_drawColor`,
  координаторы жестов/сессий), не должны помечаться как нарушение сами по себе.
  Но если они дергают `_core.commands.write*` или `_core.write(...)`, то это
  уже canonical write seam и подчиняется routing-правилам как обычно.

### 3. Защищаемое состояние

Guardrail считает mutation-capable owner state следующие surface-ы:

- `SceneControllerCore._store` и любые локальные alias-ы на него, включая
  mutation к его полям (например `controllerEpoch`, `commitRevision`,
  `structuralRevision`, `boundsRevision`, `visualRevision`, `sceneDoc`,
  `selectedNodeIds`, `allNodeIds`, `nodeLocator`, `idGeneratorState`,
  `revisionState`);
- `TxnContext.changeSet` и любые локальные alias-ы на него (включая поля
  `documentReplaced`, `structuralChanged`, ... и `txnMark*`/`txnTrack*`);
- `TxnContext.workingSelection` и любые локальные alias-ы на него;
- `TxnContext.idGeneratorState` и любые локальные alias-ы на него;
- `TxnContext.revisionState` и любые локальные alias-ы на него;
- txn-owned materialization/mutation surface самого `TxnContext`: **любой**
  instance-вызов метода на объекте `TxnContext` считается mutation-capable,
  потому что даже read-подобные операции могут материализовать caches и менять
  внутреннее состояние транзакции. Такой вызов допустим только внутри явной
  txn-owned allow-list зоны (writer/executor/core write seam).

В mutation входят:

- обычное присваивание;
- compound assignment;
- `++` / `--`;
- mutating method calls;
- cascade mutation;
- mutation, спрятанная за local function/private helper.

Для `ChangeSet` mutating API включает не только `txnMark*`, но и `txnTrack*`.
Для `workingSelection` mutating API включает как минимум `add`, `addAll`,
`remove`, `removeAll`, `clear`, а реализация должна покрывать и эквивалентные
мутации `Set`.

### 4. Allow-list только на уровне деклараций

- Разрешённые mutation zones задаются не по файлам, а по конкретным
  declaration-ам.
- File-level allow-list запрещён: он уже приводил к blind spot, когда новый
  neutral mutator в «разрешённом» файле проходил scan.
- Каждый declaration в allow-list должен принадлежать одному из owner-ов:
  - core write seam;
  - command runner seam;
  - writer/executor transaction zone;
  - committed store apply zone.
  - effects-only commit bookkeeping zone.
- Новый mutation-capable declaration вне allow-list должен падать tooling-ом,
  пока его ownership явно не подтверждён.

### 5. Resolver model

Resolver не должен опираться на `toSource()` и exact-text сравнение там, где
достаточно AST-структуры и лексического scope.

- Declaration identity должна храниться по **AST node identity**
  (минимум: `file + offset + kind`), а не по паре `scope + name`.
  Element-resolution можно вводить только если tooling переводится на
  `ResolvedUnitResult` осознанно (perf/сложность).
- Нужно различать:
  - class methods;
  - top-level/private helpers;
  - local functions внутри методов.
- Mutation propagation обязана видеть и `MethodInvocation`, и
  `FunctionExpressionInvocation`.
- Cascade mutation обязана обрабатываться через `CascadeExpression`-sections, а
  не через `node.target` (у cascade target может быть `null`).
- Alias tracking нужен только в локальном method/function scope:
  - `final store = _store;`
  - `final tx = ctx;`
  - `final changeSet = ctx.changeSet;`
  - `final selection = ctx.workingSelection;`
  - `final ids = ctx.idGeneratorState;`
  - `final rev = ctx.revisionState;`
  - alias на canonical epoch value.
- Реализация не должна делать общий interprocedural data-flow analysis по
  всему проекту; разрешён только bounded resolution внутри declaration-а и по
  его локально вызываемым helper-ам.

### 6. Canonical mutation routing seams

Для owner-level routing допустимыми seam-ами считаются:

- `SceneControllerCore.write(...)`;
- `SceneControllerCore._writeWithSceneWriter(...)`;
- `SceneControllerCore.writeReplaceScene(...)`;
- `SceneCommands`, `DrawCommands`, `MoveCommands` через `_writeRunner(...)`;
- `SceneWriter.write*`;
- `MutationExecutor.execute*` / `_execute*` как txn-owned mutation zone;
- commit-owned helpers в `SceneControllerCore`, которые материализуют
  committed store.

Ни префикс имени, ни расположение в «похожем» файле сами по себе не делают
declaration safe.

### 7. Canonical epoch path

Guardrail проверяет именно owner path, а не spelling локальных имён:

1. `writeDocumentReplace(...)` / `ReplaceSceneOp` должны приводить к
   `changeSet.documentReplaced`.
2. `_buildControllerCommitPlan(...)` должен вычислять epoch через
   `resolveNextControllerEpoch(...)`.
3. Для **state-commit** ветки один и тот же canonical epoch value должен
   проходить через:
   - invariant assert (`controllerEpoch: nextEpoch`);
   - spatial prepare (`controllerEpoch: nextEpoch`);
   - committed store apply (`nextEpoch: nextEpoch`).
4. Для effects-only ветки epoch path не является обязательным; она может
   легитимно мутировать только commit bookkeeping (например `commitRevision`)
   без пересчёта `nextEpoch`. В частности, invariant assert в этой ветке
   легитимно использует текущий `_store.controllerEpoch`, а не resolved
   `nextEpoch`.
5. Безопасный rename локальной переменной или alias на epoch value не должен
   ломать guardrail.

### 8. Negative matrix до кода

До имплементации должны быть заранее зафиксированы отрицательные сценарии:

- новый neutral mutator в отдельном controller-файле;
- alias на `_store` с последующей mutation;
- alias на `ctx.changeSet` с `txnTrack*`;
- alias/cascade на `ctx.workingSelection`;
- alias на `ctx.idGeneratorState` или `ctx.revisionState` с последующей mutation;
- local helper, который мутирует owner state;
- local helper с именем, совпадающим с class method;
- harmless local rename в epoch path не ломает tool;
- bypass canonical `nextEpoch` path действительно ломает tool;
- `writeReplaceScene(...)` с прямым store bypass ломает tool.

## Последовательность реализации (только действия)

- [ ] Зафиксировать test fixture matrix до production-правок:
      - neutral mutator в отдельном controller-файле
      - alias на `_store`
      - alias на `ctx.changeSet` с `txnTrack*`
      - alias/cascade на `ctx.workingSelection`
      - local helper mutation
      - local helper с именем class method
      - harmless epoch rename
      - bypass canonical `nextEpoch` path
      - `writeReplaceScene(...)` store bypass
- [ ] Перевести scan candidate surface на полный обход controller tree и
      `scene_controller_interactive.dart`, без fixed-file shortcuts.
- [ ] Ввести declaration-level allow-list mutation zones вместо file-level
      исключений.
- [ ] Добавить detection прямой mutation owner state:
      `_store`, `ctx.changeSet`, `ctx.workingSelection`,
      `ctx.idGeneratorState`, `ctx.revisionState`, mutating `TxnContext` методы.
- [ ] Закрыть alias/cascade/local-helper bypass для owner state.
- [ ] Довести resolver declaration identity:
      - method vs local function
      - `MethodInvocation`
      - `FunctionExpressionInvocation`
- [ ] Перевести guardrail `epoch invalidation` с проверки символа
      `controllerEpoch` на canonical `nextEpoch` handoff path без
      exact-source-text matching.
- [ ] Защитить `writeReplaceScene(...)` как entrypoint canonical write path, а
      не как место локальной store replacement semantics.
- [ ] Явно вывести `SceneDataException` direct-throw policy из ownership
      `13.4`, чтобы этот подшаг не конфликтовал с шагами `6.1-6.4`.
- [ ] Явно развести эти проверки с public/export scan ownership `13.2`.
- [ ] Приложить финальный metrics/report пакет только после зелёной negative
      matrix на все перечисленные bypass-классы.

## Исполнительный чек-лист

### Phase 1. Harness first

- [ ] Добавить failing regression fixtures в
      `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
      до изменения production logic.
- [ ] Подтвердить, что каждый fixture падает по ожидаемой причине, а не по
      побочному parse/layout failure.

### Phase 2. Scan scope and allow-list

- [ ] Удалить любые fixed-file shortcuts из controller scan.
- [ ] Явно описать candidate files:
      весь `lib/src/controller/**` плюс
      `lib/src/interactive/scene_controller_interactive.dart`.
- [ ] Вынести declaration-level allow-list mutation zones в один owner-table.

### Phase 3. Owner-state mutation detection

- [ ] Покрыть direct writes to `_store`.
- [ ] Покрыть direct mutation calls на `ctx.changeSet`, включая `txnTrack*`.
- [ ] Покрыть direct mutation calls на `ctx.workingSelection`.
- [ ] Покрыть direct mutation к `ctx.idGeneratorState` и `ctx.revisionState`.
- [ ] Покрыть mutating вызовы на `TxnContext` (txn-owned materialization surface).
- [ ] Покрыть alias tracking внутри одного declaration scope.
- [ ] Покрыть cascades и local helper calls.

### Phase 4. Resolver hardening

- [ ] Развести identity для class methods и local functions.
- [ ] Добавить propagation через `FunctionExpressionInvocation`.
- [ ] Проверить сценарий одинаковых имён local helper и class method.

### Phase 5. Canonical epoch path

- [ ] Проверить, что `ReplaceSceneOp` приводит к `documentReplaced`.
- [ ] Проверить, что `_buildControllerCommitPlan(...)` использует
      `resolveNextControllerEpoch(...)`.
- [ ] Проверить, что canonical epoch value проходит через
      invariant assert, spatial prepare и committed store apply.
- [ ] Убедиться, что harmless local rename/alias не ломает guardrail.

### Phase 6. Closure

- [ ] Подтвердить, что `13.4` не лезет в `SceneDataException` global policy.
- [ ] Подтвердить, что `13.4` не дублирует ownership `13.2`.
- [ ] Прогнать metrics и приложить step diagnostics.

## Рекомендуемая нарезка коммитов

### Commit 1

- [ ] Только harness:
      negative fixtures и failing regression matrix без production-логики.

Gate:
`test/tool/guardrails/guardrails_controller_api_tool_test.dart`

### Commit 2

- [ ] Полный scan controller tree.
- [ ] Declaration-level allow-list zones.

Gate:
fixtures на fixed-file blind spot и file-level bypass

### Commit 3

- [ ] Direct owner-state mutation detection.
- [ ] `txnTrack*` coverage.
- [ ] Alias/cascade detection для `_store`, `changeSet`, `workingSelection`,
      `idGeneratorState`, `revisionState` и mutating `TxnContext` surface.

Gate:
fixtures на alias/cascade/direct mutation

### Commit 4

- [ ] Resolver hardening:
      local helper, `FunctionExpressionInvocation`, name-collision scenario.

Gate:
fixtures на local helper bypass и collision local function vs method

### Commit 5

- [ ] Canonical `nextEpoch` path guardrail.
- [ ] `writeReplaceScene(...)` canonical pipeline guardrail.

Gate:
fixtures на harmless rename, stale epoch path и replace-scene bypass

### Commit 6

- [ ] Cleanup.
- [ ] Metrics.
- [ ] Final ownership assertions in docs/step result.

Gate:
`dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`

## Критерии приёмки

- [ ] Мутирующий метод с нейтральным именем не обходит write-only mutation
      guardrail, если не идёт через canonical write seam.
- [ ] Прямой `_store` mutation вне явной commit-owned зоны приводит к
      tool failure.
- [ ] Alias/cascade/local-helper обход owner state вне явной commit-owned зоны
      приводит к tool failure.
- [ ] Локальная epoch math или использование stale `_store.controllerEpoch`
      вместо `nextEpoch` в canonical commit path не проходит guardrail.
- [ ] Безопасный rename локальной переменной в canonical epoch path не ломает
      guardrail сам по себе.
- [ ] `writeReplaceScene(...)`, обходящий canonical write pipeline, приводит к
      tool failure.
- [ ] Effects-only commit (когда нет state commit) не ломается guardrail-ом и
      может легитимно мутировать только commit bookkeeping (например
      `commitRevision`) без требований по `nextEpoch`.
- [ ] Public interactive методы, меняющие только interactive-local state (например
      `setMode`, `setDrawTool`, `setDrawColor`), не требуют routing через
      `_core.write(...)` и не падают tool-ом сами по себе.
- [ ] Подшаг не становится second owner-ом public signature scan и
      `SceneDataException` boundary policy.
- [ ] Повторная диагностика
      `dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`
      приложена к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.

## Тестовый контур шага

- [ ] `test/tool/guardrails/guardrails_controller_api_tool_test.dart` с отрицательными
      сценариями:
      - public mutation entrypoint с нейтральным именем, обходящий
        `_core.write(...)` или `_core.commands.write*`
      - прямой `_store` mutation вне commit-owned helper
      - alias/cascade/local-helper bypass для `_store`, `ctx.changeSet` или
        `ctx.workingSelection`
      - alias на `ctx.idGeneratorState` или `ctx.revisionState` с последующей
        mutation
      - bypass canonical `nextEpoch` path
      - `writeReplaceScene(...)`, обходящий canonical write pipeline
- [ ] И как минимум один положительный сценарий (не должен падать):
      - public interactive setter, меняющий только interactive-local state
        (например `setMode`)
      - effects-only commit branch с commit bookkeeping mutation
- [ ] Если потребуется отдельный fixture, он остаётся test-only и не вводит
      второй owner policy вне `check_guardrails.dart`

## Диагностика шага

- [ ] До завершения подшага приложен `dcm calculate-metrics`-отчёт по
      owner-level AST surface в
      `tool/src/guardrails/controller_api_guardrails.dart`.
- [ ] Любые новые visitor/helper-модули для AST detection укладываются в предел
      `10 / 4 / 40`.
- [ ] Если hotspot остаётся в `controller_api_guardrails.dart`, он явно
      закреплён за owner-level mutation/epoch checks этого подшага, а не
      размыт между `13.2` и `13.4`.
