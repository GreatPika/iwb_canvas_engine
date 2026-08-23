from __future__ import annotations

import unittest
from dataclasses import replace

import design_lint_validation_graph as _graph
import design_lint_validation_test_support as _support

_record = _graph._record


class ValidationBasisTest(_support.ValidationTestCase):
    # Permanent-artifact admission: graph-identity-and-usage — canonical IDs are globally unique and records require parsed semantic consumers; duplicate and lexical-self-use witnesses preserve causal graph integrity.
    # Permanent-artifact admission: graph-projection — derived views are duplicate-free exact projections with reverse coverage; omission and wrong-concern witnesses prevent canonical/view drift.
    def test_ready_requires_exactly_one_carried_and_assured_outcome(self) -> None:
        baseline = self.minimal_ready_graph()
        mutations = (
            (
                baseline.with_extra_outcome("R-099"),
                "exactly one outcome requirement is required",
            ),
            (
                baseline.replace_frontmatter(outcome="R-002"),
                "frontmatter outcome must reference the unique outcome requirement",
            ),
            (
                baseline.replace_record(
                    "D-001",
                    Basis="R-002, R-003, R-004, E-001, E-002",
                ).replace_record(
                    "D-002",
                    Basis="R-002, R-003, R-004, E-001, E-002",
                ),
                "outcome requirement R-001 must be carried by a selected decision",
            ),
            (
                baseline.replace_record("A-001", Verifies="D-002/owner"),
                "outcome requirement R-001 requires exact assurance",
            ),
        )

        for graph, expected in mutations:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))

    def test_canonical_record_identity_is_global_and_mapping_exact(self) -> None:
        graph = self.minimal_ready_graph()
        records = dict(graph.parsed.records)
        records["R-099"] = replace(records["R-001"], line=34)
        graph = replace(graph, parsed=replace(graph.parsed, records=records))

        messages = self.validate(graph)

        self.assertIn("record mapping key R-099 must equal identifier R-001", messages)
        self.assertIn("duplicate canonical record identifier R-001", messages)

    # Permanent-artifact admission: decision-dependency-acyclicity — D.Depends on must remain a DAG without self-edges; direct and transitive cycle witnesses preserve realizable ordering across graph refactors.
    def test_decision_dependencies_are_acyclic_and_type_exact(self) -> None:
        graph = self.minimal_ready_graph().with_dependency("D-001", "R-001")

        messages = self.validate(graph)

        self.assertIn("Depends on accepts only D references", messages)

    def test_decision_dependency_must_precede_consumer(self) -> None:
        graph = self.minimal_ready_graph().with_forward_dependency(
            "D-001",
            "D-002",
        )

        messages = self.validate(graph)

        self.assertIn("dependency must precede decision D-001", messages)

    def test_decision_dependency_cycle_is_rejected(self) -> None:
        graph = self.minimal_ready_graph().with_dependency("D-001", "D-002")

        messages = self.validate(graph)

        self.assertIn("decision dependencies must be acyclic", messages)

    def test_decision_cannot_depend_on_itself(self) -> None:
        graph = self.minimal_ready_graph().with_dependency("D-001", "D-001")

        messages = self.validate(graph)

        self.assertIn("decision dependencies must be acyclic", messages)

    # Permanent-artifact admission: source-provenance — every accepted user/other source reaches a meaningful R while S remains the single locator owner; missing-user-R and unowned-other witnesses preserve normative traceability.
    def test_source_coverage_is_lossless_and_exact_by_kind(self) -> None:
        baseline = self.minimal_ready_graph()
        coverage = baseline.parsed.tables["Source Coverage"]
        mutations = (
            (
                baseline.replace_table(
                    "Source Coverage",
                    replace(
                        coverage,
                        rows=coverage.rows[:-1],
                        row_lines=coverage.row_lines[:-1],
                    ),
                ),
                "Source Coverage must list every source kind exactly once in schema order",
            ),
            (
                baseline.replace_table(
                    "Source Coverage",
                    replace(
                        coverage,
                        rows=(
                            ("prior_design", "S-001, S-001"),
                            *coverage.rows[1:],
                        ),
                    ),
                ),
                "Source Coverage prior_design contains duplicate source S-001",
            ),
            (
                baseline.replace_record("S-006", Kind="repository"),
                "Source Coverage repository must equal canonical source order",
            ),
        )

        for graph, expected in mutations:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))

    def test_user_and_other_sources_preserve_normative_provenance(self) -> None:
        baseline = self.minimal_ready_graph()
        without_user_requirement = baseline.replace_record(
            "R-001",
            Basis="E-001",
        )
        without_other_requirement = baseline.replace_record(
            "R-003",
            Basis="S-004",
        )
        invalid_user_shape = baseline.replace_record(
            "R-003",
            **{
                "Statement": "none",
                "Open shape": "n/a",
            },
        )
        explicitly_fixed_shape = baseline.replace_record(
            "R-003",
            **{
                "Open shape": (
                    "The explicit user decision fully fixes this shape; no "
                    "incidental choice remains."
                )
            },
        )

        self.assertIn(
            "user source S-004 must produce a meaningful requirement",
            self.validate(without_user_requirement),
        )
        self.assertIn(
            "other source S-006 must produce a meaningful requirement",
            self.validate(without_other_requirement),
        )
        invalid_messages = self.validate(invalid_user_shape)
        self.assertIn(
            "other source S-006 must produce a meaningful requirement",
            invalid_messages,
        )
        self.assertIn("R-003.Statement must be meaningful", invalid_messages)
        self.assertIn("R-003.Open shape must be meaningful", invalid_messages)
        self.assertEqual(
            invalid_messages.count("R-003.Open shape must be meaningful"),
            1,
        )
        self.assertNotIn(
            "R-003.Open shape must be meaningful",
            self.validate(explicitly_fixed_shape),
        )

    def test_normative_requirements_reach_selected_decisions_or_exact_blocker(
        self,
    ) -> None:
        baseline = self.minimal_ready_graph()
        uncaptured = baseline.replace_record(
            "D-001",
            Basis="R-001, R-003, R-004, E-001, E-002",
        ).replace_record(
            "D-002",
            Basis="R-001, R-003, R-004, E-001, E-002",
        )
        without_exclusion_owner = baseline.replace_record(
            "D-002",
            Concerns=", ".join(
                f"`{item}`"
                for item in (
                    "owner",
                    "in_scope",
                    "source_of_truth",
                    "compatibility",
                    "order",
                    "policy",
                    "dependency",
                    "state_data",
                    "migration_retirement",
                    "temporal",
                    "atomicity",
                    "negative_proof_fixture",
                    "recognition",
                )
            ),
        )

        self.assertIn(
            "requirement R-002 must reach a selected decision or exact blocker",
            self.validate(uncaptured),
        )
        self.assertIn(
            "exclusion R-004 requires an out_of_scope selected decision",
            self.validate(without_exclusion_owner),
        )

    # Permanent-artifact admission: assurance-closure — outcomes, exact observable decision-concerns, and durable impacts require gate-used assurance; coarse-D and unassured-impact witnesses preserve proof coverage.
    def test_assurance_required_concerns_require_exact_verification(self) -> None:
        baseline = self.minimal_ready_graph()
        verifies = baseline.parsed.records["A-002"].fields["Verifies"].split(", ")
        for concern in ("compatibility", "temporal", "atomicity"):
            exact = f"D-002/{concern}"
            graph = baseline.replace_record(
                "A-002",
                Verifies=", ".join(item for item in verifies if item != exact),
            )
            with self.subTest(concern=concern):
                self.assertIn(
                    f"decision D-002 concern {concern} requires exact assurance",
                    self.validate(graph),
                )

        coarse = baseline.replace_record("A-002", Verifies="D-002")
        self.assertIn(
            "assurance A-002 must use exact D/concern references",
            self.validate(coarse),
        )

    def test_assurance_decision_concern_target_must_match_owner(self) -> None:
        baseline = self.minimal_ready_graph()
        verifies = baseline.parsed.records["A-002"].fields["Verifies"]
        graph = baseline.replace_record(
            "A-002",
            Verifies=f"{verifies}, D-001/temporal",
        )

        self.assertIn(
            "assurance A-002 references concern temporal not owned by D-001",
            self.validate(graph),
        )

    def test_gate_assurance_must_verify_the_same_decision_concern(self) -> None:
        graph = self.minimal_ready_graph().replace_table_row(
            "Gate Closure",
            "Temporal Surface Closure",
            ("Temporal Surface Closure", "pass", "D-002, A-001"),
        )

        messages = self.validate(graph)

        self.assertIn(
            "gate Temporal Surface Closure requires assurance for D-002/temporal",
            messages,
        )

    def test_observable_durable_impact_requires_exact_assurance(self) -> None:
        graph = (
            self.minimal_ready_graph()
            .with_assured_impact()
            .replace_record(
                "A-003",
                Verifies="R-001",
            )
        )

        messages = self.validate(graph)

        self.assertIn("durable impact I-001 requires exact assurance", messages)

    def test_assurance_contract_index_is_not_a_semantic_consumer(self) -> None:
        graph = (
            self.minimal_ready_graph()
            .add_record(
                "Assurance Register",
                _record(
                    "A-099",
                    "A",
                    {
                        "Verifies": "D-002/temporal",
                        "Claim": "A duplicate claim is deliberately orphaned.",
                        "Failure": "The orphan has no gate consumer.",
                        "Oracle": "A direct temporal oracle exists.",
                        "Proxy risk": "The projection can look complete while unused.",
                        "Evidence constraints": "Use the real temporal seam.",
                        "Architecture seam": "The temporal boundary is exercised.",
                    },
                    73,
                ),
            )
            .replace_record(
                "CONTRACT",
                Assurance="A-001, A-002, A-099",
            )
        )

        messages = self.validate(graph)

        self.assertIn("assurance A-099 must participate in Gate Closure", messages)

    # Permanent-artifact admission: candidate-proportionality — compared forms and material obligations require complete membership, authority, selection, and realization; self-authorized-obligation witnesses remain valid across implementation refactors.
    def test_candidate_cardinality_result_and_form_owner_are_exact(self) -> None:
        baseline = self.minimal_ready_graph()
        forms = baseline.parsed.tables["Forms"]
        one_form = baseline.remove_record("Candidate Analysis", "F-002").replace_table(
            "Forms",
            replace(
                forms,
                rows=forms.rows[:1],
                row_lines=forms.row_lines[:1],
            ),
        )
        missing_selection = baseline.replace_record(
            "CANDIDATE",
            Result="`selected F-099`",
        )
        two_form_owners = baseline.replace_record(
            "D-002",
            Concerns=(f"`form`, {baseline.parsed.records['D-002'].fields['Concerns']}"),
        )

        self.assertIn(
            "two_or_three comparison requires two or three forms",
            self.validate(one_form),
        )
        self.assertIn(
            "Candidate Result must select exactly one defined form",
            self.validate(missing_selection),
        )
        self.assertIn(
            "ready design requires exactly one selected form-owning decision",
            self.validate(two_form_owners),
        )

    def test_material_membership_and_authority_are_complete(self) -> None:
        baseline = self.minimal_ready_graph()
        matrix = baseline.parsed.tables["Material-Obligation Delta"]
        wrong_header = baseline.replace_table(
            "Material-Obligation Delta",
            replace(
                matrix,
                header=(
                    "ID",
                    "Material obligation",
                    "F-001",
                    "Independent authority",
                ),
            ),
        )
        no_membership = baseline.replace_table_row(
            "Material-Obligation Delta",
            "M-002",
            (
                "M-002",
                "Reuse the accepted external boundary.",
                "no",
                "no",
                "R-003, E-002",
            ),
        )
        self_authorized = baseline.replace_record(
            "M-002",
            **{"Independent authority": "none"},
        ).replace_table_row(
            "Material-Obligation Delta",
            "M-002",
            (
                "M-002",
                "Reuse the accepted external boundary.",
                "yes",
                "no",
                "none",
            ),
        )

        self.assertIn(
            "Material-Obligation Delta form columns must exactly match compared forms",
            self.validate(wrong_header),
        )
        self.assertIn(
            "material obligation M-002 must belong to at least one form",
            self.validate(no_membership),
        )
        self.assertIn(
            "selected-only material obligation M-002 requires independent R/E authority",
            self.validate(self_authorized),
        )

    def test_selected_form_cannot_omit_or_fail_to_realize_obligation(self) -> None:
        baseline = self.minimal_ready_graph()
        omitted = baseline.replace_table_row(
            "Material-Obligation Delta",
            "M-002",
            (
                "M-002",
                "Reuse the accepted external boundary.",
                "no",
                "yes",
                "R-003, E-002",
            ),
        )
        unrealized = baseline.replace_record("D-001", Realizes="M-001")

        self.assertIn(
            "selected form F-001 omits independently authorized obligation M-002",
            self.validate(omitted),
        )
        self.assertIn(
            "selected material obligation M-002 must be realized exactly",
            self.validate(unrealized),
        )

    def test_candidate_semantic_cells_are_meaningful(self) -> None:
        baseline = self.minimal_ready_graph()
        mutations = (
            (
                baseline.replace_record("F-001", **{"Main trade-off": ""}),
                "F-001.Main trade-off must be meaningful",
            ),
            (
                baseline.replace_record("M-002", **{"Material obligation": ""}),
                "M-002.Material obligation must be meaningful",
            ),
            (
                baseline.replace_record("P-001", **{"Accepted cost or risk": ""}),
                "P-001.Accepted cost or risk must be meaningful",
            ),
        )

        for graph, expected in mutations:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))

    def test_solution_proportionality_projection_is_complete_and_duplicate_free(
        self,
    ) -> None:
        baseline = self.minimal_ready_graph()
        omitted = baseline.replace_table_row(
            "Gate Closure",
            "Solution Proportionality",
            (
                "Solution Proportionality",
                "pass",
                "F-001, M-001, M-002, R-002, R-003, E-002",
            ),
        )
        duplicate = baseline.replace_table_row(
            "Gate Closure",
            "Solution Proportionality",
            (
                "Solution Proportionality",
                "pass",
                "F-001, F-001, F-002, M-001, M-002, R-002, R-003, E-002",
            ),
        )

        self.assertIn(
            "Solution Proportionality must exactly project F/M and independent R/E",
            self.validate(omitted),
        )
        self.assertIn(
            "Solution Proportionality contains duplicate reference F-001",
            self.validate(duplicate),
        )

    def test_common_mandatory_and_form_delta_keep_one_normative_owner(self) -> None:
        baseline = self.minimal_ready_graph()
        paraphrased_common = baseline.replace_record(
            "M-001",
            **{"Material obligation": "Keep the repository owner authoritative."},
        ).replace_table_row(
            "Material-Obligation Delta",
            "M-001",
            (
                "M-001",
                "Keep the repository owner authoritative.",
                "yes",
                "yes",
                "R-002",
            ),
        )
        duplicate_requirement = baseline.replace_record(
            "M-002",
            **{"Material obligation": ("Preserve the accepted external constraint.")},
        ).replace_table_row(
            "Material-Obligation Delta",
            "M-002",
            (
                "M-002",
                "Preserve the accepted external constraint.",
                "yes",
                "no",
                "R-003, E-002",
            ),
        )

        self.assertIn(
            "common mandatory material obligation M-001 must use an exact R reference",
            self.validate(paraphrased_common),
        )
        self.assertIn(
            "material obligation M-002 duplicates canonical requirement R-003",
            self.validate(duplicate_requirement),
        )


if __name__ == "__main__":
    unittest.main()
