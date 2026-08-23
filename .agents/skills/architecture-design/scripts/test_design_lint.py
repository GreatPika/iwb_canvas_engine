from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import design_lint


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
TEMPLATE = ROOT / "assets" / "design-artifact-template.md"


def fixture(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def messages(text: str, *, template: bool = False) -> list[str]:
    return [
        finding.message for finding in design_lint.lint_text(text, template=template)
    ]


def checkpoint_messages(text: str, checkpoint: str) -> list[str]:
    return [
        finding.message
        for finding in design_lint.lint_checkpoint_text(text, checkpoint=checkpoint)
    ]


V1_ARTIFACT = """---
date: 2026-07-16
commit: abc1234
branch: v1-artifact
disposition: READY_FOR_CONTRACT
product_outcome: >-
  Existing owners publish one current result.
---

# Design: Representative V1 Artifact

## Source Inputs

- Prior Design: none
- Research: none
- PLAN: none
- Other: `AGENTS.md`

## Target Contract Classification

Profile: `REFACTOR`

Obligations: `None`

ADR Impact: none
"""


class DesignLintTest(unittest.TestCase):
    def assert_rejected(self, text: str, *, template: bool = False) -> None:
        self.assertNotEqual(messages(text, template=template), [])

    def mutate(self, text: str, old: str, new: str) -> str:
        self.assertIn(old, text)
        return text.replace(old, new, 1)

    # Permanent-artifact admission: disposition-fixture-integration — all dispositions and a conditional-ready graph must lint against actual repository owners; fixture/vocabulary-drift witnesses protect end-to-end model integration.
    def test_all_disposition_fixtures_pass(self) -> None:
        for name in (
            "ready.md",
            "ready_conditional.md",
            "design_not_required.md",
            "needs_research.md",
            "architecture_gate.md",
        ):
            with self.subTest(name=name):
                self.assertEqual(messages(fixture(name)), [])

    # Permanent-artifact admission: mixed-blocker-disposition — schema/lint own the invariant that one BLOCKED design preserves simultaneous research and user-decision reasons as separate B records; rejection or collapse of the dual-reason witness would lose an independently resolvable stop condition.
    def test_blocked_disposition_accepts_multiple_reason_kinds(self) -> None:
        text = (
            fixture("needs_research.md")
            .replace(
                "- Result: `blocked B-001`",
                "- Result: `blocked B-001, B-002`",
            )
            .replace(
                "- Result basis: B-001, F-001",
                "- Result basis: B-001, B-002, F-001",
            )
        )
        text += """

### B-002 — Product boundary
- Kind: `user_decision`
- Gate: `Candidate Comparison`
- Need: Decide which product boundary the selected form must preserve.
- Blocks because: The viable forms expose different product behavior.
- Resolution requires: An explicit user decision on the required behavior.
- Related: R-001, F-001, F-002, M-001, M-002, P-001
"""

        self.assertEqual(messages(text), [])

    def test_template_passes(self) -> None:
        self.assertEqual(
            messages(TEMPLATE.read_text(encoding="utf-8"), template=True),
            [],
        )

    # Permanent-artifact admission: template-marker-parity — schema and template markers must match exactly by identity and multiplicity; missing/duplicate/unknown/malformed-marker witnesses protect generated artifact completeness.
    def test_template_rejects_one_unknown_marker(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8") + "\n{{UNKNOWN_MARKER}}\n"
        self.assert_rejected(text, template=True)

    def test_template_rejects_one_missing_declared_marker(self) -> None:
        text = self.mutate(
            TEMPLATE.read_text(encoding="utf-8"),
            "{{TITLE}}",
            "Filled title",
        )
        self.assert_rejected(text, template=True)

    def test_template_rejects_one_duplicate_singleton_marker(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8") + "\n{{TITLE}}\n"
        self.assert_rejected(text, template=True)

    def test_malformed_brace_markers_are_rejected(self) -> None:
        cases = (
            (
                "template-empty",
                self.mutate(
                    TEMPLATE.read_text(encoding="utf-8"),
                    "{{TITLE}}",
                    "{{}}",
                ),
                True,
                "{{}}",
            ),
            (
                "active-nested",
                self.mutate(
                    fixture("ready.md"),
                    "Internal organization remains open.",
                    "{{bad{marker}}}",
                ),
                False,
                "{{bad{marker}}}",
            ),
        )
        for name, text, template, marker in cases:
            with self.subTest(name=name):
                self.assertIn(
                    f"malformed fill marker `{marker}`",
                    messages(text, template=template),
                )

    def test_lint_text_accepts_positional_template_argument(self) -> None:
        text = TEMPLATE.read_text(encoding="utf-8")
        self.assertEqual(design_lint.lint_text(text, True), [])

    def test_lint_file_accepts_positional_template_argument(self) -> None:
        self.assertEqual(design_lint.lint_file(TEMPLATE, True), [])

    # Permanent-artifact admission: checkpoint-prefix-validation — a named schema section must validate only a complete, ordered, grammatically valid prefix; omitted suffix, future typed references, and suffix markers must not block incremental authoring while prefix defects remain findings.
    def test_checkpoint_accepts_a_complete_prefix_and_defers_later_content(
        self,
    ) -> None:
        prefix = fixture("ready.md").split("## Impact Register", 1)[0]
        prefix = self.mutate(prefix, "| D-001 |", "| A-001 |")
        text = prefix + "## Impact Register\n\n{{LATER_MARKER}}\n"

        self.assertIn("unresolved fill marker `{{LATER_MARKER}}`", messages(text))
        self.assertIn(
            "required section `Assurance Register` is missing",
            messages(text),
        )

        self.assertEqual(
            checkpoint_messages(text, "Decision Register"),
            [],
        )
        self.assertEqual(
            checkpoint_messages(fixture("needs_research.md"), "Open Blockers"),
            [],
        )
        sections = design_lint.load_schema().raw.get("sections")
        self.assertIsInstance(sections, dict)
        assert isinstance(sections, dict)
        order = sections.get("order")
        self.assertIsInstance(order, list)
        assert isinstance(order, list)
        for checkpoint in order:
            with self.subTest(checkpoint=checkpoint):
                self.assertEqual(
                    checkpoint_messages(fixture("ready.md"), checkpoint),
                    [],
                )

    def test_impact_checkpoint_starts_durable_impact_correspondence_validation(
        self,
    ) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "`classification`, `owner`, `source_of_truth`, `policy`, `dependency`, `unit_family`",
            "`classification`, `owner`, `source_of_truth`, `policy`, `dependency`, `unit_family`, `durable_impact`",
        )

        self.assertEqual(checkpoint_messages(text, "Decision Register"), [])
        sections = design_lint.load_schema().raw.get("sections")
        self.assertIsInstance(sections, dict)
        assert isinstance(sections, dict)
        order = sections.get("order")
        self.assertIsInstance(order, list)
        assert isinstance(order, list)
        for checkpoint in order[order.index("Impact Register") :]:
            with self.subTest(checkpoint=checkpoint):
                self.assertIn(
                    "selected durable_impact decision D-001 requires an Impact Register "
                    "reference",
                    checkpoint_messages(text, checkpoint),
                )

    def test_checkpoint_rejects_unknown_missing_interposed_and_malformed_prefix(
        self,
    ) -> None:
        prefix = fixture("ready.md").split("## Impact Register", 1)[0]
        cases = (
            (
                "unknown",
                prefix,
                "Unknown Register",
                "unknown checkpoint `Unknown Register`",
            ),
            (
                "disallowed",
                fixture("needs_research.md"),
                "Impact Register",
                "checkpoint `Impact Register` is not allowed for BLOCKED",
            ),
            (
                "allowed-but-absent",
                fixture("architecture_gate.md"),
                "Decision Register",
                "required checkpoint prefix section `Decision Register` is missing",
            ),
            (
                "absent-prior-owner-edge",
                fixture("architecture_gate.md").replace(
                    "- Related: R-001, R-002, F-001, F-002, M-001, M-002, P-001, E-001, E-002",
                    "- Related: D-999",
                    1,
                ),
                "Open Blockers",
                "unknown typed reference D-999 from B-001.Related",
            ),
            (
                "terminal-orphan",
                fixture("ready.md").replace(
                    "| P-001 | More consumers may need the current result. | S-002, E-002 | absorbed | D-001 | Synchronous fan-out remains an accepted cost until measured evidence requires another form. |",
                    "| P-001 | More consumers may need the current result. | S-002, E-002 | absorbed | D-001 | Synchronous fan-out remains an accepted cost until measured evidence requires another form. |\n| P-002 | A second consumer may need the current result. | S-002, E-002 | absorbed | D-001 | Synchronous fan-out remains an accepted cost until measured evidence requires another form. |",
                    1,
                ),
                "Open Blockers",
                "orphan record P-002 has no allowed typed consumer",
            ),
            (
                "ready-decision-requirement-carry",
                fixture("ready.md")
                .replace("- Basis: R-001, R-003, E-002", "- Basis: R-001, E-002", 1)
                .replace("- Basis: R-001, R-003, E-002", "- Basis: R-001, E-002", 1),
                "Decision Register",
                "requirement R-003 must reach a selected decision or exact blocker",
            ),
            (
                "assurance-owner",
                fixture("ready.md").replace(
                    "D-001/owner, D-001/source_of_truth",
                    "D-001/compatibility, D-001/source_of_truth",
                    1,
                ),
                "Assurance Register",
                "assurance A-001 references concern compatibility not owned by D-001",
            ),
            (
                "contract-profile",
                fixture("ready.md").replace(
                    "- Profile: `REFACTOR`",
                    "- Profile: `UNKNOWN`",
                    1,
                ),
                "Contract Interface",
                "unknown Contract Interface Profile UNKNOWN",
            ),
            (
                "readiness-owner",
                fixture("ready.md").replace(
                    "| owner | closed | D-001 |",
                    "| owner | closed | D-999 |",
                    1,
                ),
                "Readiness Matrix",
                "Architecture Closure owner references a decision without the matching concern",
            ),
            (
                "missing",
                prefix.replace("## Candidate Analysis", "## Interposed", 1),
                "Decision Register",
                "required checkpoint prefix section `Candidate Analysis` is missing",
            ),
            (
                "interposed",
                prefix.replace(
                    "## Decision Register",
                    "## Extra Register\n\n## Decision Register",
                    1,
                ),
                "Decision Register",
                "unknown section `Extra Register`",
            ),
            (
                "malformed",
                prefix.replace(
                    "- Lock: `ExistingOwner` remains",
                    "{{PREFIX_MARKER}}\n- Lock: `ExistingOwner` remains",
                    1,
                ),
                "Decision Register",
                "unresolved fill marker `{{PREFIX_MARKER}}`",
            ),
            (
                "grammar",
                prefix.replace("- Lock:", "Lock:", 1),
                "Decision Register",
                "free prose is not allowed outside canonical fields or generated views",
            ),
            (
                "future-reference-type",
                prefix.replace("| D-001 |", "| R-001 |", 1),
                "Decision Register",
                "only A, B, D, I references are allowed; found R-001",
            ),
            (
                "resolved-prefix-edge",
                prefix.replace(
                    "- Basis: R-001, R-002, E-001, E-002",
                    "- Basis: R-999, R-002, E-001, E-002",
                    1,
                ),
                "Decision Register",
                "unknown typed reference R-999 from D-001.Basis",
            ),
        )

        for name, text, checkpoint, expected in cases:
            with self.subTest(name=name):
                self.assertIn(expected, checkpoint_messages(text, checkpoint))

    def test_frontmatter_keys_order_and_schema_identity_are_exact(self) -> None:
        valid = fixture("ready.md")
        mutations = (
            self.mutate(valid, "commit: abc1234", "commit: abc1234\nowner: Codex"),
            self.mutate(valid, "date: 2026-08-09\n", ""),
            self.mutate(
                valid,
                "commit: abc1234",
                "commit: abc1234\ncommit: abc1234",
            ),
            self.mutate(
                valid,
                "schema: architecture-design/v4\ndate: 2026-08-09",
                "date: 2026-08-09\nschema: architecture-design/v4",
            ),
            self.mutate(
                valid,
                "schema: architecture-design/v4",
                "schema: architecture-design/v1",
            ),
        )
        for text in mutations:
            with self.subTest(text=text.splitlines()[:3]):
                self.assert_rejected(text)

    def test_frontmatter_date_commit_and_outcome_are_valid(self) -> None:
        valid = fixture("ready.md")
        mutations = (
            self.mutate(valid, "date: 2026-08-09", "date: 2026-02-31"),
            self.mutate(valid, "commit: abc1234", "commit: not-a-commit"),
            self.mutate(valid, "outcome: R-001", "outcome: D-001"),
        )
        for text in mutations:
            with self.subTest(frontmatter=text.split("---", 2)[1]):
                self.assert_rejected(text)

    def test_all_dispositions_require_one_matching_outcome(self) -> None:
        cases = (
            (
                "design-not-required-extra",
                self.mutate(
                    fixture("design_not_required.md"),
                    "| R-002 | repository_rule |",
                    "| R-002 | outcome |",
                ),
                "exactly one outcome requirement is required",
            ),
            (
                "needs-research-zero",
                self.mutate(
                    fixture("needs_research.md"),
                    "| R-001 | outcome |",
                    "| R-001 | constraint |",
                ),
                "exactly one outcome requirement is required",
            ),
            (
                "architecture-gate-mismatch",
                self.mutate(
                    fixture("architecture_gate.md"),
                    "outcome: R-001",
                    "outcome: R-002",
                ),
                "frontmatter outcome must reference the unique outcome requirement",
            ),
        )
        for name, text, expected in cases:
            with self.subTest(name=name):
                self.assertIn(expected, messages(text))

    def test_folded_frontmatter_values_are_rejected(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "date: 2026-08-09",
            "date: >-\n  2026-08-09",
        )
        self.assert_rejected(text)

    def test_section_order_is_exact_and_fence_aware(self) -> None:
        invalid = self.mutate(
            fixture("ready.md"),
            "## Basis",
            "## Decision Register",
        )
        self.assert_rejected(invalid)

        fenced = self.mutate(
            fixture("ready_conditional.md"),
            "sequenceDiagram",
            "sequenceDiagram\n  Note over Repo: ## Open Blockers",
        )
        self.assertEqual(messages(fenced), [])

    def test_sections_are_exact_for_disposition_profile(self) -> None:
        text = self.mutate(
            fixture("needs_research.md"),
            "## Open Blockers",
            "## Impact Register\n\nNone\n\n## Open Blockers",
        )
        self.assert_rejected(text)

    def test_active_design_rejects_template_markers(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "Internal organization remains open.",
            "{{IMPLEMENTATION_FREEDOM}}",
        )
        self.assert_rejected(text)

    def test_forbidden_tokens_are_rejected(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "Publication mechanics remain open.",
            "TODO: choose publication mechanics.",
        )
        self.assert_rejected(text)

    def test_canonical_table_headers_are_exact(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "| ID | Source | Locator | Observed fact |",
            "| ID | Source | Fact |",
        )
        self.assert_rejected(text)

    def test_contract_vocabulary_values_are_complete_and_enforced(self) -> None:
        valid = fixture("ready.md")
        mutations = (
            self.mutate(valid, "- Profile: `REFACTOR`", "- Profile: `UNKNOWN`"),
            self.mutate(
                valid,
                "- Obligations: `None`",
                "- Obligations: `UNKNOWN`",
            ),
            self.mutate(
                valid,
                "- Profile: `REFACTOR`",
                "- Profile: `REFACTOR` trailing",
            ),
        )
        for text in mutations:
            self.assert_rejected(text)

    def test_source_coverage_must_list_every_kind(self) -> None:
        text = self.mutate(fixture("ready.md"), "| other | none |\n", "")
        self.assert_rejected(text)

    def test_source_coverage_must_equal_source_table(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "| repository | S-001, S-002 |",
            "| repository | S-001 |",
        )
        self.assert_rejected(text)

    def test_other_source_kind_is_lossless(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "| other | none |",
            "| other | S-001 |",
        )
        self.assert_rejected(text)

    def test_user_and_other_sources_preserve_provenance(self) -> None:
        user = self.mutate(
            fixture("architecture_gate.md"),
            "| R-001 | outcome | Consumers receive the current result. | S-001, E-001 |",
            "| R-001 | outcome | Consumers receive the current result. | E-001 |",
        )
        self.assert_rejected(user)

        with tempfile.TemporaryDirectory() as directory:
            external = Path(directory) / "external-source.md"
            external.write_text("external evidence\nsecond line\n", encoding="utf-8")
            valid = fixture("ready.md")
            valid = self.mutate(
                valid,
                "| S-002 | repository | "
                "`.agents/skills/architecture-design/references/design-rules.md` "
                "| Current architecture owner and review seam |",
                f"| S-002 | other | `{external}` "
                "| Current architecture owner and review seam |",
            )
            valid = self.mutate(
                valid,
                "| repository | S-001, S-002 |",
                "| repository | S-001 |",
            )
            valid = self.mutate(valid, "| other | none |", "| other | S-002 |")
            self.assertEqual(messages(valid), [])

            invalid = self.mutate(
                valid,
                "| R-001 | outcome | Existing owners publish one current result "
                "that consumers can observe after mutation. | "
                "S-001, E-001, E-002 |",
                "| R-001 | outcome | Existing owners publish one current result "
                "that consumers can observe after mutation. | S-001, E-001 |",
            )
            invalid = self.mutate(
                invalid,
                "| R-003 | exclusion | Product behavior and public result format "
                "do not change. | S-002, E-002 |",
                "| R-003 | exclusion | Product behavior and public result format "
                "do not change. | S-001, E-001 |",
            )
            self.assert_rejected(invalid)

    def test_requirements_are_carried_by_selected_decisions(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "- Basis: R-001, R-002, E-001, E-002",
            "- Basis: R-001, E-001, E-002",
        )
        self.assert_rejected(text)

    def test_exclusion_requires_out_of_scope_decision(self) -> None:
        text = self.mutate(
            fixture("ready.md"),
            "- Concerns: `in_scope`, `out_of_scope`",
            "- Concerns: `in_scope`",
        )
        self.assert_rejected(text)

    def test_readiness_rows_and_statuses_are_exact(self) -> None:
        ready = fixture("ready.md")
        design_not_required = fixture("design_not_required.md")
        mutations = (
            self.mutate(
                ready,
                "| recognition | not_applicable | E-004 |\n",
                "",
            ),
            self.mutate(
                ready,
                "| Ownership | pass | D-001, A-001 |",
                "| Ownership | not_applicable | E-001 |",
            ),
            self.mutate(
                design_not_required,
                "| recognition | not_applicable | E-002 |\n",
                "",
            ),
            self.mutate(
                design_not_required,
                "| Ownership | already_closed | E-001 |",
                "| Ownership | pass | E-001 |",
            ),
            self.mutate(
                design_not_required,
                "| owner | already_closed | E-001 |",
                "| owner | already_closed | S-001 |",
            ),
        )
        for text in mutations:
            with self.subTest(
                disposition=text.split("disposition: ", 1)[1].splitlines()[0]
            ):
                self.assert_rejected(text)

    def test_candidate_result_resolves_to_exact_form_or_blocker(self) -> None:
        ready = self.mutate(
            fixture("ready.md"),
            "- Result: `selected F-001`",
            "- Result: `selected F-999`",
        )
        blocked = self.mutate(
            fixture("needs_research.md"),
            "- Result: `blocked B-001`",
            "- Result: `blocked B-999`",
        )
        self.assert_rejected(ready)
        self.assert_rejected(blocked)

    def test_previous_schema_identities_are_rejected(self) -> None:
        self.assert_rejected(V1_ARTIFACT)
        self.assert_rejected(
            self.mutate(
                fixture("ready.md"),
                "schema: architecture-design/v4",
                "schema: architecture-design/v3",
            )
        )

    def test_ready_only_sections_are_rejected_for_every_non_ready_profile(self) -> None:
        sections = (
            ("Impact Register", "## Impact Register\n\nNone\n\n"),
            (
                "Stop Conditions",
                """## Stop Conditions

### H-001 — Premature stop
- Trigger: A premature stop condition appears.
- Invalidates: R-001
- Resolution requires: Resolve the profile before adding a stop condition.

""",
            ),
            (
                "Contract Interface",
                """## Contract Interface

- Profile: `REFACTOR`
- Obligations: `None`
- ADR Impact: none
- Sources: S-001
- Requirements: R-001
- Commitments: D-001
- Assurance: A-001
- Impacts: none
- Stops: H-001

""",
            ),
        )
        profiles = (
            ("architecture_gate.md", "BLOCKED", "## Open Blockers"),
            ("needs_research.md", "BLOCKED", "## Open Blockers"),
            (
                "design_not_required.md",
                "DESIGN_NOT_REQUIRED",
                "## Readiness Matrix",
            ),
        )
        for name, disposition, anchor in profiles:
            for section_name, section in sections:
                with self.subTest(name=name, section=section_name):
                    findings = messages(
                        self.mutate(fixture(name), anchor, f"{section}{anchor}")
                    )
                    self.assertIn(
                        f"section `{section_name}` is not allowed for {disposition}",
                        findings,
                    )

    def test_old_nested_v2_layout_is_rejected(self) -> None:
        text = (
            fixture("ready.md")
            .replace(
                "## Impact Register\n\nNone\n\n",
                "",
                1,
            )
            .replace(
                """## Stop Conditions

### H-001 — Ownership contradiction
- Trigger: Repository evidence shows another accepted authority or requires a public-format change that conflicts with D-001 or D-003.
- Invalidates: D-001, D-002, D-003, A-001
- Resolution requires: Re-open architecture selection with the conflicting authority or compatibility requirement as canonical evidence.

""",
                "",
                1,
            )
            .replace(
                "- Stops: H-001\n\n",
                """- Stops: H-001

### Durable Impacts

None

### Stop Conditions

#### H-001 — Ownership contradiction
- Trigger: Repository evidence shows another accepted authority or requires a public-format change that conflicts with D-001 or D-003.
- Invalidates: D-001, D-002, D-003, A-001
- Resolution requires: Re-open architecture selection with the conflicting authority or compatibility requirement as canonical evidence.

""",
                1,
            )
        )

        self.assert_rejected(text)


class DesignLintCliTest(unittest.TestCase):
    def run_main(self, arguments: list[str]) -> tuple[int, str]:
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            return design_lint.main(arguments), stderr.getvalue()

    def test_valid_file_returns_zero(self) -> None:
        code, stderr = self.run_main([str(FIXTURES / "ready.md")])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")

    # Permanent-artifact admission: controlled-cli-failure — CLI outcomes are exactly 0 for valid input, 1 for lint findings, and 2 for missing/input/invocation failures without traceback; missing-file, malformed-owner, and lint witnesses preserve automation behavior.
    def test_cli_lint_failure_returns_one(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "v1.md"
            path.write_text(V1_ARTIFACT, encoding="utf-8")
            code, stderr = self.run_main([str(path)])
        self.assertEqual(code, 1)
        self.assertNotEqual(stderr, "")
        self.assertNotIn("Traceback", stderr)

    def test_cli_missing_file_returns_two(self) -> None:
        code, stderr = self.run_main(["missing-design.md"])
        self.assertEqual(code, 2)
        self.assertNotIn("Traceback", stderr)

    def test_cli_invocation_failure_returns_two(self) -> None:
        for arguments in ([], ["one.md", "two.md"]):
            with self.subTest(arguments=arguments):
                code, stderr = self.run_main(arguments)
                self.assertEqual(code, 2)
                self.assertNotIn("Traceback", stderr)

    def test_cli_invalid_schema_failure_is_controlled(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".git").mkdir()
            schema = root / "design-artifact-schema.json"
            schema.write_text('{"version":', encoding="utf-8")
            with mock.patch.object(design_lint, "SCHEMA_PATH", schema):
                code, stderr = self.run_main([str(FIXTURES / "ready.md")])
        self.assertEqual(code, 2)
        self.assertIn("design_lint:", stderr)
        self.assertNotIn("Traceback", stderr)

    def test_cli_template_path_returns_zero(self) -> None:
        code, stderr = self.run_main(["--template", str(TEMPLATE)])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")

    def test_cli_checkpoint_returns_zero_for_a_complete_prefix_and_two_for_ambiguity(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "prefix.md"
            path.write_text(
                fixture("ready.md").split("## Impact Register", 1)[0],
                encoding="utf-8",
            )
            code, stderr = self.run_main(
                ["--checkpoint", "Decision Register", str(path)]
            )
            self.assertEqual(code, 0)
            self.assertEqual(stderr, "")

            code, stderr = self.run_main(
                ["--checkpoint", "Unknown Register", str(path)]
            )
            self.assertEqual(code, 1)
            self.assertIn("unknown checkpoint `Unknown Register`", stderr)

            code, stderr = self.run_main(
                ["--checkpoint", "Decision Register", "--template", str(TEMPLATE)]
            )
        self.assertEqual(code, 2)
        self.assertNotIn("Traceback", stderr)


if __name__ == "__main__":
    unittest.main()
