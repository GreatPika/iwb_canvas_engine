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
- guardrail не должен пытаться доказать произвольную runtime-семантику по
  AST-фрагментам, потому что это ведёт к хрупкому, легко-обходному tooling.

Задача подшага: отказаться от псевдо-semantic сканирования «любых опасных
операций» и перевести `controller_api_guardrails.dart` на owner-level AST
guardrails, которые проверяют фиксированные mutation/epoch chokepoint-ы и не
пытаются заново доказать всю runtime-семантику контроллера.

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
- Нужно различать class methods, top-level/private helpers и local functions
  внутри методов.
- Mutation propagation обязана видеть и `MethodInvocation`, и
  `FunctionExpressionInvocation`.
- Cascade mutation обязана обрабатываться через `CascadeExpression`-sections, а
  не через `node.target` (у cascade target может быть `null`).
- Alias tracking нужен только в локальном method/function scope для `_store`,
  `ctx`, `ctx.changeSet`, `ctx.workingSelection`, `ctx.idGeneratorState`,
  `ctx.revisionState` и canonical epoch value.
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

## Правило выполнения этого шага

1. Один срез = один маленький поведенческий контракт + его test gate.
2. Срез считается закрытым только когда в том же изменении есть fixture или
   targeted test, который доказывает новый контракт.
3. Нельзя отмечать следующий срез завершённым, если предыдущий не получил свой
   зелёный test gate.
4. Подготовительные изменения сами по себе не считаются закрытым срезом.

## Вертикальные срезы

### Срез 1. Зафиксировать harness для controller-wide scan

- [ ] Результат: новый public neutral mutator в отдельном controller-файле
      гарантированно попадает в scan, а public interactive setter,
      меняющий только interactive-local state, остаётся положительным
      сценарием.
- Test gate:
  - отрицательный fixture на fixed-file blind spot;
  - положительный fixture на interactive-only setter;
  - оба сценария живут в
    `test/tool/guardrails/guardrails_controller_api_tool_test.dart`.

### Срез 2. Заменить file-level исключения на declaration-level allow-list

- [ ] Результат: новый mutation-capable declaration больше не проходит scan
      автоматически только потому, что он находится в special-case файле;
      ownership задаётся только через явный owner-table деклараций.
- Test gate:
  - отрицательный fixture на bypass через declaration в
    `scene_controller_interactive.dart` или другом file-level special case;
  - существующий положительный маршрут через canonical write seam остаётся
    зелёным.

### Срез 3. Закрыть прямой bypass через committed store

- [ ] Результат: direct write в `_store` вне commit-owned зоны падает guardrail-ом.
- Test gate:
  - отрицательный fixture на прямой `_store` mutation;
  - targeted tool test доказывает, что падение происходит именно по owner-state
    bypass, а не по побочной parse/layout ошибке.

### Срез 4. Закрыть `changeSet` и `workingSelection` bypass

- [ ] Результат: direct/alias/cascade mutation на `ctx.changeSet` и
      `ctx.workingSelection`, включая `txnTrack*`, больше не обходят guardrail.
- Test gate:
  - отрицательный fixture на alias `ctx.changeSet` с `txnTrack*`;
  - отрицательный fixture на alias или cascade для `ctx.workingSelection`.

### Срез 5. Закрыть `idGeneratorState`, `revisionState` и mutating `TxnContext`

- [ ] Результат: mutation `ctx.idGeneratorState`, `ctx.revisionState` и
      mutating instance-вызовы на `TxnContext` допустимы только внутри узкой
      txn-owned зоны.
- Test gate:
  - отрицательный fixture на alias `ctx.idGeneratorState`;
  - отрицательный fixture на alias `ctx.revisionState`;
  - отрицательный fixture на mutating вызов `TxnContext` вне allow-list.

### Срез 6. Закрыть local-helper bypass и resolver collision cases

- [ ] Результат: mutation больше нельзя спрятать в local helper,
      `FunctionExpressionInvocation` или в local function с тем же именем, что
      и class method.
- Test gate:
  - отрицательный fixture на local helper mutation;
  - отрицательный fixture на `FunctionExpressionInvocation`;
  - отрицательный fixture на name collision local function vs class method.

### Срез 7. Зафиксировать canonical `nextEpoch` handoff path

- [ ] Результат: guardrail валидирует именно state-commit path от
      `documentReplaced` и `resolveNextControllerEpoch(...)` до invariant
      assert, spatial prepare и committed store apply; harmless rename/alias не
      ломает проверку.
- Test gate:
  - отрицательный fixture на stale `_store.controllerEpoch` или локальную epoch
    math в canonical path;
  - положительный fixture на harmless rename/alias;
  - положительный fixture на effects-only branch без обязательного `nextEpoch`.

### Срез 8. Закрыть `writeReplaceScene(...)` как owner-level routing seam

- [ ] Результат: `writeReplaceScene(...)` не может обойти canonical write
      pipeline прямой заменой committed store.
- Test gate:
  - отрицательный fixture на direct store bypass из `writeReplaceScene(...)`;
  - существующий canonical replace-scene path остаётся зелёным.

### Срез 9. Финальное закрытие шага

- [ ] Результат: все срезы `1-8` закрыты зелёным regression pack и приложенной
      диагностикой.
- Test gate:
  - полный прогон
    `test/tool/guardrails/guardrails_controller_api_tool_test.dart`;
  - `dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`.

## Критерии приёмки

- [ ] Срезы `1-8` закрыты строго сверху вниз; prep-изменения не считаются
      завершённым результатом без собственного test gate.
- [ ] Guardrail закрывает routing bypass, owner-state bypass и resolver
      bypass на всем описанном surface.
- [ ] Guardrail валидирует canonical `nextEpoch` handoff path для state-commit,
      не ломает harmless rename/alias, не требует `nextEpoch` для effects-only
      branch и не допускает bypass в `writeReplaceScene(...)`.
- [ ] Public interactive-only методы не падают сами по себе.
- [ ] Реализация не захватывает ownership `13.2` и не становится owner-ом
      `SceneDataException` boundary policy.
- [ ] Финальный прогон
      `test/tool/guardrails/guardrails_controller_api_tool_test.dart` и
      `dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`
      приложен к результату шага; новые или step-owned methods не содержат
      `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
      `maximum-nesting-level` и `source-lines-of-code`, а целевой предел
      остаётся `10 / 4 / 40`.
