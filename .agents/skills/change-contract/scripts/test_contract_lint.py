from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import contract_lint


VALID_CONTRACT = """# Change Contract

## Goal

Consolidate one workflow without changing accepted behavioral guarantees.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `accepted-design` | docs/planning/designs/accepted.md |
| Research | none | none |
| PLAN | none | none |
| Other | `repository-instructions` | AGENTS.md |
| Other | `user-request` | user request |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `COMMAND_REFERENCE_MIGRATION`, `WORK_BUDGET_CLOSURE`

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `one-canonical-route` | retired workflow routes remain discoverable | Retire duplicate routes atomically | Boundaries / Order Constraints | `legacy-route-is-retired` |

## Repository Evidence

- `AGENTS.md:58` / mandatory workflow route: the old route is current -> migrate the canonical owner atomically.

## Boundaries

Owner: Change Contract workflow
In Scope: Unified authoring and review route
Out of Scope: Historical references
Source of Truth: Shared contract rulebook
Compatibility: Old public skill names are retired without shims
Order Constraints: Add the replacement and migrate consumers before deletion
Temporal Surface Closure: Not applicable: no runtime callback surface changes
All-Or-Nothing Failure Boundary: Route migration and legacy deletion land together
Negative Proof And Fixture Quarantine: Current-source absence queries exclude history
Bounded Recognition Scope: Exact current skill names and normalized field labels only
Work Budget And Cost Displacement: Construction and migration may inspect current routes once; route lookup never shifts a whole-route scan into another query or publication phase.

## Execution Units

### [ ] Unit 1: Consolidate the contract workflow

Owner: Change Contract workflow
Boundary: Authoring, review, and deterministic validation
Verification Profile: `BEHAVIOR_CHANGE`
Change: Replace duplicate semantic owners with one mode-driven package

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `legacy-route-is-retired` | Duplicate skill routes exist | The route migration completes | Current discovery exposes only `$change-contract` | Historical evidence remains unchanged |

Depends On: None

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `canonical-route-evidence` | `legacy-route-is-retired` | `SOURCE_QUERY` | Current non-historical workflow routes | Current routes contain both retired names | No current route contains either retired name | Query excludes history; a green linter alone is insufficient | A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |

## Permanent Artifact Admissions

None

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Finding disposition | All discovered findings | Apply `AGENTS.md#Verification` | No finding exists only in chat |
| Canonical route integrity | Current repository routes | Repository-local source query excluding history | No retired route remains current |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Temporary design and plan | Registered artifact lifecycle state | No temporary artifact remains active |
"""

VALID_BLOCKER = """# Contract Blocker

## Goal

Consolidate the contract workflow without inventing public error behavior.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `accepted-design` | docs/planning/designs/accepted.md |
| Research | `current-facts` | docs/history/research/current-facts.md |
| PLAN | none | none |
| Other | `repository-instructions` | AGENTS.md |

## Blocking Decisions

| Decision ID | Blocking decision | Blocks because | Needed evidence or authority |
| --- | --- | --- | --- |
| `public-error-protocol` | Select one public error protocol for the data-core seam. | The design permits return or throw while current research requires a typed non-throwing result. | Product or architecture authority selecting the public protocol and compatibility rule. |
| `legacy-compatibility` | Select the compatibility policy for existing callers. | Current callers depend on incompatible public behavior. | Product authority selecting the migration rule. |

## Repository Evidence

- `lib/data/core.dart:40` / public operation: the current seam throws -> implementation cannot infer a typed-result migration without authority.
"""


def messages(text: str) -> list[str]:
    return [finding.message for finding in contract_lint.lint_text(text)]


def assert_invalid(test: unittest.TestCase, text: str) -> None:
    test.assertTrue(messages(text), "mutation unexpectedly passed lint")


def with_second_unit(
    *, unit_number: int = 2, dependency: str = "- Unit 1 — produces: canonical route; consumed as: documented route"
) -> str:
    unit = f"""### [ ] Unit {unit_number}: Document the canonical route

Owner: Repository workflow documentation
Boundary: Current route documentation
Verification Profile: `DOCUMENTATION`
Change: Update the current route documentation

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `canonical-route-is-documented` | Current documentation names old routes | Documentation is updated | Current documentation names the canonical route | Historical evidence remains unchanged |

Depends On:
{dependency}

"""
    matrix_row = "| `canonical-route-doc-evidence` | `canonical-route-is-documented` | `SOURCE_QUERY` | Current documentation | Old route names are present | Only the canonical route is present | History is excluded from the query | A retired route remains in current documentation; the bounded query must report it. | `UPDATE_EXISTING` | `AGENTS.md` | None |"
    text = VALID_CONTRACT.replace("## Verification Matrix", unit + "## Verification Matrix")
    return text.replace(
        "| `canonical-route-evidence` | `legacy-route-is-retired` | `SOURCE_QUERY` | Current non-historical workflow routes | Current routes contain both retired names | No current route contains either retired name | Query excludes history; a green linter alone is insufficient | A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |",
        "| `canonical-route-evidence` | `legacy-route-is-retired` | `SOURCE_QUERY` | Current non-historical workflow routes | Current routes contain both retired names | No current route contains either retired name | Query excludes history; a green linter alone is insufficient | A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |\n"
        + matrix_row,
    )


def with_admission(
    *,
    impact: str = "ADD",
    matrix_outcome: str = "legacy-route-is-retired",
    admission_covers: str = "legacy-route-is-retired",
    matrix_artifact: str = "test/change_contract_route_test.dart",
    admission_artifact: str = "test/change_contract_route_test.dart",
    admission_key: str = "canonical-route-admission",
) -> str:
    text = VALID_CONTRACT.replace(
        "`UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |",
        f"`{impact}` | {matrix_artifact} | `{admission_key}` |",
    ).replace(
        "| `canonical-route-evidence` | `legacy-route-is-retired` |",
        f"| `canonical-route-evidence` | `{matrix_outcome}` |",
    )
    entry = f"""### `{admission_key}`: Canonical route regression protection

Covers: `{admission_covers}`
Impact: `{impact}`
Failure family: current route discovery exposes a retired skill
Failure mode or stable invariant: current discovery exposes only the canonical route
Verification owner: repository workflow route suite
Current verification gap: no owning check rejects retired route names
Failing witness: current discovery exposes both retired routes
Durable and refactor-stable value: protects the public workflow route across internal refactors
Artifact target: {admission_artifact}
"""
    return text.replace("## Permanent Artifact Admissions\n\nNone", f"## Permanent Artifact Admissions\n\n{entry}")


class ContractSchemaTest(unittest.TestCase):
    def test_source_inputs_use_identity_and_location_only(self) -> None:
        self.assertEqual(
            contract_lint.CONTRACT_SCHEMA.table_columns["Source Inputs"],
            ("Category", "Source ID", "Location or authority"),
        )

    def test_loader_reads_schema_and_vocabulary_route(self) -> None:
        schema = contract_lint.load_contract_schema(contract_lint.SCHEMA_PATH)
        self.assertEqual(schema.version, 2)
        self.assertEqual(schema.vocabulary_path, "contract-vocabulary.json")
        self.assertIn("Verification Matrix", schema.table_columns)
        self.assertEqual(
            schema.table_columns["Decision Trace"],
            (
                "Decision ID",
                "Independent failure family",
                "Source decision",
                "Contract location",
                "Acceptance or evidence target",
            ),
        )
        self.assertIn(
            "Adversarial false-positive case and kill signal",
            schema.table_columns["Verification Matrix"],
        )
        self.assertIn("Work Budget And Cost Displacement", schema.boundary_fields)

    def test_loader_rejects_unknown_schema_key(self) -> None:
        data = json.loads(contract_lint.SCHEMA_PATH.read_text())
        data["unexpected"] = True
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "schema.json"
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                contract_lint.load_contract_schema(path)

    def test_loader_rejects_invalid_template_marker(self) -> None:
        data = json.loads(contract_lint.SCHEMA_PATH.read_text())
        data["template_markers"] = ["not-a-marker"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "schema.json"
            path.write_text(json.dumps(data))
            (Path(directory) / "contract-vocabulary.json").write_text(
                contract_lint.VOCABULARY_PATH.read_text()
            )
            with self.assertRaises(ValueError):
                contract_lint.load_contract_schema(path)

    def test_vocabulary_loader_remains_public(self) -> None:
        payload = {
            "profiles": ["CUSTOM_PROFILE"],
            "obligations": ["CUSTOM_OBLIGATION"],
            "no_obligation": "Nothing",
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "vocabulary.json"
            path.write_text(json.dumps(payload))
            vocabulary = contract_lint.load_contract_vocabulary(path)
        self.assertEqual(vocabulary.profiles, frozenset({"CUSTOM_PROFILE"}))
        self.assertEqual(vocabulary.obligations, frozenset({"CUSTOM_OBLIGATION"}))

    def test_vocabulary_declares_work_budget_closure(self) -> None:
        self.assertIn("WORK_BUDGET_CLOSURE", contract_lint.CONTRACT_VOCABULARY.obligations)


class SchemaV2RequiredSlotsTest(unittest.TestCase):
    def test_v2_required_slots_reject_missing_reordered_or_empty_values(self) -> None:
        decision_header = (
            "| Decision ID | Independent failure family | Source decision | Contract location | "
            "Acceptance or evidence target |"
        )
        matrix_header = (
            "| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | "
            "Pass signal | Evidence constraints and rejected proxy | "
            "Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |"
        )
        work_budget = (
            "Work Budget And Cost Displacement: Construction and migration may inspect current routes once; "
            "route lookup never shifts a whole-route scan into another query or publication phase."
        )
        mutations = (
            VALID_CONTRACT.replace(" | Independent failure family", "", 1),
            VALID_CONTRACT.replace(
                decision_header,
                "| Independent failure family | Decision ID | Source decision | Contract location | "
                "Acceptance or evidence target |",
                1,
            ),
            VALID_CONTRACT.replace("| `one-canonical-route` | retired workflow routes remain discoverable |", "| `one-canonical-route` |  |", 1),
            VALID_CONTRACT.replace(" | Adversarial false-positive case and kill signal", "", 1),
            VALID_CONTRACT.replace(
                matrix_header,
                "| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | "
                "Pass signal | Adversarial false-positive case and kill signal | "
                "Evidence constraints and rejected proxy | Durable impact | Artifact target | Admission |",
                1,
            ),
            VALID_CONTRACT.replace(
                "| A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `UPDATE_EXISTING` |",
                "|  | `UPDATE_EXISTING` |",
                1,
            ),
            VALID_CONTRACT.replace(work_budget + "\n", "", 1),
            VALID_CONTRACT.replace(
                "Bounded Recognition Scope: Exact current skill names and normalized field labels only\n" + work_budget,
                work_budget + "\nBounded Recognition Scope: Exact current skill names and normalized field labels only",
                1,
            ),
            VALID_CONTRACT.replace(work_budget, "Work Budget And Cost Displacement:", 1),
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                assert_invalid(self, mutation)

    def test_v1_form_rejection_suppresses_dependent_semantic_findings(self) -> None:
        v1_contract = (
            VALID_CONTRACT.replace(
                ", `WORK_BUDGET_CLOSURE`",
                "",
                1,
            )
            .replace(
                "| Decision ID | Independent failure family | Source decision | Contract location | "
                "Acceptance or evidence target |",
                "| Decision ID | Source decision | Contract location | Acceptance or evidence target |",
                1,
            )
            .replace("| --- | --- | --- | --- | --- |", "| --- | --- | --- | --- |", 1)
            .replace(
                "| `one-canonical-route` | retired workflow routes remain discoverable | "
                "Retire duplicate routes atomically | Boundaries / Order Constraints | "
                "`legacy-route-is-retired` |",
                "| `one-canonical-route` | Retire duplicate routes atomically | "
                "Boundaries / Order Constraints | `legacy-route-is-retired` |",
                1,
            )
            .replace(
                "Work Budget And Cost Displacement: Construction and migration may inspect current routes once; "
                "route lookup never shifts a whole-route scan into another query or publication phase.\n",
                "",
                1,
            )
            .replace(
                "| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | "
                "Pass signal | Evidence constraints and rejected proxy | "
                "Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |",
                "| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | "
                "Pass signal | Evidence constraints and rejected proxy | Durable impact | Artifact target | Admission |",
                1,
            )
            .replace("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |", 1)
            .replace(
                "| Query excludes history; a green linter alone is insufficient | "
                "A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | "
                "`UPDATE_EXISTING` |",
                "| Query excludes history; a green linter alone is insufficient | `UPDATE_EXISTING` |",
                1,
            )
        )

        findings = messages(v1_contract)

        self.assertTrue(findings)
        self.assertFalse(any("outcome `" in finding for finding in findings))
        self.assertFalse(any("admission `" in finding for finding in findings))

    def test_malformed_outcome_table_suppresses_matrix_coverage_findings(self) -> None:
        row = (
            "| `legacy-route-is-retired` | Duplicate skill routes exist | The route migration completes | "
            "Current discovery exposes only `$change-contract` | Historical evidence remains unchanged |"
        )
        malformed = VALID_CONTRACT.replace(
            row,
            "| `legacy-route-is-retired` | Duplicate skill routes exist | The route migration completes | "
            "Current discovery exposes only `$change-contract` |",
            1,
        )

        findings = messages(malformed)

        self.assertTrue(findings)
        self.assertFalse(any("covers unknown outcome" in finding for finding in findings))


class ValidArtifactTest(unittest.TestCase):
    def test_complete_contract_is_valid(self) -> None:
        self.assertEqual(contract_lint.lint_text(VALID_CONTRACT), [])

    def test_real_template_is_valid_in_template_mode(self) -> None:
        template = Path(__file__).resolve().parents[1] / "assets" / "change-contract-template.md"
        template_text = template.read_text(encoding="utf-8")
        self.assertEqual(
            set(re.findall(contract_lint.CONTRACT_SCHEMA.template_marker_pattern, template_text)),
            set(contract_lint.CONTRACT_SCHEMA.template_markers),
        )
        self.assertEqual(contract_lint.lint_text(template_text, template=True), [])
        self.assertEqual(contract_lint.lint_file(template, template=True), [])
        self.assertIn(
            "unknown fill marker `{{UNKNOWN}}`",
            [
                finding.message
                for finding in contract_lint.lint_text(
                    template_text.replace("{{goal}}", "{{UNKNOWN}}", 1),
                    template=True,
                )
            ],
        )
        self.assertIn(
            "unrendered template marker `{{goal}}`",
            [finding.message for finding in contract_lint.lint_text(template_text)],
        )

        script = Path(__file__).with_name("contract_lint.py")
        result = subprocess.run(
            [sys.executable, str(script), "--template", str(template)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "contract_lint: PASS\n")
        for command in (
            [sys.executable, str(script)],
            [sys.executable, str(script), str(template), "--template", str(template)],
        ):
            with self.subTest(command=command):
                self.assertEqual(subprocess.run(command, capture_output=True, text=True).returncode, 2)

    def test_template_mode_allows_marker_admission_for_concrete_add(self) -> None:
        template = Path(__file__).resolve().parents[1] / "assets" / "change-contract-template.md"
        template_text = template.read_text(encoding="utf-8")
        self.assertEqual(
            contract_lint.lint_text(
                template_text.replace("`{{durable_impact}}`", "`ADD`", 1),
                template=True,
            ),
            [],
        )

    def test_template_mode_rejects_malformed_markers(self) -> None:
        template = Path(__file__).resolve().parents[1] / "assets" / "change-contract-template.md"
        template_text = template.read_text(encoding="utf-8")
        for marker in ("{{}}", "{{bad{marker}}}"):
            with self.subTest(marker=marker):
                self.assertIn(
                    f"unknown fill marker `{marker}`",
                    [
                        finding.message
                        for finding in contract_lint.lint_text(
                            template_text.replace("{{goal}}", marker, 1),
                            template=True,
                        )
                    ],
                )

    def test_complete_blocker_is_valid(self) -> None:
        self.assertEqual(contract_lint.lint_text(VALID_BLOCKER), [])

    def test_admitted_add_is_valid(self) -> None:
        self.assertEqual(contract_lint.lint_text(with_admission()), [])


class ArtifactShapeMutationTest(unittest.TestCase):
    def test_structural_headings_inside_fenced_code_are_ignored(self) -> None:
        mutation = VALID_CONTRACT.replace(
            "Consolidate one workflow without changing accepted behavioral guarantees.",
            """Consolidate one workflow without changing accepted behavioral guarantees.

```text
# captured output
## captured section
Owner: captured field
```
""",
            1,
        )

        self.assertEqual(contract_lint.lint_text(mutation), [])

    def test_required_field_present_only_inside_fenced_code_is_missing(self) -> None:
        source_table = VALID_CONTRACT.split("## Source Inputs\n\n", 1)[1].split("\n## Classification", 1)[0]
        mutation = VALID_CONTRACT.replace(source_table, f"```text\n{source_table}```", 1)

        self.assertIn("Source Inputs is missing its table or data rows", messages(mutation))

    def test_wrong_and_duplicate_h1_are_rejected(self) -> None:
        for mutation in (
            VALID_CONTRACT.replace("# Change Contract", "# Plan Contract", 1),
            "# Change Contract\n\n" + VALID_CONTRACT,
        ):
            with self.subTest(mutation=mutation[:40]):
                assert_invalid(self, mutation)

    def test_section_order_presence_uniqueness_and_vocabulary_are_exact(self) -> None:
        mutations = (
            VALID_CONTRACT.replace("## Goal", "## Unexpected", 1),
            VALID_CONTRACT.replace("## Goal\n\nConsolidate one workflow without changing accepted behavioral guarantees.\n\n", "", 1),
            VALID_CONTRACT.replace("## Source Inputs", "## Goal\n\nAnother goal.\n\n## Source Inputs", 1),
            VALID_CONTRACT.replace("## Goal", "## TEMP", 1).replace("## Source Inputs", "## Goal", 1).replace("## TEMP", "## Source Inputs", 1),
        )
        for mutation in mutations:
            with self.subTest():
                assert_invalid(self, mutation)

    def test_field_order_presence_uniqueness_and_vocabulary_are_exact(self) -> None:
        mutations = (
            VALID_CONTRACT.replace("Owner: Change Contract workflow\nIn Scope:", "In Scope:", 1),
            VALID_CONTRACT.replace("Owner: Change Contract workflow", "Owner: Change Contract workflow\nOwner: Duplicate", 1),
            VALID_CONTRACT.replace("Owner: Change Contract workflow", "Unexpected: Change Contract workflow", 1),
            VALID_CONTRACT.replace("Owner: Change Contract workflow\nBoundary:", "Boundary:", 1),
        )
        for mutation in mutations:
            with self.subTest():
                assert_invalid(self, mutation)

    def test_table_columns_are_exact(self) -> None:
        assert_invalid(
            self,
            VALID_CONTRACT.replace(
                "| Decision ID | Independent failure family | Source decision |",
                "| Source decision | Independent failure family | Decision ID |",
                1,
            ),
        )
        assert_invalid(self, VALID_CONTRACT.replace("| Outcome key | Starting state |", "| Outcome key | Unknown |", 1))
        for replacement in (
            "| Category | Source name | Location or authority |",
            "| Source ID | Category | Location or authority |",
            "| Category | Source ID | Location or authority | Extra |",
        ):
            with self.subTest(replacement=replacement):
                mutation = VALID_CONTRACT.replace(
                    "| Category | Source ID | Location or authority |",
                    replacement,
                    1,
                )
                self.assertTrue(any("Source Inputs" in message for message in messages(mutation)))

    def test_escaped_pipe_inside_table_cell_is_not_a_delimiter(self) -> None:
        mutation = VALID_CONTRACT.replace(
            "Retire duplicate routes atomically",
            r"Retire duplicate routes atomically \| without splitting the cell",
            1,
        )

        self.assertEqual(contract_lint.lint_text(mutation), [])

    def test_disconnected_pipe_row_does_not_complete_a_table(self) -> None:
        row = "| `one-canonical-route` | retired workflow routes remain discoverable | Retire duplicate routes atomically | Boundaries / Order Constraints | `legacy-route-is-retired` |"
        mutation = VALID_CONTRACT.replace(
            row,
            "Captured output follows.\n\n" + row,
            1,
        )

        self.assertIn(
            "Decision Trace has no complete data rows",
            messages(mutation),
        )

    def test_classification_uses_known_profile_and_material_obligations(self) -> None:
        mutations = (
            VALID_CONTRACT.replace("`BEHAVIOR_CHANGE`", "`UNKNOWN`", 1),
            VALID_CONTRACT.replace("`SEAM_MIGRATION`", "`UNKNOWN`", 1),
            VALID_CONTRACT.replace("`SEAM_MIGRATION`, ", "`None`, ", 1),
            VALID_CONTRACT.replace("`SEAM_MIGRATION`, ", "`SEAM_MIGRATION`, `SEAM_MIGRATION`, ", 1),
        )
        for mutation in mutations:
            assert_invalid(self, mutation)

    def test_blocker_sections_and_fields_are_exact(self) -> None:
        assert_invalid(self, VALID_BLOCKER.replace("## Blocking Decisions", "## Decisions", 1))
        assert_invalid(self, VALID_BLOCKER.replace("`public-error-protocol`", "", 1))
        assert_invalid(self, VALID_BLOCKER.replace("| Decision ID |", "| Unknown |", 1))


class UnitAndReferenceMutationTest(unittest.TestCase):
    def test_second_unit_fixture_is_valid(self) -> None:
        self.assertEqual(contract_lint.lint_text(with_second_unit()), [])

    def test_checked_skipped_and_duplicate_units_are_rejected(self) -> None:
        assert_invalid(self, VALID_CONTRACT.replace("### [ ] Unit 1", "### [x] Unit 1", 1))
        assert_invalid(self, with_second_unit(unit_number=3))
        self.assertIn(
            "unit numbers must be unique and contiguous from 1; found [1, 1]",
            messages(with_second_unit(unit_number=1, dependency="None")),
        )

    def test_unknown_and_non_topological_dependencies_are_rejected(self) -> None:
        assert_invalid(self, with_second_unit(dependency="- Unit 9 — produces: route; consumed as: documentation"))
        assert_invalid(self, with_second_unit(dependency="- Unit 2 — produces: route; consumed as: documentation"))
        assert_invalid(self, with_second_unit(dependency="Unit 1"))

    def test_dependency_descriptions_require_non_whitespace_text(self) -> None:
        dependency = "- Unit 1 — produces:   ; consumed as: documented route"
        self.assertIn(
            "Unit 2 dependency descriptions must contain non-whitespace text",
            messages(with_second_unit(dependency=dependency)),
        )

    def test_invalid_and_duplicate_semantic_keys_are_rejected(self) -> None:
        assert_invalid(self, VALID_CONTRACT.replace("`one-canonical-route`", "`Invalid_Key`", 1))
        outcome_row = "| `legacy-route-is-retired` | Duplicate skill routes exist | The route migration completes | Current discovery exposes only `$change-contract` | Historical evidence remains unchanged |"
        duplicate_outcome = VALID_CONTRACT.replace(outcome_row, f"{outcome_row}\n{outcome_row}", 1)
        self.assertIn("duplicate outcome key `legacy-route-is-retired`", messages(duplicate_outcome))
        evidence_row = "| `canonical-route-evidence` | `legacy-route-is-retired` | `SOURCE_QUERY` | Current non-historical workflow routes | Current routes contain both retired names | No current route contains either retired name | Query excludes history; a green linter alone is insufficient | A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |"
        duplicate_evidence = VALID_CONTRACT.replace(evidence_row, f"{evidence_row}\n{evidence_row}", 1)
        self.assertIn("duplicate evidence key `canonical-route-evidence`", messages(duplicate_evidence))
        admitted = with_admission()
        entry = admitted.split("### `canonical-route-admission`", 1)[1].split("## Verification Gate", 1)[0]
        assert_invalid(self, admitted.replace("## Verification Gate", "### `canonical-route-admission`" + entry + "## Verification Gate", 1))

    def test_unknown_references_and_uncovered_outcomes_are_rejected(self) -> None:
        assert_invalid(self, VALID_CONTRACT.replace("| `canonical-route-evidence` | `legacy-route-is-retired` |", "| `canonical-route-evidence` | `unknown-outcome` |", 1))
        assert_invalid(self, VALID_CONTRACT.replace("`legacy-route-is-retired` | Duplicate skill routes exist", "`uncovered-outcome` | Duplicate skill routes exist", 1))
        assert_invalid(self, with_admission(admission_covers="unknown-outcome"))
        assert_invalid(self, with_admission().replace("| `canonical-route-evidence`", "| `orphan-evidence` | `unknown-outcome` | `SOURCE_QUERY` | Current routes | Old | New | Direct | A stale alias remains discoverable; the route query must report it. | `UPDATE_EXISTING` | `AGENTS.md` | None |\n| `canonical-route-evidence`", 1))


class AdmissionAndImpactMutationTest(unittest.TestCase):
    def test_add_and_extend_coverage_require_admissions(self) -> None:
        for impact in ("ADD", "EXTEND_COVERAGE"):
            mutation = VALID_CONTRACT.replace(
                "`UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |",
                f"`{impact}` | test/route_test.dart | None |",
                1,
            )
            assert_invalid(self, mutation)

    def test_orphan_admission_is_rejected(self) -> None:
        orphan = """### `orphan-route-admission`: Orphan route regression protection

Covers: `legacy-route-is-retired`
Impact: `ADD`
Failure family: current route discovery exposes a retired alias
Failure mode or stable invariant: current discovery excludes retired aliases
Verification owner: repository workflow route suite
Current verification gap: no owning check rejects one retired alias
Failing witness: current discovery exposes the retired alias
Durable and refactor-stable value: protects the public route across internal refactors
Artifact target: test/change_contract_route_test.dart

"""
        mutation = with_admission().replace(
            "## Verification Gate",
            orphan + "## Verification Gate",
            1,
        )

        self.assertEqual(
            messages(mutation),
            [
                "admission `orphan-route-admission` is not referenced by ADD or EXTEND_COVERAGE evidence",
                "admission `orphan-route-admission` outcome `legacy-route-is-retired` has no matching matrix row",
            ],
        )

    def test_admission_and_matrix_outcome_relationship_is_bidirectional(self) -> None:
        second_outcome = "| `route-alias-is-absent` | A retired alias exists | Migration completes | The alias is absent | History is unchanged |\n"
        acceptance_row = "| `legacy-route-is-retired` | Duplicate skill routes exist | The route migration completes | Current discovery exposes only `$change-contract` | Historical evidence remains unchanged |\n"
        base = with_admission().replace(
            acceptance_row,
            acceptance_row + second_outcome,
            1,
        )

        matrix_row = "| `canonical-route-evidence` | `legacy-route-is-retired` | `SOURCE_QUERY` | Current non-historical workflow routes | Current routes contain both retired names | No current route contains either retired name | Query excludes history; a green linter alone is insufficient | A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `ADD` | test/change_contract_route_test.dart | `canonical-route-admission` |\n"
        update_row = "| `alias-evidence` | `route-alias-is-absent` | `SOURCE_QUERY` | Current routes | Alias exists | Alias absent | History excluded | A retired alias remains discoverable; the route query must report it. | `UPDATE_EXISTING` | `AGENTS.md` | None |\n"
        admission_covers_extra_outcome = base.replace(
            matrix_row,
            matrix_row + update_row,
            1,
        ).replace(
            "Covers: `legacy-route-is-retired`",
            "Covers: `legacy-route-is-retired`, `route-alias-is-absent`",
            1,
        )
        self.assertEqual(
            messages(admission_covers_extra_outcome),
            [
                "admission `canonical-route-admission` outcome `route-alias-is-absent` has no matching matrix row",
            ],
        )

        two_rows = base.replace(
            matrix_row,
            matrix_row + "| `alias-evidence` | `route-alias-is-absent` | `SOURCE_QUERY` | Current routes | Alias exists | Alias absent | History excluded | A retired alias remains discoverable; the route query must report it. | `ADD` | test/change_contract_route_test.dart | `canonical-route-admission` |\n",
            1,
        )
        self.assertEqual(
            messages(two_rows),
            [
                "admission `canonical-route-admission` does not cover evidence `alias-evidence` outcome `route-alias-is-absent`",
            ],
        )

    def test_admission_impact_and_artifact_match_referenced_rows(self) -> None:
        assert_invalid(self, with_admission(impact="ADD").replace("Impact: `ADD`", "Impact: `EXTEND_COVERAGE`", 1))
        assert_invalid(self, with_admission(admission_artifact="test/other_test.dart"))

    def test_every_non_none_row_has_artifact_target(self) -> None:
        assert_invalid(self, VALID_CONTRACT.replace("`UPDATE_EXISTING` | `AGENTS.md` and current skill consumers |", "`UPDATE_EXISTING` | None |", 1))

    def test_none_rows_have_no_artifact_or_admission(self) -> None:
        none_row = VALID_CONTRACT.replace(
            "`UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |",
            "`NONE` | `AGENTS.md` | None |",
            1,
        )
        assert_invalid(self, none_row)
        none_admission = VALID_CONTRACT.replace(
            "`UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |",
            "`NONE` | None | `none-admission` |",
            1,
        )
        self.assertEqual(
            messages(none_admission),
            ["Verification Matrix row 1 NONE impact requires Admission None"],
        )

    def test_one_outcome_cannot_mix_none_and_non_none_rows(self) -> None:
        matrix_row = "| `canonical-route-evidence` | `legacy-route-is-retired` | `SOURCE_QUERY` | Current non-historical workflow routes | Current routes contain both retired names | No current route contains either retired name | Query excludes history; a green linter alone is insufficient | A retired route remains discoverable through a compatibility alias; the bounded route query must report the alias. | `UPDATE_EXISTING` | `AGENTS.md` and current skill consumers | None |"
        extra_row = "| `unchanged-route-evidence` | `legacy-route-is-retired` | `MANUAL_INSPECTION` | Current route | Old routes exist | Reviewer sees only canonical route | Inspection is direct | A retired alias remains; bounded inspection must report it. | `NONE` | None | None |"
        mixed_impacts = VALID_CONTRACT.replace(matrix_row, f"{matrix_row}\n{extra_row}", 1)
        self.assertEqual(
            messages(mixed_impacts),
            ["outcome `legacy-route-is-retired` mixes NONE and non-NONE durable impacts"],
        )

    def test_admissions_none_is_incompatible_with_add_or_extend(self) -> None:
        assert_invalid(self, VALID_CONTRACT.replace("`UPDATE_EXISTING`", "`ADD`", 1))


class PlaceholderAndGateMutationTest(unittest.TestCase):
    def test_active_mode_ignores_non_template_marker_literals(self) -> None:
        literal_text = VALID_CONTRACT.replace(
            "Consolidate one workflow without changing accepted behavioral guarantees.",
            "Consolidate one workflow without changing accepted behavioral guarantees {{UPPERCASE_LITERAL}}.",
            1,
        )
        self.assertNotIn(
            "unrendered template marker `{{UPPERCASE_LITERAL}}`",
            messages(literal_text),
        )

    def test_template_and_legacy_markers_are_rejected(self) -> None:
        for marker in ("{{goal}}", "TODO", "TBD"):
            assert_invalid(self, VALID_CONTRACT.replace("Consolidate one workflow", marker, 1))

    def test_required_gate_rows_are_present_once(self) -> None:
        for check in ("Finding disposition", "Diff hygiene", "Lifecycle closure", "Canonical route integrity"):
            row = next(line for line in VALID_CONTRACT.splitlines() if line.startswith(f"| {check} |"))
            assert_invalid(self, VALID_CONTRACT.replace(row + "\n", "", 1))
            assert_invalid(self, VALID_CONTRACT.replace(row, row + "\n" + row, 1))

    def test_obligation_specific_gate_is_not_required_without_obligation(self) -> None:
        text = VALID_CONTRACT.replace(
            ", `COMMAND_REFERENCE_MIGRATION`", "", 1
        )
        row = next(line for line in text.splitlines() if line.startswith("| Canonical route integrity |"))
        self.assertEqual(contract_lint.lint_text(text.replace(row + "\n", "", 1)), [])

    def test_semantic_phrase_and_command_prefix_checks_are_absent(self) -> None:
        text = VALID_CONTRACT.replace(
            "The route migration completes",
            "`dart test test/owner_test.dart` runs and works correctly",
            1,
        ).replace(
            "Query excludes history; a green linter alone is insufficient",
            "Then tests pass",
            1,
        )
        self.assertEqual(contract_lint.lint_text(text), [])


class DeterministicFormGapRegressionTest(unittest.TestCase):
    def test_source_input_table_supports_repeated_paths_and_user_request(self) -> None:
        self.assertEqual(contract_lint.lint_text(VALID_CONTRACT), [])
        source_rows = (
            ("| Research | none | none |", "| PLAN | none | none |"),
            ("`repository-instructions`", "`accepted-design`"),
            ("| PLAN | none | none |", "| PLAN | none | docs/plan.md |"),
            ("| Other | `user-request` | user request |", "| Other | `user-request` | none |"),
        )
        for old, new in source_rows:
            with self.subTest(old=old, new=new):
                self.assertTrue(
                    any("Source Inputs" in message for message in messages(VALID_CONTRACT.replace(old, new, 1))),
                )
        mixed_plan_sources = VALID_CONTRACT.replace(
            "| PLAN | none | none |",
            "| PLAN | none | none |\n"
            "| PLAN | `plan-source` | docs/plan.md |",
            1,
        )
        self.assertIn(
            "Source Inputs Category `PLAN` cannot mix `none` with concrete sources",
            messages(mixed_plan_sources),
        )

    def test_source_input_authority_rejects_noncanonical_values(self) -> None:
        for authority in (
            "inline-" + "base" + "64:SGVsbG8=",
            "../outside.md",
            "docs//plan.md",
            "arbitrary authority",
        ):
            with self.subTest(authority=authority):
                mutation = VALID_CONTRACT.replace(
                    "docs/planning/designs/accepted.md",
                    authority,
                    1,
                )
                self.assertIn(
                    "Source Inputs row 1 has an invalid Location or authority",
                    messages(mutation),
                )

    def test_source_input_authority_accepts_absolute_external_path(self) -> None:
        mutation = VALID_CONTRACT.replace(
            "docs/planning/designs/accepted.md",
            "/external/designs/accepted.md",
            1,
        )
        self.assertEqual(contract_lint.lint_text(mutation), [])

    def test_goal_is_exactly_one_non_empty_paragraph(self) -> None:
        for text in (VALID_CONTRACT, VALID_BLOCKER):
            goal = text.split("## Goal\n\n", 1)[1].split("\n## Source Inputs", 1)[0]
            for replacement in ("", goal + "\n\nA second paragraph."):
                with self.subTest(heading=text.splitlines()[0], replacement=replacement):
                    self.assertIn(
                        "Goal must contain exactly one non-empty paragraph",
                        messages(text.replace(goal, replacement, 1)),
                    )

    def test_blocking_decisions_are_repeatable_keyed_rows(self) -> None:
        self.assertEqual(contract_lint.lint_text(VALID_BLOCKER), [])
        for replacement in (
            "|  | Select one public error protocol for the data-core seam. | The design permits return or throw while current research requires a typed non-throwing result. | Product or architecture authority selecting the public protocol and compatibility rule. |",
            "| `public-error-protocol` | Select a second public error protocol. | Current callers depend on incompatible public behavior. | Product authority selecting the migration rule. |",
        ):
            with self.subTest(replacement=replacement):
                mutation = VALID_BLOCKER.replace(
                    "| `legacy-compatibility` | Select the compatibility policy for existing callers. | Current callers depend on incompatible public behavior. | Product authority selecting the migration rule. |",
                    replacement,
                    1,
                )
                self.assertTrue(any("Blocking Decisions" in message for message in messages(mutation)))

    def test_blocker_rejects_provisional_plan_headings(self) -> None:
        for mutation in (
            VALID_BLOCKER + "\n## Execution Units\n",
            VALID_BLOCKER + "\n### [ ] Unit 1: Select a protocol\n",
            VALID_BLOCKER + "\n### [x] Unit 1: Select a protocol\n",
        ):
            with self.subTest(mutation=mutation):
                self.assertIn("Contract Blocker contains provisional implementation content", messages(mutation))

    def test_repository_evidence_rows_are_structured(self) -> None:
        row = "- `AGENTS.md:58` / mandatory workflow route: the old route is current -> migrate the canonical owner atomically."
        for replacement in (
            "- AGENTS.md:58 / mandatory workflow route: the old route is current -> migrate the canonical owner atomically.",
            "- `AGENTS.md:58` mandatory workflow route: the old route is current -> migrate the canonical owner atomically.",
            "- `AGENTS.md:58` / mandatory workflow route: the old route is current.",
        ):
            with self.subTest(replacement=replacement):
                self.assertIn("Repository Evidence row 1 is malformed", messages(VALID_CONTRACT.replace(row, replacement, 1)))

    def test_schema_owned_tables_reject_surrounding_prose(self) -> None:
        for section in (
            "Source Inputs",
            "Decision Trace",
            "Acceptance Outcomes",
            "Verification Matrix",
            "Verification Gate",
        ):
            marker = f"## {section}\n\n" if section != "Acceptance Outcomes" else "Acceptance Outcomes:\n\n"
            start = VALID_CONTRACT.index(marker) + len(marker)
            end_marker = "\nDepends On:" if section == "Acceptance Outcomes" else "\n## "
            next_marker = VALID_CONTRACT.find(end_marker, start)
            end = len(VALID_CONTRACT) if next_marker == -1 else next_marker
            table = VALID_CONTRACT[start:end]
            mutation = (
                VALID_CONTRACT[:start]
                + "Unexpected leading prose.\n\n"
                + table
                + "\nUnexpected trailing prose.\n"
                + VALID_CONTRACT[end:]
            )
            with self.subTest(section=section):
                self.assertIn(f"{section} must contain only its table", messages(mutation))
            for fenced_content in (
                "```\nUnexpected fenced leading content.\n```\n\n" + table,
                table + "\n```\nUnexpected fenced trailing content.\n```\n",
            ):
                mutation = VALID_CONTRACT[:start] + fenced_content + VALID_CONTRACT[end:]
                with self.subTest(section=section, fenced_content=fenced_content):
                    self.assertIn(f"{section} must contain only its table", messages(mutation))
        marker = "## Blocking Decisions\n\n"
        start = VALID_BLOCKER.index(marker) + len(marker)
        end = VALID_BLOCKER.index("\n## ", start)
        mutation = (
            VALID_BLOCKER[:start]
            + "Unexpected leading prose.\n\n"
            + VALID_BLOCKER[start:end]
            + "\nUnexpected trailing prose.\n"
            + VALID_BLOCKER[end:]
        )
        self.assertIn("Blocking Decisions must contain only its table", messages(mutation))
        for fenced_content in (
            "```\nUnexpected fenced leading content.\n```\n\n" + VALID_BLOCKER[start:end],
            VALID_BLOCKER[start:end] + "\n```\nUnexpected fenced trailing content.\n```\n",
        ):
            mutation = VALID_BLOCKER[:start] + fenced_content + VALID_BLOCKER[end:]
            with self.subTest(fenced_content=fenced_content):
                self.assertIn("Blocking Decisions must contain only its table", messages(mutation))

    def test_diff_hygiene_requires_exact_command(self) -> None:
        mutation = VALID_CONTRACT.replace("`git diff --check`", "none", 1)
        self.assertIn("Verification Gate Diff hygiene must use exact `git diff --check`", messages(mutation))

    def test_every_referenced_admission_covers_every_row_outcome(self) -> None:
        outcome = "| `route-alias-is-absent` | A retired alias exists | Migration completes | The alias is absent | History is unchanged |\n"
        acceptance_row = "| `legacy-route-is-retired` | Duplicate skill routes exist | The route migration completes | Current discovery exposes only `$change-contract` | Historical evidence remains unchanged |\n"
        alias_admission = """### `alias-admission`: Alias admission

Covers: `legacy-route-is-retired`, `route-alias-is-absent`
Impact: `ADD`
Failure family: retired aliases are discoverable
Failure mode or stable invariant: retired aliases are absent
Verification owner: repository workflow route suite
Current verification gap: no owning check rejects retired aliases
Failing witness: retired aliases are currently discoverable
Durable and refactor-stable value: route absence survives internal refactors
Artifact target: test/change_contract_route_test.dart

"""
        mutation = with_admission().replace(acceptance_row, acceptance_row + outcome, 1)
        mutation = mutation.replace(
            "| `canonical-route-evidence` | `legacy-route-is-retired` |",
            "| `canonical-route-evidence` | `legacy-route-is-retired`, `route-alias-is-absent` |",
            1,
        ).replace("## Verification Gate", alias_admission + "## Verification Gate", 1)
        mutation = mutation.replace("`canonical-route-admission` |", "`canonical-route-admission`, `alias-admission` |", 1)
        self.assertIn(
            "admission `canonical-route-admission` does not cover evidence `canonical-route-evidence` outcome `route-alias-is-absent`",
            messages(mutation),
        )

    def test_cli_stdin_matches_file(self) -> None:
        script = Path(__file__).with_name("contract_lint.py")
        invalid_contract = VALID_CONTRACT.replace(
            "| PLAN | none | none |",
            "| PLAN | none | docs/plan.md |",
            1,
        )
        for text in (VALID_CONTRACT, invalid_contract):
            with self.subTest(invalid=text == invalid_contract), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "contract.md"
                path.write_text(text)
                file_result = subprocess.run([sys.executable, str(script), str(path)], capture_output=True, text=True)
                stdin_result = subprocess.run([sys.executable, str(script), "-"], input=text, capture_output=True, text=True)
                self.assertEqual(stdin_result.returncode, file_result.returncode)
                self.assertEqual(stdin_result.stdout, file_result.stdout)
                self.assertEqual(stdin_result.stderr, file_result.stderr)


if __name__ == "__main__":
    unittest.main()
