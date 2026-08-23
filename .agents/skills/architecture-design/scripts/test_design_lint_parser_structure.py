from __future__ import annotations

import re
import unittest
from dataclasses import replace

import design_lint_parser_test_support as _support

parse_design = _support.parse_design
parse_reference_list = _support.parse_reference_list


class ParserStructureTest(_support.ParserTestCase):

    def test_unknown_heading_and_generic_field_outside_record_are_rejected(
        self,
    ) -> None:
        self.assert_has(
            self.minimal_design().replace(
                "### Sources",
                "### Unknown Source View\n\n### Sources",
                1,
            ),
            "unknown subsection",
        )
        self.assert_has(
            self.minimal_design().replace(
                "## Basis",
                "- Surprise: hidden value\n\n## Basis",
                1,
            ),
            "generic field outside record",
        )

    def test_duplicate_record_id_and_field_are_rejected(self) -> None:
        duplicate_record = """### B-001 — Second blocker
- Kind: `user_decision`
- Gate: `Disposition`
- Need: Another answer.
- Blocks because: The identifier is duplicated.
- Resolution requires: Remove the duplicate.
- Related: R-001

"""
        self.assert_has(
            self.minimal_design().replace(
                "### B-001 — Parser implementation",
                duplicate_record + "### B-001 — Parser implementation",
                1,
            ),
            "duplicate record identifier `B-001`",
        )
        self.assert_has(
            self.minimal_design().replace(
                "- Related: R-001",
                "- Related: R-001\n- Related: E-001",
                1,
            ),
            "duplicate field `Related`",
        )

    def test_tables_are_contiguous_and_require_exact_separator(self) -> None:
        missing_separator = self.minimal_design().replace(
            "| --- | --- | --- | --- |\n| S-001",
            "| S-001",
            1,
        )
        self.assert_has(missing_separator, "table separator")

        non_contiguous = self.minimal_design().replace(
            "| --- | --- | --- | --- |\n| S-001",
            "| --- | --- | --- | --- |\nTable note\n| S-001",
            1,
        )
        self.assert_has(non_contiguous, "table rows must be contiguous")

        blank_gap_cases = (
            self.minimal_design().replace(
                "| --- | --- | --- | --- |\n| S-001",
                "| --- | --- | --- | --- |\n\n| S-001",
                1,
            ),
            self.minimal_design().replace(
                "| S-001 | repository | `AGENTS.md` | Repository authority |",
                """| S-001 | repository | `AGENTS.md` | Repository authority |

| S-002 | repository | `README.md` | Secondary authority |""",
                1,
            ),
        )
        for text in blank_gap_cases:
            with self.subTest(gap=text.count("\n\n")):
                self.assert_has(text, "table rows must be contiguous")

    def test_tables_parse_escaped_pipes_and_code_spans_deterministically(self) -> None:
        text = self.minimal_design().replace(
            "Parse every owned line.",
            r"Parse escaped \| pipe and `code|span`.",
            1,
        )

        parsed, findings = parse_design(text, self.schema())

        self.assertEqual(findings, [])
        assert parsed is not None
        self.assertIn("Requirements", parsed.tables)
        self.assertEqual(
            parsed.tables["Requirements"].rows[0][2],
            "Parse escaped | pipe and `code|span`.",
        )

        self.assert_has(
            text.replace("`code|span`", "`code|span", 1),
            "unclosed code span",
        )

    def test_record_and_reference_ids_use_schema_compiled_patterns(self) -> None:
        schema = self.schema()
        patterns = dict(schema.id_patterns)
        patterns["material_obligation"] = re.compile(r"^Z-[0-9]{2}$")
        mutated_schema = replace(schema, id_patterns=patterns)
        text = self.minimal_design().replace("M-001", "Z-01")

        parsed, findings = parse_design(text, mutated_schema)

        self.assertEqual(findings, [])
        assert parsed is not None
        self.assertIn("Z-01", parsed.records)
        references, reference_findings = parse_reference_list(
            "Z-01",
            allowed=frozenset({"Z"}),
            schema=mutated_schema,
        )
        self.assertEqual(reference_findings, [])
        self.assertEqual(references[0].identifier, "Z-01")

    def test_wrapped_references_use_schema_patterns_and_are_materialized(self) -> None:
        schema = self.schema()
        patterns = dict(schema.id_patterns)
        patterns.update(
            {
                "requirement": re.compile(r"^Q-[0-9]{2}$"),
                "form": re.compile(r"^X-[0-9]{2}$"),
                "decision": re.compile(r"^J-[0-9]{2}$"),
            }
        )
        ready_schema = replace(schema, id_patterns=patterns)
        ready_text = (
            self.ready_design()
            .replace("R-001", "Q-01")
            .replace("F-001", "X-01")
            .replace("D-001", "J-01")
        )

        parsed, findings = parse_design(ready_text, ready_schema)

        self.assertEqual(findings, [])
        assert parsed is not None
        raw_references = [reference.raw for reference in parsed.references]
        self.assertEqual(raw_references.count("X-01"), 3)
        self.assertIn("J-01/owner", raw_references)
        self.assertIn("Q-01", raw_references)

        blocker_patterns = dict(schema.id_patterns)
        blocker_patterns["blocker"] = re.compile(r"^K-[0-9]{2}$")
        blocker_schema = replace(schema, id_patterns=blocker_patterns)
        blocker_text = self.minimal_design().replace("B-001", "K-01")

        blocker_parsed, blocker_findings = parse_design(
            blocker_text,
            blocker_schema,
        )

        self.assertEqual(blocker_findings, [])
        assert blocker_parsed is not None
        self.assertEqual(
            [reference.raw for reference in blocker_parsed.references].count("K-01"),
            3,
        )

    # Permanent-artifact admission: diagram-fence-grammar — one or more DG records are allowed, each with exactly one non-empty mapped fence, while None is exclusive; per-DG fence and outer-parser witnesses remain stable across parser refactors.
    def test_diagrams_require_exact_dg_or_none_alternative(self) -> None:
        diagram = """### DG-001 — Parser state
- Type: `context`
- Question: Which construct owns this line?
- Supports: R-001
```mermaid
graph TD
```"""
        invalid_alternatives = (
            (
                self.minimal_design().replace(diagram, "", 1),
                "one or more DG records or exactly one None",
            ),
            (
                self.minimal_design().replace(
                    diagram,
                    "None: R-001 shows no diagram is needed.\nNone: E-001 confirms it.",
                    1,
                ),
                "exactly one None",
            ),
        )
        for text, expected in invalid_alternatives:
            with self.subTest(expected=expected):
                self.assert_has(text, expected)

        single_none = self.minimal_design().replace(
            diagram,
            "None: R-001 shows no diagram is needed.",
            1,
        )
        _, single_none_findings = parse_design(single_none, self.schema())
        self.assertEqual(single_none_findings, [])

        second_diagram = diagram.replace("DG-001", "DG-002", 1)
        multiple_diagrams = self.minimal_design().replace(
            diagram,
            f"{diagram}\n\n{second_diagram}",
            1,
        )
        parsed, findings = parse_design(multiple_diagrams, self.schema())
        self.assertEqual(findings, [])
        assert parsed is not None
        self.assertEqual(
            parsed.sections["Diagrams"].record_ids,
            ("DG-001", "DG-002"),
        )

    def test_diagram_fence_is_single_non_empty_balanced_and_mapped(self) -> None:
        source = self.minimal_design()
        mutations = (
            ("graph TD", "", "non-empty fenced diagram"),
            (
                "```mermaid\ngraph TD\n```",
                "```mermaid\ngraph TD\n```\n```mermaid\ngraph LR\n```",
                "exactly one fenced diagram",
            ),
            ("```mermaid\ngraph TD", "```dot\ngraph TD", "fence language"),
            (
                "```mermaid\ngraph TD\n```",
                "```mermaid\ngraph TD",
                "unterminated fenced block",
            ),
        )
        for old, new, expected in mutations:
            with self.subTest(expected=expected):
                self.assert_has(source.replace(old, new, 1), expected)


if __name__ == "__main__":
    unittest.main()
