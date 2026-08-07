# ADR-0012: Route sanitized internal diagnostics through one hub without a public stream

- Status: accepted
- Date: 2026-05-28
- Implementation state: partially implemented
- Source designs:
  - `docs/history/designs/2026-05-25-diagnostics-public-surface-guard.md`
  - `docs/history/designs/2026-05-28-diagnostics-hub-ssot-routing-table.md`
- Current owners:
  - `docs/contracts/diagnostics.md`
  - `docs/contracts/public_api_v1.md`
  - `docs/_registry/public_api_v1.yaml`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Subsystems need a common way to report recoverable internal failures without
leaking sensitive values or turning diagnostics into a public compatibility
surface. Before the routing decision, the internal hub and its public-surface
guard existed, but diagnostic-producing paths did not have one semantic owner
that distinguished hub writes, intentionally pure results, and deferred routes.

Inferring public API membership from names or source layout would be fragile.
Likewise, making tests, diagrams, or registries independently define diagnostic
routing would create competing sources of truth and obscure known routing gaps.

## Decision

Use one internal `DiagnosticsHub` for admitted diagnostic records. The hub
skips record creation when diagnostics are disabled and sanitizes structured
details before retaining an admitted record. It is an internal reliability
mechanism and is not exposed as a public diagnostics stream in the v1 API.

The diagnostics contract is the semantic owner of routing. It distinguishes
paths that write admitted records from paths that intentionally return typed
results without a hub write and from routes whose delivery is not yet
implemented. Public membership is enforced explicitly through the public API
registry rather than inferred from naming or test allowlists. Diagrams and
other views are projections of these owners, not independent routing
authorities.

## Rationale

A single policy boundary makes sanitization and disabled behavior predictable.
Keeping the hub internal avoids promising event ordering or stream behavior as
public compatibility commitments.

Owning routing semantics in the diagnostics contract allows intentional
non-writes and incomplete routes to remain visible instead of being hidden by a
blanket requirement that every reliability result emit a record. Explicit
public registry membership gives the public guard a stable source that survives
ordinary implementation renames.

## Consequences

- Admitted internal records share one sanitization and policy boundary.
- Disabling diagnostics prevents record and detail retention rather than merely
  hiding delivery.
- Pure typed reliability results need not acquire diagnostic side effects.
- Public clients cannot depend on an engine diagnostics stream in API v1.
- The retained decision is only partially implemented until the current
  routing owner closes or deliberately resolves its deferred delivery and
  self-protection gaps.

## Current owners and enforcement

`docs/contracts/diagnostics.md` owns diagnostic semantics, admission, and route
classification. `docs/contracts/public_api_v1.md` owns the public compatibility
promise, while `docs/_registry/public_api_v1.yaml` is the structured membership
source used to enforce that promise.

The implemented policy boundary is in
`lib/src/diagnostics/diagnostics_hub.dart`, with current producers routed from
their owning subsystems. The current diagnostics contract also records deferred
delivery and self-protection work. Those explicit gaps are why the implementation
state remains `partially implemented`; the existing hub and implemented
producers do not establish full routing coverage.

## Source evidence

The 2026-05-25 design selected explicit public-registry membership and an
internal sanitized hub, rejecting naming and test-maintained public allowlists.
The 2026-05-28 design selected the diagnostics contract as the routing source of
truth and made registries and diagrams subordinate projections.

Commit `6d3f2950` on 2026-05-28 recorded the execution Change Contract for that
full routing decision. Commit `23d7c11f` added the canonical routing model and
`c5fa6bc0` closed its documentation step. Earlier commits `59e4ad95`,
`c15300b6`, and `3242c272` had already implemented the hub and public-surface
guard. Current contract and code evidence confirm implemented routing alongside
deferred delivery and self-protection, establishing the header date and
partially implemented state.
