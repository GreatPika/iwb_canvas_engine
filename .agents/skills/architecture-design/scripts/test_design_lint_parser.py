from __future__ import annotations

import unittest

import design_lint_parser_test_support as _support

parse_design = _support.parse_design
parse_reference_list = _support.parse_reference_list
parse_vocabulary_list = _support.parse_vocabulary_list


class ParserBehaviorTest(_support.ParserTestCase):
    # Permanent-artifact admission: markdown-ownership — every non-empty line must have one canonical grammar owner; free-prose and unknown-heading witnesses prevent untyped architecture after refactors.
    def test_every_non_empty_line_has_one_owner(self) -> None:
        text = self.minimal_design().replace(
            "## Basis",
            "Normative override: D-001 is optional.\n\n## Basis",
        )

        _, findings = parse_design(text, self.schema())

        self.assertIn("free prose is not allowed", self.messages(findings))

    def test_fenced_section_heading_does_not_create_a_section(self) -> None:
        text = self.minimal_design().replace(
            "```mermaid\ngraph TD\n```",
            "```mermaid\n## Not a section\ngraph TD\n```",
        )

        _, findings = parse_design(text, self.schema())

        self.assertNotIn("unknown section", self.messages(findings))

    # Permanent-artifact admission: typed-value-grammar — typed fields accept only complete, duplicate-free, resolvable values of allowed types; wrong-type and trailing-text witnesses survive parser refactors.
    def test_reference_field_rejects_wrong_type_and_duplicate(self) -> None:
        _, wrong_type = parse_reference_list(
            "M-001, D-001", allowed=frozenset({"M"}), schema=self.schema()
        )
        _, duplicate = parse_reference_list(
            "M-001, M-001", allowed=frozenset({"M"}), schema=self.schema()
        )

        self.assertIn("only M references", self.messages(wrong_type))
        self.assertIn("duplicate reference M-001", self.messages(duplicate))

    def test_vocabulary_field_rejects_unparsed_suffix(self) -> None:
        _, findings = parse_vocabulary_list(
            "`None`, UNKNOWN", allowed=frozenset({"None"})
        )

        self.assertIn("unparsed text", self.messages(findings))

    def test_complete_typed_fields_reject_wrong_types_and_suffixes(self) -> None:
        mutations = (
            ("- Basis: R-001, E-001", "- Basis: A-001, E-001", "only E, R references"),
            ("- Depends on: none", "- Depends on: R-001", "only D references"),
            (
                "- Verifies: R-001, D-001/owner",
                "- Verifies: R-001, D-001",
                "decision assurance requires an exact concern",
            ),
            (
                "- Concerns: `form`, `owner`",
                "- Concerns: `form`, `owner` trailing",
                "unparsed text",
            ),
            ("- Depends on: none", "- Depends on: none trailing", "unparsed text"),
            (
                "- ADR Impact: none",
                "- ADR Impact: create ADR-0001 trailing",
                "ADR action",
            ),
            (
                "| E-001 | S-001 | `line 1` |",
                "| E-001 | S-001 | `line 1 trailing` |",
                "evidence locator",
            ),
        )
        for old, new, expected in mutations:
            with self.subTest(expected=expected):
                self.assert_has(self.ready_design().replace(old, new, 1), expected)

    # Permanent-artifact admission: table-grammar — canonical tables require exact contiguous structure and deterministic cell parsing; malformed-table witnesses preserve record boundaries across parser changes.
    def test_minimal_design_builds_schema_owned_ast(self) -> None:
        parsed, findings = parse_design(self.minimal_design(), self.schema())

        self.assertEqual(findings, [])
        self.assertIsNotNone(parsed)
        assert parsed is not None
        self.assertEqual(
            tuple(parsed.sections),
            ("Basis", "Candidate Analysis", "Diagrams", "Open Blockers"),
        )
        self.assertIn("CANDIDATE", parsed.records)
        self.assertEqual(parsed.records["CANDIDATE"].kind, "candidate")
        self.assertEqual(parsed.records["CANDIDATE"].fields["Comparison"], "`blocked`")
        self.assertIn("DG-001", parsed.records)
        self.assertEqual(parsed.records["DG-001"].fields["Type"], "`context`")
        self.assertIn("Requirements", parsed.tables)
        self.assertEqual(parsed.tables["Requirements"].header[0], "ID")
        self.assertEqual(parsed.tables["Requirements"].rows[0][0], "R-001")

    def test_ready_design_builds_contract_synthetic_record(self) -> None:
        parsed, findings = parse_design(self.ready_design(), self.schema())

        self.assertEqual(findings, [])
        self.assertIsNotNone(parsed)
        assert parsed is not None
        self.assertIn("CONTRACT", parsed.records)
        self.assertEqual(parsed.records["CONTRACT"].kind, "contract")
        self.assertEqual(parsed.records["CONTRACT"].fields["Stops"], "H-001")
        self.assertEqual(
            parsed.sections["Contract Interface"].record_ids,
            ("CONTRACT",),
        )
        self.assertEqual(parsed.sections["Impact Register"].record_ids, ())
        self.assertEqual(parsed.sections["Stop Conditions"].record_ids, ("H-001",))

    def test_impact_register_none_is_exclusive_and_exactly_once(self) -> None:
        two_none = self.ready_design().replace(
            "None\n\n## Assurance Register",
            "None\nNone\n\n## Assurance Register",
            1,
        )
        _, duplicate_findings = parse_design(two_none, self.schema())
        duplicate_messages = self.messages(duplicate_findings)
        self.assertEqual(
            duplicate_messages.count("None form must appear exactly once"),
            1,
        )

        mixed = self.ready_design().replace(
            "None\n\n## Assurance Register",
            """None

### I-001 — Durable result
- Action: `update`
- Surface: The repository-owned durable result surface.
- Required by: D-001
- Resulting authority: D-001
- Contract requirement: Update the durable result under D-001 authority.

## Assurance Register""",
            1,
        )
        self.assert_has(mixed, "None is exclusive with impact records")

    def test_stop_conditions_require_records_and_reject_old_nested_layout(self) -> None:
        no_stop = self.ready_design().replace(
            """### H-001 — Parser contradiction
- Trigger: The schema declares a construct the parser cannot own.
- Invalidates: D-001, A-001
- Resolution requires: Re-open parser design against the canonical schema.""",
            "None",
            1,
        )
        self.assert_has(no_stop, "free prose is not allowed")

        nested = (
            self.ready_design()
            .replace(
                "## Impact Register\n\nNone\n\n",
                "",
                1,
            )
            .replace(
                """## Stop Conditions

### H-001 — Parser contradiction
- Trigger: The schema declares a construct the parser cannot own.
- Invalidates: D-001, A-001
- Resolution requires: Re-open parser design against the canonical schema.

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

#### H-001 — Parser contradiction
- Trigger: The schema declares a construct the parser cannot own.
- Invalidates: D-001, A-001
- Resolution requires: Re-open parser design against the canonical schema.

""",
                1,
            )
        )
        self.assert_has(nested, "unknown heading `### Durable Impacts`")

    def test_ready_layout_requires_new_sections_in_order(self) -> None:
        missing = self.ready_design().replace(
            "## Impact Register\n\nNone\n\n",
            "",
            1,
        )
        self.assert_has(missing, "required section `Impact Register` is missing")

        misordered = (
            self.ready_design()
            .replace(
                "## Impact Register",
                "## TEMPORARY",
                1,
            )
            .replace(
                "## Assurance Register",
                "## Impact Register",
                1,
            )
            .replace(
                "## TEMPORARY",
                "## Assurance Register",
                1,
            )
        )
        self.assert_has(misordered, "sections are not in schema order")

    def test_template_mode_defers_typed_marker_resolution(self) -> None:
        text = self.ready_design()
        mutations = (
            ("date: 2026-08-11", "date: {{DATE}}"),
            ("commit: abc1234", "commit: {{COMMIT}}"),
            ("branch: parser-test", "branch: {{BRANCH}}"),
            ("disposition: READY_FOR_CONTRACT", "disposition: {{DISPOSITION}}"),
            ("| S-001 | repository |", "| S-001 | {{SOURCE_KIND}} |"),
            ("- Comparison: `single_viable`", "- Comparison: `{{COMPARISON}}`"),
            ("- Concerns: `form`, `owner`", "- Concerns: `{{CONCERNS}}`"),
            ("- Verifies: R-001, D-001/owner", "- Verifies: {{VERIFIES}}"),
            ("- Profile: `REFACTOR`", "- Profile: `{{PROFILE}}`"),
            ("- Obligations: `None`", "- Obligations: `{{OBLIGATIONS}}`"),
        )
        for old, new in mutations:
            text = text.replace(old, new, 1)

        parsed, findings = parse_design(text, self.schema(), template=True)

        self.assertIsNotNone(parsed)
        self.assertEqual(findings, [])

    def test_template_mode_still_rejects_invalid_literal_values(self) -> None:
        literal_mutations = (
            ("date: 2026-08-11", "date: 2026-02-30", ("valid calendar date",)),
            (
                "- Basis: R-001, E-001",
                "- Basis: A-001, A-001",
                ("only E, R references", "duplicate reference A-001"),
            ),
            ("- Depends on: none", "- Depends on: none trailing", ("unparsed text",)),
            ("- Type: `context`", "- Type: `unknown`", ("unknown vocabulary",)),
        )
        for old, new, expected_messages in literal_mutations:
            with self.subTest(expected_messages=expected_messages):
                _, findings = parse_design(
                    self.ready_design().replace(old, new, 1),
                    self.schema(),
                    template=True,
                )
                messages = self.messages(findings)
                for expected in expected_messages:
                    self.assertIn(expected, messages)

    def test_frontmatter_keys_order_formats_and_folded_values_are_exact(self) -> None:
        mutations = (
            (
                "commit: abc1234\nbranch: parser-test",
                "branch: parser-test\ncommit: abc1234",
                "frontmatter fields must appear exactly once in schema order",
            ),
            ("date: 2026-08-11", "date: 2026-02-30", "valid calendar date"),
            ("commit: abc1234", "commit: not-a-hash", "commit format"),
            ("outcome: R-001", "outcome: >\n  R-001", "folded frontmatter values"),
            (
                "branch: parser-test",
                "parallel: true\nbranch: parser-test",
                "frontmatter fields",
            ),
        )
        for old, new, expected in mutations:
            with self.subTest(expected=expected):
                self.assert_has(self.minimal_design().replace(old, new, 1), expected)

    def test_h1_sections_and_subsections_are_exact(self) -> None:
        mutations = (
            (
                "# Design: Parser Boundary",
                "# Parser Boundary",
                "exactly one `# Design: `",
            ),
            ("## Basis", "## Mystery", "unknown section"),
            ("### Source Coverage", "### Parallel Coverage", "unknown subsection"),
            ("## Basis", "## Candidate Analysis", "duplicate section"),
            ("## Open Blockers", "Open Blockers", "required section `Open Blockers`"),
        )
        for old, new, expected in mutations:
            with self.subTest(expected=expected):
                self.assert_has(self.minimal_design().replace(old, new, 1), expected)

        reversed_sections = (
            self.minimal_design()
            .replace("## Basis", "## TEMPORARY", 1)
            .replace("## Candidate Analysis", "## Basis", 1)
            .replace("## TEMPORARY", "## Candidate Analysis", 1)
        )
        self.assert_has(reversed_sections, "sections are not in schema order")


if __name__ == "__main__":
    unittest.main()
