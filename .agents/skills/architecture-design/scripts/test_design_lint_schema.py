from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from design_lint_schema import load_schema, load_vocabulary


class SchemaModuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repository_root = Path(self.temporary_directory.name)
        (self.repository_root / ".git").mkdir()

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write_schema(self, payload: dict[str, object]) -> Path:
        path = self.repository_root / "design-artifact-schema.json"
        path.write_text(json.dumps(payload), encoding="utf-8")
        return path

    def write_vocabulary(self, payload: dict[str, object] | None) -> Path:
        if payload is None:
            return self.repository_root / "missing-vocabulary.json"
        path = self.repository_root / "contract-vocabulary.json"
        path.write_text(json.dumps(payload), encoding="utf-8")
        return path

    def assert_schema_rejected(
        self,
        payload: dict[str, object],
        expected: str,
    ) -> None:
        with self.assertRaisesRegex(ValueError, expected):
            load_schema(self.write_schema(payload))

    @staticmethod
    def vocabulary_failures() -> list[tuple[dict[str, object] | None, str]]:
        return [
            (
                {
                    "profiles": ["PROFILE_A", "PROFILE_A"],
                    "obligations": ["OBLIGATION_A"],
                    "no_obligation": "None",
                },
                "profiles must contain unique strings",
            ),
            (
                {
                    "profiles": ["PROFILE_A"],
                    "obligations": ["OBLIGATION_A", "OBLIGATION_A"],
                    "no_obligation": "None",
                },
                "obligations must contain unique strings",
            ),
            (
                {
                    "profiles": ["SHARED"],
                    "obligations": ["SHARED"],
                    "no_obligation": "None",
                },
                "profiles and obligations must be disjoint",
            ),
            (
                {
                    "profiles": ["PROFILE_A"],
                    "obligations": ["OBLIGATION_A"],
                    "no_obligation": "OBLIGATION_A",
                },
                "no_obligation must not be a profile or material obligation",
            ),
            (None, "unable to read JSON object"),
            (
                {
                    "profiles": ["PROFILE_A"],
                    "obligations": ["OBLIGATION_A"],
                    "no_obligation": "None",
                    "copied_owner": True,
                },
                "contract vocabulary has unexpected keys",
            ),
        ]

    @staticmethod
    def valid_schema_payload() -> dict[str, object]:
        return {
            "version": "architecture-design/v4",
            "frontmatter": {
                "fields": [
                    "schema",
                    "date",
                    "commit",
                    "branch",
                    "disposition",
                    "outcome",
                ],
                "dispositions": [
                    "READY_FOR_CONTRACT",
                    "BLOCKED",
                    "DESIGN_NOT_REQUIRED",
                ],
                "date_pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
                "commit_pattern": "^[0-9a-f]{7,40}$",
                "outcome_pattern": "^R-[0-9]{3}$",
            },
            "sections": {
                "order": [
                    "Basis",
                    "Candidate Analysis",
                    "Decision Register",
                    "Impact Register",
                    "Assurance Register",
                    "Stop Conditions",
                    "Contract Interface",
                    "Diagrams",
                    "Readiness Matrix",
                    "Open Blockers",
                ],
                "required": {
                    "READY_FOR_CONTRACT": [
                        "Basis",
                        "Candidate Analysis",
                        "Decision Register",
                        "Impact Register",
                        "Assurance Register",
                        "Stop Conditions",
                        "Contract Interface",
                        "Diagrams",
                        "Readiness Matrix",
                        "Open Blockers",
                    ],
                    "BLOCKED": [
                        "Basis",
                        "Candidate Analysis",
                        "Open Blockers",
                    ],
                    "DESIGN_NOT_REQUIRED": [
                        "Basis",
                        "Candidate Analysis",
                        "Readiness Matrix",
                        "Open Blockers",
                    ],
                },
                "optional": {
                    "READY_FOR_CONTRACT": [],
                    "BLOCKED": [
                        "Decision Register",
                        "Assurance Register",
                        "Diagrams",
                        "Readiness Matrix",
                    ],
                    "DESIGN_NOT_REQUIRED": ["Diagrams"],
                },
            },
            "ids": {
                "source": "^S-[0-9]{3}$",
                "evidence": "^E-[0-9]{3}$",
                "requirement": "^R-[0-9]{3}$",
                "form": "^F-[0-9]{3}$",
                "material_obligation": "^M-[0-9]{3}$",
                "pressure": "^P-[0-9]{3}$",
                "decision": "^D-[0-9]{3}$",
                "assurance": "^A-[0-9]{3}$",
                "impact": "^I-[0-9]{3}$",
                "guard": "^H-[0-9]{3}$",
                "diagram": "^DG-[0-9]{3}$",
                "blocker": "^B-[0-9]{3}$",
            },
            "basis": {
                "source_header": ["ID", "Kind", "Locator", "Use"],
                "source_kinds": [
                    "prior_design",
                    "research",
                    "plan",
                    "user",
                    "repository",
                    "other",
                ],
                "evidence_header": ["ID", "Source", "Locator", "Observed fact"],
                "requirement_header": [
                    "ID",
                    "Kind",
                    "Statement",
                    "Basis",
                    "Open shape",
                ],
                "requirement_kinds": [
                    "outcome",
                    "constraint",
                    "user_decision",
                    "repository_rule",
                    "exclusion",
                ],
                "source_coverage_header": ["Kind", "Sources or none"],
            },
            "candidate": {
                "fields": ["Comparison", "Result", "Result basis"],
                "comparison_values": [
                    "two_or_three",
                    "single_viable",
                    "not_applicable",
                    "blocked",
                ],
                "result_patterns": [
                    "^selected F-[0-9]{3}$",
                    "^not_required$",
                    "^blocked B-[0-9]{3}(?:, B-[0-9]{3})*$",
                ],
                "forms_header": [
                    "ID",
                    "Form",
                    "Hard constraints",
                    "Main trade-off",
                    "Basis",
                ],
                "material_prefix": ["ID", "Material obligation"],
                "material_suffix": ["Independent authority"],
                "future_pressure_header": [
                    "ID",
                    "Pressure",
                    "Basis",
                    "Treatment",
                    "Closure refs",
                    "Accepted cost or risk",
                ],
                "future_pressure_none_dispositions": [
                    "DESIGN_NOT_REQUIRED",
                ],
                "future_pressure_none_literal": "None",
                "pressure_treatments": ["absorbed", "deferred", "rejected"],
                "yes_no": ["yes", "no"],
            },
            "decision": {
                "fields": [
                    "Concerns",
                    "Lock",
                    "Open",
                    "Basis",
                    "Form",
                    "Realizes",
                    "Depends on",
                    "Contract targets",
                    "Rationale",
                ],
                "concerns": [
                    "form",
                    "owner",
                    "in_scope",
                    "out_of_scope",
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
                ],
                "contract_targets": [
                    "classification",
                    "owner",
                    "scope",
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
                    "acceptance",
                    "evidence",
                    "verification",
                    "durable_impact",
                    "unit_family",
                ],
                "assurance_required_concerns": [
                    "owner",
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
                ],
                "concern_contract_target_map": {
                    "form": ["classification"],
                    "owner": ["owner"],
                    "in_scope": ["scope"],
                    "out_of_scope": ["scope"],
                    "source_of_truth": ["source_of_truth"],
                    "compatibility": ["compatibility"],
                    "order": ["order"],
                    "policy": ["policy"],
                    "dependency": ["dependency"],
                    "state_data": ["state_data"],
                    "migration_retirement": ["migration_retirement"],
                    "temporal": ["temporal"],
                    "atomicity": ["atomicity"],
                    "negative_proof_fixture": ["negative_proof_fixture"],
                    "recognition": ["recognition"],
                },
            },
            "assurance": {
                "fields": [
                    "Verifies",
                    "Claim",
                    "Failure",
                    "Oracle",
                    "Proxy risk",
                    "Evidence constraints",
                    "Architecture seam",
                ],
                "verifies_patterns": {
                    "requirement": "^R-[0-9]{3}$",
                    "decision_concern": "^D-[0-9]{3}/[a-z][a-z0-9_]*$",
                    "impact": "^I-[0-9]{3}$",
                },
            },
            "impact": {
                "fields": [
                    "Action",
                    "Surface",
                    "Required by",
                    "Resulting authority",
                    "Contract requirement",
                ],
                "actions": ["create", "update", "supersede", "retire", "remove"],
                "none_literal": "None",
            },
            "guard": {
                "fields": ["Trigger", "Invalidates", "Resolution requires"],
            },
            "contract": {
                "fields": [
                    "Profile",
                    "Obligations",
                    "ADR Impact",
                    "Sources",
                    "Requirements",
                    "Commitments",
                    "Assurance",
                    "Impacts",
                    "Stops",
                ],
                "adr_pattern": (
                    "^(?:none|create ADR-[0-9]{4}|"
                    "(?:supersede|retire) ADR-[0-9]{4}"
                    "(?:, ADR-[0-9]{4})*)$"
                ),
            },
            "coverage": {
                "architecture_header": ["Concern", "Status", "Support refs"],
                "architecture_concerns": [
                    "owner",
                    "in_scope",
                    "out_of_scope",
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
                ],
                "ready_architecture_statuses": ["closed", "not_applicable"],
                "existing_architecture_statuses": [
                    "already_closed",
                    "not_applicable",
                ],
                "gate_header": ["Gate", "Status", "Support refs"],
                "core_gates": [
                    "Owner-Level Fix",
                    "Ownership",
                    "Source-Of-Truth Singularity",
                    "Source-Truth Minimality",
                    "Boundary-Owned Policy",
                    "Dependency Direction",
                    "Solution Proportionality",
                    "Outcome-Proof Fit",
                    "Verification",
                    "Future Pressure",
                    "Handoff Consumability",
                ],
                "conditional_gates": [
                    "Negative Proof And Fixture Quarantine",
                    "State/Data Ownership",
                    "Sequenced Migration And Retirement",
                    "Temporal Surface Closure",
                    "All-Or-Nothing Failure Boundary",
                    "Bounded Recognition Scope",
                ],
                "ready_core_status": "pass",
                "ready_conditional_statuses": ["pass", "not_applicable"],
                "existing_core_status": "already_closed",
                "existing_conditional_statuses": [
                    "already_closed",
                    "not_applicable",
                ],
                "blocking_failure_statuses": ["failed", "unresolved"],
                "gate_required_ref_groups": {
                    "Owner-Level Fix": [["D"], ["R", "E"]],
                    "Ownership": [["D"]],
                    "Source-Of-Truth Singularity": [["D"]],
                    "Source-Truth Minimality": [["D"], ["M", "F"]],
                    "Boundary-Owned Policy": [["D"]],
                    "Dependency Direction": [["D"]],
                    "Solution Proportionality": [["F"], ["M"], ["R", "E"]],
                    "Outcome-Proof Fit": [["A"]],
                    "Verification": [["A"]],
                    "Future Pressure": [["P", "E"]],
                    "Handoff Consumability": [["CONTRACT"]],
                    "Negative Proof And Fixture Quarantine": [["D"], ["A"]],
                    "State/Data Ownership": [["D"], ["A"]],
                    "Sequenced Migration And Retirement": [["D"], ["A"]],
                    "Temporal Surface Closure": [["D"], ["A"]],
                    "All-Or-Nothing Failure Boundary": [["D"], ["A"]],
                    "Bounded Recognition Scope": [["D"], ["A"]],
                },
                "concern_gate_map": {
                    "owner": ["Owner-Level Fix", "Ownership"],
                    "source_of_truth": [
                        "Source-Of-Truth Singularity",
                        "Source-Truth Minimality",
                    ],
                    "policy": ["Boundary-Owned Policy"],
                    "dependency": ["Dependency Direction"],
                    "negative_proof_fixture": ["Negative Proof And Fixture Quarantine"],
                    "state_data": ["State/Data Ownership"],
                    "migration_retirement": ["Sequenced Migration And Retirement"],
                    "temporal": ["Temporal Surface Closure"],
                    "atomicity": ["All-Or-Nothing Failure Boundary"],
                    "recognition": ["Bounded Recognition Scope"],
                },
            },
            "diagram": {
                "fields": ["Type", "Question", "Supports"],
                "types": [
                    "context",
                    "container",
                    "component",
                    "data_flow",
                    "sequence",
                    "state",
                ],
                "type_language_map": {
                    "context": "mermaid",
                    "container": "mermaid",
                    "component": "mermaid",
                    "data_flow": "mermaid",
                    "sequence": "mermaid",
                    "state": "mermaid",
                },
            },
            "blocker": {
                "fields": [
                    "Kind",
                    "Gate",
                    "Need",
                    "Blocks because",
                    "Resolution requires",
                    "Related",
                ],
                "kinds": ["research", "user_decision"],
                "additional_gates": [
                    "Source Authority",
                    "Candidate Comparison",
                    "Disposition",
                ],
                "disposition_kinds_map": {
                    "BLOCKED": ["research", "user_decision"],
                },
            },
            "locators": {
                "repository_relative_source_kinds": [
                    "prior_design",
                    "research",
                    "plan",
                    "repository",
                ],
                "external_absolute_source_kinds": ["other"],
                "literal_source_locators": {"user": "user request"},
                "evidence_line_pattern": "^line [1-9][0-9]*$",
                "evidence_range_pattern": "^lines [1-9][0-9]*-[1-9][0-9]*$",
                "evidence_surface_exceptions": [
                    "new_path",
                    "generated_output",
                    "command_surface",
                    "configuration_surface",
                ],
            },
            "forbidden_tokens": {
                "active_tokens": ["TODO", "TBD"],
                "template_markers": {"{{TITLE}}": 1},
                "placeholder_values": ["none", "n/a", "not applicable"],
                "meaningful_fields": {
                    "R": ["Open shape"],
                    "D": ["Lock", "Open", "Rationale"],
                    "A": [
                        "Claim",
                        "Failure",
                        "Oracle",
                        "Proxy risk",
                        "Evidence constraints",
                        "Architecture seam",
                    ],
                    "I": [
                        "Action",
                        "Surface",
                        "Required by",
                        "Resulting authority",
                        "Contract requirement",
                    ],
                    "H": ["Trigger", "Resolution requires"],
                    "B": ["Need", "Blocks because", "Resolution requires"],
                },
            },
            "vocabulary": "contract-vocabulary.json",
        }

    # Permanent-artifact admission: schema-closure — reject incoherent schema declarations before artifact validation; malformed-schema witnesses preserve deterministic ownership across parser refactors.
    def test_v4_schema_module_loads_closed_schema(self) -> None:
        schema_path = self.write_schema(self.valid_schema_payload())

        schema = load_schema(schema_path)

        self.assertEqual(schema.version, "architecture-design/v4")
        self.assertEqual(schema.source_path, schema_path)
        self.assertEqual(schema.frontmatter_fields[-1], "outcome")
        candidate = schema.raw["candidate"]
        assert isinstance(candidate, dict)
        self.assertEqual(
            candidate["future_pressure_none_dispositions"],
            ["DESIGN_NOT_REQUIRED"],
        )
        self.assertEqual(candidate["future_pressure_none_literal"], "None")
        sections = schema.raw["sections"]
        assert isinstance(sections, dict)
        required = sections["required"]
        optional = sections["optional"]
        assert isinstance(required, dict)
        assert isinstance(optional, dict)
        self.assertEqual(
            required["READY_FOR_CONTRACT"],
            [
                "Basis",
                "Candidate Analysis",
                "Decision Register",
                "Impact Register",
                "Assurance Register",
                "Stop Conditions",
                "Contract Interface",
                "Diagrams",
                "Readiness Matrix",
                "Open Blockers",
            ],
        )
        for disposition in (
            "BLOCKED",
            "DESIGN_NOT_REQUIRED",
        ):
            with self.subTest(disposition=disposition):
                self.assertNotIn("Impact Register", required[disposition])
                self.assertNotIn("Stop Conditions", required[disposition])
                self.assertNotIn("Contract Interface", required[disposition])
                self.assertNotIn("Impact Register", optional[disposition])
                self.assertNotIn("Stop Conditions", optional[disposition])
                self.assertNotIn("Contract Interface", optional[disposition])

    def test_impact_and_guard_are_required_closed_schema_owners(self) -> None:
        for owner in ("impact", "guard"):
            with self.subTest(owner=owner):
                payload = self.valid_schema_payload()
                payload.pop(owner)

                self.assert_schema_rejected(
                    payload,
                    f"design schema is missing keys: {owner}",
                )

    def test_impact_and_guard_reject_unknown_configuration(self) -> None:
        for owner in ("impact", "guard"):
            with self.subTest(owner=owner):
                payload = self.valid_schema_payload()
                configuration = payload[owner]
                assert isinstance(configuration, dict)
                configuration["copied_owner"] = True

                self.assert_schema_rejected(
                    payload,
                    f"{owner} has unexpected keys",
                )

    def test_contract_rejects_former_impact_and_guard_configuration(self) -> None:
        for key in ("impact_fields", "impact_actions", "guard_fields"):
            with self.subTest(key=key):
                payload = self.valid_schema_payload()
                contract = payload["contract"]
                assert isinstance(contract, dict)
                contract[key] = []

                self.assert_schema_rejected(
                    payload,
                    "contract has unexpected keys",
                )

    def test_invalid_utf8_schema_is_a_controlled_value_error(self) -> None:
        path = self.repository_root / "design-artifact-schema.json"
        path.write_bytes(b"\xff")

        with self.assertRaisesRegex(ValueError, "unable to read JSON object"):
            load_schema(path)

    def test_unknown_top_level_schema_key_is_rejected(self) -> None:
        payload = self.valid_schema_payload()
        payload["parallel_owner"] = {}

        self.assert_schema_rejected(payload, "design schema has unexpected keys")

    def test_duplicate_frontmatter_field_is_rejected(self) -> None:
        payload = self.valid_schema_payload()
        frontmatter = payload["frontmatter"]
        assert isinstance(frontmatter, dict)
        fields = frontmatter["fields"]
        assert isinstance(fields, list)
        fields.append("outcome")

        self.assert_schema_rejected(
            payload, "frontmatter.fields must contain unique strings"
        )

    def test_frontmatter_dispositions_are_exactly_three_supported_profiles(self) -> None:
        payload = self.valid_schema_payload()
        frontmatter = payload["frontmatter"]
        assert isinstance(frontmatter, dict)
        dispositions = frontmatter["dispositions"]
        assert isinstance(dispositions, list)
        dispositions.append("SCHEMA_ONLY")

        self.assert_schema_rejected(
            payload,
            "frontmatter.dispositions must declare the three supported dispositions",
        )

    def test_section_profile_cannot_reference_unknown_section(self) -> None:
        payload = self.valid_schema_payload()
        sections = payload["sections"]
        assert isinstance(sections, dict)
        required = sections["required"]
        assert isinstance(required, dict)
        ready = required["READY_FOR_CONTRACT"]
        assert isinstance(ready, list)
        ready.append("Parallel Decisions")

        self.assert_schema_rejected(
            payload,
            "sections.required.READY_FOR_CONTRACT references unknown section",
        )

    def test_malformed_domain_regex_is_rejected_as_schema_input(self) -> None:
        payload = self.valid_schema_payload()
        candidate = payload["candidate"]
        assert isinstance(candidate, dict)
        candidate["result_patterns"] = ["["]

        self.assert_schema_rejected(
            payload,
            r"candidate.result_patterns\[0\] must be a valid regular expression",
        )

    def test_concern_gate_mapping_cannot_reference_unknown_gate(self) -> None:
        payload = self.valid_schema_payload()
        coverage = payload["coverage"]
        assert isinstance(coverage, dict)
        concern_gate_map = coverage["concern_gate_map"]
        assert isinstance(concern_gate_map, dict)
        concern_gate_map["owner"] = ["Unknown Gate"]

        self.assert_schema_rejected(
            payload,
            "coverage.concern_gate_map.owner references unknown gate",
        )

    def test_status_vocabularies_cannot_overlap_failure_statuses(self) -> None:
        payload = self.valid_schema_payload()
        coverage = payload["coverage"]
        assert isinstance(coverage, dict)
        coverage["blocking_failure_statuses"] = ["failed", "pass"]

        self.assert_schema_rejected(
            payload,
            "blocking failure statuses must not overlap closure statuses",
        )

    def test_ready_and_existing_statuses_share_only_not_applicable(self) -> None:
        payload = self.valid_schema_payload()
        coverage = payload["coverage"]
        assert isinstance(coverage, dict)
        coverage["existing_conditional_statuses"] = [
            "already_closed",
            "not_applicable",
            "pass",
        ]

        self.assert_schema_rejected(
            payload,
            "ready and existing status vocabularies may overlap only at not_applicable",
        )

    def test_locator_source_kind_groups_must_partition_declared_kinds(self) -> None:
        payload = self.valid_schema_payload()
        locators = payload["locators"]
        assert isinstance(locators, dict)
        locators["external_absolute_source_kinds"] = ["other", "repository"]

        self.assert_schema_rejected(
            payload,
            "locator source-kind groups must be disjoint",
        )

    def test_template_marker_requires_canonical_shape_and_positive_count(self) -> None:
        payload = self.valid_schema_payload()
        forbidden_tokens = payload["forbidden_tokens"]
        assert isinstance(forbidden_tokens, dict)
        forbidden_tokens["template_markers"] = {"title": 0}

        self.assert_schema_rejected(
            payload,
            "forbidden_tokens.template_markers has invalid marker",
        )

    def test_meaningful_field_must_be_declared_by_its_record_kind(self) -> None:
        payload = self.valid_schema_payload()
        forbidden_tokens = payload["forbidden_tokens"]
        assert isinstance(forbidden_tokens, dict)
        meaningful_fields = forbidden_tokens["meaningful_fields"]
        assert isinstance(meaningful_fields, dict)
        meaningful_fields["D"] = ["Lock", "Unknown field"]

        self.assert_schema_rejected(
            payload,
            "forbidden_tokens.meaningful_fields.D references unknown field",
        )

    def test_schema_path_requires_repository_root_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "design-artifact-schema.json"
            path.write_text(json.dumps(self.valid_schema_payload()), encoding="utf-8")

            with self.assertRaisesRegex(
                ValueError, "no repository root containing .git"
            ):
                load_schema(path)

    # Permanent-artifact admission: vocabulary-coherence — canonical contract vocabulary must be unique, non-overlapping, and consumed as complete values; incoherent-vocabulary witnesses prevent a second classification owner.
    def test_vocabulary_is_unique_disjoint_and_repository_relative(self) -> None:
        for mutation, expected in self.vocabulary_failures():
            with self.subTest(expected=expected):
                schema_path = self.write_schema(self.valid_schema_payload())
                vocabulary_path = self.write_vocabulary(mutation)
                with self.assertRaisesRegex(ValueError, expected):
                    load_vocabulary(
                        load_schema(schema_path),
                        vocabulary_path,
                    )

    def test_schema_vocabulary_route_is_relative_json_and_cannot_escape_repo(
        self,
    ) -> None:
        for route in ("/tmp/vocabulary.json", "../outside.json", "vocabulary.yaml"):
            with self.subTest(route=route):
                payload = self.valid_schema_payload()
                payload["vocabulary"] = route
                schema_path = self.write_schema(payload)
                with self.assertRaises(ValueError):
                    load_vocabulary(load_schema(schema_path))

    def test_valid_vocabulary_loads_declared_values(self) -> None:
        schema = load_schema(self.write_schema(self.valid_schema_payload()))
        self.write_vocabulary(
            {
                "profiles": ["PROFILE_A"],
                "obligations": ["OBLIGATION_A"],
                "no_obligation": "None",
            }
        )

        vocabulary = load_vocabulary(schema)

        self.assertEqual(vocabulary.profiles, frozenset({"PROFILE_A"}))
        self.assertEqual(vocabulary.obligations, frozenset({"OBLIGATION_A"}))
        self.assertEqual(vocabulary.no_obligation, "None")


if __name__ == "__main__":
    unittest.main()
