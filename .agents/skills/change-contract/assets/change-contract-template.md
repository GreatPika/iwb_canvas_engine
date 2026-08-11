# Change Contract

## Goal

{{goal}}

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `{{design_source_id}}` | {{design_location_or_authority}} |
| Research | `{{research_source_id}}` | {{research_location_or_authority}} |
| PLAN | `{{plan_source_id}}` | {{plan_location_or_authority}} |
| Other | `{{other_source_id}}` | {{other_location_or_authority}} |

## Classification

Profile: `{{profile}}`
Obligations: {{obligations}}

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `{{decision_key}}` | {{independent_failure_family}} | {{source_decision}} | {{contract_location}} | `{{decision_target_key}}` |

## Repository Evidence

- `{{evidence_location}}` / {{evidence_surface}}: {{observed_fact}} -> {{contract_consequence}}.

## Boundaries

Owner: {{owner}}
In Scope: {{in_scope}}
Out of Scope: {{out_of_scope}}
Source of Truth: {{source_of_truth}}
Compatibility: {{compatibility}}
Order Constraints: {{order_constraints}}
Temporal Surface Closure: {{temporal_surface_closure}}
All-Or-Nothing Failure Boundary: {{all_or_nothing_failure_boundary}}
Negative Proof And Fixture Quarantine: {{negative_proof_and_fixture_quarantine}}
Bounded Recognition Scope: {{bounded_recognition_scope}}
Work Budget And Cost Displacement: {{work_budget_and_cost_displacement}}

## Execution Units

### [ ] Unit 1: {{imperative_unit_title}}

Owner: {{unit_owner}}
Boundary: {{unit_boundary}}
Verification Profile: `{{unit_profile}}`
Change: {{unit_change}}

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `{{outcome_key}}` | {{starting_state}} | {{system_action}} | {{observable_result}} | {{required_side_conditions}} |

Depends On: None

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `{{verification_key}}` | `{{outcome_key}}` | `{{evidence_class}}` | {{verification_surface}} | {{preimplementation_witness}} | {{pass_signal}} | {{evidence_constraints_and_rejected_proxy}} | {{adversarial_false_positive_case_and_kill_signal}} | `{{durable_impact}}` | {{artifact_target}} | {{admission_reference}} |

## Permanent Artifact Admissions

{{admission_entries_or_none}}

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Finding disposition | {{finding_scope}} | {{finding_evidence}} | {{finding_pass_signal}} |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Active contract and source design | {{lifecycle_evidence}} | {{lifecycle_pass_signal}} |
