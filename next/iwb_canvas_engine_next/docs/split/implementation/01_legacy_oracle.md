<!-- CONTEXT:BEGIN -->
Registry id: `section_01_legacy_oracle`
Source: `iwb_canvas_engine_next_full_implementation_plan_v2.md / section 1`
Canonical original: `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`
Owns:
- 1. Что проверено по старому архиву
Must read before editing:
- `section_00_status_and_scope`
- `docs/split/donors/00_reuse_rules.md`
- `docs/split/donors/01_summary_by_decision.md`
Depends on:
- `section_00_status_and_scope`
- `docs/split/donors/00_reuse_rules.md`
- `docs/split/donors/01_summary_by_decision.md`
Feeds phases:
- `P1`
Related donors:
- `none`
Related diagrams:
- `none`
Required tests:
- `none`
Guardrails:
- `new_api.functional_ledger_complete`
Do not infer:
- old engine is oracle only
- no old runtime fallback
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 1. Что проверено по старому архиву

Статическая сверка выполнена по распакованному архиву текущего кода. Тесты не запускались, потому что в среде нет `dart`/`flutter` toolchain. Старый код использован только как источник возможностей и поведения.

Основные oracle-файлы:

```text
lib/iwb_canvas_engine.dart
lib/src/contract/snapshot.dart
lib/src/contract/node_spec.dart
lib/src/contract/node_patch.dart
lib/src/contract/scene_contract_limits.dart
lib/src/contract/pointer_input.dart
lib/src/contract/canvas_pointer_input.dart
lib/src/contract/scene_data_exception.dart
lib/src/core/action_events.dart
lib/src/core/scene_limits.dart
lib/src/core/tool_defaults.dart
lib/src/core/node_geometry.dart
lib/src/core/hit_test.dart
lib/src/core/scene_spatial_index.dart
lib/src/core/paint_candidate_admission.dart
lib/src/interactive/scene_controller.dart
lib/src/interactive/scene_controller_scene.dart
lib/src/interactive/scene_controller_interaction.dart
lib/src/interactive/scene_controller_selection.dart
lib/src/interactive/internal/scene_controller_interaction_config.dart
lib/src/interactive/internal/interactive_event_dispatcher.dart
lib/src/interactive/internal/interactive_move_commit_coordinator.dart
lib/src/interactive/internal/interactive_move_selection_coordinator.dart
lib/src/interactive/internal/interactive_draw_action_emitter.dart
lib/src/interactive/internal/scene_controller_mutation_boundary.dart
lib/src/controller/scene_controller_commit_write_runner.dart
lib/src/controller/scene_controller_commit_runtime.dart
lib/src/controller/scene_controller_committed_mutation_access.dart
lib/src/model/scene_builder_decode_*.dart
lib/src/serialization/scene_codec.dart
lib/src/view/scene_view_interactive.dart
lib/src/view/scene_view_interactive_overlay_painter.dart
lib/src/contract/scene_view_render_state.dart
example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart
tool/goldens/public_api_symbols.txt
```

Поведенческие свойства старого кода, которые должны быть сохранены функционально:

```text
- синхронная невложенная запись;
- запрет async write callback;
- stale write handle после завершения транзакции;
- rollback без сигналов и repaint;
- staged document replacement: validate/materialize -> interrupt gesture -> atomic install;
- неуспешная загрузка/replace не прерывает активный жест;
- main paint захватывает frame один раз;
- overlay repaint отделён от main repaint;
- selected move preview repaint-ит main scene, а не overlay;
- marquee/draw/line/eraser preview repaint-ит overlay;
- pending line state хранит start/timestamp/color/thickness;
- text editing инициируется событием, а UI редактирования принадлежит приложению;
- pointer policy имеет tapSlop/doubleTapSlop/doubleTapMaxDelayMs/deferSingleTap/dragStartSlop;
- draw style имеет отдельные thickness для pencil/marker/line/eraser и marker opacity;
- external visual resource repaint был представлен через notifySceneChanged();
- scene limits включают id lengths, text/path/stroke/json/layer/node limits;
- geometry имеет hit slop 4.0, отдельные hit bounds и paint bounds;
- spatial index имеет cell size 256, max cells per node 1024, max query cells 50000, large-node/outlier registry и fallback;
- old action stream закрывается при dispose;
- timestamps монотонно нормализуются runtime-ом;
- старый imageId должен быть мигрируем в resourceId/appKey;
- palette и grid.color существуют в старом документе и не должны потеряться.
```

### 1.1 Current-code donor inventory

Старый движок является не только functional oracle, но и donor source для
проверенных алгоритмов, контрактов, тестов и guardrails.

Donor reuse не означает legacy facade:

```text
- новый package не импортирует старый package или старые runtime paths;
- old public API names не становятся public API нового package;
- donor code переносится только как copy/adapt/rewrite-reference;
- каждый перенесённый donor обязан получить ported/equivalent tests;
- если donor shape конфликтует с новым API v1, package layout или no-legacy
  rules, новое решение имеет приоритет.
```

Подробный donor inventory вынесен в отдельный файл:

```text
iwb_canvas_engine_next_donor_inventory.md
```

P1 обязан закрыть этот inventory до начала deep runtime implementation.
Особенно важные donor families:

```text
- geometry kernel: Transform2D, numeric policy, geometry helpers, local bounds;
- hit-test/eraser: node geometry rules, path/stroke hit-test, eraser projection;
- spatial/render: uniform grid index, paint admission, frame read, render caches;
- DTO/validation: limits, structured errors, value validators, immutability,
  tri-state update semantics, structure validation;
- codec/migration: JSON guards, path-aware readers, primitive parsers, schema
  family decode/encode behavior and schema v7 migration references;
- interaction/edit: pointer tracker/router/normalizer, gesture ownership,
  action/text events, mutation boundary and staged loadDocument semantics.
```

---

<!-- ORIGINAL-SECTION:END -->
