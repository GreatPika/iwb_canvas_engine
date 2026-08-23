# Architecture Design Skill Maintenance

Read this file only when changing this skill's resources or active artifact form. It is
not runtime authoring or review guidance.

When changing semantic module contents or boundaries, also read `design-rules.md` and
every affected module. Keep core semantics and routing in `design-rules.md`; keep each
later semantic concern in exactly one additional module.

## Resource Ownership

| Resource | Stable v4 concern | Parent route | Consumers | Update trigger | Verification owner |
| --- | --- | --- | --- | --- | --- |
| `design-artifact-schema.json` | Exact `architecture-design/v4` form, profiles, grammar, mappings, and projections | Architecture Design form | Linter, template, authoring, review | A form, profile, field, reference, mapping, or projection changes | Schema-preflight and design-lint tests |
| `../scripts/design_lint.py` | Mechanical schema/vocabulary/template/artifact validation and controlled CLI | Architecture Design form | Authoring and review modes | Deterministic parsing, validation, diagnostic, or CLI behavior changes | Design-lint tests |
| `../assets/design-artifact-template.md` | Canonical writable v4 skeleton and marker placement | Architecture Design form | Authoring and template lint | Schema-owned section, field, table, record, or marker placement changes | Exact schema/template marker parity and template lint |
| `design-rules.md` | Core semantic rules and mode- and prefix-specific module loading | Architecture Design semantic rules | Authoring and both review modes | A core semantic rule, module boundary, or loading trigger changes | Independent terminal semantic review; whole-skill procedure audit and real use |
| `design-rules-basis-candidates.md` | Source, evidence, requirement, authority, candidate, and proportionality rules | Architecture Design semantic rules | Authoring and both review modes | One of its semantic rules changes | Independent terminal semantic review |
| `design-rules-decisions-gates.md` | Decision closure, implementation freedom, gate, assurance, and conditional-semantics rules | Architecture Design semantic rules | Decision-and-later authoring and both review modes | One of its semantic rules changes | Independent terminal semantic review |
| `design-rules-handoff.md` | Impact, assurance ordering, stop, Contract Interface, and diagram rules | Architecture Design semantic rules | Handoff authoring and both review modes | One of its semantic rules changes | Independent terminal semantic review |
| `design-rules-final-consistency.md` | Whole-artifact semantic reconciliation before a terminal result | Architecture Design semantic rules | Authoring handoff and terminal review modes | One of its semantic rules changes | Independent terminal semantic review |
| `authoring.md` | Write-capable evidence, decision, admission, repair, section-sealing, and reviewer orchestration lifecycle | Create/update/repair workflow | Create/update and repair modes | Intake, brainstorming, authoring order, registration, admission, repair, seal, or reviewer orchestration changes | Whole-skill procedure audit and real use |
| `checkpoint-reviewing.md` | Independent semantic review of one completed schema prefix and its downstream sufficiency | Create/update checkpoint workflow | Sequential checkpoint reviewer sessions | A checkpoint contract, prefix boundary, session lifecycle, finding output, or seal criterion changes | Whole-skill procedure audit and real use |
| `reviewing.md` | Lint-first independent terminal whole-design audit, blocked routes, and exact output | Terminal review workflow | Review-only and terminal repair re-review modes | Full-artifact evidence checks, semantic audit, routes, output, or repair boundary changes | Whole-skill procedure audit and real use |
| `maintenance.md` | Skill-resource ownership, artifact-form maintenance routing, and form-version lifecycle | Architecture Design skill maintenance | Skill maintainers | A resource owner, maintenance route, or form-version lifecycle changes | Repository-knowledge verifier and skill tests |
| `../../change-contract/references/contract-vocabulary.json` | Canonical Profile, Obligations, and no-obligation tokens | Change Contract vocabulary | Contract/design authoring, review, schema, and lint | A canonical contract token is introduced, renamed, or retired | Contract-lint and design-lint integration tests |

## Artifact-Form Version Lifecycle

A form-breaking change cannot silently reuse the current schema identity. It requires
an explicit version decision and a new schema identity. In the same atomic transition,
every then-active design must receive an explicit disposition under that decision—for
example migration to the new sole active form, retirement from active registration, or
another authorized terminal disposition—so no repository state exposes mixed active
formats. This lifecycle rule does not authorize multi-version runtime support.
