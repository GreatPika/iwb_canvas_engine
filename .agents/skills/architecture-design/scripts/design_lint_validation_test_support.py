from __future__ import annotations

import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from design_lint_model import ContractVocabulary, ParsedDesign, Section
from design_lint_validation import validate_design

from design_lint_validation_graph import _Graph, _record, _table
from design_lint_validation_schema import _schema


class ValidationTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.repository_directory = tempfile.TemporaryDirectory()
        self.external_directory = tempfile.TemporaryDirectory()
        self.repository_root = Path(self.repository_directory.name)
        (self.repository_root / ".git").mkdir()
        for name in ("prior.md", "research.md", "plan.md", "source.md"):
            (self.repository_root / name).write_text(
                "line one\nline two\nline three\n",
                encoding="utf-8",
            )
        self.external_source = Path(self.external_directory.name) / "other.md"
        self.external_source.write_text(
            "external one\nexternal two\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.external_directory.cleanup()
        self.repository_directory.cleanup()

    def validate(self, graph: _Graph) -> str:
        findings = validate_design(
            graph.parsed,
            graph.schema,
            graph.vocabulary,
        )
        return "\n".join(finding.message for finding in findings)

    def minimal_ready_graph(self) -> _Graph:
        schema = _schema(self.repository_root)
        source_rows = (
            ("S-001", "prior_design", "`prior.md`", "Prior accepted design"),
            ("S-002", "research", "`research.md`", "Accepted research"),
            ("S-003", "plan", "`plan.md`", "Accepted implementation plan"),
            ("S-004", "user", "user request", "Explicit product direction"),
            ("S-005", "repository", "`source.md`", "Current repository authority"),
            (
                "S-006",
                "other",
                f"`{self.external_source}`",
                "Accepted external input",
            ),
        )
        evidence_rows = (
            ("E-001", "S-005", "`line 1`", "The repository owner is current."),
            ("E-002", "S-006", "`line 1`", "The external constraint is accepted."),
        )
        requirement_rows = (
            (
                "R-001",
                "outcome",
                "Publish one consumer-visible result.",
                "S-004, E-001",
                "Internal helper shape remains open.",
            ),
            (
                "R-002",
                "repository_rule",
                "Keep the repository owner authoritative.",
                "S-005, E-001",
                "Publication mechanics remain open.",
            ),
            (
                "R-003",
                "user_decision",
                "Preserve the accepted external constraint.",
                "S-006, E-002",
                "Incidental organization remains open.",
            ),
            (
                "R-004",
                "exclusion",
                "Do not create a second authority.",
                "S-001, S-002, S-003, E-001",
                "Non-authoritative local helpers remain allowed.",
            ),
        )
        form_rows = (
            (
                "F-001",
                "Use the existing owner.",
                "pass",
                "Smallest lifecycle surface.",
                "R-001, R-002, R-003, R-004, E-001",
            ),
            (
                "F-002",
                "Create a second authority.",
                "pass",
                "Adds drift and retirement cost.",
                "R-001, R-004, E-001",
            ),
        )
        material_rows = (
            ("M-001", "R-002", "yes", "yes", "R-002"),
            (
                "M-002",
                "Reuse the accepted external boundary.",
                "yes",
                "no",
                "R-003, E-002",
            ),
        )
        pressure_rows = (
            (
                "P-001",
                "More consumers may arrive.",
                "S-005, E-001",
                "absorbed",
                "D-001",
                "Synchronous fan-out is accepted until evidence changes.",
            ),
        )
        all_secondary_concerns = (
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
        )
        assurance_concerns = (
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
        )
        records = {
            row[0]: _record(
                row[0],
                "S",
                {"Kind": row[1], "Locator": row[2], "Use": row[3]},
                10 + index,
            )
            for index, row in enumerate(source_rows)
        }
        records.update(
            {
                row[0]: _record(
                    row[0],
                    "E",
                    {
                        "Source": row[1],
                        "Locator": row[2],
                        "Observed fact": row[3],
                    },
                    20 + index,
                )
                for index, row in enumerate(evidence_rows)
            }
        )
        records.update(
            {
                row[0]: _record(
                    row[0],
                    "R",
                    {
                        "Kind": row[1],
                        "Statement": row[2],
                        "Basis": row[3],
                        "Open shape": row[4],
                    },
                    30 + index,
                )
                for index, row in enumerate(requirement_rows)
            }
        )
        records["CANDIDATE"] = _record(
            "CANDIDATE",
            "candidate",
            {
                "Comparison": "`two_or_three`",
                "Result": "`selected F-001`",
                "Result basis": (
                    "F-001, F-002, M-001, M-002, R-001, R-002, "
                    "R-003, R-004, E-001, E-002"
                ),
            },
            40,
            title="Candidate Analysis",
        )
        records.update(
            {
                row[0]: _record(
                    row[0],
                    "F",
                    {
                        "Form": row[1],
                        "Hard constraints": row[2],
                        "Main trade-off": row[3],
                        "Basis": row[4],
                    },
                    45 + index,
                )
                for index, row in enumerate(form_rows)
            }
        )
        records.update(
            {
                row[0]: _record(
                    row[0],
                    "M",
                    {
                        "Material obligation": row[1],
                        "F-001": row[2],
                        "F-002": row[3],
                        "Independent authority": row[4],
                    },
                    50 + index,
                )
                for index, row in enumerate(material_rows)
            }
        )
        records.update(
            {
                row[0]: _record(
                    row[0],
                    "P",
                    {
                        "Pressure": row[1],
                        "Basis": row[2],
                        "Treatment": row[3],
                        "Closure refs": row[4],
                        "Accepted cost or risk": row[5],
                    },
                    55 + index,
                )
                for index, row in enumerate(pressure_rows)
            }
        )
        records["D-001"] = _record(
            "D-001",
            "D",
            {
                "Concerns": "`form`",
                "Lock": "The selected existing-owner form is mandatory.",
                "Open": "Internal helper decomposition remains open.",
                "Basis": "R-001, R-002, R-003, R-004, E-001, E-002",
                "Form": "F-001",
                "Realizes": "M-001, M-002",
                "Depends on": "none",
                "Contract targets": "`classification`, `unit_family`",
                "Rationale": "It satisfies every obligation with one authority.",
            },
            60,
        )
        records["D-002"] = _record(
            "D-002",
            "D",
            {
                "Concerns": ", ".join(f"`{item}`" for item in all_secondary_concerns),
                "Lock": "Ownership, scope, compatibility, order, and lifecycle are fixed.",
                "Open": "Incidental implementation organization remains open.",
                "Basis": "R-001, R-002, R-003, R-004, E-001, E-002",
                "Form": "F-001",
                "Realizes": "none",
                "Depends on": "D-001",
                "Contract targets": ", ".join(
                    f"`{item}`"
                    for item in (
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
                        "unit_family",
                    )
                ),
                "Rationale": "The complete boundary prevents downstream redesign.",
            },
            61,
        )
        records["A-001"] = _record(
            "A-001",
            "A",
            {
                "Verifies": "R-001",
                "Claim": "Consumers observe the current owner result.",
                "Failure": "A stale or copied value is observed.",
                "Oracle": "Mutate the real owner and read through the public seam.",
                "Proxy risk": "A mock can pass while the real value stays stale.",
                "Evidence constraints": "Use the real owner and consumer path.",
                "Architecture seam": "The public owner read boundary is exercised.",
            },
            70,
        )
        records["A-002"] = _record(
            "A-002",
            "A",
            {
                "Verifies": ", ".join(
                    f"D-002/{concern}" for concern in assurance_concerns
                ),
                "Claim": "Every observable architecture boundary remains closed.",
                "Failure": "A boundary changes without direct detection.",
                "Oracle": "Exercise each named boundary through its public seam.",
                "Proxy risk": "Private-shape assertions can miss observable drift.",
                "Evidence constraints": "Use direct behavior at each boundary.",
                "Architecture seam": "The owner, order, and lifecycle seams are exercised.",
            },
            71,
        )
        records["CONTRACT"] = _record(
            "CONTRACT",
            "contract",
            {
                "Profile": "`PROFILE_A`",
                "Obligations": "`OBLIGATION_A`",
                "ADR Impact": "none",
                "Sources": ", ".join(row[0] for row in source_rows),
                "Requirements": ", ".join(row[0] for row in requirement_rows),
                "Commitments": "D-001, D-002",
                "Assurance": "A-001, A-002",
                "Impacts": "none",
                "Stops": "H-001",
            },
            80,
            title="Contract Interface",
        )
        records["H-001"] = _record(
            "H-001",
            "H",
            {
                "Trigger": "Accepted evidence contradicts D-001 or D-002.",
                "Invalidates": "D-001, D-002, A-001, A-002",
                "Resolution requires": "Re-open architecture with the contradiction.",
            },
            81,
        )

        source_coverage_rows = tuple(
            (kind, source_id)
            for kind, source_id in zip(
                schema.raw["basis"]["source_kinds"],  # type: ignore[index]
                (row[0] for row in source_rows),
            )
        )
        architecture_rows = tuple(
            (concern, "closed", "D-002") for concern in all_secondary_concerns
        )
        gate_support = {
            "Owner-Level Fix": "D-002, A-002, R-001",
            "Ownership": "D-002, A-002",
            "Source-Of-Truth Singularity": "D-002, A-002",
            "Source-Truth Minimality": "D-002, A-002, F-001, F-002, M-001, M-002",
            "Boundary-Owned Policy": "D-002, A-002",
            "Dependency Direction": "D-002, A-002",
            "Solution Proportionality": (
                "F-001, F-002, M-001, M-002, R-002, R-003, E-002"
            ),
            "Outcome-Proof Fit": "A-001",
            "Verification": "A-001, A-002",
            "Future Pressure": "P-001, E-001",
            "Handoff Consumability": ("CONTRACT, D-001, D-002, A-001, A-002, H-001"),
            "Negative Proof And Fixture Quarantine": "D-002, A-002",
            "State/Data Ownership": "D-002, A-002",
            "Sequenced Migration And Retirement": "D-002, A-002",
            "Temporal Surface Closure": "D-002, A-002",
            "All-Or-Nothing Failure Boundary": "D-002, A-002",
            "Bounded Recognition Scope": "D-002, A-002",
        }
        all_gates = (
            *schema.raw["coverage"]["core_gates"],  # type: ignore[index]
            *schema.raw["coverage"]["conditional_gates"],  # type: ignore[index]
        )
        gate_rows = tuple((gate, "pass", gate_support[gate]) for gate in all_gates)
        tables = {
            "Sources": _table(
                "Sources",
                ("ID", "Kind", "Locator", "Use"),
                source_rows,
                10,
            ),
            "Source Coverage": _table(
                "Source Coverage",
                ("Kind", "Sources or none"),
                source_coverage_rows,
                16,
            ),
            "Evidence": _table(
                "Evidence",
                ("ID", "Source", "Locator", "Observed fact"),
                evidence_rows,
                20,
            ),
            "Requirements": _table(
                "Requirements",
                ("ID", "Kind", "Statement", "Basis", "Open shape"),
                requirement_rows,
                30,
            ),
            "Forms": _table(
                "Forms",
                ("ID", "Form", "Hard constraints", "Main trade-off", "Basis"),
                form_rows,
                45,
            ),
            "Material-Obligation Delta": _table(
                "Material-Obligation Delta",
                (
                    "ID",
                    "Material obligation",
                    "F-001",
                    "F-002",
                    "Independent authority",
                ),
                material_rows,
                50,
            ),
            "Future Pressures": _table(
                "Future Pressures",
                (
                    "ID",
                    "Pressure",
                    "Basis",
                    "Treatment",
                    "Closure refs",
                    "Accepted cost or risk",
                ),
                pressure_rows,
                55,
            ),
            "Architecture Closure": _table(
                "Architecture Closure",
                ("Concern", "Status", "Support refs"),
                architecture_rows,
                90,
            ),
            "Gate Closure": _table(
                "Gate Closure",
                ("Gate", "Status", "Support refs"),
                gate_rows,
                110,
            ),
        }
        sections = {
            "Basis": Section(
                "Basis",
                9,
                tuple(
                    [
                        *(row[0] for row in source_rows),
                        *(row[0] for row in evidence_rows),
                        *(row[0] for row in requirement_rows),
                    ]
                ),
                ("Sources", "Source Coverage", "Evidence", "Requirements"),
            ),
            "Candidate Analysis": Section(
                "Candidate Analysis",
                40,
                (
                    "CANDIDATE",
                    *(row[0] for row in form_rows),
                    *(row[0] for row in material_rows),
                    *(row[0] for row in pressure_rows),
                ),
                ("Forms", "Material-Obligation Delta", "Future Pressures"),
            ),
            "Decision Register": Section(
                "Decision Register", 59, ("D-001", "D-002"), ()
            ),
            "Impact Register": Section("Impact Register", 66, (), ()),
            "Assurance Register": Section(
                "Assurance Register", 69, ("A-001", "A-002"), ()
            ),
            "Stop Conditions": Section("Stop Conditions", 76, ("H-001",), ()),
            "Contract Interface": Section("Contract Interface", 79, ("CONTRACT",), ()),
            "Diagrams": Section("Diagrams", 85, (), ()),
            "Readiness Matrix": Section(
                "Readiness Matrix",
                89,
                (),
                ("Architecture Closure", "Gate Closure"),
            ),
            "Open Blockers": Section("Open Blockers", 130, (), ()),
        }
        parsed = ParsedDesign(
            frontmatter={
                "schema": "architecture-design/v4",
                "date": "2026-08-11",
                "commit": "8652749",
                "branch": "test",
                "disposition": "READY_FOR_CONTRACT",
                "outcome": "R-001",
            },
            sections=sections,
            records=records,
            tables=tables,
            references=(),
            body_line=9,
        )
        return _Graph(
            parsed=parsed,
            schema=schema,
            vocabulary=ContractVocabulary(
                profiles=frozenset({"PROFILE_A"}),
                obligations=frozenset({"OBLIGATION_A"}),
                no_obligation="None",
            ),
        )

    def graph_with_projection_only_orphan(self, kind: str) -> _Graph:
        graph = self.minimal_ready_graph()
        if kind == "S":
            graph = graph.add_record(
                "Basis",
                _record(
                    "S-099",
                    "S",
                    {
                        "Kind": "repository",
                        "Locator": "`source.md`",
                        "Use": "S-099 appears only in its own prose and indexes.",
                    },
                    18,
                ),
            )
            sources = graph.parsed.tables["Sources"]
            graph = graph.replace_table(
                "Sources",
                replace(
                    sources,
                    rows=(
                        *sources.rows,
                        (
                            "S-099",
                            "repository",
                            "`source.md`",
                            "S-099 appears only in its own prose and indexes.",
                        ),
                    ),
                    row_lines=(*sources.row_lines, 18),
                ),
            ).replace_table_row(
                "Source Coverage",
                "repository",
                ("repository", "S-005, S-099"),
            )
            return graph.replace_record(
                "CONTRACT",
                Sources="S-001, S-002, S-003, S-004, S-005, S-006, S-099",
            )
        if kind == "R":
            graph = graph.add_record(
                "Basis",
                _record(
                    "R-099",
                    "R",
                    {
                        "Kind": "constraint",
                        "Statement": "R-099 is mentioned only by itself and the index.",
                        "Basis": "S-005",
                        "Open shape": "Incidental shape remains open.",
                    },
                    34,
                ),
            )
            requirements = graph.parsed.tables["Requirements"]
            graph = graph.replace_table(
                "Requirements",
                replace(
                    requirements,
                    rows=(
                        *requirements.rows,
                        (
                            "R-099",
                            "constraint",
                            "R-099 is mentioned only by itself and the index.",
                            "S-005",
                            "Incidental shape remains open.",
                        ),
                    ),
                    row_lines=(*requirements.row_lines, 34),
                ),
            )
            return graph.replace_record(
                "CONTRACT",
                Requirements="R-001, R-002, R-003, R-004, R-099",
            )
        if kind == "D":
            graph = graph.add_record(
                "Decision Register",
                _record(
                    "D-099",
                    "D",
                    {
                        "Concerns": "`compatibility`",
                        "Lock": "A projection-only decision lock.",
                        "Open": "Incidental implementation remains open.",
                        "Basis": "R-001",
                        "Form": "F-001",
                        "Realizes": "none",
                        "Depends on": "D-002",
                        "Contract targets": "`compatibility`",
                        "Rationale": "The record is intentionally not consumed.",
                    },
                    62,
                ),
            )
            return graph.replace_record(
                "CONTRACT",
                Commitments="D-001, D-002, D-099",
            )
        if kind == "A":
            graph = graph.add_record(
                "Assurance Register",
                _record(
                    "A-099",
                    "A",
                    {
                        "Verifies": "D-002/temporal",
                        "Claim": "A projection-only assurance claim.",
                        "Failure": "The assurance has no gate consumer.",
                        "Oracle": "A direct temporal oracle exists.",
                        "Proxy risk": "The index can mask an unused proof.",
                        "Evidence constraints": "Use the real temporal seam.",
                        "Architecture seam": "The temporal boundary is exercised.",
                    },
                    73,
                ),
            )
            return graph.replace_record(
                "CONTRACT",
                Assurance="A-001, A-002, A-099",
            )
        if kind == "I":
            graph = graph.add_record(
                "Impact Register",
                _record(
                    "I-099",
                    "I",
                    {
                        "Action": "update",
                        "Surface": "A projection-only durable surface.",
                        "Required by": "D-002",
                        "Resulting authority": "D-002",
                        "Contract requirement": (
                            "Update the projection-only surface under D-002."
                        ),
                    },
                    83,
                ),
            )
            return graph.replace_record("CONTRACT", Impacts="I-099")
        if kind == "H":
            graph = graph.add_record(
                "Stop Conditions",
                _record(
                    "H-099",
                    "H",
                    {
                        "Trigger": "A projection-only stop trigger appears.",
                        "Invalidates": "D-002",
                        "Resolution requires": "Re-open the projection-only stop.",
                    },
                    84,
                ),
            )
            return graph.replace_record("CONTRACT", Stops="H-001, H-099")
        raise AssertionError(f"unsupported orphan kind {kind}")

    def minimal_blocking_graph(
        self,
        blocker_kind: str,
        *,
        with_matrix: bool = False,
    ) -> _Graph:
        if blocker_kind not in {"research", "user_decision"}:
            raise AssertionError(f"unsupported blocker kind {blocker_kind}")
        if with_matrix and blocker_kind != "user_decision":
            raise AssertionError("partial matrix fixture is user-decision only")
        graph = self.minimal_ready_graph()
        blocker_gate = (
            "Verification"
            if with_matrix
            else "Source Authority"
            if blocker_kind == "research"
            else "Candidate Comparison"
        )
        graph = (
            graph.replace_frontmatter(disposition="BLOCKED")
            .replace_record(
                "CANDIDATE",
                Comparison="`blocked`",
                Result="`blocked B-001`",
                **{
                    "Result basis": (
                        "B-001, F-001, F-002, M-001, M-002, P-001, "
                        "R-001, R-002, R-003, R-004, E-001, E-002"
                    )
                },
            )
            .add_record(
                "Open Blockers",
                _record(
                    "B-001",
                    "B",
                    {
                        "Kind": blocker_kind,
                        "Gate": blocker_gate,
                        "Need": "Resolve the exact missing authority before continuing.",
                        "Blocks because": "The next architecture choice is not yet valid.",
                        "Resolution requires": "Accepted evidence or an explicit decision.",
                        "Related": (
                            "R-001, R-002, R-003, R-004, E-001, E-002, "
                            "F-001, F-002, M-001, M-002, P-001"
                        ),
                    },
                    131,
                ),
            )
        )
        keep_kinds = {"S", "E", "R", "F", "M", "P", "B"}
        keep_sections = {"Basis", "Candidate Analysis", "Open Blockers"}
        keep_tables = {
            "Sources",
            "Source Coverage",
            "Evidence",
            "Requirements",
            "Forms",
            "Material-Obligation Delta",
            "Future Pressures",
        }
        if with_matrix:
            keep_kinds.update({"D", "A"})
            keep_sections.update(
                {"Decision Register", "Assurance Register", "Readiness Matrix"}
            )
            keep_tables.update({"Architecture Closure", "Gate Closure"})
        records = {
            identifier: record
            for identifier, record in graph.parsed.records.items()
            if record.kind in keep_kinds or record.kind == "candidate"
        }
        sections = {
            name: section
            for name, section in graph.parsed.sections.items()
            if name in keep_sections
        }
        tables = {
            name: table
            for name, table in graph.parsed.tables.items()
            if name in keep_tables
        }
        if with_matrix:
            architecture = tables["Architecture Closure"]
            tables["Architecture Closure"] = replace(
                architecture,
                rows=architecture.rows[:3],
                row_lines=architecture.row_lines[:3],
            )
            gates = tables["Gate Closure"]
            verification_index = next(
                index
                for index, row in enumerate(gates.rows)
                if row[0] == "Verification"
            )
            tables["Gate Closure"] = replace(
                gates,
                rows=(
                    *gates.rows[:verification_index],
                    ("Verification", "failed", "B-001"),
                ),
                row_lines=gates.row_lines[: verification_index + 1],
            )
        else:
            records["P-001"] = replace(
                records["P-001"],
                fields={
                    **records["P-001"].fields,
                    "Closure refs": "B-001",
                },
            )
        return replace(
            graph,
            parsed=replace(
                graph.parsed,
                records=records,
                sections=sections,
                tables=tables,
            ),
        )
