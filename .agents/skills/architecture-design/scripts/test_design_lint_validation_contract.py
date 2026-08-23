from __future__ import annotations

import unittest
from dataclasses import replace

import design_lint_validation_graph as _graph
import design_lint_validation_test_support as _support

_Graph = _graph._Graph


class ValidationContractTest(_support.ValidationTestCase):
    # Permanent-artifact admission: graph-projection — derived views are duplicate-free exact projections with reverse coverage; omission and wrong-concern witnesses prevent canonical/view drift.
    def test_architecture_closure_is_exact_and_bidirectional(self) -> None:
        baseline = self.minimal_ready_graph()
        closure = baseline.parsed.tables["Architecture Closure"]
        wrong_owner = baseline.replace_table_row(
            "Architecture Closure",
            "source_of_truth",
            ("source_of_truth", "closed", "D-001"),
        )
        omitted = baseline.replace_table(
            "Architecture Closure",
            replace(
                closure,
                rows=tuple(row for row in closure.rows if row[0] != "compatibility"),
                row_lines=closure.row_lines[:-1],
            ),
        )
        missing_reverse = baseline.replace_record(
            "D-001",
            Concerns="`form`, `owner`",
        )

        self.assertIn(
            "Architecture Closure source_of_truth references a decision without "
            "the matching concern",
            self.validate(wrong_owner),
        )
        self.assertIn(
            "Architecture Closure rows must exactly match schema concern order",
            self.validate(omitted),
        )
        self.assertIn(
            "decision D-001 concern owner lacks reverse Architecture Closure coverage",
            self.validate(missing_reverse),
        )

    def test_closed_architecture_and_mapped_pass_require_exact_owner(self) -> None:
        baseline = self.minimal_ready_graph()
        decision = baseline.parsed.records["D-002"]
        assurance = baseline.parsed.records["A-002"]

        ownerless_architecture = (
            baseline.replace_record(
                "D-002",
                Concerns=", ".join(
                    item
                    for item in decision.fields["Concerns"].split(", ")
                    if item != "`compatibility`"
                ),
            )
            .replace_record(
                "A-002",
                Verifies=", ".join(
                    item
                    for item in assurance.fields["Verifies"].split(", ")
                    if item != "D-002/compatibility"
                ),
            )
            .replace_table_row(
                "Architecture Closure",
                "compatibility",
                ("compatibility", "closed", "R-002"),
            )
        )

        ownerless_gate = (
            baseline.replace_record(
                "D-002",
                Concerns=", ".join(
                    item
                    for item in decision.fields["Concerns"].split(", ")
                    if item != "`policy`"
                ),
            )
            .replace_record(
                "A-002",
                Verifies=", ".join(
                    item
                    for item in assurance.fields["Verifies"].split(", ")
                    if item != "D-002/policy"
                ),
            )
            .replace_table_row(
                "Architecture Closure",
                "policy",
                ("policy", "not_applicable", "R-002"),
            )
        )

        self.assertIn(
            "Architecture Closure compatibility closed requires an owning decision",
            self.validate(ownerless_architecture),
        )
        self.assertIn(
            "gate Boundary-Owned Policy pass requires an owning decision for policy",
            self.validate(ownerless_gate),
        )

    def test_concern_gate_ownership_is_exact(self) -> None:
        graph = self.minimal_ready_graph().replace_table_row(
            "Gate Closure",
            "Ownership",
            ("Ownership", "pass", "D-001, A-001"),
        )

        messages = self.validate(graph)

        self.assertIn(
            "gate Ownership must be owned by D-002/owner",
            messages,
        )

    # Permanent-artifact admission: handoff-correspondence — decision concerns and canonical sets project completely and duplicate-free while CONTRACT remains non-semantic; incomplete-target witnesses preserve downstream consumability.
    def test_decision_concerns_require_exact_contract_targets(self) -> None:
        baseline = self.minimal_ready_graph()
        targets = baseline.parsed.records["D-002"].fields["Contract targets"]
        without_compatibility = ", ".join(
            item for item in targets.split(", ") if item != "`compatibility`"
        )
        unrelated_only = baseline.replace_record(
            "D-002",
            **{"Contract targets": "`unit_family`"},
        )

        self.assertIn(
            "decision D-002 concern compatibility requires Contract target compatibility",
            self.validate(
                baseline.replace_record(
                    "D-002",
                    **{"Contract targets": without_compatibility},
                )
            ),
        )
        unrelated_messages = self.validate(unrelated_only)
        self.assertIn(
            "decision D-002 concern compatibility requires Contract target compatibility",
            unrelated_messages,
        )
        self.assertIn(
            "decision D-002 concern order requires Contract target order",
            unrelated_messages,
        )

    def test_ready_gate_rows_statuses_and_required_groups_are_exact(self) -> None:
        baseline = self.minimal_ready_graph()
        gate_table = baseline.parsed.tables["Gate Closure"]
        omitted = baseline.replace_table(
            "Gate Closure",
            replace(
                gate_table,
                rows=tuple(row for row in gate_table.rows if row[0] != "Verification"),
                row_lines=gate_table.row_lines[:-1],
            ),
        )
        invalid_status = baseline.replace_table_row(
            "Gate Closure",
            "Ownership",
            ("Ownership", "not_applicable", "R-002"),
        )
        missing_group = baseline.replace_table_row(
            "Gate Closure",
            "Owner-Level Fix",
            ("Owner-Level Fix", "pass", "D-002, A-002"),
        )

        self.assertIn(
            "Gate Closure rows must exactly match schema gate order",
            self.validate(omitted),
        )
        self.assertIn(
            "core gate Ownership must use status pass",
            self.validate(invalid_status),
        )
        self.assertIn(
            "gate Owner-Level Fix lacks required R/E support",
            self.validate(missing_group),
        )

    # Permanent-artifact admission: handoff-correspondence — decision concerns and canonical sets project completely and duplicate-free while CONTRACT remains non-semantic; incomplete-target witnesses preserve downstream consumability.
    def test_contract_projection_requires_ordered_duplicate_free_equality(self) -> None:
        baseline = self.minimal_ready_graph()
        cases = (
            ("Sources", "S-002, S-001, S-003, S-004, S-005, S-006"),
            ("Requirements", "R-002, R-001, R-003, R-004"),
            ("Commitments", "D-002, D-001"),
            ("Assurance", "A-002, A-001"),
            ("Stops", "H-001, H-001"),
        )
        for field, value in cases:
            graph = baseline.replace_record("CONTRACT", **{field: value})
            messages = self.validate(graph)
            with self.subTest(field=field):
                if field == "Stops":
                    self.assertIn(
                        "Contract Interface Stops contains duplicate reference H-001",
                        messages,
                    )
                self.assertIn(
                    f"Contract Interface {field} must equal canonical record order",
                    messages,
                )

        impact_graph = baseline.with_assured_impact().replace_record(
            "CONTRACT",
            Impacts="none",
        )
        self.assertIn(
            "Contract Interface Impacts must equal canonical record order",
            self.validate(impact_graph),
        )

    def test_contract_projection_is_a_typed_index(self) -> None:
        graph = self.minimal_ready_graph().replace_record(
            "CONTRACT",
            Commitments="R-001, D-002",
        )

        messages = self.validate(graph)

        self.assertIn(
            "Contract Interface Commitments accepts only D references",
            messages,
        )

    def test_contract_vocabulary_values_are_complete_and_canonical(self) -> None:
        baseline = self.minimal_ready_graph()
        mutations = (
            (
                baseline.replace_record("CONTRACT", Profile="`PROFILE_A` trailing"),
                "Contract Interface Profile must be one complete canonical value",
            ),
            (
                baseline.replace_record("CONTRACT", Profile="`UNKNOWN`"),
                "unknown Contract Interface Profile UNKNOWN",
            ),
            (
                baseline.replace_record(
                    "CONTRACT",
                    Obligations="`OBLIGATION_A`, `OBLIGATION_A`",
                ),
                "Contract Interface Obligations contains duplicate OBLIGATION_A",
            ),
            (
                baseline.replace_record(
                    "CONTRACT",
                    Obligations="`None`, `OBLIGATION_A`",
                ),
                "Contract Interface no-obligation value cannot be combined",
            ),
        )

        for graph, expected in mutations:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))

    def test_contract_token_alone_never_proves_handoff_consumability(self) -> None:
        graph = self.minimal_ready_graph().replace_table_row(
            "Gate Closure",
            "Handoff Consumability",
            ("Handoff Consumability", "pass", "CONTRACT"),
        )

        messages = self.validate(graph)

        self.assertIn(
            "CONTRACT alone cannot prove Handoff Consumability",
            messages,
        )

    # Permanent-artifact admission: mandatory-contract-stop-condition — every ready design has and exactly projects a meaningful H re-entry condition; missing-H and placeholder-stop witnesses preserve the future contract stop boundary.
    def test_ready_design_requires_explicit_contract_stop_condition(self) -> None:
        graph = (
            self.minimal_ready_graph()
            .remove_record(
                "Stop Conditions",
                "H-001",
            )
            .replace_record(
                "CONTRACT",
                Stops="none",
            )
        )

        messages = self.validate(graph)

        self.assertIn(
            "ready design requires at least one explicit contract stop condition",
            messages,
        )

    # Permanent-artifact admission: durable-impact-decision-correspondence — every selected decision that targets durable_impact and every D Required by an impact must agree exactly; missing-impact and non-durable-D witnesses prevent an unassigned durable transition or a false durable owner while R-required impacts remain valid.
    def test_durable_impact_decisions_and_impacts_correspond_exactly(self) -> None:
        baseline = self.minimal_ready_graph().with_assured_impact()
        missing_impact = self.minimal_ready_graph().replace_record(
            "D-002",
            **{
                "Contract targets": (
                    "`owner`, `scope`, `source_of_truth`, `compatibility`, "
                    "`order`, `policy`, `dependency`, `state_data`, "
                    "`migration_retirement`, `temporal`, `atomicity`, "
                    "`negative_proof_fixture`, `recognition`, `acceptance`, "
                    "`evidence`, `verification`, `unit_family`, "
                    "`durable_impact`"
                )
            },
        )
        non_durable_requirement = baseline.replace_record(
            "D-002",
            **{
                "Contract targets": (
                    "`owner`, `scope`, `source_of_truth`, `compatibility`, "
                    "`order`, `policy`, `dependency`, `state_data`, "
                    "`migration_retirement`, `temporal`, `atomicity`, "
                    "`negative_proof_fixture`, `recognition`, `acceptance`, "
                    "`evidence`, `verification`, `unit_family`"
                )
            },
        )

        self.assertEqual(self.validate(baseline), "")
        self.assertIn(
            "selected durable_impact decision D-002 requires an Impact Register "
            "reference",
            self.validate(missing_impact),
        )
        self.assertIn(
            "durable impact I-001 Required by decision D-002 must target "
            "durable_impact",
            self.validate(non_durable_requirement),
        )
        self.assertEqual(
            self.validate(
                non_durable_requirement.replace_record(
                    "I-001",
                    **{"Required by": "R-002"},
                )
            ),
            "",
        )

    # Permanent-artifact admission: durable-impact-correspondence — ADR and durable impacts match exact targets and complete authority transitions with assurance; wrong-target witnesses preserve lifecycle truth.
    def test_adr_impact_requires_exact_action_and_target(self) -> None:
        baseline = self.minimal_ready_graph().with_assured_adr_impact()
        mutations = (
            (
                baseline.replace_record("I-001", Action="update"),
                "ADR Impact action supersede has no matching durable impact "
                "for ADR-0001",
            ),
            (
                baseline.replace_record(
                    "I-001",
                    Surface="ADR-0002 and its repository authority route.",
                ),
                "ADR Impact action supersede has no matching durable impact "
                "for ADR-0001",
            ),
            (
                baseline.replace_record("CONTRACT", **{"ADR Impact": "none"}),
                "durable impact I-001 action supersede for ADR-0001 is missing "
                "from ADR Impact",
            ),
        )

        for graph, expected in mutations:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))

    def test_adr_impact_requires_durable_owner_and_resulting_authority(self) -> None:
        baseline = self.minimal_ready_graph().with_assured_adr_impact()
        wrong_required_by = baseline.replace_record(
            "I-001",
            **{"Required by": "D-001"},
        )
        wrong_authority = baseline.replace_record(
            "I-001",
            **{"Resulting authority": "D-001"},
        )

        self.assertIn(
            "durable impact I-001 Required by decision D-001 must target "
            "durable_impact",
            self.validate(wrong_required_by),
        )
        self.assertIn(
            "I-001.Resulting authority must correspond to Required by",
            self.validate(wrong_authority),
        )

    def test_adr_impact_future_contract_requirement_corresponds_exactly(self) -> None:
        graph = (
            self.minimal_ready_graph()
            .with_assured_adr_impact()
            .replace_record(
                "I-001",
                **{
                    "Contract requirement": (
                        "Update a different ADR under an unspecified authority."
                    )
                },
            )
        )

        messages = self.validate(graph)

        self.assertIn(
            "I-001.Contract requirement must name supersede ADR-0001 and "
            "resulting authority",
            messages,
        )

    def test_meaningful_record_fields_reject_placeholders(self) -> None:
        baseline = self.minimal_ready_graph()
        cases: list[tuple[_Graph, str]] = []
        for field in ("Lock", "Open", "Rationale"):
            cases.append(
                (
                    baseline.replace_record("D-001", **{field: "none"}),
                    f"D-001.{field} must be meaningful",
                )
            )
        for field in (
            "Claim",
            "Failure",
            "Oracle",
            "Proxy risk",
            "Evidence constraints",
            "Architecture seam",
        ):
            cases.append(
                (
                    baseline.replace_record("A-001", **{field: "{{TITLE}}"}),
                    f"A-001.{field} must be meaningful",
                )
            )
        impact = baseline.with_assured_impact()
        for field in (
            "Action",
            "Surface",
            "Required by",
            "Resulting authority",
            "Contract requirement",
        ):
            cases.append(
                (
                    impact.replace_record("I-001", **{field: "n/a"}),
                    f"I-001.{field} must be meaningful",
                )
            )
        for field in ("Trigger", "Resolution requires"):
            cases.append(
                (
                    baseline.replace_record("H-001", **{field: "`none`"}),
                    f"H-001.{field} must be meaningful",
                )
            )

        for graph, expected in cases:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.validate(graph))


if __name__ == "__main__":
    unittest.main()
