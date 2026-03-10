language: russian

# Development Plan

Этот файл теперь служит индексом плана. Детализация каждого шага вынесена в отдельный документ, чтобы обсуждать и обновлять шаги независимо друг от друга без перегрузки одного большого файла.

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
- [ ] [Шаг 5. Ввести единый `ScenePolicy` через подшаги 5.1-5.4](development_plan/step_05_scene_policy.md)
- [x] [Шаг 5.1. Зафиксировать runtime и boundary policy для `backgroundLayer`](development_plan/step_05_1_background_layer_runtime_and_boundary_policy.md)
- [x] [Шаг 5.2. Ввести entrypoints `ScenePolicy` и делегацию из builder](development_plan/step_05_2_scene_policy_entrypoints_and_builder_delegation.md)
- [ ] [Шаг 5.3. Свести scene-level validation к одному владельцу и единому error-contract](development_plan/step_05_3_scene_level_validation_owner_and_error_contract.md)
- [ ] [Шаг 5.4. Выровнять serialization boundary и зачистить мёртвые policy-ветки](development_plan/step_05_4_serialization_alignment_and_dead_policy_cleanup.md)
- [ ] [Шаг 6. Нормализовать всю внешнюю границу данных и ошибок](development_plan/step_06_external_data_and_error_boundary.md)
- [ ] [Шаг 7. Перевести id и ревизии на безопасную политику](development_plan/step_07_id_and_revision_safety_policy.md)
- [ ] [Шаг 8. Ввести ядро операций записи](development_plan/step_08_write_operations_core.md)
- [ ] [Шаг 9. Довести командный слой до правильной сложности и семантики](development_plan/step_09_command_layer_complexity_and_semantics.md)
- [ ] [Шаг 10. Вынести pointer-router в правильную форму](development_plan/step_10_pointer_router_structure.md)
- [ ] [Шаг 11. Вынести gesture-machine и единый предикат допустимости](development_plan/step_11_gesture_machine_and_admission_predicate.md)
- [ ] [Шаг 12. Перевести рендер и кеши на структурно безопасную форму](development_plan/step_12_render_and_cache_structural_safety.md)
- [ ] [Шаг 13. Ужесточить guardrails и реестр инвариантов](development_plan/step_13_guardrails_and_invariant_registry.md)
- [ ] [Шаг 14. Закрыть тестами и невозвратом все этапы](development_plan/step_14_test_and_non_regression_closure.md)
