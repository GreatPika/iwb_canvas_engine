language: russian

# Шаг 8.5. Свести controller commit к одному internal plan и схлопнуть ветвления

## Цель шага

После `8.4` controller уже использует prepared result executor-а и держит
правильный lifecycle ownership, но giant commit branch в
[scene_controller.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_controller.dart)
всё ещё остаётся слишком большим для финальной формы write-core.

Задача подшага: превратить `_txnWriteCommit(...)` из крупного decision tree в
тонкий pipeline поверх одного internal commit plan, чтобы controller остался
единственным owner-ом commit semantics, но перестал держать в одном методе
сразу normalization, branch selection, revision derivation, invariant inputs и
post-commit orchestration.

## Что уже подтверждено по текущему состоянию

1. `SceneControllerCore._txnWriteCommit(...)` сейчас имеет:
   - `cyclomatic-complexity = 19`
   - `source-lines-of-code = 144`
2. В одном методе сейчас смешаны:
   - selection/grid normalization;
   - решение между `no-op`, `effects-only` и `state-commit` ветками;
   - расчёт epoch/revision значений;
   - invariant precheck input assembly;
   - spatial prepare/apply;
   - signal/repaint commit logic.
3. `MutationExecutor.prepareCommitResult(...)` уже даёт prepared result, значит
   controller не должен продолжать строить параллельный decision tree поверх
   сырых данных txn.
4. Signal-only и repaint-only fast path нужны и дальше, но не как отдельный
   неформальный алгоритм, а как branch kind внутри того же commit contract.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneControllerCore` остаётся единственным owner-ом store commit,
   invariant precheck, spatial prepare/apply и post-commit effects.
2. Новый слой вида `commit_service`, `commit_engine`, `pipeline_orchestrator`
   или внешний helper-owner не вводится. Closure делается через private
   controller-local types и функции.
3. Вводится один private value object уровня controller, например
   `_ControllerCommitPlan`, который собирается ровно один раз после
   normalization и описывает:
   - branch kind;
   - prepared change set;
   - committed selection/state references;
   - next epoch/revision values;
   - необходимость signal/repaint post-effects.
   Этот plan хранит только decision data и refs, но не становится execution
   owner-ом для already-drained signals, prepared spatial commit или других
   одноразовых side effects.
4. `_applyCommittedStore(...)` остаётся единственной точкой записи committed
   runtime state в store.
5. Prepared result executor-а остаётся единственным источником committed
   `scene`, `allNodeIds`, `nodeLocator`, id allocator state и revision state.
   Controller не пересобирает эти данные повторным чтением из `TxnContext`.
6. Debug fields (`debugLastCommitPhases`, `debugLastChangeSet`, clone stats)
   сохраняются, но должны наполняться из plan/execution pipeline, а не через
   ad hoc ветвления, размазанные по методу.
7. Selection/grid normalization тоже перестаёт жить как большой inline prelude
   внутри `_txnWriteCommit(...)`: она либо входит в явную pre-plan stage, либо
   оформляется через отдельный narrow helper до сборки plan.

## Граница шага

- In:
  - giant branch decomposition в `scene_controller.dart`;
  - один internal commit plan поверх prepared result;
  - схлопывание `no-op`, `effects-only`, `state-commit` веток;
  - упрощение revision/epoch derivation и post-effect wiring.
- Out:
  - перенос commit ownership в executor;
  - redesign public `write(...)` API;
  - command-layer concerns шага `9`;
  - новый cache/snapshot/change model.

## Точная реализация, которую должен описывать код

1. `SceneControllerCore.write(...)` по-прежнему:
   - создаёт `TxnContext`;
   - создаёт `SceneWriter`;
   - исполняет пользовательский callback;
   - коммитит только после завершения write.
2. После normalization controller строит один `_ControllerCommitPlan`, который
   принимает решение о ветке commit-а без повторного дублирования условий в
   нескольких местах.
   Selection/grid normalization при этом не остаётся inline giant prelude в том
   же методе.
3. План должен иметь как минимум три branch kind:
   - `noEffects`
   - `effectsOnly`
   - `stateCommit`
4. Расчёт `nextEpoch`, `nextStructuralRevision`, `nextBoundsRevision`,
   `nextVisualRevision`, `nextCommitRevision` происходит в одном месте plan
   assembly, а не по нескольким веткам `_txnWriteCommit(...)`.
5. Исполнение commit разбивается минимум на три narrow stage:
   - build plan;
   - execute state/effects branch;
   - dispatch post-commit effects.
6. Signal-only и repaint-only path используют тот же plan и не обходят общий
   commit contract.
7. Если plan не несёт committed state candidate, store apply не выполняется.

## Последовательность реализации (только действия)

[x] Ввести private `_ControllerCommitPlan` и явный `branch kind` рядом с
    `SceneControllerCore`, не вынося это в новый внешний owner.
[x] Вынести из `_txnWriteCommit(...)` отдельную сборку plan после normalization
    и prepared result executor-а.
[x] Вынести selection/grid normalization в явную pre-plan stage или narrow
    helper, чтобы `_txnWriteCommit(...)` не оставался большим даже после
    появления `_ControllerCommitPlan`.
[x] Свести revision/epoch derivation и invariant-precheck inputs к одному месту
    сборки plan.
[x] Разделить исполнение на узкие ветки `effects-only` и `state-commit`,
    сохранив `_applyCommittedStore(...)` единственной точкой записи store.
[x] Оставить signal/repaint fast path, но перевести его на тот же commit plan,
    а не на отдельные ad hoc условия.
[x] Повторно снять диагностические метрики для `_txnWriteCommit(...)` и
    убедиться, что giant branch больше не остаётся owner-ом всей commit зоны.

## Критерии приёмки

[x] `SceneControllerCore` остаётся единственным owner-ом commit lifecycle.
[x] `_txnWriteCommit(...)` больше не совмещает branch selection, revision
    derivation, invariant input assembly, normalization prelude и post-effect
    orchestration в одном giant method body.
[x] В коде существует один internal commit plan, а не несколько параллельных
    decision tree поверх prepared result и buffered effects.
[x] `_ControllerCommitPlan` не становится вторым execution owner-ом для
    одноразовых side effects.
[x] Signal-only и repaint-only writes не теряют fast path, но используют тот
    же commit contract, что и state-change path.
[x] Для controller watchpoint зоны шага `8` не остаётся необъяснённого giant
    owner-а по `cyclomatic-complexity` и `source-lines-of-code`.

## Тестовый контур шага

[x] `test/controller/core/scene_controller_commit_atomicity_test.dart`
[x] `test/controller/core/scene_controller_commit_failures_test.dart`
[x] `test/controller/core/scene_controller_signals_delivery_test.dart`
[x] `test/controller/core/scene_controller_commit_effects_test.dart`
[x] Точечные сценарии:
    - `effects-only` commit не делает store apply
    - `state-commit` path использует prepared result без повторного derive
    - `debugLastCommitPhases` и `debugLastChangeSet` сохраняют прежнюю
      семантику

## Итоговые метрики

1. Повторная диагностика `dcm calculate-metrics lib/src/controller/scene_controller.dart --report-all`
   показывает для `_txnWriteCommit(...)`:
   - `cyclomatic-complexity = 1`
   - `source-lines-of-code = 10`
2. Giant branch больше не живёт в одном owner-method: decision data собирается
   в `_buildControllerCommitPlan(...)`, а execution разбит между
   `_executeEffectsOnlyCommitPlan(...)` и `_executeStateCommitPlan(...)`.
