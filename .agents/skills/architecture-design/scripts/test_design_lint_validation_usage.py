from __future__ import annotations

import unittest
from dataclasses import replace

import design_lint_validation_graph as _graph
import design_lint_validation_test_support as _support

_record = _graph._record


class ValidationUsageTest(_support.ValidationTestCase):
    # Permanent-artifact admission: graph-identity-and-usage — canonical IDs are globally unique and records require parsed semantic consumers; duplicate and lexical-self-use witnesses preserve causal graph integrity.
    def test_orphan_evidence_ignores_lexical_and_self_reference(self) -> None:
        graph = self.minimal_ready_graph().add_record(
            "Basis",
            _record(
                "E-099",
                "E",
                {
                    "Source": "S-005",
                    "Locator": "`line 2`",
                    "Observed fact": (
                        "E-099 mentions E-099 but no typed consumer uses it."
                    ),
                },
                22,
            ),
        )
        evidence = graph.parsed.tables["Evidence"]
        graph = graph.replace_table(
            "Evidence",
            replace(
                evidence,
                rows=(
                    *evidence.rows,
                    (
                        "E-099",
                        "S-005",
                        "`line 2`",
                        "E-099 mentions E-099 but no typed consumer uses it.",
                    ),
                ),
                row_lines=(*evidence.row_lines, 22),
            ),
        )

        messages = self.validate(graph)

        self.assertIn("orphan record E-099 has no allowed typed consumer", messages)

    def test_wrong_field_and_unknown_references_are_rejected(self) -> None:
        baseline = self.minimal_ready_graph()
        wrong_type = baseline.replace_record("D-001", Basis="A-001")
        unknown = baseline.replace_record("D-001", Basis="R-999")

        self.assertIn(
            "D-001.Basis accepts only R/E references",
            self.validate(wrong_type),
        )
        self.assertIn(
            "unknown typed reference R-999 from D-001.Basis",
            self.validate(unknown),
        )

    def test_projection_only_records_are_orphans_for_every_causal_kind(self) -> None:
        for kind in ("S", "R", "D", "A", "I", "H"):
            identifier = f"{kind}-099"
            with self.subTest(kind=kind):
                self.assertIn(
                    f"orphan record {identifier} has no allowed typed consumer",
                    self.validate(self.graph_with_projection_only_orphan(kind)),
                )

    # Permanent-artifact admission: repository-locators — source paths have one S owner and E adds only exact in-source locations or bounded exceptions; repeated-path witnesses prevent locator mirrors.
    def test_source_locators_are_kind_exact_and_accessible(self) -> None:
        baseline = self.minimal_ready_graph()
        cases = (
            (
                baseline.replace_record("S-005", Locator="`../source.md`"),
                "S-005.Locator must be a repository-relative accessible file",
            ),
            (
                baseline.replace_record("S-005", Locator="`missing.md`"),
                "S-005.Locator must be a repository-relative accessible file",
            ),
            (
                baseline.replace_record("S-006", Locator="`other.md`"),
                "S-006.Locator must be an absolute accessible external file",
            ),
            (
                baseline.replace_record("S-004", Locator="`user request`"),
                "S-004.Locator must equal literal user request",
            ),
        )

        for graph, expected in cases:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))

    def test_evidence_locator_line_and_range_are_bounded_by_source(self) -> None:
        baseline = self.minimal_ready_graph()
        valid_range = baseline.replace_record("E-001", Locator="`lines 1-3`")
        cases = (
            ("`line 0`", "E-001.Locator is not an allowed line, range, or surface"),
            ("`lines 3-2`", "E-001.Locator range must not be reversed"),
            ("`line 4`", "E-001.Locator exceeds source line count 3"),
            (
                "`arbitrary location`",
                "E-001.Locator is not an allowed line, range, or surface",
            ),
            ("`source.md:1`", "E-001.Locator must not repeat source path"),
        )

        self.assertNotIn("E-001.Locator", self.validate(valid_range))
        for locator, expected in cases:
            with self.subTest(locator=locator):
                self.assertIn(
                    expected,
                    self.validate(baseline.replace_record("E-001", Locator=locator)),
                )

    def test_evidence_surface_exception_is_schema_owned_and_kind_compatible(
        self,
    ) -> None:
        baseline = self.minimal_ready_graph()
        compatible = baseline.replace_record(
            "E-001",
            Locator="`command_surface`",
        )
        incompatible = baseline.replace_record(
            "E-002",
            Locator="`command_surface`",
        )

        self.assertNotIn("E-001.Locator", self.validate(compatible))
        self.assertIn(
            "E-002.Locator surface exception is incompatible with source kind other",
            self.validate(incompatible),
        )

    # Permanent-artifact admission: blocker-profiles — blocking profiles resolve to exact meaningful blockers and only valid partial closure; wrong-B and invented-gate witnesses preserve stop semantics.
    def test_early_blocking_profiles_accept_no_readiness_matrix(self) -> None:
        for blocker_kind in ("research", "user_decision"):
            with self.subTest(blocker_kind=blocker_kind):
                messages = self.validate(self.minimal_blocking_graph(blocker_kind))
                self.assertEqual(messages, "")

    def test_blocking_result_identity_and_kind_vocabulary_are_exact(self) -> None:
        baseline = self.minimal_blocking_graph("research")
        wrong_result = baseline.replace_record(
            "CANDIDATE",
            Result="`blocked B-002`",
        )
        wrong_kind = baseline.replace_record("B-001", Kind="unsupported")

        self.assertIn(
            "Candidate Result must reference exact blocker set B-001",
            self.validate(wrong_result),
        )
        self.assertIn(
            "BLOCKED blocker B-001 has unsupported kind unsupported",
            self.validate(wrong_kind),
        )

    def test_partial_readiness_matrix_matches_exact_blocker_prefix(self) -> None:
        baseline = self.minimal_blocking_graph(
            "user_decision",
            with_matrix=True,
        )
        self.assertEqual(self.validate(baseline), "")

        wrong_blocker = baseline.replace_table_row(
            "Gate Closure",
            "Verification",
            ("Verification", "failed", "B-002"),
        )
        gates = baseline.parsed.tables["Gate Closure"]
        invented_later = baseline.replace_table(
            "Gate Closure",
            replace(
                gates,
                rows=(
                    *gates.rows,
                    ("Future Pressure", "pass", "P-001, E-001"),
                ),
                row_lines=(*gates.row_lines, 140),
            ),
        )
        no_failure = baseline.replace_table_row(
            "Gate Closure",
            "Verification",
            ("Verification", "pass", "A-001"),
        )

        self.assertIn(
            "partial Gate Closure failure must reference exact blocker set B-001",
            self.validate(wrong_blocker),
        )
        self.assertIn(
            "partial Gate Closure must stop at blocker gate Verification",
            self.validate(invented_later),
        )
        self.assertIn(
            "partial Gate Closure requires exactly one failed or unresolved row",
            self.validate(no_failure),
        )

    def test_partial_architecture_rows_keep_evaluated_semantics(self) -> None:
        baseline = self.minimal_blocking_graph(
            "user_decision",
            with_matrix=True,
        )
        invalid_status = baseline.replace_table_row(
            "Architecture Closure",
            "owner",
            ("owner", "already_closed", "D-002"),
        )
        missing_owner_support = baseline.replace_table_row(
            "Architecture Closure",
            "owner",
            ("owner", "closed", "R-002"),
        )

        self.assertIn(
            "Architecture Closure owner has invalid ready status already_closed",
            self.validate(invalid_status),
        )
        self.assertIn(
            "decision D-002 concern owner lacks reverse Architecture Closure coverage",
            self.validate(missing_owner_support),
        )

    def test_partial_gate_rows_keep_status_support_owner_and_assurance(self) -> None:
        baseline = self.minimal_blocking_graph(
            "user_decision",
            with_matrix=True,
        )
        invalid_status = baseline.replace_table_row(
            "Gate Closure",
            "Ownership",
            ("Ownership", "not_applicable", "R-002"),
        )
        missing_support = baseline.replace_table_row(
            "Gate Closure",
            "Owner-Level Fix",
            ("Owner-Level Fix", "pass", "D-002, A-002"),
        )
        wrong_owner = baseline.replace_table_row(
            "Gate Closure",
            "Ownership",
            ("Ownership", "pass", "D-001, A-002"),
        )
        wrong_assurance = baseline.replace_table_row(
            "Gate Closure",
            "Ownership",
            ("Ownership", "pass", "D-002, A-001"),
        )

        self.assertIn(
            "core gate Ownership must use status pass",
            self.validate(invalid_status),
        )
        self.assertIn(
            "gate Owner-Level Fix lacks required R/E support",
            self.validate(missing_support),
        )
        self.assertIn(
            "gate Ownership must be owned by D-002/owner",
            self.validate(wrong_owner),
        )
        self.assertIn(
            "gate Ownership requires assurance for D-002/owner",
            self.validate(wrong_assurance),
        )

    def test_partial_terminal_blocker_row_consumes_assurance_for_usage(self) -> None:
        graph = (
            self.minimal_blocking_graph(
                "user_decision",
                with_matrix=True,
            )
            .add_record(
                "Assurance Register",
                _record(
                    "A-099",
                    "A",
                    {
                        "Verifies": "R-001",
                        "Claim": "The terminal blocker preserves the outcome boundary.",
                        "Failure": "The blocker could be resolved against stale evidence.",
                        "Oracle": "Inspect the accepted evidence before resolving B-001.",
                        "Proxy risk": "Pre-terminal gates do not consume this assurance.",
                        "Evidence constraints": "Use the terminal blocker evidence only.",
                        "Architecture seam": "The blocked verification boundary is explicit.",
                    },
                    132,
                ),
            )
            .replace_table_row(
                "Gate Closure",
                "Verification",
                ("Verification", "failed", "B-001, A-099"),
            )
        )

        self.assertEqual(self.validate(graph), "")

    def test_blocking_profile_rejects_ready_shaped_downstream_records(self) -> None:
        blocked = self.minimal_blocking_graph("user_decision").add_record(
            "Open Blockers",
            _record(
                "I-099",
                "I",
                {
                    "Action": "update",
                    "Surface": "A premature durable surface.",
                    "Required by": "R-001",
                    "Resulting authority": "R-001",
                    "Contract requirement": "A premature contract requirement.",
                },
                133,
            ),
        )

        self.assertIn(
            "record I-099 is not allowed for BLOCKED",
            self.validate(blocked),
        )

    def test_blocker_fields_are_meaningful(self) -> None:
        graph = self.minimal_blocking_graph("research").replace_record(
            "B-001",
            Need="none",
            **{
                "Blocks because": "n/a",
                "Resolution requires": "{{TITLE}}",
            },
        )

        messages = self.validate(graph)

        for field in ("Need", "Blocks because", "Resolution requires"):
            self.assertIn(f"B-001.{field} must be meaningful", messages)


if __name__ == "__main__":
    unittest.main()
