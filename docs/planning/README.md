# Planning document lifecycle

This page owns how repository research, architecture designs, and Change
Contracts are named, registered as active, and moved to history. It is policy,
not a roadmap or a manually maintained index of active work.

## Routes

| Artifact | Active route | Historical route |
| --- | --- | --- |
| Research | Not applicable | `docs/history/research/YYYY-MM-DD-topic.md` |
| Architecture design | `docs/planning/designs/YYYY-MM-DD-topic.md` | `docs/history/designs/YYYY-MM-DD-topic.md` |
| Change Contract | `docs/planning/plans/YYYY-MM-DD-topic.md` | `docs/history/plans/YYYY-MM-DD-topic.md` |

Research records repository facts and is historical evidence from creation.
Create it directly under `docs/history/research/`; do not promote it through an
active planning directory.

The direct children of `docs/planning/designs/` and `docs/planning/plans/` are
the complete active registrations. Do not add a root roadmap, checkbox mirror,
or separate active-work index.

## Naming

Use `YYYY-MM-DD-topic.md` for every new research, design, and plan. The date is
the artifact's creation date and the topic is a descriptive filename-safe slug.
Do not prefix plans with `step_`, add sequence numbers, or omit the date.

Moving an artifact between active and historical routes never changes its
filename. Rename an invalid legacy filename before treating the artifact as an
active design or plan.

## Lifecycle

1. Create research directly in `docs/history/research/` when current repository
   facts must be captured for later design or planning.
2. Register an architecture design by creating it as a direct child of
   `docs/planning/designs/`. Keep it active while its accepted scope still needs
   a Change Contract or implementation.
3. Register an accepted Change Contract by creating it as a direct child of
   `docs/planning/plans/`. Its declared sources link it to the design and
   research evidence it consumes.
4. After all implementation units, review findings, and required verification
   are closed, move the plan to `docs/history/plans/` with the same filename.
5. Move a linked design to `docs/history/designs/` with the same filename only
   when every in-scope Decision Trace and Change Contract Handoff target is
   covered by completed plans and no direct-child active plan still declares
   the design in its `Source Inputs` `Design` rows. The workflow closing the
   last such plan owns this check and move.

If closure verification requires another implementation change, restore the
plan to its active route before resuming implementation. A design remains
active when another active plan declares it as a design source or its accepted
handoff is not yet fully covered.

## Follow-ups

`docs/planning/FOLLOW_UPS.md` is the single registry for confirmed, durable
work discovered outside an accepted plan. Presence in that registry means the
concern is unresolved; it does not authorize implementation or replace an
active Change Contract.

Add only evidence-backed concerns with a concrete owner or decision needed.
Deduplicate against active plans and existing follow-ups. Remove an entry in
the same change that moves the exact concern into an accepted active plan,
resolves it at its source of truth, or proves it no longer applies. Never reuse
its identifier.

## Authority boundary

Active and historical planning artifacts are inputs to implementation, not
owners of current package behavior. Current architecture, contracts,
verification policy, registries, guardrails, and code retain their existing
owners. Historical documents preserve decisions and evidence at their time of
creation and must not be treated as current authority when those owners differ.
