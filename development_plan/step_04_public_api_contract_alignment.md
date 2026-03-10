language: russian

# Шаг 4. Закрыть public API contract alignment через подшаги 4.1-4.4

## Цель шага

Шаг `4` больше не должен жить как один тяжёлый кусок работы. После завершения boundary-перехода в шагах `2` и `3.x` здесь остаётся не один рефакторинг, а несколько почти независимых contract-контуров:

- public entrypoint и export surface;
- `SceneBuilder` и codec entrypoints;
- единая политика `TextAlign`;
- writer/controller return types и transform semantics.

Этот umbrella-шаг нужен, чтобы развести владельцев ответственности и не смешивать в одном документе guardrails, serialization contract, enum semantics и controller-facing API.

## Как разбит этап

### Шаг 4.1

`development_plan/step_04_1_public_entrypoint_and_export_surface_contract.md`

Владелец public surface для:

- `lib/iwb_canvas_engine.dart` как единственного public entrypoint;
- `validated.dart` как поддерживаемой части внешнего API;
- guardrails/public API surface tooling;
- правил, не позволяющих `src/**` стать скрыто поддерживаемым integration contract.

### Шаг 4.2

`development_plan/step_04_2_scene_builder_and_codec_contract.md`

Владелец точного контракта для:

- `SceneBuilder.buildFromSnapshot(...)`;
- `SceneBuilder.buildFromJson(...)`;
- `encodeScene(...)` / `encodeSceneToJson(...)`;
- `decodeScene(...)` / `decodeSceneFromJson(...)`;
- `SceneDataException.path` и `throws` semantics на public import/codec boundary.

### Шаг 4.3

`development_plan/step_04_3_text_align_boundary_and_serialization_policy.md`

Владелец единой политики `TextAlign` для:

- `snapshot/spec/patch` boundary;
- JSON encode/decode;
- builder/import semantics;
- общей договорённости по supported values и error diagnostics.

### Шаг 4.4

`development_plan/step_04_4_writer_return_types_and_transform_semantics.md`

Владелец controller/write contract для:

- `DrawCommands.writeDrawStroke(...)`;
- `DrawCommands.writeDrawLine(...)`;
- `SceneWriteTxn.writeSelectionTransform(...)`;
- явной фиксации return-type и transform composition semantics в docs/tests.

## Карта переноса деталей из исходного шага 4

1. Подтверждённая тема single-entrypoint и export-surface закрепляется в `4.1`.
2. Точный `throws`-контракт `SceneBuilder` и codec entrypoints закрепляется в `4.2`.
3. Дыра с `SceneDataException.path` для unsupported `TextAlign` и общее выравнивание enum semantics закрепляются в `4.3`.
4. Contract drift around draw return types и порядка композиции transform закрывается в `4.4`.
5. Решение по `validated.dart` фиксируется в `4.1`: этот экспорт остаётся официальной частью public API, а шаг не откатывает результат шагов `2` и `2.1`.

## Общие правила для всех подшагов

1. `lib/iwb_canvas_engine.dart` остаётся единственным поддерживаемым public import root; новый `advanced.dart`, compat-layer или второй barrel не вводятся.
2. Подшаги `4.2-4.4` уточняют контракт уже существующего API и не добавляют новые фасады.
3. Документация обновляется внутри соответствующего подшага вместе с кодом и тестами; отдельный docs-only follow-up не создаётся.
4. Шаг `4` не забирает scope следующих этапов:
   - `ScenePolicy` и scene-level orchestration остаются в шаге `5`;
   - общая нормализация external data/error boundary остаётся в шаге `6`;
   - id/revision safety policy остаётся в шаге `7`.
5. Если в каком-то подпункте проблема не подтверждается кодом, подшаг фиксирует это через docs/tests/guardrails, а не придумывает изменение ради симметрии.

## Критерии готовности umbrella-шага

1. Для шагов `4.1`, `4.2`, `4.3`, `4.4` существуют отдельные step-файлы с собственной целью, границей ответственности, критериями приёмки и тестовым контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `4.1` отвечает за entrypoint/export surface;
   - `4.2` отвечает за `SceneBuilder` и codec `throws/path` contract;
   - `4.3` отвечает за `TextAlign` policy;
   - `4.4` отвечает за writer/controller contract.
3. Для каждого риска исходного шага `4` явно указано, он подтверждён кодом или опровергнут; после разбиения не осталось расплывчатых формулировок вида "проверить на всякий случай".
4. Граница со следующими шагами остаётся чистой: шаг `4.x` не расширяется до scene-policy refactor, общей error-boundary нормализации или id/revision redesign.

## Чеклист выполнения

[x] Переформулировать шаг `4` как umbrella-этап и вынести решение по реализации в `4.1`, `4.2`, `4.3`, `4.4`.
[x] В `4.1` явно зафиксировать, что `validated.dart` остаётся частью поддерживаемого public API.
[x] В `4.2` сузить `SceneBuilder` и codec до точного `throws/path`-контракта без расплывчатых формулировок.
[x] В `4.3` принять одну финальную политику `TextAlign` для boundary, serialization и builder/import.
[x] В `4.4` закрепить `NodeId` return types и transform composition semantics как публичный контракт.
