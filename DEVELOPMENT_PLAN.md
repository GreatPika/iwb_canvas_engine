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
- [ ] [Шаг 4. Сразу выровнять точный публичный API-контракт](development_plan/step_04_public_api_contract_alignment.md)
- [ ] [Шаг 5. Ввести единый `ScenePolicy`](development_plan/step_05_scene_policy.md)
- [ ] [Шаг 6. Нормализовать всю внешнюю границу данных и ошибок](development_plan/step_06_external_data_and_error_boundary.md)
- [ ] [Шаг 7. Перевести id и ревизии на безопасную политику](development_plan/step_07_id_and_revision_safety_policy.md)
- [ ] [Шаг 8. Ввести ядро операций записи](development_plan/step_08_write_operations_core.md)
- [ ] [Шаг 9. Довести командный слой до правильной сложности и семантики](development_plan/step_09_command_layer_complexity_and_semantics.md)
- [ ] [Шаг 10. Вынести pointer-router в правильную форму](development_plan/step_10_pointer_router_structure.md)
- [ ] [Шаг 11. Вынести gesture-machine и единый предикат допустимости](development_plan/step_11_gesture_machine_and_admission_predicate.md)
- [ ] [Шаг 12. Перевести рендер и кеши на структурно безопасную форму](development_plan/step_12_render_and_cache_structural_safety.md)
- [ ] [Шаг 13. Ужесточить guardrails и реестр инвариантов](development_plan/step_13_guardrails_and_invariant_registry.md)
- [ ] [Шаг 14. Закрыть тестами и невозвратом все этапы](development_plan/step_14_test_and_non_regression_closure.md)
