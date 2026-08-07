from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import design_lint


def source_inputs() -> str:
    return """- Prior Design: none
- Research: none
- PLAN: none
- Other: `AGENTS.md`"""


def valid_design() -> str:
    return f"""---
date: 2026-07-16
commit: abc1234
branch: test-branch
disposition: READY_FOR_CONTRACT
product_outcome: >-
  Existing owners publish one current result.
---

# Design: Minimal Valid Design

## Source Inputs

{source_inputs()}

## Target Contract Classification

Profile: `REFACTOR`

Obligations: `None`

ADR Impact: none

## Repository Evidence

- `AGENTS.md:1` / repository policy: `ExistingOwner` is required -> keep one owner.

## Design Form Candidates

### Candidate A

Use the existing owner. Repository evidence rules out a second owner.

## Selected Form

Keep the existing owner and expose its current immutable result.

## Boundary Locks For Change Contract

Owner: Existing owner

In Scope: Current-result publication

Out of Scope: Product behavior

Source of Truth: Existing owner

Compatibility: No public format changes

Order Constraints: Publish after mutation

Temporal Surface Closure: Synchronous publication

All-Or-Nothing Failure Boundary: No new fallible mutation

Negative Proof And Fixture Quarantine: No new negative guarantee

Bounded Recognition Scope: No structured scanner

## Decision Trace

| Decision ID | Decision | Evidence | Future contract handoff target |
| ----------- | -------- | -------- | ------------------------------ |
| D1 | Keep one owner | `AGENTS.md:1` | Boundary Locks |

## Outcome-Proof Fit

| Claim | Concrete failure mode | Acceptance oracle | Proxy risk | Evidence constraints |
| ----- | --------------------- | ----------------- | ---------- | -------------------- |
| One current result | Consumer sees stale state | Read after mutation sees the new value | A mock-only assertion | Observe the owning boundary |

## Hard Gate Check

| Gate | Result | Evidence |
| ---- | ------ | -------- |
| Owner-Level Fix | pass | Existing owner changes |
| Ownership | pass | Existing owner remains responsible |
| Source-Of-Truth Singularity | pass | No second state owner |
| Source-Truth Minimality | pass | No duplicate durable state |
| Boundary-Owned Policy | pass | Publication stays with owner |
| Dependency Direction | pass | Consumer depends on owner seam |
| Outcome-Proof Fit | pass | Oracle observes current result |
| Verification | pass | Owning boundary is observable |
| Future Pressure | pass | Current-result seam remains stable |

## Known Future Pressures

| Pressure | Evidence | Selected-form response | Accepted cost or risk |
| -------- | -------- | ---------------------- | --------------------- |
| More consumers | Existing shared seam | Reuse current-result publication | Synchronous fan-out cost |

## Diagram Requirements

| Type | Design question | Reason |
| ---- | --------------- | ------ |
| none | Is another diagram required? | The single owner and consumer seam are explicit in prose. |

## Provisional Diagrams

None

## Source-Of-Truth Impact

The existing owner remains the only source of truth.

## Verification Strategy

Observe the owner before and after mutation at its public seam.

## Change Contract Handoff

Required profile: `REFACTOR`

Required obligations: `None`

Source inputs to preserve: `AGENTS.md`

Boundary locks to preserve: Existing owner remains sole source of truth

Decision IDs to preserve: D1

Required acceptance oracles and evidence constraints: Read after mutation at the owner seam

Forbidden contract drift: No second state owner

Contract Blocker triggers: Repository evidence contradicts the selected owner

## Open Decisions

None
"""


def messages(text: str, template: bool = False) -> list[str]:
    return [finding.message for finding in design_lint.lint_text(text, template)]


class DesignLintTest(unittest.TestCase):
    def test_valid_active_design_passes(self) -> None:
        self.assertEqual(messages(valid_design()), [])

    def test_unknown_frontmatter_field_is_rejected(self) -> None:
        text = valid_design().replace("commit: abc1234\n", "commit: abc1234\ndesigner: Codex\n")
        self.assertTrue(any("unexpected frontmatter" in item for item in messages(text)))

    def test_missing_or_invalid_frontmatter_is_rejected(self) -> None:
        missing = valid_design().replace("date: 2026-07-16\n", "")
        invalid = valid_design().replace("date: 2026-07-16", "date: 2026-02-31")
        unfolded = valid_design().replace(
            "product_outcome: >-\n  Existing owners publish one current result.",
            "product_outcome: Existing owners publish one current result.",
        )
        self.assertTrue(any("frontmatter" in item for item in messages(missing)))
        self.assertTrue(any("date" in item for item in messages(invalid)))
        self.assertTrue(any("frontmatter" in item for item in messages(unfolded)))

        schema = design_lint.load_schema()
        frontmatter = schema["frontmatter"]
        assert isinstance(frontmatter, dict)
        schema["frontmatter"] = {
            **frontmatter,
            "dispositions": [*frontmatter["dispositions"], "SCHEMA_ONLY"],
        }
        schema_only = valid_design().replace(
            "disposition: READY_FOR_CONTRACT",
            "disposition: SCHEMA_ONLY",
        )
        with mock.patch.object(design_lint, "load_schema", return_value=schema):
            self.assertTrue(any("no semantic validator" in item for item in messages(schema_only)))

        template = Path(__file__).resolve().parents[1] / "assets" / "design-artifact-template.md"
        self.assertEqual(messages(template.read_text(encoding="utf-8"), template=True), [])

    def test_folded_product_outcome_preserves_leading_indented_blank_lines(self) -> None:
        text = valid_design().replace(
            "product_outcome: >-\n  Existing owners publish one current result.",
            "product_outcome: >-\n  \n  \n  Existing owners publish one current result.",
        )
        parsed, findings = design_lint.parse_frontmatter(text)

        self.assertEqual(findings, [])
        self.assertIsNotNone(parsed)
        assert parsed is not None
        self.assertEqual(
            parsed.frontmatter["product_outcome"],
            "\n\nExisting owners publish one current result.",
        )

    def test_reordered_section_is_rejected(self) -> None:
        text = valid_design().replace(
            "## Source Inputs\n\n" + source_inputs() + "\n\n## Target Contract Classification",
            "## Target Contract Classification",
        ) + "\n\n## Source Inputs\n\n" + source_inputs()
        self.assertTrue(any("section order" in item for item in messages(text)))

    def test_missing_or_duplicated_section_is_rejected(self) -> None:
        missing = valid_design().replace("## Provisional Diagrams\n\nNone\n\n", "")
        duplicated = valid_design() + "\n## Open Decisions\n\nNone\n"
        self.assertTrue(any("section" in item for item in messages(missing)))
        self.assertTrue(any("section" in item for item in messages(duplicated)))

    def test_unresolved_fill_marker_is_rejected(self) -> None:
        marker = "{{" + "VALUE" + "}}"
        self.assertTrue(any("fill marker" in item for item in messages(valid_design() + marker)))

    def test_malformed_fill_markers_are_rejected_in_template_mode(self) -> None:
        template = Path(__file__).resolve().parents[1] / "assets" / "design-artifact-template.md"
        template_text = template.read_text(encoding="utf-8")
        for marker in ("{{}}", "{{bad{marker}}}"):
            with self.subTest(marker=marker):
                self.assertIn(
                    f"unknown fill marker `{marker}`",
                    messages(
                        template_text.replace("{{PRODUCT_OUTCOME}}", marker, 1),
                        template=True,
                    ),
                )

    def test_todo_token_is_rejected(self) -> None:
        self.assertTrue(any("placeholder" in item for item in messages(valid_design() + "\nTODO\n")))

    def test_structured_fields_are_rejected(self) -> None:
        text = valid_design().replace(
            "| Claim | Concrete failure mode | Acceptance oracle | Proxy risk | Evidence constraints |",
            "| Claim | Result |",
        )
        self.assertTrue(any("Outcome-Proof Fit" in item for item in messages(text)))

        blocked = (
            valid_design()
            .replace("disposition: READY_FOR_CONTRACT", "disposition: NEEDS_RESEARCH")
            .replace("Profile: `REFACTOR`", "Profile: `Unresolved: confirm the owner`")
            .replace("Obligations: `None`", "Obligations: `Unresolved: confirm the owner`")
            .replace(
                "| Owner-Level Fix | pass | Existing owner changes |\n"
                "| Ownership | pass | Existing owner remains responsible |\n"
                "| Source-Of-Truth Singularity | pass | No second state owner |\n"
                "| Source-Truth Minimality | pass | No duplicate durable state |\n"
                "| Boundary-Owned Policy | pass | Publication stays with owner |\n"
                "| Dependency Direction | pass | Consumer depends on owner seam |\n"
                "| Outcome-Proof Fit | pass | Oracle observes current result |\n"
                "| Verification | pass | Owning boundary is observable |\n"
                "| Future Pressure | pass | Current-result seam remains stable |",
                "| Owner-Level Fix | fail | The owner fact requires research |",
            )
            .replace(
                "## Open Decisions\n\nNone",
                "## Open Decisions\n\n"
                "- Decision needed: Confirm the owner\n"
                "  Blocks because: The owner fact is unavailable\n"
                "  Needed evidence or user choice: Current owner evidence",
            )
        )
        self.assertTrue(
            any(
                "unknown diagram type" in item
                for item in messages(
                    blocked.replace(
                        "| none | Is another diagram required? | The single owner and consumer seam are explicit in prose. |",
                        "| unknown | Is another diagram required? | The single owner and consumer seam are explicit in prose. |",
                    ),
                )
            ),
        )
        self.assertTrue(
            any(
                "single exclusive row" in item
                for item in messages(
                    blocked.replace(
                        "| none | Is another diagram required? | The single owner and consumer seam are explicit in prose. |",
                        "| none | Is another diagram required? | The single owner and consumer seam are explicit in prose. |\n"
                        "| context | Which owner participates? | A second diagram would be needed. |",
                    ),
                )
            ),
        )
        self.assertTrue(
            any(
                "Open Decisions group requires `Blocks because:` exactly once" in item
                for item in messages(
                    blocked.replace(
                        "- Decision needed: Confirm the owner\n"
                        "  Blocks because: The owner fact is unavailable\n"
                        "  Needed evidence or user choice: Current owner evidence",
                        "- Decision needed: Confirm the first owner\n\n"
                        "- Decision needed: Confirm the second owner\n"
                        "  Blocks because: The owner fact is unavailable\n"
                        "  Needed evidence or user choice: Current owner evidence",
                    ),
                )
            ),
        )

    def test_unknown_profile_is_rejected(self) -> None:
        text = valid_design().replace("Profile: `REFACTOR`", "Profile: `UNKNOWN`")
        self.assertTrue(any("unknown profile" in item for item in messages(text)))

    def test_unknown_obligation_is_rejected(self) -> None:
        text = valid_design().replace("Obligations: `None`", "Obligations: `UNKNOWN`")
        self.assertTrue(any("unknown obligation" in item for item in messages(text)))

class DesignLintCliTest(unittest.TestCase):
    def test_valid_file_returns_zero(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "design.md"
            path.write_text(valid_design(), encoding="utf-8")
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(design_lint.main([str(path)]), 0)

    def test_missing_file_returns_two(self) -> None:
        path = Path("missing-design.md")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(design_lint.main([str(path)]), 2)


if __name__ == "__main__":
    unittest.main()
