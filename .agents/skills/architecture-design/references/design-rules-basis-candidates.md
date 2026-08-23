# Architecture Design Basis And Candidate Rules

## 3. Sources, Evidence, Requirements, And Authority

### Source Identity And Locators

Read every available source named by the request or artifact and every repository
surface needed to determine current authority. `S` records each input identity and
locator exactly once. `E.Source` points to that `S`; `E.Locator` records only the
location inside the source and must not repeat `S.Locator`.

Use the schema-owned locator forms. Stable text evidence identifies an exact line or
range inside its `S`. A path-only evidence locator is allowed only for a schema-listed
surface exception such as a new path, generated output, command surface, or
configuration surface. The source record still owns the path. Raw search output, long
quotations, research logs, and private reasoning transcripts are not evidence.

### Source Coverage

Preserve all inputs losslessly by source kind. In particular, `other` preserves a
user-supplied or external input that is neither a plan, research, prior design,
repository source, nor the current user request. Every schema source kind appears once
in Source Coverage, whose lists exactly equal the corresponding `S` records. `none`
means no source of that kind was used; it is not evidence.

### Evidence And Requirements

`E` states only a confirmed observed fact. `R` owns the accepted norm or exclusion and
names its `S/E` basis. Research is factual input, never future source of truth. If a
required fact is unavailable, contradicted, stale, or unverifiable, do not infer it:
record an exact `B.Kind=research` and use `BLOCKED`.

### User Decisions And Exclusions

Preserve every accepted upstream decision by meaning unless redesign is authorized.
For each explicit user decision, an `R.Kind=user_decision` states the exact mandatory
material axis and `R.Open shape` states which incidental identifiers, cardinality, and
decomposition remain open. A generic topic or unavailable chat reference is
insufficient. If the user mandates exact incidental shape, preserve it, record the rule
conflict, and use `BLOCKED` with `B.Kind=user_decision` unless redesign is authorized.

Historical, resolved, deferred, and genuinely out-of-scope mentions are not blockers.
Each intentional exclusion is an `R.Kind=exclusion` carried by a selected
`D.Concerns=out_of_scope` and supported by repository evidence or explicit user
authority. Never silently omit or narrow a named source or accepted decision.

### Repository Authority

Authority selection starts with the current owner of every affected durable value and
its direct consumers. A copied inventory, exact-parity validator, test, generated view,
or other mirror is not authority. Intentional duplication is valid only when the design
records its distinct durable concept, owner, lifecycle, consumers, invariant, and
direct verification; otherwise remove the mirror or block for unsafe source of truth.

## 4. Candidate Analysis And Solution Proportionality

### Architecture Forms

An `F` is an architecture form, not a Change Contract profile or execution plan. It may
extend or move responsibility to an existing owner; create, replace, split,
consolidate, or retire a seam; add boundary validation or a port; separate or
consolidate state; remove duplicate truth; add bounded structural enforcement; or
schedule a later durable-source update.

Compare two or three materially different viable forms. Use one form only when evidence
shows every material alternative violates a hard constraint. When comparison is
blocked, preserve the candidate work that is valid before the blockers and resolve the
result to the exact `B` set; never invent ready-shaped decisions. `DESIGN_NOT_REQUIRED`
instead requires evidence that no architecture form needs selection.

### Material Comparison

`F` owns form and principal trade-off. `M` owns every material delta: observable
behavior; state/lifecycle; coordination/order; owner, seam, or abstraction;
compatibility, migration, or retirement; verification seam or failure family; or a
durable artifact. A common mandatory obligation points to its canonical `R`. A
selected-only obligation requires independent `R/E` authority and must be realized by
the selected `D`; a candidate mechanism, `P`, implementation convenience, or
downstream artifact cannot authorize itself.

### Selection And Proportionality

Evaluate in order:

1. Reject forms that violate accepted outcomes, mandatory constraints, repository
   authority, or applicable gates.
2. Compare surviving forms by owner fit, hard constraints, migration cost, evidence
   strength, source-of-truth safety, compatibility, drift risk, and every `M` axis.
3. Use evidence-backed future pressure only as a tie-breaker between forms for which
   neither is strictly simpler.
4. Select the surviving form or record the exact `B` set.

A viable alternative preserves every accepted outcome and mandatory constraint. It is
strictly simpler only when it removes at least one material obligation without adding
another or weakening an accepted norm. Line count, declaration count, precedent,
implementation convenience, ease of testing, speculative flexibility, and
specification completeness do not establish simplicity.

For each obligation unique to the selected form, require independent authority for
that exact axis or a concrete evidence-backed failure that violates an accepted norm,
is prevented by the obligation, and is not prevented by a simpler repair.

- A strictly simpler viable alternative blocks with `DISPROPORTIONATE_SOLUTION`.
- An unsupported organization preference removable without weakening accepted norms
  also blocks with `DISPROPORTIONATE_SOLUTION`; do not manufacture a user decision.
- Incomparable material trade-offs require `BLOCKED` with a `B.Kind=user_decision`;
  reviewer preference cannot resolve them.

There need not be a globally least-complex form. User approval covers only the compared
material axes and deltas. A later material obligation requires a new decision unless an
accepted norm already forces it. A mandatory constraint may justify in-scope work or
block the design, but cannot expand approved scope.

### Future Pressure

Before selection, inspect the request, active plan and plan files, documentation,
historical research, code comments, tests, repository rules, and read-only source-query
output for known pressure. Each `P` records its evidence, treatment (`absorbed`,
`deferred`, or `rejected`), closure references, and accepted cost or migration risk. If
none exists in a profile that permits none, say so and do not claim future-proofing.

A pressure not already accepted as an outcome or mandatory constraint cannot justify a
present obligation. It may only break a proportional tie. Deferred pressure cannot be
silently converted into present scope.
