from __future__ import annotations

import datetime as dt
import re
from dataclasses import dataclass
from typing import Mapping, Sequence, cast

from design_lint_model import DesignSchema, Finding, ParsedDesign, Section

from design_lint_parser_common import (
    _Context,
    _FIELD_PATTERN,
    _Fence,
    _SectionSlice,
    _frontmatter_close,
    _is_deferred_marker_value,
    _is_fenced,
    _match_reference,
    _schema_object,
)
from design_lint_parser_sections import _parse_section
from design_lint_parser_values import _validate_typed_values


_TEMPLATE_MARKER_PATTERN = re.compile(r"\{\{[A-Z][A-Z0-9_]*\}\}")
_BRACE_MARKER_RESIDUE_PATTERN = re.compile(r"\{\{[^\r\n]*\}\}")


def parse_design(
    text: str,
    schema: DesignSchema,
    *,
    template: bool = False,
    checkpoint: str | None = None,
) -> tuple[ParsedDesign | None, list[Finding]]:
    lines = _checkpoint_prefix_lines(text, schema, checkpoint)
    if not lines or lines[0] != "---":
        return None, [Finding(1, "frontmatter", "frontmatter must start with `---`")]

    context = _Context(
        lines=lines,
        schema=schema,
        template=template,
        owners=[0] * len(lines),
        fence_membership=[None] * len(lines),
    )
    _validate_forbidden_tokens(context)
    frontmatter, close = _parse_frontmatter(context)
    if close is None:
        return None, context.findings
    context.disposition = (
        "READY_FOR_CONTRACT" if template else frontmatter.get("disposition", "")
    )

    _classify_fences(context, close + 1)
    slices, section_lines = _parse_body_structure(
        context,
        frontmatter,
        close,
        checkpoint=checkpoint,
    )
    for section in slices:
        _parse_section(context, section)

    _validate_typed_values(context)
    _finish_line_ownership(context)
    sections = {
        name: Section(
            name=name,
            line=line,
            record_ids=tuple(context.section_record_ids.get(name, ())),
            table_names=tuple(context.section_table_names.get(name, ())),
        )
        for name, line in section_lines.items()
    }
    return (
        ParsedDesign(
            frontmatter=frontmatter,
            sections=sections,
            records=context.records,
            tables=context.tables,
            references=tuple(context.references),
            body_line=close + 2,
        ),
        context.findings,
    )


def _checkpoint_prefix_lines(
    text: str,
    schema: DesignSchema,
    checkpoint: str | None,
) -> list[str]:
    lines = text.splitlines()
    if checkpoint is None:
        return lines

    sections = _schema_object(schema, "sections")
    declared_order = tuple(cast(list[str], sections["order"]))
    positions = {name: index for index, name in enumerate(declared_order)}
    target_index = positions.get(checkpoint)
    if target_index is None:
        return lines

    in_fence = False
    checkpoint_seen = False
    following_section: int | None = None
    for index, line in enumerate(lines):
        if line.strip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or not line.startswith("## "):
            continue

        section_name = line[3:].strip()
        if checkpoint_seen:
            following_section = index
            break
        if section_name == checkpoint:
            checkpoint_seen = True
        elif positions.get(section_name, -1) > target_index:
            following_section = index
            break

    return lines[:following_section]


@dataclass(frozen=True)
class _MarkerInventory:
    occurrences: tuple[tuple[int, str], ...]
    malformed: tuple[tuple[int, str], ...]
    counts: Mapping[str, int]
    first_lines: Mapping[str, int]

    @classmethod
    def scan(cls, lines: Sequence[str]) -> _MarkerInventory:
        occurrences: list[tuple[int, str]] = []
        malformed: list[tuple[int, str]] = []
        counts: dict[str, int] = {}
        first_lines: dict[str, int] = {}
        for index, line in enumerate(lines):
            line_number = index + 1
            for match in _TEMPLATE_MARKER_PATTERN.finditer(line):
                marker = match.group(0)
                occurrences.append((line_number, marker))
                counts[marker] = counts.get(marker, 0) + 1
                first_lines.setdefault(marker, line_number)
            residue = _TEMPLATE_MARKER_PATTERN.sub("", line)
            malformed.extend(
                (line_number, match.group(0))
                for match in _BRACE_MARKER_RESIDUE_PATTERN.finditer(residue)
            )
        return cls(tuple(occurrences), tuple(malformed), counts, first_lines)


def _validate_active_tokens(context: _Context, active_tokens: list[str]) -> None:
    for token in active_tokens:
        pattern = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(token)}(?![A-Za-z0-9_])")
        for index, line in enumerate(context.lines):
            for _match in pattern.finditer(line):
                context.findings.append(
                    Finding(
                        index + 1,
                        "placeholder",
                        f"placeholder token `{token}` is not allowed",
                    )
                )


def _validate_template_markers(
    context: _Context,
    expected: Mapping[str, int],
    inventory: _MarkerInventory,
) -> None:
    for line, marker in inventory.occurrences:
        if marker not in expected:
            context.findings.append(
                Finding(
                    line,
                    "fill-marker",
                    f"unknown fill marker `{marker}`",
                )
            )
    for marker, expected_count in expected.items():
        actual_count = inventory.counts.get(marker, 0)
        if actual_count != expected_count:
            context.findings.append(
                Finding(
                    inventory.first_lines.get(marker, 1),
                    "fill-marker",
                    f"fill marker `{marker}` occurs {actual_count} times; "
                    f"expected {expected_count}",
                )
            )


def _validate_forbidden_tokens(context: _Context) -> None:
    forbidden = _schema_object(context.schema, "forbidden_tokens")
    _validate_active_tokens(
        context,
        cast(list[str], forbidden.get("active_tokens", [])),
    )

    raw_markers = forbidden.get("template_markers")
    assert isinstance(raw_markers, dict)
    expected = cast(dict[str, int], raw_markers)
    inventory = _MarkerInventory.scan(context.lines)
    for line, marker in inventory.malformed:
        context.findings.append(
            Finding(
                line,
                "fill-marker",
                f"malformed fill marker `{marker}`",
            )
        )
    if context.template:
        _validate_template_markers(context, expected, inventory)
        return
    for line, marker in inventory.occurrences:
        context.findings.append(
            Finding(
                line,
                "fill-marker",
                f"unresolved fill marker `{marker}`",
            )
        )


def _parse_frontmatter(
    context: _Context,
) -> tuple[dict[str, str], int | None]:
    context.consume(0)
    close = _frontmatter_close(context.lines)
    if close is None:
        context.findings.append(
            Finding(1, "frontmatter", "frontmatter closing `---` is missing")
        )
        return {}, None

    frontmatter: dict[str, str] = {}
    order: list[str] = []
    field_lines: dict[str, int] = {}
    for index in range(1, close):
        raw = context.lines[index]
        if not raw.strip():
            continue
        context.consume(index)
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*):[ \t]*(.*)", raw)
        if match is None:
            context.findings.append(
                Finding(index + 1, "frontmatter", "invalid frontmatter field line")
            )
            if raw[:1].isspace():
                context.findings.append(
                    Finding(
                        index + 1,
                        "frontmatter",
                        "folded frontmatter values are not allowed",
                    )
                )
            continue
        name, value = match.groups()
        order.append(name)
        if value in {">", "|"}:
            context.findings.append(
                Finding(
                    index + 1,
                    "frontmatter",
                    "folded frontmatter values are not allowed",
                )
            )
        if name in frontmatter:
            context.findings.append(
                Finding(
                    index + 1, "frontmatter", f"duplicate frontmatter field `{name}`"
                )
            )
            continue
        frontmatter[name] = value.strip()
        field_lines[name] = index + 1
    context.consume(close)

    if tuple(order) != context.schema.frontmatter_fields:
        context.findings.append(
            Finding(
                1,
                "frontmatter",
                "frontmatter fields must appear exactly once in schema order",
            )
        )
    _validate_frontmatter_values(context, frontmatter, field_lines)
    return frontmatter, close


def _validate_date_value(
    context: _Context,
    value: str,
    line: int,
    pattern: str,
) -> None:
    if _is_deferred_marker_value(context, value):
        return
    if re.fullmatch(pattern, value) is None:
        context.findings.append(Finding(line, "date", "date format is invalid"))
        return
    try:
        dt.date.fromisoformat(value)
    except ValueError:
        context.findings.append(
            Finding(line, "date", "date must be a valid calendar date")
        )


def _validate_pattern_value(
    context: _Context,
    value: str,
    line: int,
    *,
    pattern: str,
    code: str,
    message: str,
) -> None:
    if not _is_deferred_marker_value(context, value) and re.fullmatch(
        pattern, value
    ) is None:
        context.findings.append(Finding(line, code, message))


def _validate_outcome_reference(
    context: _Context,
    value: str,
    line: int,
) -> None:
    matched = _match_reference(value, context.schema)
    if _is_deferred_marker_value(context, value):
        return
    if matched is None or matched[1] != "requirement":
        context.findings.append(
            Finding(line, "outcome", "outcome reference format is invalid")
        )
        return
    context.references.append(matched[0])


def _validate_frontmatter_values(
    context: _Context,
    frontmatter: Mapping[str, str],
    field_lines: Mapping[str, int],
) -> None:
    raw = _schema_object(context.schema, "frontmatter")
    for field_name in context.schema.frontmatter_fields:
        if not frontmatter.get(field_name, ""):
            context.findings.append(
                Finding(
                    field_lines.get(field_name, 1),
                    "frontmatter",
                    f"frontmatter field `{field_name}` must not be empty",
                )
            )

    schema_value = frontmatter.get("schema", "")
    if (
        not _is_deferred_marker_value(context, schema_value)
        and schema_value != context.schema.version
    ):
        context.findings.append(
            Finding(
                field_lines.get("schema", 1),
                "schema",
                "unsupported design schema version",
            )
        )

    _validate_date_value(
        context,
        frontmatter.get("date", ""),
        field_lines.get("date", 1),
        cast(str, raw["date_pattern"]),
    )
    _validate_pattern_value(
        context,
        frontmatter.get("commit", ""),
        field_lines.get("commit", 1),
        pattern=cast(str, raw["commit_pattern"]),
        code="commit",
        message="commit format is invalid",
    )

    disposition = frontmatter.get("disposition", "")
    if (
        not _is_deferred_marker_value(context, disposition)
        and disposition not in context.schema.dispositions
    ):
        context.findings.append(
            Finding(
                field_lines.get("disposition", 1),
                "disposition",
                f"unknown disposition `{disposition}`",
            )
        )

    _validate_outcome_reference(
        context,
        frontmatter.get("outcome", ""),
        field_lines.get("outcome", 1),
    )


def _classify_fences(context: _Context, start: int) -> None:
    open_index: int | None = None
    language = ""
    for index in range(start, len(context.lines)):
        stripped = context.lines[index].strip()
        if open_index is None:
            if stripped.startswith("```"):
                open_index = index
                language = stripped[3:].strip()
                context.fence_membership[index] = index
            continue
        context.fence_membership[index] = open_index
        if stripped == "```":
            context.fences[open_index] = _Fence(open_index, index, language)
            open_index = None
            language = ""
    if open_index is not None:
        context.fences[open_index] = _Fence(open_index, None, language)
        context.findings.append(
            Finding(open_index + 1, "fence", "unterminated fenced block")
        )


@dataclass(frozen=True)
class _SectionProfile:
    declared_order: tuple[str, ...]
    required: tuple[str, ...]
    allowed: frozenset[str]
    disposition: str

    @classmethod
    def build(
        cls,
        context: _Context,
        close: int,
        checkpoint: str | None,
    ) -> _SectionProfile:
        raw = _schema_object(context.schema, "sections")
        declared_order = tuple(cast(list[str], raw["order"]))
        required_map = cast(dict[str, object], raw["required"])
        optional_map = cast(dict[str, object], raw["optional"])
        required = tuple(cast(list[str], required_map.get(context.disposition, [])))
        optional = tuple(cast(list[str], optional_map.get(context.disposition, [])))
        allowed = frozenset((*required, *optional))

        if checkpoint is None:
            return cls(declared_order, required, allowed, context.disposition)
        positions = {name: index for index, name in enumerate(declared_order)}
        checkpoint_index = positions.get(checkpoint)
        if checkpoint_index is None:
            context.findings.append(
                Finding(close + 2, "checkpoint", f"unknown checkpoint `{checkpoint}`")
            )
        elif checkpoint not in allowed:
            context.findings.append(
                Finding(
                    close + 2,
                    "checkpoint",
                    f"checkpoint `{checkpoint}` is not allowed for "
                    f"{context.disposition}",
                )
            )
        else:
            required_set = set(required)
            required = tuple(
                name
                for index, name in enumerate(declared_order)
                if name == checkpoint
                or (name in required_set and index <= checkpoint_index)
            )
        return cls(declared_order, required, allowed, context.disposition)


def _document_heading_indices(
    context: _Context,
    start: int,
) -> tuple[list[int], list[int]]:
    h1_indices: list[int] = []
    section_indices: list[int] = []
    for index in range(start, len(context.lines)):
        if _is_fenced(context, index):
            continue
        raw = context.lines[index]
        if raw.startswith("# "):
            h1_indices.append(index)
        elif raw.startswith("## "):
            section_indices.append(index)
    return h1_indices, section_indices


def _validate_document_h1(
    context: _Context,
    close: int,
    h1_indices: list[int],
    section_indices: list[int],
) -> None:
    for index in h1_indices:
        context.consume(index)
    valid = len(h1_indices) == 1 and re.fullmatch(
        r"# Design: \S(?:.*\S)?", context.lines[h1_indices[0]]
    ) is not None
    if not valid:
        context.findings.append(
            Finding(close + 2, "h1", "expected exactly one `# Design: ` heading")
        )
    elif section_indices and h1_indices[0] > section_indices[0]:
        context.findings.append(
            Finding(h1_indices[0] + 1, "h1", "the H1 must precede all sections")
        )


def _parse_declared_sections(
    context: _Context,
    close: int,
    section_indices: list[int],
    profile: _SectionProfile,
    checkpoint: str | None,
) -> tuple[list[_SectionSlice], dict[str, int]]:
    slices: list[_SectionSlice] = []
    section_lines: dict[str, int] = {}
    observed: list[str] = []
    declared = frozenset(profile.declared_order)
    for position, index in enumerate(section_indices):
        context.consume(index)
        name = context.lines[index][3:].strip()
        end = (
            section_indices[position + 1]
            if position + 1 < len(section_indices)
            else len(context.lines)
        )
        if name not in declared:
            context.findings.append(
                Finding(index + 1, "sections", f"unknown section `{name}`")
            )
            continue

        observed.append(name)
        if name in section_lines:
            context.findings.append(
                Finding(index + 1, "sections", f"duplicate section `{name}`")
            )
        else:
            section_lines[name] = index + 1
        if name not in profile.allowed:
            context.findings.append(
                Finding(
                    index + 1,
                    "sections",
                    f"section `{name}` is not allowed for {profile.disposition}",
                )
            )
        slices.append(_SectionSlice(name, index, end))

    expected_present = [name for name in profile.declared_order if name in observed]
    if observed != expected_present:
        context.findings.append(
            Finding(close + 2, "sections", "sections are not in schema order")
        )
    for name in profile.required:
        if name not in section_lines:
            context.findings.append(
                Finding(
                    close + 2,
                    "sections",
                    (
                        f"required checkpoint prefix section `{name}` is missing"
                        if checkpoint is not None
                        else f"required section `{name}` is missing"
                    ),
                )
            )
    return slices, section_lines


def _parse_body_structure(
    context: _Context,
    frontmatter: Mapping[str, str],
    close: int,
    *,
    checkpoint: str | None = None,
) -> tuple[list[_SectionSlice], dict[str, int]]:
    del frontmatter
    h1_indices, section_indices = _document_heading_indices(context, close + 1)
    _validate_document_h1(context, close, h1_indices, section_indices)
    profile = _SectionProfile.build(context, close, checkpoint)
    return _parse_declared_sections(
        context, close, section_indices, profile, checkpoint
    )


def _finish_line_ownership(context: _Context) -> None:
    for index, raw in enumerate(context.lines):
        if not raw.strip() or context.owners[index] != 0:
            continue
        if _FIELD_PATTERN.fullmatch(raw):
            message = "generic field outside record is not allowed"
        elif raw.lstrip().startswith("#"):
            message = f"unknown heading `{raw.strip()}`"
        elif raw.strip().startswith("|"):
            message = "unparsed table fragment is not allowed"
        elif _is_fenced(context, index):
            message = "fenced block is allowed only inside a DG record"
        else:
            message = (
                "free prose is not allowed outside canonical fields or generated views"
            )
        context.findings.append(Finding(index + 1, "closed-grammar", message))
        context.consume(index)
