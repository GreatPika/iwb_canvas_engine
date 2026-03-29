language: russian

# Шаг 15. Свести duplicate owner-ы и локальные structural repeats без public contract drift

## 1. Change Mandate

Этот шаг вводит один верифицируемый cleanup-этап, который сводит подтверждённые
duplicate owner-ы к одному владельцу в пределах текущего layer DAG без смены
public API, schema contract или runtime source of truth.

## 2. Change Boundary

### Included in the Change

- Сведение к одному owner-у duplicate реализации `Scene -> SceneSnapshot` в
  `lib/src/model/`.
- Сведение к одному owner-у подтверждённых leaf helper-дублей в
  `core/controller/interactive/render`, если для них существует однозначный
  owner в текущем DAG.
- Сведение exact duplicate field-group validation в
  `scene_value_validation_node.part.dart` и
  `scene_value_validation_top_level.part.dart` без склейки snapshot/runtime
  entrypoint-ов.
- Локальный cleanup exact duplicate helper-ов в
  `scene_builder_json_require.part.dart`, `test/model/`,
  `test/public_api/` и `test/tool/`.

### Not Included in the Change

- Изменение public API, export surface, `schemaVersion` или внешнего JSON
  contract-а.
- Новый cross-layer utility layer, generic dedup framework или sync glue между
  существующими owner-ами.
- Слияние snapshot и runtime моделей в один shared abstraction layer.
- Широкий рефакторинг controller mutation semantics, render cache policy или
  test architecture вне подтверждённых duplicate pair-ов.
- Structural pair-ы из текущего clone report без зафиксированного owner
  выигрыша:
  - `_setBackgroundColor` / `_setGridEnabled` / `_setGridCellSize` /
    `_setCameraOffset` в `lib/src/controller/mutation_executor.dart`;
  - `_pixelColor` / `_pixelAt` в render tests;
  - structural overlap между base field validators и family-specific validators
    в `scene_value_validation_node.part.dart`, если итоговая change не удаляет
    exact duplicate body без смешения разных semantics.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/document.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_value_validation_node.part.dart`
- `lib/src/model/scene_value_validation_top_level.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `lib/src/core/node_geometry.dart`
- `lib/src/controller/commands/draw_commands.dart`
- `lib/src/interactive/internal/interactive_geometry.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/core/node_geometry_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/tool/coverage_tool_test.dart`

### Analysis Area

- `lib/src/model/**`
- `lib/src/core/**`
- `lib/src/controller/commands/**`
- `lib/src/interactive/internal/**`
- `lib/src/render/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/core/**`
- `test/controller/commands/**`
- `test/render/**`
- `test/tool/**`
- `tool/analysis/find_similar_clones.dart`

### Outside the Change Boundary

- Любые файлы вне перечисленных зон.
- Исключение допустимо только для точечного изменения, без которого нельзя
  закрыть конкретный slice и его verification.

### File Change Rule

- Каждый изменённый implementation file должен быть привязан к одному slice.
- Каждый новый или изменённый test должен быть привязан к одной verification
  поверхности.
- Непривязанные изменения считаются выходом за границу шага.

## 4. Locked Decisions

1. `SceneSnapshot` остаётся единственным committed source of truth; этот шаг не
   вводит второй runtime cache или второй representation layer.
2. Для каждого подтверждённого duplicate behavior должен остаться один owner в
   уже существующем layer DAG; duplicate code не заменяется sync glue.
3. Snapshot/runtime validation entrypoint-ы остаются отдельными; dedup
   разрешён только ниже уровня entrypoint-а через field-group helper-ы.
4. Render-only helper-ы остаются внутри `render/`; runtime math и sampling
   helper-ы не закрепляются за `interactive/`, если их используют более низкие
   слои.
5. Test-only и tool-only helper-ы не переносятся в production код ради
   устранения duplicate test bodies.
6. Structural similarity без ясного owner выиграша не входит в обязательный
   scope этого шага, даже если она попадает в отчёт clone tool.

## 5. Result Requirements

1. В `lib/src/model/` остаётся один model-owned implementation для
   `Scene -> SceneSnapshot`, и оба текущих call site используют его без
   изменения публичной семантики.
2. Подтверждённые exact duplicate leaf helper-ы из целевых зон имеют одного
   owner-а в корректном слое, а локальные копии удалены.
3. Snapshot/runtime node validation и top-level layer traversal больше не
   содержат exact duplicate field-group bodies там, где семантика после шага
   одинакова, при сохранении различий `allowZero`, field naming и runtime-only
   behavior.
4. Exact duplicate helper-ы в `scene_builder_json_require.part.dart`,
   `test/model/scene_builder_test.dart`,
   `test/public_api/scene_builder_test.dart` и
   `test/tool/coverage_tool_test.dart` либо сведены к одному локальному owner-у,
   либо удалены без потери текущих negative/positive scenarios.
5. Повторный прогон `tool/analysis/find_similar_clones.dart` по затронутым
   зонам больше не показывает pair-ы, закрытые этим шагом.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Отправной точкой считаются только pair-ы, подтверждённые
  `dart run tool/analysis/find_similar_clones.dart --top 20 .` в текущем
  состоянии репозитория.
- Внутри этого шага разрешено закрывать только те duplicate pair-ы, для
  которых можно указать одного owner-а без нарушения dependency DAG из
  `ARCHITECTURE.md`.
- Pair-ы с одинаковой формой, но с разной domain semantics, не должны
  схлопываться в общий helper только ради уменьшения отчёта clone tool.
- Подтверждённые, но отложенные structural pair-ы из текущего top-20 отчёта не
  считаются пропущенным scope этого шага, если они перечислены в
  `Not Included in the Change`.

### 6.3 Protected States, Data, or Structures

- Public API surface, export graph и `schemaVersion = 5`.
- `SceneSnapshot` как committed source of truth.
- Разделение ownership между `model`, `core`, `controller`, `interactive` и
  `render`, зафиксированное в `ARCHITECTURE.md`.
- Разделение boundary validation и runtime semantics, уже закреплённое шагами
  `5.x` и `6.x`.
- Текущие negative scenarios tool/test-ов, которые подтверждают rejection
  paths, а не только happy path.

### 6.4 Allowed Semantic Change Zones

- Один model-owned conversion path для `Scene -> SceneSnapshot`.
- Shared leaf helper ownership для numeric/sampling helpers в нижнем допустимом
  слое.
- Shared render-local helper ownership для render-only path construction.
- Shared field-group helper ownership внутри `scene_value_validation_*` при
  сохранении раздельных snapshot/runtime entrypoint-ов.
- Локальный test/tool helper ownership внутри соответствующих test/tool зон.

### 6.8 Prohibited

- Добавлять новый публичный API, новый barrel export или новый public entrypoint.
- Создавать cross-layer `utils`-модуль, который смешивает `model`, `core`,
  `interactive`, `controller` и `render`.
- Поднимать render-local helper-ы в `core`, если их семантика принадлежит
  только render pipeline.
- Переносить tool/test helper-ы в `lib/src/**`.
- Закрывать шаг только улучшением числа duplicate pair-ов без зелёной
  verification по каждому закрытому slice.

## 7. Execution Rules

1. Один slice закрывает один новый верифицируемый change contract.
2. Каждый slice обязан иметь собственную verification.
3. Slice считается закрытым только в том изменении, где есть его verification
   и зелёный прогон.
4. Подготовительные изменения без закрытой verification не считаются закрытым
   slice.
5. Следующий slice запрещён, пока предыдущий не закрыт.
6. Если slice закрывает failure scenario, к результату прикладывается
   диагностический вывод, подтверждающий точку срабатывания.
7. Если slice меняет analysis rule или duplicate owner mapping, должны быть
   покрыты отрицательные и положительные сценарии там, где это применимо.
8. Расширение scope запрещено, пока не закрыты обязательные slices.

## 8. Vertical Slices

### Slice 1. [x] One model owner for Scene to SceneSnapshot conversion

#### Slice Contract

В `lib/src/model/` существует один owner для conversion `Scene -> SceneSnapshot`,
и duplicate body между `document.dart` и
`scene_builder_snapshot_from_scene.part.dart` больше не поддерживается в двух
копиях.

#### Change

Свести duplicate implementation в
`lib/src/model/document.dart` и
`lib/src/model/scene_builder_snapshot_from_scene.part.dart`
к одному model-owned path и перевести второй call site на делегацию.

#### Verification

- MCP test runner: `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart`
- `dart run tool/analysis/find_similar_clones.dart --top 20 lib/src/model`

#### Closure Evidence

- Зелёный прогон перечисленных verifications.
- В отчёте clone tool больше нет exact pair-а между
  `lib/src/model/document.dart` и
  `lib/src/model/scene_builder_snapshot_from_scene.part.dart`.

### Slice 2. [x] One owner per confirmed leaf helper family

#### Slice Contract

Подтверждённые duplicate leaf helper-ы для numeric transform, point sampling и
render-only stroke path construction имеют одного owner-а каждый в корректном
слое, а duplicate local copies удалены.

#### Change

Свести к одному owner-у duplicate pair-ы между:

- `lib/src/core/node_geometry.dart` и
  `lib/src/interactive/internal/interactive_geometry.dart`;
- `lib/src/controller/commands/draw_commands.dart` и
  `lib/src/interactive/internal/interactive_geometry.dart`;
- `lib/src/render/scene_painter.dart` и
  `lib/src/render/cache/scene_stroke_path_cache.dart`.

#### Verification

- MCP test runner: `test/core/node_geometry_test.dart`
- MCP test runner: `test/controller/commands/draw_commands_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP test runner: `test/render/scene_painter_test.dart test/render/scene_static_layer_cache_test.dart test/render/scene_stroke_path_cache_test.dart`
- `dart run tool/analysis/find_similar_clones.dart --top 20 lib/src`

#### Closure Evidence

- Зелёный прогон перечисленных verifications.
- В scoped clone report по `lib/src` больше нет закрытых этим slice duplicate
  pair-ов.

### Slice 3. [x] Field-group validator reuse without snapshot-runtime merge

#### Slice Contract

`scene_value_validation_node.part.dart` и
`scene_value_validation_top_level.part.dart`
переиспользуют shared field-group helper-ы там, где правила совпадают, но
snapshot/runtime entrypoint-ы и различающиеся semantics остаются разделёнными.

#### Change

Выделить shared field-group helper-ы только для тех exact duplicate bodies,
которые сейчас совпадают между snapshot/runtime validation paths, и оставить
различия `allowZero`, runtime field naming и runtime-only semantics в их
текущих owner-ах.

#### Verification

- MCP test runner: `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`
- `dart run tool/analysis/find_similar_clones.dart --top 20 lib/src/model`

#### Positive Scenarios

- Snapshot и runtime validation принимают те же валидные payload-ы, что и до
  шага.
- Layer traversal и node traversal продолжают давать тот же coverage по
  background/content layers.

#### Negative Scenarios

- `instanceRevision` не теряет различие между `allowZero: true` и
  `allowZero: false`.
- Runtime field names вроде `localPoints`, `localA`, `localB` не дрейфуют к
  snapshot naming.

#### Closure Evidence

- Зелёный прогон перечисленных verifications.
- В отчёте clone tool больше нет exact duplicate pair-ов, закрытых этим slice,
  в `scene_value_validation_node.part.dart` и
  `scene_value_validation_top_level.part.dart`.

### Slice 4. [x] Local helper ownership in JSON require and tests

#### Slice Contract

Точные duplicate helper-ы в `scene_builder_json_require.part.dart`,
`test/model/scene_builder_test.dart`,
`test/public_api/scene_builder_test.dart` и
`test/tool/coverage_tool_test.dart`
сведены к одному локальному owner-у на каждую зону без переноса test/tool
кода в production слой.

#### Change

Свести к одному локальному owner-у:

- duplicate `_requireString` / `_requireBool`-style bodies в
  `lib/src/model/scene_builder_json_require.part.dart`, если итоговая helper
  форма не скрывает field-specific diagnostics;
- duplicate `_minimalRectNodeJson` и связанные minimal scene fixtures в
  `test/model/scene_builder_test.dart` и
  `test/public_api/scene_builder_test.dart`;
- duplicate registration scaffolding в
  `test/tool/coverage_tool_test.dart`.

#### Verification

- MCP test runner: `test/model/scene_builder_test.dart test/public_api/scene_builder_test.dart`
- MCP test runner: `test/tool/coverage_tool_test.dart`
- `dart run tool/run_tool_tests.dart`
- `dart run tool/analysis/find_similar_clones.dart --top 20 test`
- `dart run tool/analysis/find_similar_clones.dart --top 20 lib/src/model`

#### Positive Scenarios

- Shared minimal JSON fixtures продолжают задавать тот же import/build surface
  для model и public API tests.

#### Negative Scenarios

- Tool negative cases по missing coverage и leaked logic продолжают падать в тех
  же сценариях.
- Field-specific diagnostics в JSON require helper-ах не теряют точность.

#### Closure Evidence

- Зелёный прогон перечисленных verifications.
- Scoped clone reports больше не показывают duplicate pair-ы, закрытые этим
  slice, в `test/**` и `scene_builder_json_require.part.dart`.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard: `test/core`
- MCP test shard: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test shard: `test/controller/internal`
- MCP test shard: `test/controller/core test/controller/commands` plus controller-root `*_test.dart`
- MCP test shard: `test/render test/view`
- MCP test shard: `test/interactive`
- MCP test shard with root `example/`: `example/test`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- `dart run tool/analysis/find_similar_clones.dart --top 20 .`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
