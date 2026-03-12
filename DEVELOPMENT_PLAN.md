language: russian

# Development Plan

Этот файл служит индексом плана. Детализация каждого шага вынесена в отдельный документ, чтобы обсуждать и обновлять шаги независимо.

## Общая информация

- Порядок шагов сохраняет исходную зависимость работ и должен читаться сверху вниз.
- Детальное описание, критерии готовности и чек-листы живут только в файлах отдельных шагов.
- При изменении содержания шага обновляй соответствующий step-файл и, при необходимости, название или порядок ссылок в этом индексе.

## Файлы шагов

- [x] [Шаг 1. Зафиксировать среду, конвейер и правила анализа](development_plan/step_01_environment_pipeline_and_analysis.md)
- [x] [Шаг 2. Ввести валидированные типы и фабрики на публичной границе](development_plan/step_02_validated_boundary_types_and_factories.md)
- [x] [Шаг 2.1. Закрыть boundary-drift после шага 2](development_plan/step_02_1_close_boundary_drift_after_step_2.md)
- [ ] [Шаг 3. Закрыть boundary-этап через подшаги 3.1-3.4](development_plan/step_03_public_boundary_constructors_and_semantics.md)
- [x] [Шаг 3.1. Перевести public snapshot boundary на validated semantics](development_plan/step_03_1_public_snapshot_boundary_on_validated_semantics.md)
- [x] [Шаг 3.2. Перевести public NodeSpec/NodePatch boundary на validated semantics](development_plan/step_03_2_public_node_spec_and_patch_boundary_on_validated_semantics.md)
- [x] [Шаг 3.3. Развести boundary validation и runtime write semantics как подготовку к write core](development_plan/step_03_3_scene_write_txn_semantics_and_downstream_cleanup.md)
- [x] [Шаг 3.4. Выровнять ownership и allocation policy для collection payloads](development_plan/step_03_4_collection_payload_ownership_and_allocation_policy.md)
- [x] [Шаг 4. Закрыть public API contract alignment через подшаги 4.1-4.4](development_plan/step_04_public_api_contract_alignment.md)
- [x] [Шаг 4.1. Зафиксировать public entrypoint и export surface](development_plan/step_04_1_public_entrypoint_and_export_surface_contract.md)
- [x] [Шаг 4.2. Уточнить контракт `SceneBuilder` и codec entrypoints](development_plan/step_04_2_scene_builder_and_codec_contract.md)
- [x] [Шаг 4.3. Выровнять политику `TextAlign` на публичной границе и в сериализации](development_plan/step_04_3_text_align_boundary_and_serialization_policy.md)
- [x] [Шаг 4.4. Довести writer/controller contract до точной публичной семантики](development_plan/step_04_4_writer_return_types_and_transform_semantics.md)
- [x] [Шаг 5. Ввести единый `ScenePolicy` через подшаги 5.1-5.6](development_plan/step_05_scene_policy.md)
- [x] [Шаг 5.1. Зафиксировать runtime и boundary policy для `backgroundLayer`](development_plan/step_05_1_background_layer_runtime_and_boundary_policy.md)
- [x] [Шаг 5.2. Ввести entrypoints `ScenePolicy` и делегацию из builder](development_plan/step_05_2_scene_policy_entrypoints_and_builder_delegation.md)
- [x] [Шаг 5.3. Свести scene-level validation к одному владельцу и единому error-contract](development_plan/step_05_3_scene_level_validation_owner_and_error_contract.md)
- [x] [Шаг 5.4. Выровнять serialization boundary и зачистить мёртвые policy-ветки](development_plan/step_05_4_serialization_alignment_and_dead_policy_cleanup.md)
- [x] [Шаг 5.5. Разрезать decode pipeline и убрать второй owner policy в JSON decode](development_plan/step_05_5_decode_pipeline_decomposition_and_policy_boundary.md)
- [x] [Шаг 5.6. Разрезать giant validators и закрыть диагностические watchpoints шага 5](development_plan/step_05_6_validator_decomposition_and_metrics_closure.md)
- [x] [Шаг 6. Нормализовать внешнюю границу данных и ошибок через подшаги 6.1-6.4](development_plan/step_06_external_data_and_error_boundary.md)
- [x] [Шаг 6.1. Зафиксировать контракт `SceneDataException` и taxonomy error-codes](development_plan/step_06_1_scene_data_exception_contract_and_error_codes.md)
- [x] [Шаг 6.2. Ввести `codec_guards.dart` без нарушения layer DAG](development_plan/step_06_2_codec_guards_and_boundary_factory.md)
- [x] [Шаг 6.3. Перевести `SceneBuilder.buildFromJson(...)` на model-local boundary guard](development_plan/step_06_3_scene_builder_json_boundary_guard.md)
- [x] [Шаг 6.4. Довести `scene_codec.dart` до единого `code/path/details` boundary](development_plan/step_06_4_scene_codec_boundary_adoption_and_contract_matrix.md)
- [x] [Шаг 7. Ввести безопасную политику id и revision через подшаги 7.1-7.4](development_plan/step_07_id_and_revision_safety_policy.md)
- [x] [Шаг 7.1. Зафиксировать новый generated-id contract и owner `id_generator`](development_plan/step_07_1_generated_id_contract_and_generator_owner.md)
- [x] [Шаг 7.2. Перевести store/txn/document на stateful id allocation без scene-scan](development_plan/step_07_2_stateful_id_allocation_in_store_txn_and_document.md)
- [x] [Шаг 7.3. Ввести безопасную revision policy и связать её с `epoch`](development_plan/step_07_3_revision_policy_and_epoch_contract.md)
- [x] [Шаг 7.4. Зафиксировать render-cache invalidation на composite revision contract](development_plan/step_07_4_render_cache_revision_contract.md)
- [x] [Шаг 8. Ввести ядро операций записи через подшаги 8.1-8.7](development_plan/step_08_write_operations_core.md)
- [x] [Шаг 8.1. Зафиксировать контракт операций и границу `mutation_executor`](development_plan/step_08_1_mutation_op_contract_and_executor_boundary.md)
- [x] [Шаг 8.2. Подготовить `TxnContext` и `document.dart` к operation-oriented apply](development_plan/step_08_2_txn_apply_semantics_and_document_helpers.md)
- [x] [Шаг 8.3. Перевести `SceneWriter` на executor и зачистить write-boundary drift](development_plan/step_08_3_scene_writer_executor_adoption.md)
- [x] [Шаг 8.4. Довести `SceneControllerCore` до ясного commit pipeline и dispose contract](development_plan/step_08_4_scene_controller_commit_pipeline.md)
- [x] [Шаг 8.5. Свести controller commit к одному internal plan и схлопнуть ветвления](development_plan/step_08_5_controller_commit_plan_and_branch_collapse.md)
- [x] [Шаг 8.6. Довести `MutationExecutor` до operation-family hot path без пустого postcheck](development_plan/step_08_6_executor_operation_family_cleanup.md)
- [x] [Шаг 8.7. Упростить `TxnContext` hot primitives без второго runtime cache](development_plan/step_08_7_txn_context_hot_path_primitives.md)
- [x] [Шаг 9. Довести command-layer до правильной сложности и семантики через подшаги 9.1-9.3](development_plan/step_09_command_layer_complexity_and_semantics.md)
- [x] [Шаг 9.1. Довести low-level delete и stroke patch semantics в `document.dart`](development_plan/step_09_1_document_delete_and_stroke_patch_hot_paths.md)
- [x] [Шаг 9.2. Зафиксировать `SceneWriter` как owner selection/signal hot path](development_plan/step_09_2_scene_writer_selection_and_signal_hot_path.md)
- [x] [Шаг 9.3. Перевести `DrawCommands` и `SceneCommands` на exact writer semantics](development_plan/step_09_3_command_adapters_exact_signal_and_input_semantics.md)
- [x] [Шаг 10. Вынести pointer-router в правильную форму через подшаги 10.1-10.3](development_plan/step_10_pointer_router_structure.md)
- [x] [Шаг 10.1. Зафиксировать owner `scene_view_pointer_router` и контракт raw-to-slot routing](development_plan/step_10_1_scene_view_pointer_router_owner_and_slot_contract.md)
- [x] [Шаг 10.2. Зафиксировать host admission, host terminal cleanup и flush/timer lifecycle в `SceneViewInteractive`](development_plan/step_10_2_pointer_event_admission_and_flush_lifecycle.md)
- [x] [Шаг 10.3. Зафиксировать `PointerInputSettings` как value object и apply-on-idle contract](development_plan/step_10_3_pointer_settings_transition_and_value_semantics.md)
- [x] [Шаг 11. Вынести gesture-machine и единый предикат допустимости через подшаги 11.1-11.6](development_plan/step_11_gesture_machine_and_admission_predicate.md)
- [x] [Шаг 11.1. Зафиксировать controller pointer entry contract и canonical terminal semantics](development_plan/step_11_1_controller_pointer_entry_and_terminal_semantics.md)
- [x] [Шаг 11.2. Ввести одного controller-owned owner-а active gesture и forced reset lifecycle](development_plan/step_11_2_controller_gesture_owner_and_lifecycle_reset.md)
- [x] [Шаг 11.3. Ввести одного owner-а interactive admissibility в `interaction_eligibility_policy.dart`](development_plan/step_11_3_interaction_eligibility_policy_owner.md)
- [x] [Шаг 11.4. Перевести move session на shared eligibility policy и canonical cancel semantics](development_plan/step_11_4_move_session_policy_and_cancel_semantics.md)
- [x] [Шаг 11.5. Перевести draw lifecycle, delete admissibility и pending-line cleanup на controller-owned contract](development_plan/step_11_5_draw_gesture_lifecycle_and_pending_line_cleanup.md)
- [x] [Шаг 11.6. Запретить внешние selection mutations во время active gesture](development_plan/step_11_6_selection_api_gesture_exclusivity.md)
- [ ] [Шаг 12. Закрыть structural safety рендера и кешей через подшаги 12.1-12.4](development_plan/step_12_render_and_cache_structural_safety.md)
- [x] [Шаг 12.1. Ввести `canvas_scope.dart` и frame-local contract для `ScenePainter`](development_plan/step_12_1_canvas_scope_and_painter_frame_contract.md)
- [ ] [Шаг 12.2. Свести grid rendering и static cache к одному owner-у](development_plan/step_12_2_grid_renderer_and_static_cache_unification.md)
- [ ] [Шаг 12.3. Свести runtime node geometry к одному owner-у для render parity, hit-test и spatial index](development_plan/step_12_3_shared_node_geometry_for_render_hit_test_and_spatial_index.md)
- [ ] [Шаг 12.4. Зафиксировать render cache key / revision contract и supporting invariants](development_plan/step_12_4_render_cache_keys_revision_contract_and_invariants.md)
- [ ] [Шаг 13. Ужесточить guardrails и реестр инвариантов](development_plan/step_13_guardrails_and_invariant_registry.md)
- [ ] [Шаг 14. Закрыть тестами и невозвратом все этапы](development_plan/step_14_test_and_non_regression_closure.md)
