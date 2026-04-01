language: russian

# Шаг 72. Герметизировать public contract boundary и убрать signal enqueue из публичной write-транзакции

## 1. Мандат изменения

Это изменение исправляет негерметичную публичную границу пакета: удаляет `writeSignalEnqueue(...)` из публичного `SceneWriteTxn`, убирает `internalBacking` и `materialize(...)` из экспортируемых contract-типов, сохраняет internal fast-path backing/materialization graph и замыкает невозврат проблемы через guardrails, tool-тесты и обновлённую публичную документацию.

## 2. Граница изменения

### Входит в изменение

* Очистка публичного write-контракта `SceneWriteTxn`, который доступен внешнему коду через `controller.scene.write(...)`.
* Герметизация всех экспортируемых snapshot boundary-типов из `lib/src/contract/snapshot.dart`.
* Герметизация всех экспортируемых spec/patch boundary-типов из `lib/src/contract/node_spec.dart` и `lib/src/contract/node_patch.dart`.
* Перевод internal materialization/backing bridge на неэкспортируемую internal-only поверхность без опоры на члены, видимые на экспортируемых типах.
* Сохранение internal signal pipeline в controller/core слое без превращения сигналов в новый публичный capability.
* Усиление guardrails и tool-тестов на member-level leaks публичной поверхности.
* Обновление `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md` и `CHANGELOG.md` в рамках той же правки.

### Не входит в изменение

* Любая read-side проблема вокруг `SceneRenderState`, render-state ownership или доступа `view -> interactive/internal`.
* Любая унификация `SceneView` и `SceneViewInteractive`.
* Любое расширение экспортируемого `SceneController` новым публичным `signals` API.
* Любой новый публичный тип сигнала, новый публичный stream сигналов или новый публичный callback-механизм сигналов.
* Любой широкий рефакторинг interactive-контура, не нужный для закрытия этой конкретной публичной boundary-проблемы.
* Любая попытка решать проблему исключительно через `@internal`, без реального удаления leaked members из экспортируемых типов.
* Любое изменение `VERIFICATION.md`, если в ходе шага не меняется обязательная verification surface репозитория.

## 3. Карта файлов и зоны анализа

### Implementation Files

* `lib/src/contract/scene_write_txn.dart`
* `lib/src/contract/snapshot.dart`
* `lib/src/contract/node_spec.dart`
* `lib/src/contract/node_patch.dart`
* `lib/src/contract/internal/snapshot_materialization.dart`
* `lib/src/contract/internal/node_spec_materialization.dart`
* `lib/src/contract/internal/node_patch_materialization.dart`
* `lib/src/contract/internal/snapshot_fast_path.dart`
* `lib/src/contract/internal/node_spec_fast_path.dart`
* `lib/src/contract/internal/node_patch_fast_path.dart`
* `lib/src/controller/scene_writer.dart`
* `lib/src/controller/scene_writer_signals.dart`
* `tool/src/guardrails/public_surface_guardrails.dart`

### Test Files

* `test/contract/validated_fast_path_contract_test.dart`
* `test/public_api/snapshot_immutability_test.dart`
* `test/public_api/node_patch_semantics_test.dart`
* `test/entrypoints/basic_smoke_test.dart`
* `test/controller/internal/scene_writer_test.dart`
* `test/controller/core/scene_controller_writer_lifecycle_test.dart`
* `test/controller/core/scene_controller_commit_atomicity_test.dart`
* `test/controller/core/scene_controller_commit_failures_test.dart`
* `test/controller/core/scene_controller_signals_delivery_test.dart`
* `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
* `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
* `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

### Fixture and Supporting Data Files

* `PLAN.md`
* `plan/step_72_public_contract_boundary_hermeticity_and_signal_txn_cleanup.md`
* `README.md`
* `API_GUIDE.md`
* `ARCHITECTURE.md`
* `CHANGELOG.md`

### Analysis Area

* `lib/src/contract/**`
* `lib/src/controller/**`
* `lib/src/interactive/scene_controller.dart`
* `lib/src/interactive/scene_controller_scene.dart`
* `lib/iwb_canvas_engine.dart`
* `tool/src/guardrails/**`
* `test/contract/**`
* `test/public_api/**`
* `test/controller/**`
* `test/tool/guardrails/**`
* `README.md`
* `API_GUIDE.md`
* `ARCHITECTURE.md`
* `CHANGELOG.md`

### Outside the Change Boundary

* Любые файлы вне перечисленных зон.
* Исключение допустимо только для точечного изменения, без которого нельзя закрыть конкретный slice и его verification.

### File Change Rule

* Каждый изменённый implementation file должен быть привязан к конкретному slice.
* Каждый новый или изменённый тест должен быть привязан к конкретному verification.
* Каждый новый или изменённый supporting file должен быть привязан к конкретному verification или к публичному contract closure этого шага.
* Любое изменение, не привязанное к slice, считается выходом за границу шага.

## 4. Locked Decisions

1. Для этого шага выбран вариант 1: сигналы остаются internal/core write-side capability и не становятся новой публичной возможностью пакета.
2. Экспортируемый `SceneController` не получает новый `signals` stream, signal callback или любой другой полупубличный сигналовый API.
3. Публичный `SceneWriteTxn`, доступный внешнему коду через `controller.scene.write(...)`, после этого шага не содержит `writeSignalEnqueue(...)`.
4. `SceneControllerCore.signals` и текущая семантика core signal delivery остаются поддерживаемым internal behavior и не ослабляются ради исправления публичной boundary-проблемы.
5. Все экспортируемые boundary-типы из `snapshot.dart`, `node_spec.dart` и `node_patch.dart`, включая shared base owners и variant families, после этого шага не содержат публично видимых `internalBacking` и `materialize(...)`.
6. Internal fast-path backing/materialization graph, на который опираются `contract/internal/**`, `model/**`, `controller/**` и fast-path тесты, должен сохраниться и не должен быть заменён на rebuild-through-public-getters как на новый authoritative internal path.
7. Этот шаг не переоткрывает read-side render-state проблему, не трогает унификацию `SceneView` и `SceneViewInteractive` и не расширяет объём до широкого interactive refactor.
8. Защита от возврата проблемы должна быть реализована через guardrails и tool-тесты; одного `@internal` analyzer warning или одного top-level symbol golden для закрытия шага недостаточно.
9. Root public entrypoint остаётся `lib/iwb_canvas_engine.dart`; шаг не создаёт новый root entrypoint и не экспортирует новые signal-типы.
10. Удаление `writeSignalEnqueue(...)` из публичного write-контракта считается user-visible contract change и должно быть отражено в `CHANGELOG.md` под `## Unreleased` как breaking change.
11. `contract` layer остаётся part-free; `part` / `part of` не могут использоваться как способ скрыть backing/materialization members после этого шага.
12. Базовая стратегия реализации этого шага зафиксирована: backing-bearing concrete implementations должны жить только на non-exported internal surface, а exported files не должны оставлять у себя concrete backing/materialization members.

## 5. Требования к результату

1. Внешний код, работающий через `package:iwb_canvas_engine/iwb_canvas_engine.dart` и `controller.scene.write(...)`, больше не видит `writeSignalEnqueue(...)` на `SceneWriteTxn`.
2. Экспортируемые snapshot boundary-типы больше не раскрывают backing/materialization members во внешнюю поверхность пакета.
3. Экспортируемые `NodeSpec` и `NodePatch` families больше не раскрывают backing/materialization members во внешнюю поверхность пакета.
4. Internal code path по-прежнему может materialize backing objects и получать backing identity без опоры на члены, видимые на экспортируемых boundary-типах.
5. Internal core signal scenarios продолжают работать: committed signals по-прежнему буферизуются во время write, публикуются только после успешного commit и не публикуются при rollback/failure.
6. `tool/check_guardrails.dart` падает при повторном появлении `internalBacking`, `materialize(...)` или `writeSignalEnqueue(...)` на запрещённой публичной поверхности.
7. Публичная документация пакета описывает только реально поддерживаемые внешние event/write boundaries и не документирует backing/materialization как public API.
8. Root public symbol surface остаётся согласованной с `tool/check_public_api_surface.dart`; golden update не используется как средство скрыть member-level leak.
9. Export owner list в `lib/iwb_canvas_engine.dart` и canonical public export manifest не расширяются и не получают новые signal-related exports.

## 6. Спецификация реализации

### 6.1 Analysis Scope

* Проверить весь путь, через который внешний код получает `SceneWriteTxn`: `lib/iwb_canvas_engine.dart` -> `lib/src/interactive/scene_controller.dart` -> `lib/src/interactive/scene_controller_scene.dart` -> `lib/src/contract/scene_write_txn.dart`.
* Проверить все экспортируемые типы и shared bases внутри `lib/src/contract/snapshot.dart`, `lib/src/contract/node_spec.dart` и `lib/src/contract/node_patch.dart`, а не только отдельные variant classes.
* Проверить все internal materialization/backing helpers в `lib/src/contract/internal/**`, которые сегодня зависят от leaked members на экспортируемых типах.
* Проверить controller/core signal pipeline и тесты, чтобы отделить внутренний signal runtime от публичной write-транзакции.
* Проверить текущие public-surface guardrails и tool-тесты на предмет того, что они сегодня не ловят member-level leaks этой формы.
* Проверить contract-architecture guardrails на предмет того, что реализация не возвращает `part`/`part of` в `lib/src/contract/**`.

### 6.2 Target Verification Units

* Публичный контракт `SceneWriteTxn`.
* Public entrypoint smoke coverage для `iwb_canvas_engine.dart`.
* Exported snapshot boundary family.
* Exported `NodeSpec` boundary family.
* Exported `NodePatch` boundary family, включая `CommonNodePatch`.
* Internal fast-path materialization helpers и fast-path regression tests.
* Core signal lifecycle tests, которые доказывают commit-ordering, rollback safety и stale-writer semantics.
* Guardrails для публичной surface и их sandbox tool-тесты.
* Публичная документация и release notes для изменённого контракта.

### 6.3 Protected States, Data, or Structures

* Commit-time signal buffering и after-commit delivery semantics.
* Fast-path backing identity, на которую опираются internal tests и internal runtime callers.
* Публичные constructor signatures и data getters snapshot/spec/patch families.
* Single root entrypoint discipline пакета.
* Existing internal/core signal tests и их semantic intent.

### 6.4 Allowed Semantic Change Zones

* Список методов публичного `SceneWriteTxn`.
* Способ, которым exported contract families отделяют публичную boundary surface от backing-bearing implementation.
* Internal materialization/backing bridge и fast-path helper barrels.
* Guardrail detection rules и их sandbox regression coverage.
* Публичное описание write/event contract в документации пакета.

### 6.5 Concrete Implementation Form

* Exported files `snapshot.dart`, `node_spec.dart` и `node_patch.dart` должны остаться единственными root-exported owner-файлами соответствующих public типов.
* Backing-bearing concrete implementations для этих public типов должны быть вынесены в non-exported internal files под `lib/src/contract/internal/**` и не должны объявляться как экспортируемые root public symbols.
* Exported files могут содержать только public type declarations, public constructors/factories и поддерживаемые public data getters; concrete backing fields, backing getters и materialization factories не должны оставаться на exported class owners.
* Public factories в exported files должны возвращать public boundary types, но concrete object creation для materialized/internal path должно происходить через hidden internal implementation classes, а не через leaked member surface.
* Internal materialization helpers должны создавать и раскрывать hidden internal implementations напрямую; запрещено восстанавливать backing через обход по публичным getters/exported object graph как через новый authoritative internal path.
* Если для шага потребуются новые helper files, они допускаются только под `lib/src/contract/internal/**` и не могут требовать `part` / `part of`.

### 6.6 Recognition Forms That Must Be Supported Within This Change

* direct public getter leak: `internalBacking` на экспортируемом class/base owner;
* direct public factory leak: `materialize(...)` на экспортируемом class owner;
* inherited/base leak: запрещённый member объявлен на shared exported base и тем самым доступен всем экспортируемым families;
* direct public txn leak: `writeSignalEnqueue(...)` на экспортируемом `SceneWriteTxn`;
* internal-allowed contrast case: materialization/backing helpers и hidden concrete implementations остаются допустимыми только в `lib/src/contract/internal/**`, если они не пробрасываются в root public surface.

### 6.7 Allowed Forms That Do Not Count as Violations

* `SceneWriter.writeSignalEnqueue(...)` может остаться доступным для internal controller code и internal tests, потому что `SceneWriter` не экспортируется из root public entrypoint.
* `scene_writer_signals.dart` и другие controller-local signal helpers могут оставаться internal owner-ами signal buffering/enqueue semantics.
* `SceneControllerCore.signals` может оставаться internal core API, потому что root public entrypoint экспортирует интерактивный `SceneController`, а не core controller.
* Internal fast-path barrels под `lib/src/contract/internal/**` могут содержать materialization/backing helpers и hidden implementation classes, если эти helpers и implementations не объявлены как члены на экспортируемых boundary-типах и не экспортируются из root public entrypoint.

### 6.8 Requirements for Resolution of Links and Structural Analysis

* Guardrail enforcement для этой задачи должен жить в `tool/src/guardrails/public_surface_guardrails.dart`, потому что именно там уже есть AST-level проверка member surface экспортируемого `SceneWriteTxn`.
* `tool/check_public_api_surface.dart` должен оставаться secondary check для top-level symbol set и не должен считаться достаточным механизмом для member-level hermeticity.
* Guardrail scan должен учитывать все exported contract libraries, объявленные через `lib/iwb_canvas_engine.dart`, и проверять member declarations в самих экспортируемых файлах, а не только top-level exported names.
* Member ban должен применяться к shared base owners внутри экспортируемых файлов так же, как и к leaf variant classes.
* Internal files под `lib/src/contract/internal/**` и `lib/src/controller/**` не считаются нарушением сами по себе, пока они не экспортируются из `lib/iwb_canvas_engine.dart`.
* Canonical public export owner manifest в `test/tool/support/public_entrypoint_contract.dart` не должен меняться в рамках этого шага, потому что состав exported owner files остаётся тем же.

### 6.9 Prohibited

* Добавлять `signals` на экспортируемый `SceneController`.
* Экспортировать `CommittedSignal`, `BufferedSignal` или любой другой signal event type в root public entrypoint.
* Оставлять `internalBacking` или `materialize(...)` на экспортируемых boundary-типах и считать это закрытием только потому, что на члене стоит `@internal`.
* Лечить проблему удалением internal signal runtime или ослаблением after-commit semantics.
* Заменять existing internal fast path на rebuild-through-public-constructors как на новый главный internal bridge.
* Возвращать `part` / `part of` в `lib/src/contract/**` ради доступа к private materialization/backing members.
* Создавать новый root-exported owner file вместо сохранения текущих export owners в `lib/iwb_canvas_engine.dart`.
* Обновлять `tool/goldens/public_api_symbols.txt` только ради того, чтобы скрыть реальную member-level leak проблему.
* Вытаскивать в этот шаг любую read-side render-state работу, любую унификацию `SceneView` variants или любой несвязанный interactive cleanup.

## 7. Правила выполнения

1. Один slice закрывает один новый верифицируемый contract result.
2. У каждого slice есть собственный verification.
3. Slice считается закрытым только в том изменении, где существует его verification и он зелёный.
4. Preparatory-only change не считается закрытым slice.
5. Следующий slice запрещён, пока не закрыт предыдущий.
6. Если slice закрывает failure scenario, в closure evidence должен быть указан диагностический trigger point.
7. Если slice меняет analysis rule или guardrail, должны быть покрыты и positive, и negative scenarios.
8. Расширение объёма запрещено, пока не закрыты обязательные slices этого шага.

## 8. Вертикальные slices

### Slice 1. [x] Public `SceneWriteTxn` cleanup

#### Slice Contract

Публичный `SceneWriteTxn`, доступный через `controller.scene.write(...)`, больше не содержит `writeSignalEnqueue(...)`, а internal controller signal pipeline продолжает работать только через internal `SceneWriter`-уровень.

#### Change

Удалить `writeSignalEnqueue(...)` из `lib/src/contract/scene_write_txn.dart`. Не добавлять ему публичную замену. Не добавлять `signals` на экспортируемый `SceneController`. Сохранить internal enqueue capability на `SceneWriter` и в `scene_writer_signals.dart`. Все internal call sites и тесты, которым действительно нужен signal enqueue, должны работать через `SceneWriter` в internal scope, а не через публичный `SceneWriteTxn`. Любые stale-lifetime assertions после этой правки должны проверять только поддерживаемые public txn methods на `SceneWriteTxn`; signal-specific stale assertions должны быть переведены на `SceneWriter`-typed internal path.

#### Verification

* `MCP run_tests` root `.` path `test/controller/core/scene_controller_writer_lifecycle_test.dart`
* `MCP run_tests` root `.` path `test/controller/core/scene_controller_commit_atomicity_test.dart`
* `MCP run_tests` root `.` path `test/controller/core/scene_controller_commit_failures_test.dart`
* `MCP run_tests` root `.` path `test/controller/core/scene_controller_signals_delivery_test.dart`
* `MCP run_tests` root `.` path `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
* `MCP run_tests` root `.` path `test/controller/internal/scene_writer_test.dart`

#### Positive Scenarios

* Internal controller/core tests по-прежнему могут enqueue signal через `SceneWriter` и получают тот же after-commit behavior.
* Публичная scene write callback по-прежнему даёт доступ ко всем поддерживаемым write operations и immutable snapshot view.

#### Negative Scenarios

* Публичный `SceneWriteTxn` больше не документирует и не поддерживает `writeSignalEnqueue(...)`.
* Exported interactive `SceneController` не получает новый `signals` stream как “компенсацию” за удалённый public txn method.

#### Closure Evidence

* Зелёный прогон перечисленных controller/core и controller/internal verifications.
* Локальный diff показывает, что `writeSignalEnqueue(...)` удалён только из публичного `SceneWriteTxn`, а не из internal `SceneWriter`.

### Slice 2. [x] Snapshot family hermetic boundary

#### Slice Contract

Все экспортируемые snapshot boundary-типы из `lib/src/contract/snapshot.dart` больше не содержат публично видимых `internalBacking` и `materialize(...)`, а internal snapshot fast path сохраняет backing/materialization identity через non-exported internal bridge.

#### Change

Герметизировать весь exported snapshot family целиком: `SceneSnapshot`, `BackgroundLayerSnapshot`, `ContentLayerSnapshot`, `ScenePaletteSnapshot`, `NodeSnapshot` и все node snapshot variants. После этого slice exported snapshot types должны раскрывать только доменные constructors/factories и публичные data getters. Concrete backing-bearing implementations должны быть hidden internal classes под `lib/src/contract/internal/**`, а materialization bridge должен работать только через них. Внутренние helpers в `lib/src/contract/internal/snapshot_materialization.dart` и `lib/src/contract/internal/snapshot_fast_path.dart` должны быть переписаны на эту internal surface и не должны больше зависеть от leaked members на экспортируемых boundary-типах. Запрещено заменять этот путь на массовый rebuild через публичные constructors как на новый authoritative internal bridge и запрещено использовать `part` / `part of` как обход этого ограничения.

#### Verification

* `MCP run_tests` root `.` path `test/contract/validated_fast_path_contract_test.dart`
* `MCP run_tests` root `.` path `test/public_api/snapshot_immutability_test.dart`
* `MCP run_tests` root `.` path `test/entrypoints/basic_smoke_test.dart`

#### Positive Scenarios

* Публичные snapshot constructors и immutable getters продолжают работать без contract drift для внешнего кода.
* Internal fast-path tests по-прежнему могут доказать correct materialization/backing identity через internal helper surface.

#### Negative Scenarios

* Snapshot family больше не раскрывает backing/materialization members на экспортируемых class owners.
* Internal fast-path regression не должен деградировать до обхода через rebuild-from-public-data как единственный путь.

#### Closure Evidence

* Зелёный прогон перечисленных public и fast-path verifications.
* Fast-path regression assertions больше не зависят от public members на snapshot boundary-типах.

### Slice 3. [x] `NodeSpec` and `NodePatch` family hermetic boundary

#### Slice Contract

Все экспортируемые `NodeSpec` и `NodePatch` families, включая `CommonNodePatch`, больше не содержат публично видимых `internalBacking` и `materialize(...)`, а internal spec/patch fast path сохраняется на non-exported internal bridge без потери typed behavior.

#### Change

Герметизировать shared bases и variant families в `lib/src/contract/node_spec.dart` и `lib/src/contract/node_patch.dart`. Это включает `NodeSpec`, все spec variants, `CommonNodePatch`, `NodePatch` и все patch variants. После этого slice exported spec/patch types должны раскрывать только supported constructors/factories и typed domain getters. Concrete backing-bearing implementations должны быть hidden internal classes под `lib/src/contract/internal/**`. Internal helpers в `lib/src/contract/internal/node_spec_materialization.dart`, `lib/src/contract/internal/node_patch_materialization.dart`, `lib/src/contract/internal/node_spec_fast_path.dart` и `lib/src/contract/internal/node_patch_fast_path.dart` должны быть переведены на non-exported internal bridge и не должны использовать leaked members на экспортируемых типах. Fast-path tests должны подтверждать backing/materialization semantics через internal helper surface, а не через public members. Использование `part` / `part of` для доступа к private members запрещено.

#### Verification

* `MCP run_tests` root `.` path `test/contract/validated_fast_path_contract_test.dart`
* `MCP run_tests` root `.` path `test/public_api/node_patch_semantics_test.dart`
* `MCP run_tests` root `.` path `test/entrypoints/basic_smoke_test.dart`

#### Positive Scenarios

* Публичные spec/patch constructors и typed getters продолжают работать без drift для внешнего кода.
* Internal spec/patch fast path по-прежнему materialize-ит typed boundary objects и сохраняет backing identity через internal surface.

#### Negative Scenarios

* `NodeSpec` family больше не раскрывает backing/materialization members наружу.
* `NodePatch` family, включая `CommonNodePatch`, больше не раскрывает backing/materialization members наружу.

#### Closure Evidence

* Зелёный прогон перечисленных public и fast-path verifications.
* Fast-path regression assertions больше не опираются на public `internalBacking` / `materialize(...)` у spec/patch family.

### Slice 4. [x] Guardrails and published contract alignment

#### Slice Contract

Автоматическая защита и опубликованная документация согласованы с новым публичным контрактом: guardrails валят сборку при возврате запрещённых members, а docs/changelog описывают только реально поддерживаемую внешнюю поверхность.

#### Change

Расширить `tool/src/guardrails/public_surface_guardrails.dart` так, чтобы он ловил:
* `internalBacking` на экспортируемых boundary-типах из `snapshot.dart`, `node_spec.dart` и `node_patch.dart`;
* `materialize(...)` на экспортируемых boundary-типах из тех же файлов;
* `writeSignalEnqueue(...)` на публичном `SceneWriteTxn`.

Добавить sandbox negative и positive cases в `test/tool/guardrails/guardrails_public_surface_tool_test.dart`. Positive cases обязаны доказывать, что internal-only materialization helpers в `lib/src/contract/internal/**`, `SceneWriter.writeSignalEnqueue(...)` и `SceneControllerCore.signals` не считаются нарушением, пока они не экспортируются из root public surface. Обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md` и `CHANGELOG.md` в том же change set. В `API_GUIDE.md` убрать `writeSignalEnqueue(...)` из публичного write-контракта. В `ARCHITECTURE.md` зафиксировать, что backing/materialization bridge является internal contract path, а не частью public API. В `CHANGELOG.md` под `## Unreleased` явно отметить breaking removal публичного `writeSignalEnqueue(...)`.

#### Verification

* `dart run tool/check_guardrails.dart`
* `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
* `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
* `dart run tool/check_public_api_surface.dart`
* `MCP run_tests` root `.` path `test/entrypoints/basic_smoke_test.dart`

#### Positive Scenarios

* Guardrails принимают canonical exported surface без leaked members.
* Internal-only fast-path и core signal APIs не дают false positive, пока они не экспортируются из root entrypoint.
* Contract architecture guardrails по-прежнему принимают part-free реализацию `lib/src/contract/**`.

#### Negative Scenarios

* Sandbox case с `internalBacking` на экспортируемом boundary-типе валится.
* Sandbox case с `materialize(...)` на экспортируемом boundary-типе валится.
* Sandbox case с `writeSignalEnqueue(...)` на публичном `SceneWriteTxn` валится.

#### Closure Evidence

* Зелёный прогон перечисленных tooling и entrypoint verifications.
* Обновлённые `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md` и `CHANGELOG.md` присутствуют в том же change set.
* Tool diagnostics в negative sandbox cases указывают именно на запрещённый leaked member, а не на побочный parse/import failure.

## 9. Финальная верификация

* `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
* `flutter analyze`
* `(cd example && flutter analyze lib test)`
* `dcm analyze .`
* `dart run tool/check_import_boundaries.dart`
* `dart run tool/check_public_api_surface.dart`
* `dart run tool/check_guardrails.dart`
* `dart run tool/check_invariant_coverage.dart`
* `MCP` shard preset `core`
* `MCP` shard preset `model_contract`
* `MCP` shard preset `controller_internal`
* `MCP` shard preset `controller`
* `MCP` shard preset `render_view`
* `MCP` shard preset `interactive`
* `MCP` shard preset `example`
* `flutter test --coverage --no-pub --exclude-tags=tool`
* `dart run tool/check_coverage.dart`
* `dart run tool/run_tool_tests.dart`
* `dcm calculate-metrics` для каждого нового production file под `lib/**`, если в ходе шага были добавлены новые production files, а не только изменены существующие

## 10. Критерии приёмки

* Требования к результату выполнены.
* Спецификация реализации выполнена.
* Правила выполнения выполнены.
* Обязательные slices закрыты.
* Финальная верификация прошла.
