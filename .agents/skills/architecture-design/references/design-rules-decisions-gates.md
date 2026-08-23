# Architecture Design Decision And Gate Rules

## 5. Decision Closure And Implementation Freedom

### Decision Records And Trace

Every selected architecture commitment is a `D`. `D.Lock` states the architecture that
the future contract must preserve; `D.Open` states the implementation freedom remaining
inside it. `D.Basis`, `D.Form`, `D.Realizes`, `D.Depends on`, `D.Contract targets`, and
`D.Rationale` form the canonical decision trace:

```text
source or repository fact -> accepted R/E basis -> D -> exact contract target
```

### Architecture Closure

The schema owns allowed concerns, target mappings, reference types, and acyclic
dependency mechanics. Semantically, every applicable concern must be determinate and
owned by a `D`; every `D` must be necessary, evidence-backed, consistent with its
selected `F`, and complete enough for its contract targets. Architecture Closure is the
exact forward and reverse projection of concern-owning decisions, with evidence-backed
non-applicability where allowed.

### Ownership And Boundaries

Behavior, policy, invariant, state, and durable meaning have one owner. The owning
entry/exit boundary owns validation, normalization, compatibility, redaction, and
policy. Cache or performance duplication requires a locked invariant, consumer, and
evidence constraints. Do not patch a caller symptom when a shared owner, invariant,
seam, source of truth, or boundary owns the cause.

### Authorized Organization Constraints

An explicit user decision about implementation organization is a material obligation
when organization is the approved axis and incidental identifiers, cardinality, and
decomposition remain open. It may require table-driven scenarios with shared mechanics
or prohibit independent paths from deciding the same semantic result. It may not infer
exactly one helper, model, function, table, or class, and it is never an oracle.

### Concern Semantics

Compatibility records the public/API/data/configuration posture and any migration
decision. Ordering records safe consumer, publication, mutation, and retirement order.
Policy and dependency concerns remain at their owning boundary and preserve repository
layer/import direction. State and lifecycle concerns name the actual committed,
derived, cached, transient, or mutable owner and lifecycle.

## 6. Gates And Assurance

Gate Closure is a derived view. The schema owns the exact core and conditional rows,
statuses, reference groups, concern mappings, and disposition profiles; semantic review
decides truth and applicability. A gate-name reference alone proves nothing.

Core semantic obligations are:

- `Owner-Level Fix`: repair the owning cause, not a downstream symptom.
- `Ownership`: each behavior, policy, invariant, state, and durable meaning has one
  clear owner.
- `Source-Of-Truth Singularity`: each durable meaning has one owner; intentional
  duplication has its distinct contract and direct verification.
- `Source-Truth Minimality`: no second durable signal merely certifies an already-owned
  value.
- `Boundary-Owned Policy`: boundary policy stays at its owning entry/exit boundary.
- `Dependency Direction`: repository layer and import direction remain valid.
- `Solution Proportionality`: the complete `F/M/R/E` reconstruction in
  `design-rules-basis-candidates.md` passes.
- `Outcome-Proof Fit`: every observable claim has one complete canonical `A`.
- `Verification`: each oracle is direct and its evidence is feasible at the stated
  boundary.
- `Future Pressure`: every known `P` is explicitly treated without self-authorizing
  present scope.
- `Handoff Consumability`: Contract Interface plus `H` let a contract author proceed
  without making architecture.

`Source-Truth Minimality` forbids a second field, registry, allowlist, identity marker,
policy seam, token heuristic, proof-surface name, test name, comment, or copied constant
whose only purpose is certification. Negative proof may reject invalid shape, stale
mirrors, boundary violations, incoherent data, unauthorized consumers, or drift. It may
not reject a different coherent value unless a named owner supplies a closed vocabulary
or immutable allowlist. Fixtures and tests may consume truth but cannot own production
values, schemas, nodes, APIs, generated documentation, or contracts.

### Assurance Records

Use one `A` for each independently observable failure family. `A` owns:

```text
Claim -> Failure -> direct Oracle -> Proxy risk -> Evidence constraints -> Architecture seam
```

`A.Verifies` names only exact schema-valid `R-NNN`, `D-NNN/<concern>`, or `I-NNN`
subjects. Plain `D-NNN` never proves a concern. Every accepted outcome, every
assurance-required observable/lifecycle `D/<concern>`, and every observable durable
`I` transition has exact `A.Verifies` coverage, and each `A` participates in the
appropriate Gate Closure row.

The oracle must observe the claimed outcome. A command, passing test, existing file or
schema, constructed object, fired event, changed issue count, registry entry, or
successful compilation proves only that observation. Reject proxy-only proof unless
the proxy is the claim. Evidence constraints name admissible evidence classes, coverage
boundaries, and proxy risks without selecting non-architectural test implementation.
Name an architecture seam only when the seam itself is an architecture decision.

Do not lock private identifiers, helper calls, selectors, fixture implementation,
regular expressions, AST visitor shape, test layout, copied inventories, or prose
parsing as an oracle unless the mechanism is architectural. Verify an authorized
organization constraint without inspecting incidental private shape.

### Conditional Concern Semantics

When a conditional concern applies, its owning `D` locks the complete semantics below,
an exact `A.Verifies=D-NNN/<concern>` covers its observable failure, and Gate Closure
uses that `D` and `A`. When it does not apply, the view uses an evidence-backed
non-applicable status; bare assertions do not establish non-applicability.

- `negative_proof_fixture`: exact invalid state, owning production boundary, direct
  oracle, evidence constraints, and fixture quarantine. Fixture-only values and
  recognition cannot enter production truth.
- `state_data`: relevant owner and complete lifecycle for committed, derived, cached,
  transient, or mutable state.
- `migration_retirement`: replacement, consumer order, retirement gate, migration
  checks, and negative proof.
- `temporal`: temporal invariant, synchronous callback surfaces, guard owner, public
  observation order, permitted reentrant/interleaved action, and rejection or
  no-mutation signal.
- `atomicity`: irreversible point, all fallible work before it, permitted later work,
  failure projection, direct oracle, and evidence constraints.
- `recognition`: exact invalid state, target artifact, bounded recognizer surface, and
  stop rule. Reject open-ended syntax/JSONPath coverage, token heuristics, a general
  analyzer for behavioral inconvenience, or a feature-local scanner that a stable
  central boundary should own.
