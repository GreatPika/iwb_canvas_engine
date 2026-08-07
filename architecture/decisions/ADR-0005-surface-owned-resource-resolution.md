# ADR-0005: Own resource resolution and bounded image caching per active surface session

- Status: accepted
- Date: 2026-06-14
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md`
  - `docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md`
  - `docs/history/designs/2026-06-14-resource-image-cache-memory-accounting.md`
  - `docs/history/research/2026-05-18-resource-resolver-cache-surface-session.md`
  - `docs/history/research/2026-05-28-p7-resource-session-resolver-lifecycle.md`
  - `docs/history/research/2026-06-14-resource-image-cache-memory-accounting.md`
- Current owners:
  - `docs/contracts/resources.md`
  - `docs/contracts/cache_policy.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Saved documents need stable resource descriptors, but decoded images and the
resolver that supplies them belong to application and surface lifecycles. A
runtime-wide cache would outlive or mix surface resolver identities. A
frame-owned or painter-owned cache would give rendering a second resource
policy owner, while relying on a global Flutter cache would not express the
engine's descriptor revisions, dirty operations, resolver replacement, or
application image ownership.

The early implementation snapshot placed cache and resolver policy in the
runtime resource kernel and had no surface session or resolver generation. It
also bounded retained entries without accounting for the very different decoded
memory cost of images.

## Decision

Committed document storage owns resource descriptors only. The resource kernel
owns the non-surface public resource read seam, resource-visual dirty
orchestration, and accepted dirty outcomes.

Each successfully attached active surface owns one resource session implemented
by the resources module. The session owns resolver identity and generation,
resolved-image cache, per-frame resolver budget, same-frame missing-result
suppression, bounded retry signaling, and invalidation. Rejected attachment
creates no session. Resolver replacement, detach, runtime swap, and disposal
invalidate or drop the session through narrow lifecycle seams.

The resolved-image cache is bounded independently by entry count and estimated
decoded image memory. Cache identity includes resolver generation and committed
resource identity/revision. An image too large for retention may satisfy the
current resolve without being cached. Removing cache references never disposes
application-owned images.

Frame planning receives immutable descriptor facts and the active session only
at the asset-binding boundary. Painters never call the application resolver.
Dirty-resource operations publish runtime-owned visual change and invalidate an
attached session when present; the operation remains valid when no surface is
attached.

## Rationale

The active surface is the narrowest lifecycle that matches resolver identity
and image retention. Keeping the concrete session in the resources module
preserves resource policy ownership while surface code controls attachment and
disposal timing. Resolver generation makes replacement explicit instead of
trying to synchronize entries across resolver identities.

Dual capacity limits reflect actual retention pressure better than descriptor
byte length or entry count alone. Preserving application ownership of returned
images avoids hidden disposal and makes cache eviction a reference-lifetime
operation rather than an asset-lifetime decision.

## Consequences

- Runtime and committed storage do not retain live resolver or decoded-image
  truth outside the active session boundary.
- Surface lifecycle changes must install, invalidate, and drop the session in a
  defined order without turning surface into the policy owner.
- Resolver calls remain synchronous, guarded, and bounded; budget and missing
  results have distinct non-cache semantics.
- Dirty-resource publication and cache invalidation remain separate from
  document mutation.
- Memory estimation is cache-local derived policy; descriptor metadata is not
  treated as decoded-memory truth.
- Frame output receives resolved assets or placeholders, not a live resolver.

## Current owners and enforcement

`docs/contracts/resources.md` owns descriptor, resource-kernel, active-session,
resolver, dirty, invalidation, and application-image-lifetime semantics.
`docs/contracts/cache_policy.md` owns the current cache key, capacity, eviction,
and probe policy.

Their registered resource lifecycle, resolver replacement, dirty invalidation,
bounded-cache, reentrancy, painter-isolation, and application-image-lifetime
proof surfaces enforce the decision. This ADR intentionally omits their mutable
numeric limits and detailed cache ledger.

## Source evidence

The early 2026-05-18 research snapshot shows the previous runtime-kernel cache
placement and absence of session generation. The two 2026-05-28 designs selected
the narrow resource read/dirty seam and the per-surface resolver-session
lifecycle; the dirty seam explicitly deferred rather than contradicted the full
session scope. The 2026-06-14 research established the byte-pressure problem,
and the design selected decoded-memory admission alongside entry bounding
without changing application image ownership. Commit
`119462f1` on 2026-06-14 recorded the execution Change Contract adopting that
refinement. Commits `ec68f7eb`, `b2fbb470`, and `342d3fc1` implemented, proved,
and documented it that day, establishing the header date and implemented state.
