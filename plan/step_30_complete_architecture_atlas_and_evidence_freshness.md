# Change Contract

## 1. Change Mandate

Replace the partial target-map documentation under `docs/**` with one complete,
current architecture atlas that has a single human entrypoint, a complete
owner-family registry, mechanically fresh evidence, and explicit handling for
known architectural defects that must not be normalized as target architecture.

## 2. Change Boundary

### Included in the Change

- create `docs/ARCHITECTURE_ATLAS.md` as the single entrypoint for the
  architecture atlas
- rename the runtime-centered `docs/target_architecture/**` map into a complete
  current-intended `docs/architecture/**` atlas
- rename `docs/target_proof_architecture/**` into
  `docs/proof_architecture/**` and keep it as the proof-system half of the
  atlas
- keep `docs/adr/**` as historical decision records that explain why major
  choices were made, not as the current navigation surface
- add one focused atlas checker that validates formal Markdown links, ids, and
  generated evidence against repository code and tools
- make the atlas checker enforce the expected architecture/proof family id set
  from this contract so a missing family cannot be hidden by omitting it from an
  overview file
- refresh stale committed evidence artifacts already detected in the runtime
  and proof maps
- add missing engine owner-family documents for the public boundary, contract
  document model, import/build/materialization, serialization/schema, core
  scene graph and geometry, model document mutation/topology, rendering, and
  diagnostics/performance/debug ownership
- add missing proof-family coverage for verification-contract/workflow drift so
  repository proof architecture covers more than public exports, guardrails,
  and invariant reachability
- enforce that every atlas family has owners, forbidden shapes, status, evidence
  commands, committed evidence artifacts where applicable, and a clear update
  trigger
- require every generated evidence artifact to name its checked-in generator
  command, including the exact `--json-out` and `--md-out` or `--mermaid-out`
  paths used to refresh the committed files
- enforce that every engine architecture family has `Proof Links` to the proof
  families, guardrail/audit commands, generated evidence, and registry-backed
  invariant ids when such invariants exist
- derive proof-link validity from code-owned registries and tools, not from
  other Markdown documents
- enforce that atlas evidence freshness is checked mechanically from
  repository-local generator commands instead of relying on prose
- enforce that every committed evidence artifact is referenced by a family or
  flow document so stale orphan evidence cannot remain in the atlas
- encode architectural defects as linked known issues or follow-up plan steps
  rather than marking defective current behavior as `locked`
- update `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `PLAN.md`, and this step
  document so the repository source-of-truth order points to the new atlas
- delete old target-map paths after their useful content is migrated; do not
  keep archived copies of obsolete map documents

### Not Included in the Change

- no production architecture fixes for existing known issues such as `KI-2`,
  `KI-3`, `KI-4`, `KI-5`, `KI-6`, `KI-7`, `KI-8`, `KI-11`, `KI-12`, `KI-13`,
  or `KI-14`
- no public API, schema, serialization behavior, runtime behavior, rendering
  behavior, or performance-policy behavior change
- no broad rewrite of `ARCHITECTURE.md`; it remains the checked-in current
  architecture contract while the atlas becomes the navigable family map
- no new analyzer plugin or external documentation generator
- no evidence command that depends on network access or non-repository state
- no broad Markdown parser that infers architecture from prose; only formal
  links, headings, ids, and command references may be checked
- no new architecture status that lets a confirmed defect appear equivalent to
  `locked`

## 3. Surrounding Code Review

### Inspected Artifacts

- `AGENTS.md` - requires repository-specific architecture knowledge to live in
  checked-in sources of truth and prefers mechanically enforced rules over
  prose-only reminders.
- `README.md` - currently points readers to `API_GUIDE.md`,
  `ARCHITECTURE.md`, `docs/target_architecture/README.md`, `CHANGELOG.md`, and
  `example/README.md`, but has no single entrypoint for the whole `docs/**`
  architecture atlas.
- `ARCHITECTURE.md` - already describes the package boundary, layer DAG,
  runtime owners, import/build flow, serialization flow, rendering flow,
  mechanical enforcement, and contributor rules; it is the closest complete
  source for the family list but is too monolithic to be the requested atlas.
- `KNOWN_ISSUES.md` - already records active confirmed defects with mechanical
  evidence; at contract drafting it included stale proof evidence (`KI-9`) plus
  the missing freshness check for committed proof inventory (`KI-10`).
- `PLAN.md` - is the active roadmap index and requires one dedicated step
  document per execution contract.
- `docs/target_architecture/README.md` - scopes the current directory to ADR
  0001 and the runtime center, so it cannot satisfy the new full-atlas mandate
  without a purpose change.
- `docs/target_architecture/overview.md` - currently lists only five runtime
  owner families: composition root/facade, view runtime/render seam,
  interaction runtime, mutation gateway, and store/commit path.
- `docs/target_architecture/families/*.md` - already uses a useful family
  contract shape, but only for runtime-center families and with evidence that
  can drift independently from the code.
- `docs/target_architecture/execution_flows.md` - intentionally omits
  import/build flow because no checked-in probe derived it when Step 16 landed.
- `docs/target_architecture/evidence/*.json` and
  `docs/target_architecture/evidence/*.md` - committed runtime evidence exists,
  but regenerated output currently differs for `composition_root_trace`,
  `render_main_scene_read_flow`, `render_overlay_preview_flow`, and
  `pointer_input_flow`.
- `docs/target_proof_architecture/overview.md` - currently lists only public
  entrypoint/signature proof, guardrail runner/artifact model, and invariant
  registry/reachability proof.
- `docs/target_proof_architecture/evidence/proof_inventory.json` - committed
  proof inventory differed from `dart run tool/trace_proof_inventory.dart`
  output at contract drafting, matching `KI-9`.
- `test/tool/target_architecture_map_tool_test.dart` - validates Markdown
  section shape, status vocabulary, evidence links, and selected evidence
  snippets, but it does not prove full family coverage or generated evidence
  freshness.
- `test/tool/target_proof_architecture_map_tool_test.dart` - validates proof
  map Markdown shape and links; at contract drafting it did not compare
  committed evidence with regenerated `trace_proof_inventory` output, matching
  `KI-10`.
- `tool/lsp_trace_symbol.dart`, `tool/lsp_trace_flow.dart`,
  `tool/lsp_find_symbols.dart`, `tool/lsp_find_boundary_bypasses.dart`, and
  `tool/lsp_find_thin_wrappers.dart` - provide repository-local runtime and
  owner-flow evidence generation for atlas families.
- `tool/trace_export_namespace.dart` and `tool/trace_proof_inventory.dart` -
  provide repository-local proof evidence generation for public namespace and
  invariant/proof inventory artifacts.
- `tool/check_import_boundaries.dart`, `tool/check_guardrails.dart`,
  `tool/check_public_api_surface.dart`, `tool/check_invariant_coverage.dart`,
  and `tool/check_verification_contract.dart` - are the current structural proof
  surfaces that must be referenced by atlas families instead of replaced by
  prose.
- `tool/audit_validated_materialization_paths.dart`,
  `tool/audit_bridge_surfaces.dart`, `tool/audit_schema_family_parity.dart`,
  `tool/audit_patch_field_admission.dart`,
  `tool/audit_terminal_cleanup_safety.dart`,
  `tool/audit_post_commit_cleanup_order.dart`, and
  `tool/run_repository_audits.dart` - are existing audit surfaces for
  import/materialization, contract schema families, draw cleanup, and other
  defect classes that the atlas must classify rather than hide; the aggregate
  audit currently exits non-zero because several findings are active known
  issues, so it is not a final passing gate for this step.
- `lib/src/**` - is organized into `contract`, `core`, `model`, `controller`,
  `interactive`, `render`, `serialization`, and `view` layers, which provides
  the minimum complete engine-family coverage required by the atlas.
- `test/**` - contains family-level behavioral proof suites for contract,
  core, model, controller, interactive, render, serialization, view, and tool
  ownership areas.

### Current Entry Path

- repository entry today:
  `README.md` -> `ARCHITECTURE.md` ->
  `docs/target_architecture/README.md` for runtime target detail
- target atlas entry after this change:
  `README.md` / `AGENTS.md` -> `docs/ARCHITECTURE_ATLAS.md` ->
  `docs/architecture/overview.md` and
  `docs/proof_architecture/overview.md` ->
  `docs/architecture/families/*.md` and
  `docs/proof_architecture/families/*.md` ->
  committed evidence artifacts and repository-local proof commands

### Current Owner

- documentation entrypoint ownership: `docs/ARCHITECTURE_ATLAS.md`
- engine architecture family ownership: `docs/architecture/**`
- proof-system family ownership: `docs/proof_architecture/**`
- historical decision ownership: `docs/adr/**`
- active defect ownership: `KNOWN_ISSUES.md`
- execution-order ownership: `PLAN.md` and `plan/*.md`
- mechanical atlas validation ownership: one repository-local tool plus
  `test/tool/**`

### Adjacent Abstractions

- `ARCHITECTURE.md` - authoritative checked-in architecture contract, not the
  navigable family atlas.
- `API_GUIDE.md` - public integration guide, not the maintainer architecture
  map.
- `KNOWN_ISSUES.md` - confirmed active defects only; it is the right place for
  current flaws that must not be normalized into target architecture.
- `docs/adr/**` - decision history; ADRs can justify atlas rules but must not
  replace the current atlas.
- `tool/invariant_registry.dart` - invariant and proof-path source of truth
  used by the atlas checker to validate invariant ids named in docs.
- `tool/src/verification_contract/verification_contract_registry.dart` -
  executable verification graph, adjacent to proof architecture and currently
  implicated by `KI-11`.

### Existing Tests

- `test/tool/target_architecture_map_tool_test.dart` - current runtime-map
  structural Markdown test that should be replaced or reduced to entry/link
  smoke coverage.
- `test/tool/target_proof_architecture_map_tool_test.dart` - current proof-map
  structural Markdown test that should be replaced or reduced to entry/link
  smoke coverage.
- `test/tool/trace_export_namespace_tool_test.dart` - locks generated public
  namespace evidence behavior.
- `test/tool/trace_proof_inventory_tool_test.dart` - locks generated proof
  inventory behavior but does not compare canonical committed evidence.
- `test/tool/guardrails/guardrails_*_tool_test.dart` - locks structural
  guardrail behavior for public, contract, model, controller, and interactive
  families.
- `test/tool/import_boundaries/*_tool_test.dart` - locks layer DAG and import
  boundary behavior.
- `test/tool/audit/*_tool_test.dart` - locks audit command behavior used by
  multiple atlas families.
- `test/contract`, `test/core`, `test/model`, `test/controller`,
  `test/interactive`, `test/render`, `test/serialization`, `test/view`, and
  `test/public_api` - provide behavioral proof suites that each engine family
  should cite by scope instead of duplicating in prose.

### Analogous Implementation Path

- `tool/trace_proof_inventory.dart` plus
  `docs/target_proof_architecture/evidence/proof_inventory.*` - closest valid
  precedent for machine-generated committed evidence.
- `tool/invariant_registry.dart` plus `tool/check_invariant_coverage.dart` -
  closest valid precedent for code-owned proof metadata that docs can reference
  without becoming the source of truth for those facts.
- `PLAN.md` plus `plan/step_*.md` - closest valid precedent for one index file
  that routes to detailed execution contracts.

### Governing Repository Rules

- `AGENTS.md` - the repository is the source of truth for architecture,
  constraints, conventions, and operational knowledge.
- `AGENTS.md` - stable constraints should be enforced by repository-local
  tooling, structural tests, CI checks, or linting instead of repeated prose.
- `AGENTS.md` - `KNOWN_ISSUES.md` is for active confirmed defects only and
  must not be used for vague risks or archived history.
- `AGENTS.md` - when a plan step is added, use `$change-contract` as the
  canonical template and update `PLAN.md` and the linked document together.
- `ARCHITECTURE.md` - current architecture truth is the combination of
  `lib/iwb_canvas_engine.dart`, `lib/src/**`, `tool/invariant_registry.dart`,
  import-boundary tools, guardrails, and architecture-facing tests.
- `ARCHITECTURE.md` - the layer DAG and important boundary rules define the
  minimum engine-family coverage the atlas must represent.
- `KNOWN_ISSUES.md` - if an issue is listed there, it is unresolved; fixing it
  requires removing the entry in the same change that adds regression proof.

### Rejected Misleading Local Patterns

- extending `docs/target_architecture/**` in place while keeping the `target`
  name and ADR 0001 purpose - wrong entrypoint because it still reads as a
  runtime migration map rather than the complete architecture atlas.
- relying on Markdown prose parsing as the primary atlas proof - wrong evidence
  seam because prose shape does not prove generated artifact freshness or
  code-owned proof existence.
- marking every family `locked` just because current code can be traced -
  wrong architecture rule because confirmed defects must remain defects, not
  target architecture.
- putting architectural defects only in family prose - wrong source of truth
  because active confirmed defects belong in `KNOWN_ISSUES.md` or a follow-up
  plan step with mechanical evidence.
- merging proof architecture into engine family prose - wrong cohesion because
  proof tooling has its own owners, artifacts, and failure modes.
- moving all architecture detail into `ARCHITECTURE.md` - wrong navigation
  shape because the requested atlas needs one small entrypoint and family-level
  routing.
- archiving ADRs - wrong retention model because ADRs remain valid decision
  history even after the current atlas is reorganized.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- repository architecture documentation, evidence inventory, and atlas
  structural proof

#### Selected Architectural Form

- `docs/ARCHITECTURE_ATLAS.md` becomes the single human entrypoint for
  `docs/**` and is titled as the architecture atlas.
- `docs/architecture/**` becomes the complete current-intended engine
  architecture map by owner family.
- `docs/proof_architecture/**` becomes the complete proof-system architecture
  map by proof family.
- `docs/adr/**` remains decision history and is linked from the atlas, but ADRs
  do not define the active navigation structure.
- One new tool, `tool/check_architecture_atlas.dart`, reads the atlas Markdown
  in a narrow way and verifies only formal structure: overview links, family
  files, required headings, status values, proof-link targets, invariant ids
  against `tool/invariant_registry.dart`, guardrail/audit command paths,
  evidence file existence, committed-evidence freshness for supported generated
  artifacts, and required known-issue links for families whose status is not
  `locked`.
- The checker owns a small hard-coded expected-family id set that mirrors the
  family registries locked in this contract; it rejects missing, duplicate, or
  unknown architecture/proof family ids before validating family contents.
- The checker rejects orphan evidence files under
  `docs/architecture/evidence/**` and `docs/proof_architecture/evidence/**`
  unless a family or flow document references them with a supported generator
  command.
- Generated evidence is refreshed only by checked-in repository tools named in
  family docs:
  - runtime flow evidence: `dart run tool/lsp_trace_symbol.dart ... --json-out=... --mermaid-out=...`
  - public export proof evidence:
    `dart run tool/trace_export_namespace.dart ... --json-out=... --md-out=...`
  - proof inventory evidence:
    `dart run tool/trace_proof_inventory.dart --json-out=... --md-out=...`
  - audit evidence: the specific `dart run tool/audit_*.dart` command named by
    the family
- Engine family docs include a short `Proof Links` section that links to proof
  families, guardrail/audit commands, generated evidence, and registry-backed
  invariant ids when such invariants exist, without duplicating proof-family
  internals.
- Existing Markdown tests may keep only entrypoint/link smoke assertions. They
  must not infer architecture meaning from prose.
- Family status vocabulary is:
  - `locked`: intended architecture is coherent and evidence is fresh.
  - `known issue`: current code or proof state violates the intended rule and
    the family links to `KNOWN_ISSUES.md` or a dedicated follow-up plan step.
  - `docs stale`: documentation or committed evidence is stale against code and
    must be refreshed before the family can guide implementation.
- Final atlas acceptance allows no `docs stale` families. `known issue` is
  allowed only when the defect is confirmed, linked, mechanically evidenced,
  and not rephrased as the target rule.

#### Owning Layer or Module

- human entrypoint: `docs/ARCHITECTURE_ATLAS.md`
- engine atlas: `docs/architecture/**`
- proof atlas: `docs/proof_architecture/**`
- active defects: `KNOWN_ISSUES.md`
- atlas checker: `tool/check_architecture_atlas.dart` and
  `test/tool/architecture_atlas_tool_test.dart`
- verification graph integration:
  `tool/src/verification_contract/verification_contract_registry.dart`

#### Dependency Direction

- `README.md` and `AGENTS.md` point to `docs/ARCHITECTURE_ATLAS.md`.
- `docs/ARCHITECTURE_ATLAS.md` points to engine atlas, proof atlas, ADRs, and
  defect handling rules.
- `docs/architecture/overview.md` and `docs/proof_architecture/overview.md`
  route to family docs.
- Family docs point to committed evidence and repository-local commands.
- The checker reads only formal Markdown elements and generated artifacts. It
  does not infer target architecture from prose.
- `KNOWN_ISSUES.md` remains the defect ledger; family docs may link to known
  issues but do not redefine them.

#### State and Data Ownership

- Human architectural explanation lives in Markdown family documents.
- Human family inventory lives in `docs/architecture/overview.md` and
  `docs/proof_architecture/overview.md`; code-owned proof facts stay in
  repository tools and registries.
- Generated evidence lives under `docs/architecture/evidence/**` and
  `docs/proof_architecture/evidence/**`.
- Historical rationale lives in `docs/adr/**`.
- Confirmed active defects live in `KNOWN_ISSUES.md`.
- No production runtime, document, or proof state moves as part of this change.

#### Entry and Exit Boundaries

- Entry boundaries:
  `docs/ARCHITECTURE_ATLAS.md`,
  `tool/check_architecture_atlas.dart`,
  `dart run tool/run_verification_preset.dart run --preset=required_code_change`
- Exit boundaries:
  refreshed committed evidence,
  atlas checker diagnostics,
  updated documentation source-of-truth links,
  removed `KI-9` and `KI-10` only if their root causes are fixed with
  regression proof

#### Permitted Extension Seam

- Add new family Markdown files under `docs/architecture/families/**` and
  `docs/proof_architecture/families/**`.
- Add generated evidence files under the matching `evidence/**` directories.
- Add `tool/check_architecture_atlas.dart` and focused tool tests for atlas
  validation.
- Extend verification contract registry only enough to include the atlas
  checker when relevant changed paths require it.

#### Rejected Alternatives

- keep `target_architecture` as the primary name - rejected because it implies a
  partial future migration map and conflicts with the requested current atlas.
- create a separate `docs/architecture_map/**` while leaving old target maps in
  place - rejected because it preserves two competing entrypoints.
- infer architecture from Markdown prose - rejected because prose cannot prove
  evidence freshness or code-owned proof existence.
- fix all known architecture defects before creating the atlas - rejected
  because the atlas must expose known defects and route future work, not bundle
  every unrelated product/code fix.
- ignore known issues and describe current code as target architecture -
  rejected because it would lock defective behavior into the source of truth.

#### Why This Level Is Correct

- The request is about repository-wide orientation and future change safety, so
  the owner is the documentation/proof layer rather than a single runtime
  module.
- The repository already has code, guardrails, invariants, and known issues as
  sources of truth; the atlas must route to them and check freshness rather than
  duplicate their logic in prose.
- A narrow checker keeps the atlas mechanically enforceable while preserving
  `docs/ARCHITECTURE_ATLAS.md` as the small human entrypoint the user asked for.

## 5. Locked Decisions

1. The canonical human entrypoint is `docs/ARCHITECTURE_ATLAS.md`.
2. The canonical engine atlas path is `docs/architecture/**`.
3. The canonical proof atlas path is `docs/proof_architecture/**`.
4. The atlas checker path is `tool/check_architecture_atlas.dart`.
5. Old `docs/target_architecture/**` and `docs/target_proof_architecture/**`
   paths are deleted after migration; no compatibility duplicate or archive copy
   is kept.
6. The final engine family registry must include:
   `public_package_boundary`;
   `contract_document_model_and_validated_fast_paths`;
   `import_build_materialization`; `serialization_and_schema`;
   `core_scene_graph_geometry_and_spatial_indexes`;
   `model_document_mutation_and_topology`; `store_and_commit_path`;
   `composition_root_and_facade`; `interaction_runtime`;
   `mutation_gateway`; `view_runtime_and_pointer_hosting`;
   `render_frame_admission_and_caches`;
   `diagnostics_performance_and_debug_surfaces`.
7. The final proof family registry must include:
   `public_entrypoint_and_signature_proof`;
   `guardrail_runner_and_artifact_model`;
   `invariant_registry_and_proof_reachability`;
   `verification_contract_and_workflow_drift`.
8. `known issue` family status must link to `KNOWN_ISSUES.md` or a dedicated
   plan step; it must not weaken the target rule.
9. `docs stale` is allowed only during implementation and is not accepted at
    final closure.
10. Generated evidence artifacts must be reproducible from checked-in commands
    written in the relevant family document; runtime Mermaid flow evidence uses
    `tool/lsp_trace_symbol.dart`, public export evidence uses
    `tool/trace_export_namespace.dart`, and proof inventory evidence uses
    `tool/trace_proof_inventory.dart`.

## 6. Result Requirements

1. A contributor can open `docs/ARCHITECTURE_ATLAS.md` and identify the correct
   architecture family, proof family, evidence, and defect-handling path for a
   change without reading chat history.
2. Every engine family id locked in section 5 is represented exactly once in
   `docs/architecture/overview.md` and has a matching family document.
3. Every proof family id locked in section 5 is represented exactly once in
   `docs/proof_architecture/overview.md` and has a matching family document.
4. Every family has a concise normative document with purpose, target rules,
   owners, forbidden shapes, mechanical evidence, status, and update triggers.
5. Every engine architecture family has explicit `Proof Links` to existing
   proof families, guardrail/audit commands, generated evidence, and
   registry-backed invariant ids when such invariants exist.
6. Every generated evidence artifact named by family docs is fresh against its
   repository-local generator command.
7. The atlas checker fails when a family is missing, a generated evidence file
   lacks a supported generator command, an evidence artifact is stale, a proof
   link points at no proof-family file, an invariant id is not present in
   `tool/invariant_registry.dart`, a `known issue` status lacks a linked issue,
   or an evidence artifact is not referenced by a family or flow document.
8. Confirmed current flaws remain visible as known issues or follow-up plan
   work and are not described as accepted target architecture.
9. `KI-9` and `KI-10` are removed only if the proof inventory evidence is
   refreshed and the freshness assertion is added.

## 7. Execution Order and Gates

### Required Order

- Add checker characterization before moving documentation paths.
- Refresh already-stale evidence before claiming any migrated family is
  `locked`.
- Migrate runtime family docs before adding new engine family docs so existing
  evidence paths are not orphaned.
- Add missing engine family docs before finalizing the engine overview.
- Add proof-family and proof-inventory freshness checks before finalizing the
  proof overview.
- Link or add known issues before setting any defect-bearing family to
  `known issue`.
- Retire old `target_*` paths only after all normative documentation, README
  links, and AGENTS links point at the new atlas paths.

### Successor Seam and Retirement Gates

- successor for `docs/target_architecture/**`:
  `docs/architecture/**`.
  Deletion gate: no `docs/target_architecture/**` files remain, and no
  normative source file points contributors there.
- successor for `docs/target_proof_architecture/**`:
  `docs/proof_architecture/**`.
  Deletion gate: no `docs/target_proof_architecture/**` files remain, and no
  normative source file points contributors there.
- successor for Markdown-shape map tests:
  `tool/check_architecture_atlas.dart` plus focused tool tests.
  Retirement gate: atlas checker validates the expected family id set, formal
  proof links, code-owned proof ids, evidence freshness, and absence of orphan
  evidence from atlas files.

### Deferred Broad Verification

- Full `required_code_change` preset is reserved for the final gate after docs,
  tool checker, tests, evidence, and source-of-truth links are all updated.
- Family-local audit commands may run slice-local when their evidence is added
  or refreshed.

## 8. File Map

### Implementation Files

- `tool/check_architecture_atlas.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`

### Test Files

- `test/tool/architecture_atlas_tool_test.dart`
- `test/tool/target_architecture_map_tool_test.dart`
- `test/tool/target_proof_architecture_map_tool_test.dart`
- `test/tool/trace_proof_inventory_tool_test.dart`
- `test/tool/run_verification_preset_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`

### Fixtures and Supporting Data

- `docs/architecture/evidence/add_node_write_flow.json`
- `docs/architecture/evidence/add_node_write_flow.md`
- `docs/architecture/evidence/commit_move_selection_flow.json`
- `docs/architecture/evidence/commit_move_selection_flow.md`
- `docs/architecture/evidence/composition_root_trace.json`
- `docs/architecture/evidence/composition_root_trace.md`
- `docs/architecture/evidence/pointer_input_flow.json`
- `docs/architecture/evidence/pointer_input_flow.md`
- `docs/architecture/evidence/render_main_scene_read_flow.json`
- `docs/architecture/evidence/render_main_scene_read_flow.md`
- `docs/architecture/evidence/render_overlay_preview_flow.json`
- `docs/architecture/evidence/render_overlay_preview_flow.md`
- `docs/architecture/evidence/replace_scene_write_flow.json`
- `docs/architecture/evidence/replace_scene_write_flow.md`
- `docs/proof_architecture/evidence/proof_inventory.json`
- `docs/proof_architecture/evidence/proof_inventory.md`
- `docs/proof_architecture/evidence/public_export_namespace.json`
- `docs/proof_architecture/evidence/public_export_namespace.md`

### Registry, Inventory, and Workflow Files

- `README.md`
- `AGENTS.md`
- `ARCHITECTURE.md`
- `KNOWN_ISSUES.md`
- `PLAN.md`
- `plan/step_30_complete_architecture_atlas_and_evidence_freshness.md`
- `docs/ARCHITECTURE_ATLAS.md`
- `docs/architecture/overview.md`
- `docs/architecture/execution_flows.md`
- `docs/architecture/families/public_package_boundary.md`
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
- `docs/architecture/families/import_build_materialization.md`
- `docs/architecture/families/serialization_and_schema.md`
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
- `docs/architecture/families/model_document_mutation_and_topology.md`
- `docs/architecture/families/store_and_commit_path.md`
- `docs/architecture/families/composition_root_and_facade.md`
- `docs/architecture/families/interaction_runtime.md`
- `docs/architecture/families/mutation_gateway.md`
- `docs/architecture/families/view_runtime_and_pointer_hosting.md`
- `docs/architecture/families/render_frame_admission_and_caches.md`
- `docs/architecture/families/diagnostics_performance_and_debug_surfaces.md`
- `docs/proof_architecture/overview.md`
- `docs/proof_architecture/proof_flows.md`
- `docs/proof_architecture/families/public_entrypoint_and_signature_proof.md`
- `docs/proof_architecture/families/guardrail_runner_and_artifact_model.md`
- `docs/proof_architecture/families/invariant_registry_and_proof_reachability.md`
- `docs/proof_architecture/families/verification_contract_and_workflow_drift.md`
- `docs/adr/0001_target_engine_architecture.md`
- `docs/adr/0002_post_target_optimization_scope.md`

### Deleted Files

- `docs/target_architecture/README.md`
- `docs/target_architecture/evidence/add_node_write_flow.json`
- `docs/target_architecture/evidence/add_node_write_flow.md`
- `docs/target_architecture/evidence/commit_move_selection_flow.json`
- `docs/target_architecture/evidence/commit_move_selection_flow.md`
- `docs/target_architecture/evidence/composition_root_trace.json`
- `docs/target_architecture/evidence/composition_root_trace.md`
- `docs/target_architecture/evidence/pointer_input_flow.json`
- `docs/target_architecture/evidence/pointer_input_flow.md`
- `docs/target_architecture/evidence/render_main_scene_read_flow.json`
- `docs/target_architecture/evidence/render_main_scene_read_flow.md`
- `docs/target_architecture/evidence/render_overlay_preview_flow.json`
- `docs/target_architecture/evidence/render_overlay_preview_flow.md`
- `docs/target_architecture/evidence/replace_scene_write_flow.json`
- `docs/target_architecture/evidence/replace_scene_write_flow.md`
- `docs/target_architecture/execution_flows.md`
- `docs/target_architecture/families/composition_root_and_facade.md`
- `docs/target_architecture/families/interaction_runtime.md`
- `docs/target_architecture/families/mutation_gateway.md`
- `docs/target_architecture/families/store_and_commit_path.md`
- `docs/target_architecture/families/view_runtime_and_render_seam.md`
- `docs/target_architecture/overview.md`
- `docs/target_proof_architecture/README.md`
- `docs/target_proof_architecture/evidence/proof_inventory.json`
- `docs/target_proof_architecture/evidence/proof_inventory.md`
- `docs/target_proof_architecture/evidence/public_export_namespace.json`
- `docs/target_proof_architecture/evidence/public_export_namespace.md`
- `docs/target_proof_architecture/families/guardrail_runner_and_artifact_model.md`
- `docs/target_proof_architecture/families/invariant_registry_and_proof_reachability.md`
- `docs/target_proof_architecture/families/public_entrypoint_and_signature_proof.md`
- `docs/target_proof_architecture/overview.md`
- `docs/target_proof_architecture/proof_flows.md`

### Analysis Area

- `lib/iwb_canvas_engine.dart`
- `lib/src/contract/**`
- `lib/src/core/**`
- `lib/src/model/**`
- `lib/src/controller/**`
- `lib/src/interactive/**`
- `lib/src/render/**`
- `lib/src/serialization/**`
- `lib/src/view/**`
- `tool/invariant_registry.dart`
- `tool/check_import_boundaries.dart`
- `tool/check_guardrails.dart`
- `tool/check_public_api_surface.dart`
- `tool/check_invariant_coverage.dart`
- `tool/check_verification_contract.dart`
- `tool/lsp_trace_symbol.dart`
- `tool/lsp_trace_flow.dart`
- `tool/lsp_find_symbols.dart`
- `tool/lsp_find_boundary_bypasses.dart`
- `tool/lsp_find_thin_wrappers.dart`
- `tool/trace_export_namespace.dart`
- `tool/trace_proof_inventory.dart`
- individual `tool/audit_*.dart` commands named by family evidence entries

## 9. Implementation Rules

### Protected Invariants

- `INV-G-LAYER-DAG`
- `INV-G-LAYER-BOUNDARIES`
- `INV-G-PUBLIC-ENTRYPOINTS`
- `INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES`
- `INV-ENG-PUBLIC-SIGNATURE-HERMETICITY`
- `INV-ENG-CORE-ARCHITECTURE-BOUNDARY`
- `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`
- `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`
- `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`
- `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`
- `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY`
- `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY`
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`
- `INV-ENG-PERFORMANCE-PROOF-CONTOUR`

### Required Proof

- behavioral proof: family-local Flutter/tool tests named in each family
  document continue to pass through their verification scopes
- structural proof: `dart run tool/check_architecture_atlas.dart`
- structural proof: `dart run tool/check_import_boundaries.dart`
- structural proof: `dart run tool/check_guardrails.dart`
- structural proof: `dart run tool/check_public_api_surface.dart`
- structural proof: `dart run tool/check_invariant_coverage.dart`
- structural proof: `dart run tool/check_verification_contract.dart`
- evidence freshness proof: `tool/check_architecture_atlas.dart` must
  regenerate freshness-checkable evidence through the exact checked-in
  generator commands named in family docs
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- documentation moves, additions, and rewrites under `docs/**`
- one atlas checker and focused tests
- evidence regeneration from repository-local commands
- source-of-truth link updates in `README.md`, `ARCHITECTURE.md`, `AGENTS.md`,
  `PLAN.md`, and this step document
- removal of `KI-9` and `KI-10` only when their root causes are fixed by this
  step with regression proof

### Forbidden Moves

- Do not change production engine behavior to make the atlas easier to write.
- Do not describe a known defect as locked target architecture.
- Do not create duplicate normative maps under both old `target_*` and new
  atlas paths.
- Do not make Markdown heading/table parsing the primary architecture proof.
- Do not archive obsolete target-map documents instead of deleting them after
  their useful content is migrated.
- Do not remove a known issue without adding or naming the regression proof
  that prevents recurrence.
- Do not weaken existing guardrails, import-boundary checks, invariant
  coverage, public API checks, or verification-contract checks.

### Optional: Recognition Forms That Must Be Supported

- `Proof Links` sections must support generated evidence commands that produce
  JSON and Markdown companions.
- Generated runtime-flow evidence commands must support
  `tool/lsp_trace_symbol.dart` with `--json-out` and `--mermaid-out`.
- Generated proof evidence commands must support
  `tool/trace_export_namespace.dart` and `tool/trace_proof_inventory.dart` with
  `--json-out` and `--md-out`.
- `Proof Links` sections must support command-only evidence when the evidence
  is a checker with no committed output artifact.
- Family status blocks must support `known issue` entries with `KI-*` ids.
- `Proof Links` sections must support proof-family file links, `INV-*` ids,
  guardrail command paths, and audit command paths for engine architecture
  families.
- `INV-*` ids are required only when the family has a registry-backed invariant
  in `tool/invariant_registry.dart`; otherwise the family must state that no
  registry-backed invariant exists and still name at least one guardrail, audit,
  or generated evidence command.
- Family docs must support `Update Triggers` so contributors know when to
  refresh evidence or family docs.

### Optional: Allowed Forms That Are Not Violations

- ADR links from family docs are allowed as rationale, but not as mechanical
  evidence.
- A family may cite multiple evidence commands when one command cannot prove the
  whole boundary.
- A family may declare no invariant ids only under the registry-backed
  invariant rule above.
- A family may be `known issue` at final closure when the defect is confirmed,
  linked, mechanically evidenced, and outside this change boundary.
- Markdown entry/link smoke tests may remain if they do not infer semantic
  architecture coverage from prose.

### Optional: Resolution Rules

- If generated evidence differs only by unstable ordering or line numbers, fix
  the generator or checker normalization before accepting freshness as proof.
- If generated evidence reveals a behavior or ownership defect, add or update
  `KNOWN_ISSUES.md` before finalizing the family status.
- If a proof link cannot be traced to a code-owned registry or tool command,
  do not invent the link from prose; either add a real repository-local proof
  surface or leave the family unready.
- Aggregate repository audits that currently fail because of active known
  issues may be used as classification evidence only; they must not be listed
  as passing closure checks until the linked known issues are fixed.
- If a family cannot be mechanically evidenced with existing tools, add the
  smallest repository-local checker or audit needed, or mark the family
  `known issue` with a follow-up plan step; do not mark it `locked`.
- If an old target-map document cannot be cleanly migrated into the new atlas,
  stop and resolve whether it contains still-useful content before deleting it;
  do not create an archive.

## 10. Vertical Slices

### Slice 1. [x] Atlas Checker Characterization

#### Slice Contract

Introduce the checker seam before moving documentation so atlas proof depends
only on formal links, ids, code-owned registries, and generated evidence. This
slice is fixture-based: it proves the checker contract against synthetic atlas
trees, not against the repository docs that are created and migrated in slice 2.

#### Change

- Add `tool/check_architecture_atlas.dart` with validation for atlas entrypoint
  existence, overview links, family file existence, required family headings,
  valid statuses, and required known-issue links.
- Support `--docs-root=<path>` and default it to the repository `docs/`
  directory, so tests can exercise complete and broken atlas trees before the
  real atlas exists.
- Add the expected architecture/proof family id sets from section 5 to
  `tool/check_architecture_atlas.dart`, and fail on missing, duplicate, or
  unknown family ids in the overview registries.
- Validate proof-family links against existing proof-family files, invariant ids
  against `tool/invariant_registry.dart`, and guardrail/audit command paths
  against existing repository files.
- Validate generated evidence command forms for `tool/lsp_trace_symbol.dart`,
  `tool/trace_export_namespace.dart`, `tool/trace_proof_inventory.dart`, and
  family-named audit tools.
- Validate that every committed evidence file under
  `docs/architecture/evidence/**` and `docs/proof_architecture/evidence/**` is
  referenced by a family or flow document.
- Add `test/tool/architecture_atlas_tool_test.dart` with positive fixtures and
  negative cases for missing family docs, missing evidence, stale/unknown
  status, and `known issue` without an issue link.
- Reduce or preserve existing target map tests only as temporary coverage until
  slice 6 deletes old paths.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart`
  with CLI-backed fixture cases that prove the checker rejects missing
  families, orphan evidence, unsupported generator commands, and stale
  evidence.

#### Fixtures Used

- temporary test sandbox fixtures created by
  `test/tool/architecture_atlas_tool_test.dart`

#### Positive Scenarios

- An atlas family with existing docs, evidence, and a valid `locked` status
  passes.
- A `known issue` entry with a valid known issue id passes.

#### Negative Scenarios

- Missing family document fails.
- Missing expected family id fails.
- Duplicate or unknown family id fails.
- Missing evidence artifact fails.
- Orphan evidence artifact fails.
- Missing proof-family link for an engine family fails.
- Unknown invariant id fails.
- Missing guardrail or audit command file fails.
- Generated evidence without a supported generator command fails.
- Unknown status fails.
- `known issue` without a known issue id fails.

#### Closure Evidence

- Atlas checker exists, is tested against fixture atlas trees, and is ready to
  run against repository docs after slice 2 creates the real atlas skeleton.

### Slice 2. [x] Single Entrypoint And Directory Migration

#### Slice Contract

Create the one human entrypoint and move existing runtime/proof maps to the new
atlas paths without changing their family meaning yet.

#### Change

- Add `docs/ARCHITECTURE_ATLAS.md`.
- Migrate useful content from `docs/target_architecture/README.md` and
  `docs/target_proof_architecture/README.md` into `docs/ARCHITECTURE_ATLAS.md`
  and the new overviews; do not create `docs/architecture/README.md` or
  `docs/proof_architecture/README.md`.
- Move non-README target architecture files into the concrete
  `docs/architecture/**` paths listed in section 8.
- Move non-README target proof architecture files into the concrete
  `docs/proof_architecture/**` paths listed in section 8.
- Update internal links, `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, and
  existing map tests for the new paths.
- Keep ADR files in `docs/adr/**`.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart test/tool/target_architecture_map_tool_test.dart test/tool/target_proof_architecture_map_tool_test.dart`

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `! rg -n "docs/target_architecture|docs/target_proof_architecture" README.md AGENTS.md ARCHITECTURE.md docs/ARCHITECTURE_ATLAS.md docs/architecture docs/proof_architecture`

#### Fixtures Used

- Existing committed docs and evidence files.

#### Positive Scenarios

- `docs/ARCHITECTURE_ATLAS.md` routes to engine atlas, proof atlas, ADRs, known issues, and
  evidence update rules.
- Existing runtime/proof families are reachable through new paths.

#### Negative Scenarios

- Old target-map paths are not referenced as normative sources after migration.

#### Closure Evidence

- One docs entrypoint exists and old target-map names no longer own current
  architecture navigation.

### Slice 3. [x] Evidence Freshness And Existing Defect Closure

#### Slice Contract

Refresh stale committed evidence and add freshness proof so the atlas cannot
claim stale generated artifacts as current architecture.

#### Change

- Start with one failing reproducer in
  `test/tool/architecture_atlas_tool_test.dart` proving that stale committed
  proof/evidence freshness is accepted incorrectly before the fix.
- Add 1 to 3 neighboring guard tests for fresh evidence, stale Markdown
  companions, unsupported generator commands, or orphan committed evidence.
- Extend `tool/check_architecture_atlas.dart` with the minimal owner-side fix
  needed to regenerate or compare
  supported evidence commands against committed artifacts, including
  `tool/lsp_trace_symbol.dart`, `tool/trace_export_namespace.dart`, and
  `tool/trace_proof_inventory.dart`.
- Regenerate stale runtime evidence:
  `composition_root_trace.*`,
  `render_main_scene_read_flow.*`,
  `render_overlay_preview_flow.*`, and
  `pointer_input_flow.*` using `tool/lsp_trace_symbol.dart` with the family-doc
  `--json-out` and `--mermaid-out` commands.
- Regenerate stale proof evidence:
  `docs/proof_architecture/evidence/proof_inventory.*` using
  `tool/trace_proof_inventory.dart` with the family-doc `--json-out` and
  `--md-out` command.
- Remove `KI-9` and `KI-10` only after the proof inventory artifact is fresh
  and the freshness check fails on stale committed inventory in tests. Do not
  remove either issue before the failing reproducer and guard tests are in
  place.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart test/tool/trace_proof_inventory_tool_test.dart`

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/trace_proof_inventory.dart --json-out=/tmp/architecture_atlas_proof_inventory.json --md-out=/tmp/architecture_atlas_proof_inventory.md` followed by checker-backed comparison through the atlas tool

#### Fixtures Used

- Committed evidence under `docs/architecture/evidence/**` and
  `docs/proof_architecture/evidence/**`.

#### Positive Scenarios

- Fresh generated evidence matches committed artifacts.
- Runtime Mermaid evidence is reproduced from `tool/lsp_trace_symbol.dart`, not
  from hand-written diagrams.
- Proof inventory evidence matches `tool/invariant_registry.dart`.

#### Negative Scenarios

- A stale proof inventory fixture fails.
- A stale runtime evidence fixture fails when its command is marked
  freshness-checkable.
- A generated `.md` evidence artifact without a generator command fails.
- A committed evidence file that no family or flow references fails.

#### Closure Evidence

- Stale evidence found during planning is refreshed and future stale evidence
  is mechanically detected; `KI-9` and `KI-10` are removed only in the same
  change that adds the failing-first freshness regression proof.

### Slice 4. [x] Complete Engine Family Atlas

#### Slice Contract

Expand `docs/architecture/**` from runtime-center coverage to complete engine
owner-family coverage without accepting known defects as target rules.

#### Change

- Add missing engine family docs named in section 8.
- Update `docs/architecture/overview.md`,
  `docs/architecture/execution_flows.md`, and family links to include all
  engine families named in section 5.
- For each family, cite existing structural checks, behavioral suites, audits,
  generated evidence, proof-family links, applicable registry-backed invariant
  ids, and update triggers.
- Add a concise `Proof Links` section to every engine architecture family; it
  must link to proof families and code-owned checks without duplicating
  proof-family explanations.
- Link existing known issues to families they affect, including contract fast
  paths, draw terminal cleanup, runtime stroke validation, model topology,
  fill-only path hit testing, paint admission parity, selection rendering, and
  performance/benchmark tooling where applicable.
- Add new `KNOWN_ISSUES.md` entries only for newly confirmed defects found
  while building the atlas.

#### Behavioral Verification

- `flutter test --no-pub test/contract test/core test/model test/serialization test/public_api test/controller test/interactive test/render test/view`

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- Existing production tests and tool audit fixtures.

#### Positive Scenarios

- Every expected engine family id from section 5 appears exactly once in the
  atlas.
- Every family has at least one structural proof surface and one behavioral or
  audit proof surface.
- Every engine family links to the proof-family and code-owned checks that hold
  or observe it.
- Known defects are visible as issue links, not target rules.

#### Negative Scenarios

- A family missing from `docs/architecture/overview.md` fails the atlas
  checker.
- A family id not listed in section 5 fails the atlas checker.
- A `known issue` family without a linked issue fails.
- A family with no evidence command fails.
- A family with a proof link that is not backed by a proof-family file or a
  code-owned registry fails.

#### Closure Evidence

- The engine atlas is complete enough for routing future code changes by owner
  family.

### Slice 5. [x] Complete Proof Family Atlas

#### Slice Contract

Expand `docs/proof_architecture/**` so architecture enforcement, proof
artifacts, invariant reachability, public API proof, and workflow drift proof
are all discoverable from the atlas.

#### Change

- Add `docs/proof_architecture/families/verification_contract_and_workflow_drift.md`.
- Update proof overview and proof flows.
- Link `KI-11` from the verification-contract/workflow family if the workflow
  gap remains unresolved.
- Ensure public namespace, guardrail artifact, invariant reachability, and
  verification-contract proof families cite their owning tools, tests, and
  evidence artifacts.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart test/tool/trace_export_namespace_tool_test.dart test/tool/trace_proof_inventory_tool_test.dart test/tool/verification_contract_tool_test.dart`

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_verification_contract.dart`

#### Fixtures Used

- Existing public-entrypoint, proof-inventory, and verification-contract tool
  test fixtures.

#### Positive Scenarios

- Proof families identify their generated artifacts and owning tools.
- Workflow drift proof is visible even if an existing known issue keeps it from
  being `locked`.

#### Negative Scenarios

- A proof family without evidence fails atlas checking.
- A proof family id not listed in section 5 fails atlas checking.
- A workflow proof gap cannot be hidden behind a `locked` status.

#### Closure Evidence

- The proof atlas is complete enough for routing future enforcement and CI
  changes by owner family.

### Slice 6. [x] Retire Old Map Tests And Source Links

#### Slice Contract

Remove the old Markdown-parsing target-map proof role after the narrow atlas
checker owns atlas validation.

#### Change

- Replace or reduce `test/tool/target_architecture_map_tool_test.dart` and
  `test/tool/target_proof_architecture_map_tool_test.dart` so they no longer
  infer semantic completeness from Markdown prose.
- Add atlas checker invocation to the verification contract when atlas docs,
  evidence, or checker files change.
- Update `test/tool/run_verification_preset_tool_test.dart` and
  `test/tool/verification_contract_tool_test.dart` if the verification graph
  changes.
- Ensure old `docs/target_architecture/**` and
  `docs/target_proof_architecture/**` paths are absent.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart test/tool/run_verification_preset_tool_test.dart test/tool/verification_contract_tool_test.dart`

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_verification_contract.dart`
- `! rg -n "docs/target_architecture|docs/target_proof_architecture" README.md AGENTS.md ARCHITECTURE.md docs/ARCHITECTURE_ATLAS.md docs/architecture docs/proof_architecture`

#### Fixtures Used

- Verification-contract tool test fixtures.

#### Positive Scenarios

- Changed atlas paths trigger atlas verification through the repository
  verification plan.
- Markdown tests no longer own semantic atlas proof.

#### Negative Scenarios

- A target-map path reference fails in normative source files.

#### Closure Evidence

- The narrow atlas checker is the canonical atlas proof seam.

### Slice 7. [x] Final Documentation Source-Of-Truth Alignment

#### Slice Contract

Make the repository-level documentation map point at the new atlas and close
the plan step only after final verification passes.

#### Change

- Finalize `docs/ARCHITECTURE_ATLAS.md`, `README.md`, `ARCHITECTURE.md`, and `AGENTS.md`
  source-of-truth wording.
- Update `PLAN.md` and this step document checkboxes only after all slices are
  complete.
- Confirm `KNOWN_ISSUES.md` contains only active confirmed defects and that
  `KI-9`/`KI-10` were removed only if closed by slice 3.

#### Behavioral Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file="$CHANGED_PATHS_FILE"` where the file lists every modified, added, renamed, or deleted repository-relative path

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_verification_contract.dart`

#### Fixtures Used

- Final changed-paths file listing every modified, added, renamed, or deleted
  repository-relative path.

#### Positive Scenarios

- New contributors and agents can route architecture work from `docs/ARCHITECTURE_ATLAS.md`.
- Required verification includes atlas freshness for atlas-relevant changes.

#### Negative Scenarios

- No `docs stale` atlas family remains.
- No old target-map path remains as a normative source.

#### Closure Evidence

- Required preset passes and the plan step is marked complete only in the same
  implementation change that completes the atlas.

## 11. Final Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_verification_contract.dart`
- `dart run tool/run_tool_tests.dart test/tool/architecture_atlas_tool_test.dart test/tool/trace_export_namespace_tool_test.dart test/tool/trace_proof_inventory_tool_test.dart test/tool/run_verification_preset_tool_test.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file="$CHANGED_PATHS_FILE"` where the file lists every modified, added, renamed, or deleted repository-relative path

## 12. Acceptance Criteria

- `docs/ARCHITECTURE_ATLAS.md` is the single entrypoint for architecture navigation under
  `docs/**`.
- `docs/architecture/**` covers every engine owner family named in section 5.
- `docs/proof_architecture/**` covers every proof family named in section 5.
- The atlas checker enforces the exact expected family id set from section 5
  and rejects missing, duplicate, or unknown family ids.
- Every engine architecture family has checked proof links to existing proof
  families, guardrail/audit commands, evidence commands, and registry-backed
  invariant ids when such invariants exist.
- Committed generated evidence is fresh for every freshness-checkable artifact.
- No committed evidence artifact is orphaned.
- No `docs stale` family remains.
- Every `known issue` family links to `KNOWN_ISSUES.md` or a dedicated plan
  step and preserves the intended target rule.
- Old `docs/target_architecture/**` and
  `docs/target_proof_architecture/**` files are absent.
- Markdown-structure tests no longer serve as the primary atlas proof.
- Repository source-of-truth links in `README.md`, `ARCHITECTURE.md`, and
  `AGENTS.md` point at the atlas.
