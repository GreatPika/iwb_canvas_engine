# ADR-0013: Separate semantic documentation, registries, generated projections, graph closure, and external proof

- Status: accepted
- Date: 2026-06-08
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-22-architecture-graph-closure-checker.md`
  - `docs/history/designs/2026-05-22-docs-documentation-portal.md`
  - `docs/history/designs/2026-05-23-public-incremental-smoke-test.md`
  - `docs/history/designs/2026-06-08-legacy-phase-cleanup.md`
- Current owners:
  - `docs/README.md`
  - `docs/architecture/README.md`
  - `docs/architecture/architecture_graph.yaml`
  - `docs/_registry/sections.yaml`
  - `docs/_registry/diagrams.yaml`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Architecture knowledge serves several different jobs: prose explains meaning,
structured sources describe relationships, generated views aid navigation,
graph checks prove expected dependency closure, and external consumers prove
the public package boundary. Treating any one of those artifacts as authority
for every job creates duplication and makes generated or historical material
look current.

Earlier documentation still carried phase and donor navigation after the
maintained package had acquired current architecture and contract owners. The
architecture graph also needed to distinguish expected repository obligations
from analyzer-derived observations without committing a second copy of the
actual graph.

## Decision

Semantic Markdown owns current architectural and contractual meaning.
Structured registries own navigation relationships. Generated indexes and
generated architecture-graph views are disposable projections of structured
and semantic sources. Hand-authored semantic diagrams remain semantic
documentation registered by `docs/_registry/diagrams.yaml`; they are not
generated projections. Generated output does not become a semantic owner.

The checked-in architecture graph owns expected dependency and source-coverage
obligations. Mechanical checks derive actual repository relationships at
verification time and compare them with that expected model; analyzer-derived
actual graphs are not maintained as another durable source.

Public integration proof runs from an external consumer that imports the public
barrel. It verifies package accessibility and compatibility without becoming an
architecture owner. Historical research, designs, plans, phases, and donor
material remain evidence only and are not current navigation or behavior
routes.

## Rationale

Assigning each artifact class one job prevents prose, registries, generated
indexes and graph views, and tests from competing. Hand-authored diagrams retain
their semantic documentation role, while the registry supplies their
relationships and classification. Expected graph obligations are durable
design intent, while actual dependencies are best derived from current code.

External-consumer proof catches boundary failures that an in-package test can
miss, but keeping it as evidence preserves the authority of current
documentation and public contracts. Replacing legacy navigation before
removing it keeps current routes usable throughout migration.

## Consequences

- Current meaning is edited in semantic owners, not in generated projections.
- Navigation metadata and expected dependency obligations remain structured and
  mechanically checkable without duplicating current prose.
- Phase and donor routes do not participate in current documentation or graph
  closure.
- Public compile and smoke proof exercises the supported consumer boundary but
  does not define it.
- A current semantic owner may record a known projection divergence; the
  ownership model does not imply that every generated projection or
  hand-authored semantic diagram is always drift-free.

## Current owners and enforcement

`docs/README.md` owns the current documentation portal and source classes.
`docs/architecture/README.md` owns architecture navigation.
`docs/architecture/architecture_graph.yaml` owns expected graph obligations,
while `docs/_registry/sections.yaml` owns section navigation metadata and
`docs/_registry/diagrams.yaml` registers hand-authored semantic diagrams and
generated graph views with their relationship metadata and classification.

Architecture closure and generated-view checks are implemented through
`tool/architecture_graph/check.dart` and
`tool/architecture_graph/generate_views.dart`. Documentation synchronization
and validation are implemented through `docs/tool/sync_generated_docs.dart` and
`docs/tool/check_docs.dart`. Results from graph and navigation checks, together
with external-consumer proofs, remain verification evidence rather than current
semantic owners; the checked-in graph and registry metadata retain the ownership
assigned above. Known projection drift recorded by a current contract remains
visible until its owning route reconciles it.

## Source evidence

The two 2026-05-22 designs selected an expected-versus-derived architecture
graph and a documentation portal where Markdown owns meaning, registries own
relationships, and generated indexes are projections. The 2026-05-23 design
selected external public-consumer proof. The 2026-06-08 cleanup design retained
those roles while replacing phase and donor routes with current no-phase
ownership before removing the legacy artifacts.

Commit `3016a9b4` on 2026-06-08 recorded the execution Change Contract for the
full current no-phase form. Commits `0f924b39` and `a8f8d277` migrated graph and
navigation ownership, followed by `a4f1f288` and `d657fde1` removing legacy
routes and aligning current documentation. Earlier graph, portal, and external
proof commits establish the retained mechanisms. Together the evidence
establishes the header date and implemented state; the original phase-aware
parameterization is not part of the retained decision.
