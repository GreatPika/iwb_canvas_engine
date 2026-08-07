# Change Contract Rules

This is the single semantic rulebook for authoring and review. It is ordered by semantic validation layers, not by authoring sequence or rendered nesting. The mode router owns permissions; `authoring.md` and `reviewing.md` own procedure, while `../assets/change-contract-template.md` owns the rendered structure of a full contract and `Contract Blocker And Final Consistency` below owns the blocker structure. When a term appears before its owning section, the earlier occurrence states a dependency rather than redefining it.

## 1. Purpose And Output Boundary

`Goal` is exactly one paragraph describing the intended repository state after all execution units complete. It never describes authoring, lint, review activity, or intermediate implementation steps.

Return either a full contract or a Contract Blocker, never a partial contract. Contracts define future work and future evidence. Keep every unit unchecked. Do not include completed status, implementation results, command outputs, commit hashes, implementation reports, reviewer approvals, roadmap closure, or claims that future evidence passed. Read-only authoring facts belong only in `Repository Evidence`.

## 2. Source Authority And Contract Gate

Read every source explicitly named by the request or artifact. A full contract contains a `Source Inputs` table with columns `Category`, `Source ID`, and `Location or authority`, and all four categories: `Design`, `Research`, `PLAN`, and `Other`. Each category has either one `none` row or independently keyed source rows. A source is a canonical repository-relative path, an absolute external path, or literal `user request`.

Every user-named source appears in `Source Inputs`. Preserve accepted source decisions by meaning; do not redesign, reinterpret, narrow, or replace them without explicit authority. An intentional exclusion requires source/user authority, appears in `Out of Scope`, and maps through `Decision Trace`, the public obligation ledger defined in its owning section below.

For an active design, read frontmatter `disposition` and `product_outcome`:

- `NEEDS_RESEARCH` and `ARCHITECTURE_GATE` block contract authoring.
- `product_outcome` preserves intent without requiring same-named body sections.
- Historical, resolved, deferred, and out-of-scope mentions do not themselves block.

Return a Contract Blocker whenever implementation would still have to choose or reconcile a material owner, owning layer, boundary, source of truth, compatibility rule, API behavior, public error mapping or taxonomy, order, temporal behavior, atomicity or all-or-nothing behavior, migration or retirement strategy, recognition scope, handoff, acceptance oracle, or evidence constraint. Also block when accepted sources disagree on any such matter, a mandatory source update is optional, or evidence depends on an unauthorized verification mechanism.

A reviewer example, convenient repository pattern, candidate owner, or candidate verification seam proves only that a decision is missing; it grants no authority. Name the missing/incompatible decision and exact evidence or authority required. Do not propose a preferred implementation as repair.

Only local tactics inside closed semantic boundaries may remain open. Exact new test paths, fixture names/layout, selectors, private identifiers/helpers, injection hooks, regexes, AST visitors, source searches, and future commands remain open unless fixed by an upstream decision, existing owner, or mandatory resolution procedure.

When scope includes a production structural trigger, resolve the structure
against `AGENTS.md`, `docs/architecture/02_package_boundaries.md`, and, when
architecture graph nodes or edges change,
`docs/architecture/architecture_graph.yaml` before returning a full contract.
Preserve source-backed consequences in the existing
`Source Inputs`, `Decision Trace`, `Repository Evidence`, `Boundaries`, unit
owners, outcomes, and verification constraints; do not add a
`Production Structure Handoff` section or another decision artifact. A direct
change whose material axes are authority-resolved does not require a contract
merely because it is structural; file count, diff size, and estimated effort do
not decide the route. A new Graph node always requires an accepted architecture
design and this accepted Change Contract, with its ADR gate closed as required
by the shared procedure.

When scope includes a test structural trigger, resolve the structure against
`AGENTS.md`, `docs/architecture/02_package_boundaries.md`, and
`docs/verification/tests.md` before returning a full contract. Preserve the
resolved proof owner, exact target paths and names, support and import
boundaries, and oracle constraints in `Repository Evidence`, `Boundaries`,
`Decision Trace`, and applicable verification constraints; do not add a `Test
Structure Handoff` section. Test structure alone does not require a contract.
An unresolved material axis blocks the contract through the normal rule above.

## 3. Classification, Keys, And Repository Evidence

Read `contract-vocabulary.json` completely. Select exactly one primary `Profile` from `profiles` and every material `Obligations` token from `obligations`; use the no-obligation value alone only when no material obligation applies. Each unit selects a `Verification Profile` from the same profile vocabulary and may differ from the primary profile only for necessary supporting work. Exclude unrelated profiles and bundled independent changes.

Decision, outcome, evidence, and admission keys are unique lowercase kebab-case contract-local identifiers. They remain stable across unit renumbering/regrouping, contain no unit/step/phase/scheduling marker, and never become code symbols, test names, architecture identifiers, or another repository source of truth.

`Repository Evidence` rows are decision-bearing and normally cite a line:

```text
- `path/to/file.ext:line` / surface: observed fact -> contract consequence.
```

Each consequence settles or constrains an owner, boundary, source of truth, compatibility surface, order, acceptance outcome, evidence rule, verification seam, recognition scope, or exclusion. Path-only evidence is allowed only for a new artifact, generated output without stable lines, or a command/configuration surface where lines are meaningless; name the exception.

Exclude decorative/broad citations, raw search output, long quotations, research logs, private reasoning, and facts that do not support their claimed consequence. Verify that every named owner, package, path, document, registry, schema, generated output, public API, and consumer exists or is explicitly a future artifact—not only those cited as evidence.

## 4. Design Proportionality Backstop

Reverse-trace every material obligation added or strengthened by the contract to an exact accepted design decision or mandatory source constraint. Material obligations include observable behavior; state/lifecycle; coordination/order; an owner, seam, or abstraction; compatibility; migration/retirement; a verification seam or failure family; a durable artifact; or a repository-wide gate. Audit `Boundaries`, units, outcomes, evidence constraints, durable impacts, admissions, and `Verification Gate`.

A disposition, overall approval, selected form, broad intent, or decision ID is not blanket authority: the cited decision/constraint must entail the exact obligation. A proposed artifact cannot retroactively authorize a contract-only delta.

Block unsupported strengthening and extra implementation/verification work when removing it preserves every accepted decision and mandatory constraint. Precedent, convenience, ease of testing, speculative flexibility, and richer specification are insufficient alone.

Do not choose another architecture through this backstop. A current `BLOCKED` architecture-design validation makes the dependent contract non-implementable; otherwise audit only contract-added or strengthened obligations. If repair changes a material architecture axis, return `BLOCKED` and require separate `architecture-design` review rather than inventing replacement decisions.

## 5. Boundary Closure And Ordering

Every full contract closes these fields: `Owner`, `In Scope`, `Out of Scope`, `Source of Truth`, `Compatibility`, `Order Constraints`, `Temporal Surface Closure`, `All-Or-Nothing Failure Boundary`, `Negative Proof And Fixture Quarantine`, and `Bounded Recognition Scope`.

Each field is exact and non-empty. A non-applicable field gives a specific reason; bare `None`, `N/A`, or generic non-applicability is invalid. `Compatibility` covers every affected public API, data format, schema, configuration, persisted value, generated output, documentation contract, and external consumer.

Durable meaning has one owning source of truth. Cache or performance duplication is allowed only when explicit and the contract closes its invariant, consumers, and direct evidence constraint. Do not add a second certainty signal merely to prove an existing owning value intentional. A duplicate field, registry, allowlist, identity marker, policy seam, constant, token heuristic, proof-name convention, copied inventory, comment, or manual mirror is valid only for a distinct durable concept with its own owner, lifecycle, consumer, validation rules, and evidence that the existing owner cannot own it. When an owning source already names the accepted value, units make consumers read that value directly rather than adding an intent marker or parallel proof signal.

`Bounded Recognition Scope` applies only to analyzer, guardrail, schema-validator, structured-scanner, generated-output, import-scan, or fixture-recognition architecture. Preserve the source-owned invalid state, target artifact, recognizer boundary, and stop rule without locking private mechanism. Behavioral inconvenience does not justify recognition proof. Block an unbounded syntax recognizer, arbitrary JSONPath, token heuristic, or general analyzer that lacks source authority and a stable bounded owner.

Preserve negative behavior, temporal and reentrancy order, all-or-nothing and no-mutation behavior, and fixture quarantine in applicable boundaries, acceptance side conditions, and direct evidence constraints. A negative proof targets invalid shape, stale mirrors, boundary violations, incoherent data, unauthorized consumers, no-mutation failure, or source-truth drift; it must not reject a different coherent policy value merely to prove the selected value.

Close every applicable order:

- source truth and guardrails before dependants;
- replacement paths before consumer migration;
- producers, APIs, and seams before consumers;
- migration evidence before old-path retirement;
- negative/bypass evidence before enforcement claims;
- temporal/atomicity evidence before publication or mutation is closed;
- roadmap/status closure after implementation and all required evidence.

## 6. Acceptance Outcomes And Direct Evidence

`Acceptance Outcomes` are rendered inside execution units. This section defines their semantics and evidence relationship before `Execution Units And Dependency DAG` below defines how they are packaged into implementable work.

Every acceptance outcome has a semantic key and four complete parts equivalent to Given/When/Then/And:

- `Starting state`: bounded state, source-owned fact, or external input.
- `System action`: meaningful product, repository, build, dependency, or documentation action; a verification command is not the claimed action.
- `Observable result`: exact owner-observable value, route, issue, public API shape, unchanged state, rejection, absent forbidden surface, redacted/generated output, build/runtime result, or documentation result.
- `Required side conditions`: all applicable compatibility, no-mutation, temporal, atomicity, quarantine, recognition, and source-truth constraints.

Every outcome has at least one `Verification Matrix` row directly detecting the result and side conditions. One row may cover multiple outcomes only when one evidence surface observes one coherent failure family or invariant. Each row names a stable verification owner and observable, pass signal, and pre-implementation witness.

Name an exact repository-owned command when it exists; do not invent an exact future command for new coverage unless an upstream source fixes it.

Every `Evidence constraints and rejected proxy` cell names the admissible observation and at least one tempting proxy that could pass while the outcome remains false. Reject helper-call/private-identifier assertions, mere source existence, copied inventories, wording tokens, wrapper commands, and unrelated green suites when they do not directly observe the outcome. Apply this semantically, not as a phrase blacklist.

Evidence classes are exactly `TEST`, `STATIC_ANALYSIS`, `BUILD_OR_COMPILE`, `RUNTIME`, `TEMPORARY_REPRODUCER`, `STRUCTURED_DATA_CHECK`, `SOURCE_QUERY`, and `MANUAL_INSPECTION`. `SOURCE_QUERY` never proves runtime behavior. `TEMPORARY_REPRODUCER` may expose a pre-implementation failure but never becomes a committed permanent artifact.

For `BUG_FIX` and `BEHAVIOR_CHANGE`, the witness names concrete current failing/absent behavior detected by future evidence. Every other profile names a concrete current verification gap or `Not required: <profile-specific reason>`. Planning gathers no completion evidence and never reports future checks as passing.

If a source decision exceeds its direct acceptance/evidence surface, split independently meaningful outcomes, narrow the claim when sources permit, add direct evidence, move the unsupported claim to an authorized exclusion, or return a Contract Blocker.

## 7. Profile Rules

- `BUG_FIX`: require a concrete failing witness and durable red/green coverage. `NONE` is valid only when existing committed durable coverage itself fails before the fix and passes afterward; otherwise add, extend, or correctly update durable regression coverage.
- `BEHAVIOR_CHANGE`: admitted evidence detects the changed outcome and fails before implementation; an unchanged always-green suite is insufficient.
- `REFACTOR`: run existing owning verification before and after. Default to `NONE` or `UPDATE_EXISTING`; expansion requires a concrete pre-existing gap and complete admission.
- `TEST_REFACTOR`: preserve each failure-detection guarantee, transfer it, or officially retire it through `REDUCE_OR_REMOVE`.
- `ANALYZER_RULE`: use a stable central owner with accepted, rejected, and false-positive fixtures; feature-local general scanners are forbidden.
- `SOURCE_OF_TRUTH_DOCS`: use structured schemas, generated data, or machine-consumed checks; prose wording is never permanent behavior proof.
- `DOCUMENTATION`: use a docs build, link tool, generator check, or bounded human review appropriate to the claim.
- `BUILD_OR_CI`: name exact relevant build, install, compile, runtime, or smoke evidence.
- `DEPENDENCY_CHANGE`: name exact package, compatibility, supported-runtime, or integration evidence.

## 8. Durable Impact And Permanent Artifact Admission

Classify every Matrix row as exactly one of `NONE`, `ADD`, `EXTEND_COVERAGE`, `UPDATE_EXISTING`, or `REDUCE_OR_REMOVE`.

- `NONE` means no permanent verification artifact change; `Artifact target` and `Admission` are `None`.
- Every non-`NONE` row names its affected existing artifact or owner-scoped new artifact family in `Artifact target`.
- `NONE` is exclusive across rows covering the same outcome. Split unchanged and changed permanent guarantees into distinct outcomes instead of mixing `NONE` with non-`NONE` evidence.
- `UPDATE_EXISTING` applies only to the same owned failure family; a new independent guarantee is `EXTEND_COVERAGE`.
- `REDUCE_OR_REMOVE` names the official transfer owner for every detection guarantee or the owning source explicitly retiring it. Deletion alone is not closure.

Every `ADD` or `EXTEND_COVERAGE` row references a complete admission for each independent failure family. One admission cannot cover unrelated families merely because they share a file; a new independent family does not belong in a mixed-owner test.

Render each non-empty admission in this exact field order:

```markdown
### `metadata-update-atomicity-admission`: Conditional metadata transaction atomicity

Covers: `metadata-update-commits-atomically`, `metadata-update-failure-preserves-state`
Impact: `EXTEND_COVERAGE`
Failure family: metadata update can partially mutate durable state on failure
Failure mode or stable invariant: failed conditional updates commit no metadata or bundle mutation
Verification owner: lesson metadata data-core owning suite
Current verification gap: current suite has no conditional metadata update
Failing witness: the current public surface cannot exercise this outcome
Durable and refactor-stable value: commit/no-mutation behavior survives private transaction refactors
Artifact target: existing owner path when known, otherwise the owner-scoped artifact family
```

`Covers` binds an admission to semantic outcome keys. Those outcomes appear under their execution units, so the outcome keys provide the authoritative admission-to-unit relationship. Units never repeat admission keys. One unit may resolve through multiple admissions; one coherent admission may cover multiple related outcomes.

Require exact new artifact paths only when fixed upstream or extending an existing owner path. Otherwise lock the stable verification owner and failure family while leaving cohesive placement open.

`Permanent Artifact Admissions` is always present and contains `None` only when no Matrix row uses `ADD` or `EXTEND_COVERAGE`.

## 9. Execution Units And Dependency DAG

Execution units package the acceptance outcomes defined above into independently implementable work.

Each unit is independently implementable, checkable, and committable without a deliberately broken repository. It owns one stable responsibility and one bounded result; one owner means the responsibility that owns the result, not necessarily one file/class. An atomic public-seam migration combines the seam, all production implementations, bindings, fakes, and test doubles when partial migration cannot compile.

Separate independently closable outcomes when stable owners, risks, or results differ. Do not create declaration-only, consumer-only, partial-migration, file-list, mixed-owner, or otherwise non-committable units. Do not split declaration-before-use inside one atomic migration or merge outcomes with independent owners, boundaries, profiles, risks, results, or recognition scopes.

Use contiguous unchecked headings in topological order:

```text
### [ ] Unit N: Imperative outcome title
```

Each unit contains exactly, in order: `Owner`, `Boundary`, `Verification Profile`, `Change`, `Acceptance Outcomes`, `Depends On`.

`Change` is a concrete implementation outcome. Units contain no commands, test paths, admissions or admission keys, durable-impact rows, rejected-proxy prose, or completion claims.

Each dependency references an earlier producer and names the real produced and consumed surfaces:

```text
- Unit 3 — produces: <surface>; consumed as: <surface>
```

Use `None` for no dependency. Documentation order, shared topic, future command order, cleanup sequence, or broad relation creates no edge. Evidence is not a producer unless it is a separately owned deliverable. Replacement/generated/seam consumers cannot precede producers; retirement cannot precede replacement evidence; a final absence scan cannot precede units intentionally retaining the old surface.

## 10. Decision Trace

`Decision Trace` is the public obligation ledger:

```text
accepted source or repository fact -> contract decision -> boundary/unit/outcome/Matrix/Gate target -> acceptance or evidence target
```

Include every material accepted-source and repository-derived decision, including authorized exclusions. Each maps to a boundary, unit, acceptance outcome, Matrix row, or Gate constraint, then to an acceptance/evidence target. No material decision survives only as unlinked prose. Use stable contract-local keys. Map every intentional exclusion to `Out of Scope` and its source/user authority.

## 11. Verification Ownership And Gate

Tests may consume but never own or mirror product, model, schema, architecture, or documentation truth. Reject copied inventories as authority, prose parsing as product proof, feature-local general scanners, self-referential fixtures whose expected truth comes from the implementation under test, private-shape proof, and feature-local ownership when a stable central owner governs the failure family.

`Verification Gate` contains only changed-owner, cross-unit, repository, finding-disposition, diff-hygiene, canonical-route, and lifecycle closure not already owned by a Matrix row. It includes every known changed-owner check selected from the repository verification policy in `AGENTS.md`, `Finding disposition`, and `git diff --check`; it also includes canonical-route integrity when routes change and active contract/source lifecycle closure when applicable. Never mechanically duplicate focused unit evidence.

Name each exact established command once in the Matrix or Gate, with working directory when material. New-coverage commands remain implementation-owned unless fixed upstream. Every Gate check names scope, admissible future evidence, and pass signal; vague/prose-only checks are not closure. There is no fixed command count.

## 12. Contract Blocker And Final Consistency

When evidence cannot close a material decision or direct proof, return exactly:

1. `# Contract Blocker`
2. `Goal`
3. `Source Inputs`
4. `Blocking Decisions`
5. `Repository Evidence`

`Blocking Decisions` is one table with exactly `Decision ID`, `Blocking decision`, `Blocks because`, and `Needed evidence or authority`; each independent unresolved decision has one unique semantic-keyed row. The Goal describes the requested final repository state without choosing or implying an answer. Do not include provisional boundaries, units, outcomes, Matrix rows, order, classification, Verification Gate, or preferred repair. A blocker is invalid when repository or source evidence already settles every question; the result must be a full contract.

A full contract is valid only when Goal, sources, repository facts, classification, decisions, evidence, boundaries, units, outcomes, Matrix, admissions, exclusions, dependencies, and Gate agree; every added/strengthened obligation has exact authority; every decision reaches an acceptance/evidence target; every outcome has direct evidence; every permanent impact is correctly classified/admitted; every unit is topologically ordered, independently committable, and unchecked; no future command/path/private mechanism/completion result was invented. Any contradiction or unclosed material decision requires a Contract Blocker.
