# Engineering Change Unit Criteria

## Core definition

An engineering change unit is the smallest dependency-closed change that:

- moves the system from one valid state to another valid state;
- has one dominant engineering intent and one independently assessable result;
- has sufficient falsifying evidence before its behavior becomes authoritative;
- leaves no unmanaged transitional state; and
- fits one focused review.

`Dependency-closed` means the unit contains every producer, consumer, adapter,
implementation, compatibility change, proof, and boundary update required for
its result to work safely after the unit lands. It does not mean that every
related feature concern belongs in the same unit.

## Universal criteria

### 1. One primary change authority

A unit belongs to one primary invariant, architectural decision, state owner,
policy owner, or atomic seam.

The authority is a responsibility for a decision or behavior, not necessarily
one file, class, package, service, or team. A compile-atomic producer/consumer
seam may span several modules when neither side can be changed safely on its
own.

Split the unit when its parts have independent reasons to change, different
authorities, or different failure owners. Do not combine store, edit, runtime,
delivery, and documentation merely because they contribute to the same broad
feature.

### 2. One independently assessable result

The result of a unit must be expressible in one sentence.

A conjunction is only a prompt to inspect the boundary. Split the result when
its clauses can be independently:

- enabled or released;
- verified;
- reverted;
- replaced; or
- associated with different failure families.

Keep clauses together when compile safety, compatibility, atomicity, or a
single invariant makes them one inseparable state transition.

### 3. Complete dependency closure and a valid intermediate state

After every unit:

- the repository compiles;
- relevant tests and required checks pass;
- required compatibility is preserved;
- the system remains usable for its users and developers; and
- no mandatory branch is left half-migrated.

The unit must include all implementations of a changed interface, required
test doubles, the first required consumer, and boundary validation when those
changes are necessary for the result to be valid.

### 4. Evidence exists before new authority

New behavior must not become authoritative before evidence exists that can
falsify its important claims.

Prefer the nearest stable owner proof in the same unit. Valid evidence may also
be:

- an existing test that is demonstrably sensitive to the changed behavior;
- a characterization test admitted before a refactor or migration;
- a compile-time, schema, or static-analysis guarantee;
- an executable work counter or budget probe; or
- a genuine cross-owner scenario.

A new test is not required merely to create a new artifact. Existing evidence
counts only when it would fail for the relevant regression. Correct execution
alone does not justify a permanent test, scanner, fixture, or registry entry.

### 5. One authoritative truth and a controlled migration

For a concrete state, decision, or request condition, there must be one
authoritative source of truth.

Temporary coexistence of implementations is permitted only when all of the
following are explicit:

- one router or authority chooses the implementation;
- the applicable version, condition, cohort, or lifecycle phase is unambiguous;
- duplicated mutable state and uncontrolled bidirectional synchronization are
  absent;
- observation, failure handling, and rollback are defined;
- the transition has a bounded lifetime; and
- a verifiable retirement condition and retirement owner exist.

A read-only shadow used for bounded comparison may be valid when it cannot
become authoritative or produce side effects. Indefinite flags, equal competing
truths, permanent old/new paths, and synchronization glue without a justified
invariant are prohibited.

For a local in-process refactor, the default is one production path after each
unit. Multi-version coexistence is an exception for real compatibility,
deployment, schema, or externally versioned boundaries, not a convenience for
avoiding an atomic cutover.

### 6. Bounded cognitive review cost

A reviewer must be able to understand the unit in one focused review session
and explain:

- why the change is needed;
- which authority or invariant changes;
- where the main logic lives;
- which important failure modes are covered;
- how the result is verified; and
- how it can be reverted or retired.

A unit should contain one main algorithm or one migration switch. File count,
line count, and elapsed review time are useful proxies but are not universal
engineering laws. Semantic fan-out, number of authorities, independent failure
families, and unfamiliar control flow contribute directly to review cost.

Deletion, generated output, trusted mechanical rewrites, and mechanical test
tables must be reported separately from authored semantic changes. They may
have a larger line count, but they still require review of their generation or
transformation guarantee.

### 7. Preparatory units provide present value

A preparatory refactor, interface, helper, compatibility seam, test-only
change, or verification capability is a valid unit only when it independently:

- simplifies or makes the current production path safer;
- establishes a compatibility boundary that is already used or required by an
  independently deployable consumer;
- establishes a falsifying characterization baseline; or
- creates a reusable verification capability for a distinct failure family.

Unused infrastructure and speculative scaffolding are not valid units. A named
future consumer alone is insufficient when the repository receives no present
value and no real compatibility boundary requires the split.

When an atomic cutover is too large, first reduce coupling through small,
immediately useful changes to the current owners. The final cutover should be
mostly wiring and lifetime change, not the first appearance of a complex
algorithm or policy.

### 8. A separate verification unit requires an independent reason

Nearest owner evidence belongs with the owner change.

A separate verification-only unit is justified when it owns an independently
valuable proof concern, such as:

- a cross-owner invariant;
- direct/callback/promotion parity;
- a complete temporal delivery order;
- an independent performance or resource-work failure family;
- a pre-change characterization baseline; or
- a reusable integration harness whose scope cannot fit a single owner unit.

A terminal collection of tests that merely catches up with earlier behavior is
not a valid unit. A shared fixture does not make unrelated failure families one
proof concern.

### 9. Retirement occurs at the first safe point

For a local atomic replacement, remove the old path in the same unit when doing
so preserves reviewability and the replacement proof is present.

Use a separate retirement unit or contract phase when a compatibility window,
external clients, deployed versions, schema evolution, or a large mechanical
deletion requires separation. In that case:

- replacement is already authoritative and proven;
- the retirement condition has been met;
- removed code is unreachable or belongs only to the completed compatibility
  phase;
- proof, documentation, and registry credit are transferred to the replacement
  owner; and
- no new behavior appears in retirement.

Retirement must not become a terminal mixed-owner cleanup backlog.

### 10. Knowledge closes with its authority

When an architectural, behavioral, operational, or compatibility truth changes,
update its authoritative representation with the owning change. This may be:

- code, type, schema, or configuration;
- a behavioral or API contract;
- data-model or architecture documentation;
- an operational runbook;
- a verification registry; or
- an Architecture Decision Record.

Artifact and file count do not determine whether documentation is a valid unit.
A one-file ADR or one-file correction to an authoritative runbook may be a
complete result. Documentation that merely duplicates a more reliable source
of truth is not admitted.

Documentation is grouped by the truth it owns, for example data-model truth,
edit/runtime contract truth, or ADR and lifecycle closure. It is not divided or
combined merely by Markdown filename.

### 11. Unit and contract counts follow the dependency graph

Derive units from the smallest closed subgraphs of the implementation
dependency graph:

- do not cut compile, invariant, compatibility, or atomicity dependencies;
- do not merge independent authorities or failure families;
- do not choose a desired number and reshape the work to reach it; and
- treat both megacommands and meaningless fragments as decomposition failures.

Contracts group dependency-ordered units that produce one coherent
contract-level outcome. Contract size is a process limit applied after unit
boundaries are derived, not a reason to enlarge or fragment units.

## Repository contract-authoring profile

The following limits exist to preserve the quality and coherence of authored
Change Contracts. They are repository process constraints, not universal
architecture laws:

- Prefer at most 8 units in one Change Contract.
- Units 9 through 11 are permitted only when the contract still has one
  coherent outcome and splitting the contract would obscure or duplicate a
  real dependency boundary.
- 11 units is the hard maximum for one Change Contract.
- If the natural dependency graph yields more than 11 units, split the work
  into multiple ordered contracts.
- Never satisfy the maximum by merging independent results into oversized
  units.
- Never satisfy the preferred count by inventing helper-only, documentation
  fragment, deferred-test, or cleanup-tail units.
- There is no minimum number of units for a valid contract.

The target and hard maximum constrain contract authoring quality. They do not
override the rule that unit count must first follow engineering boundaries.

## Review-size calibration

The repository does not currently have a validated hard threshold for:

- production file count;
- meaningful production lines;
- total authored diff; or
- elapsed review time.

Previously discussed bands of 1–3 production files, 250–350 meaningful
production lines, roughly 600 total lines, and 20–30 minutes are unvalidated
local hypotheses. They must not be presented as established repository rules
or used to force mechanical decomposition.

Until local review data supports calibrated thresholds, use these review
prompts:

- Is there one dominant authority and one main algorithm or switch?
- Can a reviewer reconstruct intent, invariants, failure modes, evidence, and
  rollback in one focused session?
- Is semantic fan-out bounded even if a compile-atomic seam touches several
  files?
- Are independent failure families split or explicitly justified?
- Are generated, mechanical, and deletion churn reported separately?
- Would making the unit smaller require an invalid half-cutover or dead
  scaffolding?
- Would making it larger merge independently reversible results?

Calibrate future numeric thresholds from repository evidence such as actual
review duration, defect discovery, rework, follow-up fixes, semantic owner
count, and authored diff. Historical oversized changes can falsify an overly
permissive limit, but they cannot by themselves prove an optimal threshold.

## Migration profiles

### Local in-repository replacement

- Prefer one production path after every unit.
- Make preparatory owners useful on the current path.
- Switch an atomic behavior once.
- Include owner evidence with the switch.
- Remove the replaced path in the same unit when reviewable, otherwise in the
  immediately following deletion-only unit.

### Versioned API, schema, or deployment migration

- An expand/migrate/contract sequence may be necessary.
- Each phase must be independently compatible and deployable.
- One authority must select behavior for each version, cohort, or lifecycle
  condition.
- Duplicated mutable state requires an explicit invariant, direction of
  authority, reconciliation rule, observability, and bounded lifetime.
- Retirement occurs as soon as the compatibility condition is satisfied.

### Generated, mechanical, and deletion-heavy changes

- Review the generator, transformation, or deletion proof rather than treating
  raw line count as semantic complexity.
- Keep mechanical changes separate from behavioral changes when their mixture
  would hide authored intent.
- Do not use mechanical volume to conceal unrelated semantic edits.

## Unit admission checklist

Before admitting a unit into a Change Contract, record clear answers to all of
the following:

1. What single sentence describes the completed result?
2. Which invariant, decision, state owner, or atomic seam is authoritative?
3. Which dependencies must land together for the repository to remain valid?
4. What evidence would fail if the result were incorrect?
5. Does that evidence exist before the result becomes authoritative?
6. What old path, mirror, or compatibility state is replaced, and when can it
   be removed?
7. Is any temporary coexistence controlled by one authority with a bounded
   retirement condition?
8. Can the unit be reviewed in one focused session with one main algorithm or
   switch?
9. Does every preparatory artifact provide present value or a necessary
   compatibility boundary?
10. Which authoritative knowledge source changes with the result?
11. Can any part be independently enabled, verified, reverted, or retired? If
    so, why is it not a separate unit?
12. Would any further split break a real dependency, or would any merge combine
    independent authorities or failure families?

A unit is not admitted when any required answer is missing or relies only on a
future test, future consumer, future cleanup, or unspecified migration state.
