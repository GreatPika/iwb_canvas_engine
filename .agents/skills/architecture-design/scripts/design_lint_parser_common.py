from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import cast

from design_lint_model import DesignSchema, Finding, Record, Table, TypedReference


_FIELD_PATTERN = re.compile(r"^-[ \t]+([^:]+):[ \t]*(.*)$")
_SEPARATOR_CELL_PATTERN = re.compile(r"^:?-{3,}:?$")


@dataclass(frozen=True)
class _Fence:
    open_index: int
    close_index: int | None
    language: str


@dataclass(frozen=True)
class _SectionSlice:
    name: str
    heading_index: int
    end_index: int


@dataclass
class _Context:
    lines: list[str]
    schema: DesignSchema
    template: bool
    disposition: str = ""
    findings: list[Finding] = field(default_factory=list)
    owners: list[int] = field(default_factory=list)
    fence_membership: list[int | None] = field(default_factory=list)
    fences: dict[int, _Fence] = field(default_factory=dict)
    records: dict[str, Record] = field(default_factory=dict)
    tables: dict[str, Table] = field(default_factory=dict)
    references: list[TypedReference] = field(default_factory=list)
    section_record_ids: dict[str, list[str]] = field(default_factory=dict)
    section_table_names: dict[str, list[str]] = field(default_factory=dict)

    def consume(self, index: int) -> None:
        if not self.lines[index].strip():
            return
        self.owners[index] += 1
        if self.owners[index] == 2:
            self.findings.append(
                Finding(
                    index + 1,
                    "closed-grammar",
                    "non-empty line has multiple grammar owners",
                )
            )

    def add_record(self, section: str, record: Record) -> None:
        self.section_record_ids.setdefault(section, []).append(record.identifier)
        if record.identifier in self.records:
            self.findings.append(
                Finding(
                    record.line,
                    "duplicate-id",
                    f"duplicate record identifier `{record.identifier}`",
                )
            )
            return
        self.records[record.identifier] = record

    def add_table(self, section: str, table: Table, line: int) -> None:
        self.section_table_names.setdefault(section, []).append(table.name)
        if table.name in self.tables:
            self.findings.append(
                Finding(line, "table", f"duplicate table `{table.name}`")
            )
            return
        self.tables[table.name] = table


def _split_table_row(line: str) -> tuple[list[str] | None, str | None]:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return None, None
    cells: list[str] = []
    current: list[str] = []
    in_code = False
    escaped = False
    for character in stripped[1:-1]:
        if escaped:
            if character == "|":
                current.append(character)
            else:
                current.extend(("\\", character))
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == "`":
            in_code = not in_code
            current.append(character)
        elif character == "|" and not in_code:
            cells.append("".join(current).strip())
            current = []
        else:
            current.append(character)
    if escaped:
        current.append("\\")
    cells.append("".join(current).strip())
    return cells, "unclosed code span in table row" if in_code else None


def _level_headings(
    context: _Context,
    start: int,
    end: int,
    level: int,
) -> list[int]:
    return [
        index
        for index in range(start, end)
        if not _is_fenced(context, index)
        and _heading_level(context.lines[index]) == level
    ]


def _outside_fence_nonempty(
    context: _Context,
    start: int,
    end: int,
) -> list[int]:
    return [
        index
        for index in range(start, end)
        if context.lines[index].strip() and not _is_fenced(context, index)
    ]


def _heading_level(line: str) -> int | None:
    match = re.match(r"^(#+) ", line)
    return len(match.group(1)) if match is not None else None


def _frontmatter_close(lines: list[str]) -> int | None:
    for index in range(1, len(lines)):
        if lines[index] == "---":
            return index
    return None


def _is_fenced(context: _Context, index: int) -> bool:
    return context.fence_membership[index] is not None


def _schema_object(schema: DesignSchema, key: str) -> dict[str, object]:
    value = schema.raw[key]
    assert isinstance(value, dict)
    return value


def _is_deferred_marker_value(context: _Context, value: str) -> bool:
    if not context.template:
        return False
    forbidden = _schema_object(context.schema, "forbidden_tokens")
    markers = forbidden.get("template_markers")
    assert isinstance(markers, dict)
    stripped = value.strip()
    code_value = _code_scalar(stripped)
    return stripped in markers or bool(code_value and code_value in markers)


def _csv_parts(value: str) -> list[str] | None:
    if not value.strip():
        return None
    parts = [part.strip() for part in value.split(",")]
    return parts if all(parts) else None


def _code_scalar(value: str) -> str:
    match = re.fullmatch(r"`([^`\r\n]+)`", value.strip())
    return match.group(1) if match is not None else ""


def _strip_code_scalar(value: str) -> str:
    parsed = _code_scalar(value)
    return parsed or value.strip()


def _reference_kind(identifier: str) -> str:
    return identifier.split("-", 1)[0]


def _match_identifier_semantic(
    identifier: str,
    schema: DesignSchema,
) -> str | None:
    for semantic, pattern in schema.id_patterns.items():
        if pattern.fullmatch(identifier) is not None:
            return semantic
    return None


def _match_reference(
    token: str,
    schema: DesignSchema,
) -> tuple[TypedReference, str] | None:
    if token == "CONTRACT":
        return TypedReference(token, token, token), "contract"

    if "/" in token:
        identifier, separator, concern = token.partition("/")
        decision = _schema_object(schema, "decision")
        concerns = set(cast(list[str], decision["concerns"]))
        if (
            separator != "/"
            or "/" in concern
            or not concern
            or concern not in concerns
            or schema.id_patterns["decision"].fullmatch(identifier) is None
        ):
            return None
        return (
            TypedReference(
                raw=token,
                kind=_reference_kind(identifier),
                identifier=identifier,
                concern=concern,
            ),
            "decision_concern",
        )

    semantic = _match_identifier_semantic(token, schema)
    if semantic is None:
        return None
    return (
        TypedReference(
            raw=token,
            kind=_reference_kind(token),
            identifier=token,
        ),
        semantic,
    )
