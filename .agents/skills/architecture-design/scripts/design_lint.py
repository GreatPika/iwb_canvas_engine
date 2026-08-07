#!/usr/bin/env python3
"""Deterministically validate the mechanical form of active architecture designs."""
from __future__ import annotations

import argparse
import datetime
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Finding:
    line: int
    code: str
    message: str


@dataclass(frozen=True)
class ParsedDesign:
    frontmatter: dict[str, str]
    body: str
    body_start_line: int


@dataclass(frozen=True)
class ContractVocabulary:
    profiles: frozenset[str]
    obligations: frozenset[str]
    no_obligation: str


SCHEMA_PATH = Path(__file__).resolve().parents[1] / "references" / "design-artifact-schema.json"

_SCHEMA_KEYS = {
    "frontmatter",
    "sections",
    "fields",
    "tables",
    "core_gates",
    "conditional_gates",
    "diagram_types",
    "template_markers",
    "forbidden_tokens",
    "vocabulary",
}
_FRONTMATTER_KEYS = {
    "fields",
    "dispositions",
    "date_pattern",
    "commit_pattern",
    "folded_field",
}
_SECTION_RE = re.compile(r"^## (.+?)\s*$", re.MULTILINE)
_H1_RE = re.compile(r"^#(?!#) .+$", re.MULTILINE)
_MARKER_RE = re.compile(r"\{\{(?:(?!\{\{)[^\r\n])*\}\}")
_ADR_IMPACT_RE = re.compile(
    r"(?:none|create|(?:supersede|retire) ADR-[0-9]{4}(?:, ADR-[0-9]{4})*)",
)
_TABLE_SEPARATOR_RE = re.compile(r"^:?-{3,}:?$")
_OPEN_DECISION_FIELDS = (
    "Decision needed",
    "Blocks because",
    "Needed evidence or user choice",
)


class _SchemaData(dict[str, object]):
    """Dictionary-shaped schema that retains its route for vocabulary loading."""

    def __init__(self, values: dict[str, object], source_path: Path) -> None:
        super().__init__(values)
        self.source_path = source_path


class _Frontmatter(dict[str, str]):
    """Dictionary-shaped frontmatter retaining parsed field order and locations."""

    def __init__(self) -> None:
        super().__init__()
        self.entries: list[tuple[str, int]] = []
        self.folded_fields: set[str] = set()


def load_json(path: Path) -> dict[str, object]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("JSON root must be an object")
    return data


def _unique_string_list(value: object, name: str) -> list[str]:
    if (
        not isinstance(value, list)
        or not value
        or not all(isinstance(item, str) and item for item in value)
        or len(value) != len(set(value))
    ):
        raise ValueError(f"{name} must be a unique non-empty string list")
    return value


def _string_map_of_lists(value: object, name: str) -> dict[str, list[str]]:
    if not isinstance(value, dict) or not value:
        raise ValueError(f"{name} must be a non-empty object")
    result: dict[str, list[str]] = {}
    for key, items in value.items():
        if not isinstance(key, str) or not key:
            raise ValueError(f"{name} keys must be non-empty strings")
        result[key] = _unique_string_list(items, f"{name}.{key}")
    return result


def load_schema(path: Path = SCHEMA_PATH) -> dict[str, object]:
    schema = load_json(path)
    if set(schema) != _SCHEMA_KEYS:
        raise ValueError("design schema has missing or unexpected top-level keys")

    frontmatter = schema["frontmatter"]
    if not isinstance(frontmatter, dict) or set(frontmatter) != _FRONTMATTER_KEYS:
        raise ValueError("design schema frontmatter has missing or unexpected keys")
    fields = _unique_string_list(frontmatter["fields"], "frontmatter.fields")
    _unique_string_list(frontmatter["dispositions"], "frontmatter.dispositions")
    for pattern_name in ("date_pattern", "commit_pattern"):
        pattern = frontmatter[pattern_name]
        if not isinstance(pattern, str) or not pattern:
            raise ValueError(f"frontmatter.{pattern_name} must be a non-empty string")
        re.compile(pattern)
    folded_field = frontmatter["folded_field"]
    if not isinstance(folded_field, str) or folded_field not in fields:
        raise ValueError("frontmatter.folded_field must name a frontmatter field")

    sections = _unique_string_list(schema["sections"], "sections")
    schema_fields = _string_map_of_lists(schema["fields"], "fields")
    schema_tables = _string_map_of_lists(schema["tables"], "tables")
    if not set(schema_fields).issubset(sections):
        raise ValueError("schema fields must belong to declared sections")
    if not set(schema_tables).issubset(sections):
        raise ValueError("schema tables must belong to declared sections")
    for list_name in (
        "core_gates",
        "conditional_gates",
        "diagram_types",
        "template_markers",
        "forbidden_tokens",
    ):
        _unique_string_list(schema[list_name], list_name)
    if set(schema["core_gates"]) & set(schema["conditional_gates"]):
        raise ValueError("core and conditional gates must be distinct")
    for marker in schema["template_markers"]:
        if not re.fullmatch(r"\{\{[^{}\r\n]+\}\}", marker):
            raise ValueError("template markers must use double braces")

    vocabulary = schema["vocabulary"]
    if (
        not isinstance(vocabulary, str)
        or not vocabulary
        or Path(vocabulary).is_absolute()
        or not vocabulary.endswith(".json")
    ):
        raise ValueError("schema vocabulary route must be a relative JSON path")
    return _SchemaData(schema, path)


def load_vocabulary(schema: dict[str, object]) -> ContractVocabulary:
    route = schema.get("vocabulary")
    if not isinstance(route, str):
        raise ValueError("schema vocabulary route must be a string")
    source_path = schema.source_path if isinstance(schema, _SchemaData) else SCHEMA_PATH
    data = load_json((source_path.parent / route).resolve())
    if set(data) != {"profiles", "obligations", "no_obligation"}:
        raise ValueError("contract vocabulary has unexpected keys")
    profiles = _unique_string_list(data["profiles"], "contract profiles")
    obligations = _unique_string_list(data["obligations"], "contract obligations")
    no_obligation = data["no_obligation"]
    if not isinstance(no_obligation, str) or not no_obligation:
        raise ValueError("no_obligation must be a non-empty string")
    if no_obligation in obligations:
        raise ValueError("no_obligation must not be a material obligation")
    return ContractVocabulary(
        profiles=frozenset(profiles),
        obligations=frozenset(obligations),
        no_obligation=no_obligation,
    )


def _line_of(text: str, index: int, start_line: int = 1) -> int:
    return start_line + text.count("\n", 0, index)


def _fold_scalar(lines: list[str]) -> str:
    non_empty = [line for line in lines if line.strip()]
    if not non_empty:
        return ""
    indent = min(len(line) - len(line.lstrip(" \t")) for line in non_empty)
    normalized = [line[indent:] if line.strip() else "" for line in lines]
    folded: list[str] = []
    blank_count = 0
    for line in normalized:
        if not line.strip():
            blank_count += 1
            continue
        if blank_count:
            folded.append("\n" * blank_count)
        elif folded:
            folded.append(" ")
        folded.append(line)
        blank_count = 0
    return "".join(folded).rstrip()


def parse_frontmatter(text: str) -> tuple[ParsedDesign | None, list[Finding]]:
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].rstrip("\r\n") != "---":
        return None, [Finding(1, "frontmatter", "frontmatter must start with `---`")]

    closing_index: int | None = None
    for index, line in enumerate(lines[1:], start=1):
        if line.rstrip("\r\n") == "---":
            closing_index = index
            break
    if closing_index is None:
        return None, [Finding(1, "frontmatter", "frontmatter closing `---` is missing")]

    frontmatter = _Frontmatter()
    findings: list[Finding] = []
    current_folded: str | None = None
    folded_lines: list[str] = []

    def finish_folded() -> None:
        nonlocal current_folded, folded_lines
        if current_folded is not None:
            frontmatter[current_folded] = _fold_scalar(folded_lines)
            frontmatter.folded_fields.add(current_folded)
        current_folded = None
        folded_lines = []

    for line_index in range(1, closing_index):
        raw = lines[line_index].rstrip("\r\n")
        if current_folded is not None and (raw.startswith((" ", "\t")) or not raw):
            folded_lines.append(raw)
            continue
        finish_folded()
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)", raw)
        if not match:
            findings.append(
                Finding(
                    line_index + 1,
                    "frontmatter",
                    "frontmatter contains an invalid field line",
                ),
            )
            continue
        key, value = match.groups()
        frontmatter.entries.append((key, line_index + 1))
        if key == "product_outcome" and value == ">-":
            current_folded = key
            continue
        frontmatter[key] = value
    finish_folded()
    body_start_line = closing_index + 2
    body = "".join(lines[closing_index + 1 :])
    return ParsedDesign(frontmatter, body, body_start_line), findings


def section_matches(body: str) -> list[re.Match[str]]:
    return list(_SECTION_RE.finditer(body))


def _section_bounds(body: str, name: str) -> tuple[int, int] | None:
    matches = section_matches(body)
    for index, match in enumerate(matches):
        if match.group(1) == name:
            end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
            return match.end(), end
    return None


def section_text(body: str, name: str) -> str:
    bounds = _section_bounds(body, name)
    return body[bounds[0] : bounds[1]] if bounds is not None else ""


def _section_line(parsed: ParsedDesign, name: str) -> int:
    bounds = _section_bounds(parsed.body, name)
    assert bounds is not None
    return _line_of(parsed.body, bounds[0], parsed.body_start_line)


def field_value(section: str, field: str) -> str:
    pattern = re.compile(
        rf"^(?:- )?{re.escape(field)}:\s*(.*)$",
        re.MULTILINE,
    )
    match = pattern.search(section)
    return match.group(1).strip() if match else ""


def _table_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def table_header(section: str) -> list[str]:
    for line in section.splitlines():
        stripped = line.strip()
        if stripped.startswith("|") and stripped.endswith("|"):
            return _table_cells(stripped)
    return []


def _marker_value(value: str, markers: set[str]) -> bool:
    stripped = value.strip()
    if stripped.startswith("`") and stripped.endswith("`") and len(stripped) >= 2:
        stripped = stripped[1:-1]
    return stripped in markers


def _validate_frontmatter(
    parsed: ParsedDesign,
    schema: dict[str, object],
    template: bool,
) -> list[Finding]:
    frontmatter_schema = schema["frontmatter"]
    assert isinstance(frontmatter_schema, dict)
    expected_fields = frontmatter_schema["fields"]
    dispositions = frontmatter_schema["dispositions"]
    assert isinstance(expected_fields, list)
    assert isinstance(dispositions, list)
    entries = getattr(parsed.frontmatter, "entries", [])
    keys = [key for key, _ in entries]
    findings: list[Finding] = []
    unexpected = [(key, line) for key, line in entries if key not in expected_fields]
    for key, line in unexpected:
        findings.append(
            Finding(line, "frontmatter", f"unexpected frontmatter field `{key}`"),
        )
    if keys != expected_fields:
        findings.append(
            Finding(
                1,
                "frontmatter",
                "frontmatter fields must appear exactly once in schema order",
            ),
        )
    if findings:
        return findings

    markers = set(schema["template_markers"])
    values = parsed.frontmatter
    field_lines = {key: line for key, line in entries}
    folded_field = frontmatter_schema["folded_field"]
    assert isinstance(folded_field, str)
    folded_fields = getattr(parsed.frontmatter, "folded_fields", set())
    if folded_field not in folded_fields:
        findings.append(
            Finding(
                field_lines[folded_field],
                "frontmatter",
                f"frontmatter {folded_field} must use the folded `>-` form",
            ),
        )
    date_value = values["date"]
    if not (template and _marker_value(date_value, markers)):
        date_pattern = frontmatter_schema["date_pattern"]
        assert isinstance(date_pattern, str)
        if not re.fullmatch(date_pattern, date_value):
            findings.append(
                Finding(field_lines["date"], "date", "date does not match the required format"),
            )
        else:
            try:
                datetime.date.fromisoformat(date_value)
            except ValueError:
                findings.append(
                    Finding(field_lines["date"], "date", "date is not a valid calendar date"),
                )
    commit_value = values["commit"]
    if not (template and _marker_value(commit_value, markers)):
        commit_pattern = frontmatter_schema["commit_pattern"]
        assert isinstance(commit_pattern, str)
        if not re.fullmatch(commit_pattern, commit_value):
            findings.append(
                Finding(
                    field_lines["commit"],
                    "commit",
                    "commit must match the required lowercase hash format",
                ),
            )
    for field in ("branch", "product_outcome"):
        value = values[field]
        if not value and not (template and _marker_value(value, markers)):
            findings.append(
                Finding(field_lines[field], "frontmatter", f"{field} must not be empty"),
            )
    disposition = values["disposition"]
    if not (template and _marker_value(disposition, markers)) and disposition not in dispositions:
        findings.append(
            Finding(
                field_lines["disposition"],
                "disposition",
                f"unknown disposition `{disposition}`",
            ),
        )
    return findings


def _validate_h1(parsed: ParsedDesign) -> list[Finding]:
    h1s = list(_H1_RE.finditer(parsed.body))
    if len(h1s) != 1 or not h1s[0].group(0).startswith("# Design: "):
        return [
            Finding(
                parsed.body_start_line,
                "h1",
                "expected exactly one `# Design: ` H1 after frontmatter",
            ),
        ]
    return []


def _validate_sections(parsed: ParsedDesign, schema: dict[str, object]) -> list[Finding]:
    expected = schema["sections"]
    assert isinstance(expected, list)
    names = [match.group(1) for match in section_matches(parsed.body)]
    if names != expected:
        return [
            Finding(
                parsed.body_start_line,
                "sections",
                "section order must exactly match the active-design schema",
            ),
        ]
    return []


def _validate_placeholders(text: str, schema: dict[str, object], template: bool) -> list[Finding]:
    findings: list[Finding] = []
    for token in schema["forbidden_tokens"]:
        assert isinstance(token, str)
        pattern = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(token)}(?![A-Za-z0-9_])")
        for match in pattern.finditer(text):
            findings.append(
                Finding(
                    _line_of(text, match.start()),
                    "placeholder",
                    f"placeholder token `{token}` is not allowed",
                ),
            )
    markers = schema["template_markers"]
    assert isinstance(markers, list)
    if template:
        for match in _MARKER_RE.finditer(text):
            if match.group(0) not in markers:
                findings.append(
                    Finding(
                        _line_of(text, match.start()),
                        "fill-marker",
                        f"unknown fill marker `{match.group(0)}`",
                    ),
                )
    else:
        for marker in markers:
            for match in re.finditer(re.escape(marker), text):
                findings.append(
                    Finding(
                        _line_of(text, match.start()),
                        "fill-marker",
                        f"unresolved fill marker `{marker}`",
                    ),
                )
    return findings


def _field_occurrences(section: str, field: str, source_inputs: bool) -> list[re.Match[str]]:
    prefix = r"- " if source_inputs else ""
    return list(
        re.finditer(
            rf"^{prefix}{re.escape(field)}:\s*(.*)$",
            section,
            flags=re.MULTILINE,
        ),
    )


def _field_line(parsed: ParsedDesign, section_name: str, field: str) -> int:
    section = section_text(parsed.body, section_name)
    source_inputs = section_name == "Source Inputs"
    occurrences = _field_occurrences(section, field, source_inputs)
    assert len(occurrences) == 1
    return _line_of(
        section,
        occurrences[0].start(),
        _section_line(parsed, section_name),
    )


def _validate_fields(
    parsed: ParsedDesign,
    schema: dict[str, object],
    template: bool,
) -> list[Finding]:
    fields = schema["fields"]
    assert isinstance(fields, dict)
    markers = set(schema["template_markers"])
    findings: list[Finding] = []
    for section_name, required_fields in fields.items():
        assert isinstance(section_name, str)
        assert isinstance(required_fields, list)
        section = section_text(parsed.body, section_name)
        source_inputs = section_name == "Source Inputs"
        bounds = _section_bounds(parsed.body, section_name)
        assert bounds is not None
        section_start, _ = bounds
        section_line = _line_of(parsed.body, section_start, parsed.body_start_line)
        for field in required_fields:
            assert isinstance(field, str)
            occurrences = _field_occurrences(section, field, source_inputs)
            if len(occurrences) != 1:
                findings.append(
                    Finding(
                        section_line,
                        "field",
                        f"{section_name} requires `{field}:` exactly once",
                    ),
                )
                continue
            value = occurrences[0].group(1).strip()
            if not value and not (template and _marker_value(value, markers)):
                findings.append(
                    Finding(
                        _line_of(section, occurrences[0].start(), section_line),
                        "field",
                        f"{section_name} field `{field}` must not be empty",
                    ),
                )
    return findings


def _table_rows(section: str) -> list[tuple[int, list[str]]]:
    rows: list[tuple[int, list[str]]] = []
    for index, line in enumerate(section.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("|") and stripped.endswith("|"):
            rows.append((index, _table_cells(stripped)))
    return rows


def _is_separator(cells: list[str]) -> bool:
    return bool(cells) and all(_TABLE_SEPARATOR_RE.fullmatch(cell) for cell in cells)


def _is_template_row(cells: list[str], markers: set[str]) -> bool:
    return len(cells) == 1 and cells[0] == "{{ROW}}" and cells[0] in markers


def _validate_tables(
    parsed: ParsedDesign,
    schema: dict[str, object],
    template: bool,
) -> list[Finding]:
    tables = schema["tables"]
    assert isinstance(tables, dict)
    markers = set(schema["template_markers"])
    findings: list[Finding] = []
    for section_name, expected_header in tables.items():
        assert isinstance(section_name, str)
        assert isinstance(expected_header, list)
        section = section_text(parsed.body, section_name)
        rows = _table_rows(section)
        line = _section_line(parsed, section_name)
        if not rows or rows[0][1] != expected_header:
            findings.append(
                Finding(line, "table", f"{section_name} has an invalid table header"),
            )
            continue
        data_rows = [row for row in rows[1:] if not _is_separator(row[1])]
        if not data_rows:
            findings.append(
                Finding(line, "table", f"{section_name} requires at least one table row"),
            )
            continue
        for row_line, cells in data_rows:
            if template and _is_template_row(cells, markers):
                continue
            if len(cells) != len(expected_header):
                findings.append(
                    Finding(
                        line + row_line - 1,
                        "table",
                        f"{section_name} table row has the wrong column count",
                    ),
                )
    return findings


def _unresolved_value(value: str) -> bool:
    stripped = value.strip().strip("`")
    return bool(re.fullmatch(r"Unresolved:\s*\S(?:.*\S)?", stripped))


def _validate_classification(
    parsed: ParsedDesign,
    vocabulary: ContractVocabulary,
    schema: dict[str, object],
    template: bool,
) -> list[Finding]:
    section = section_text(parsed.body, "Target Contract Classification")
    disposition = parsed.frontmatter["disposition"]
    blocked = disposition in {"NEEDS_RESEARCH", "ARCHITECTURE_GATE"}
    markers = set(schema["template_markers"])
    findings: list[Finding] = []
    profile = field_value(section, "Profile")
    profile_line = _field_line(parsed, "Target Contract Classification", "Profile")
    if not (template and _marker_value(profile, markers)):
        profile_token = profile.strip().strip("`")
        if _unresolved_value(profile):
            if not blocked:
                findings.append(
                    Finding(
                        profile_line,
                        "profile",
                        "unresolved profile is only allowed for blocked dispositions",
                    ),
                )
        elif profile_token not in vocabulary.profiles:
            findings.append(Finding(profile_line, "profile", f"unknown profile `{profile_token}`"))

    obligations = field_value(section, "Obligations")
    obligations_line = _field_line(parsed, "Target Contract Classification", "Obligations")
    if not (template and _marker_value(obligations, markers)):
        if _unresolved_value(obligations):
            if not blocked:
                findings.append(
                    Finding(
                        obligations_line,
                        "obligations",
                        "unresolved obligations are only allowed for blocked dispositions",
                    ),
                )
        else:
            tokens = re.findall(r"`([^`]+)`", obligations)
            if not tokens or re.sub(r"`[^`]+`|[\s,]", "", obligations):
                findings.append(
                    Finding(
                        obligations_line,
                        "obligations",
                        "obligations must use backtick tokens",
                    ),
                )
            for token in tokens:
                if token not in vocabulary.obligations and token != vocabulary.no_obligation:
                    findings.append(
                        Finding(
                            obligations_line,
                            "obligations",
                            f"unknown obligation `{token}`",
                        ),
                    )
            if vocabulary.no_obligation in tokens and len(tokens) != 1:
                findings.append(
                    Finding(
                        obligations_line,
                        "obligations",
                        f"`{vocabulary.no_obligation}` cannot be combined with material obligations",
                    ),
                )

    adr_impact = field_value(section, "ADR Impact")
    if not (template and _marker_value(adr_impact, markers)) and not _ADR_IMPACT_RE.fullmatch(adr_impact):
        findings.append(
            Finding(
                _field_line(parsed, "Target Contract Classification", "ADR Impact"),
                "adr-impact",
                "ADR Impact has an invalid value",
            ),
        )
    return findings


def _validate_evidence(parsed: ParsedDesign) -> list[Finding]:
    section = section_text(parsed.body, "Repository Evidence")
    section_line = _section_line(parsed, "Repository Evidence")
    rows = [
        (line_number, line)
        for line_number, line in enumerate(section.splitlines(), start=section_line)
        if line.strip().startswith("- ")
    ]
    findings: list[Finding] = []
    if not rows:
        return [
            Finding(
                section_line,
                "evidence",
                "Repository Evidence requires at least one evidence row",
            ),
        ]
    for line_number, row in rows:
        if not re.match(r"^- `[^`]+` / .* -> ", row):
            findings.append(
                Finding(
                    line_number,
                    "evidence",
                    "evidence rows require one backtick source, ` / `, and ` -> `",
                ),
            )
    return findings


def _rows_for_table(parsed: ParsedDesign, section_name: str) -> list[list[str]]:
    rows = _table_rows(section_text(parsed.body, section_name))
    return [cells for _, cells in rows[1:] if not _is_separator(cells)]


def _validate_ready_disposition(parsed: ParsedDesign, schema: dict[str, object]) -> list[Finding]:
    core_gates = schema["core_gates"]
    conditional_gates = schema["conditional_gates"]
    assert isinstance(core_gates, list)
    assert isinstance(conditional_gates, list)
    known_gates = set(core_gates) | set(conditional_gates)
    gate_rows = _rows_for_table(parsed, "Hard Gate Check")
    gate_line = _section_line(parsed, "Hard Gate Check")
    findings: list[Finding] = []
    names: list[str] = []
    for row in gate_rows:
        if len(row) != 3:
            continue
        gate, result, _ = row
        names.append(gate)
        if gate not in known_gates:
            findings.append(Finding(gate_line, "gate", f"unknown hard gate `{gate}`"))
        if result != "pass":
            findings.append(
                Finding(gate_line, "gate", "ready designs require every hard gate to pass"),
            )
    for gate in core_gates:
        if names.count(gate) != 1:
            findings.append(
                Finding(gate_line, "gate", f"core gate `{gate}` must appear exactly once"),
            )
    for gate in dict.fromkeys(names):
        if names.count(gate) > 1:
            findings.append(Finding(gate_line, "gate", f"hard gate `{gate}` is duplicated"))

    open_decisions = section_text(parsed.body, "Open Decisions").strip()
    if open_decisions != "None":
        findings.append(
            Finding(
                _section_line(parsed, "Open Decisions"),
                "open-decisions",
                "ready designs require Open Decisions to be `None`",
            ),
        )
    return findings


def _open_decision_values(section: str, field: str) -> list[str]:
    return [
        match.group(1).strip()
        for match in re.finditer(
            rf"^[ \t]*(?:- )?{re.escape(field)}:[ \t]*(.*)$",
            section,
            flags=re.MULTILINE,
        )
    ]


def _validate_blocked_disposition(parsed: ParsedDesign, schema: dict[str, object]) -> list[Finding]:
    core_gates = schema["core_gates"]
    conditional_gates = schema["conditional_gates"]
    assert isinstance(core_gates, list)
    assert isinstance(conditional_gates, list)
    known_gates = set(core_gates) | set(conditional_gates)
    gate_rows = _rows_for_table(parsed, "Hard Gate Check")
    gate_line = _section_line(parsed, "Hard Gate Check")
    findings: list[Finding] = []
    names: list[str] = []
    failed = False
    for row in gate_rows:
        if len(row) != 3:
            continue
        gate, result, evidence = row
        names.append(gate)
        if gate not in known_gates:
            findings.append(Finding(gate_line, "gate", f"unknown hard gate `{gate}`"))
        if result not in {"pass", "fail"}:
            findings.append(
                Finding(gate_line, "gate", "blocked designs use only `pass` or `fail` gate results"),
            )
        if result == "fail":
            failed = True
            if not evidence:
                findings.append(
                    Finding(
                        gate_line,
                        "gate",
                        "a failed hard gate requires a blocker explanation",
                    ),
                )
    for gate in dict.fromkeys(names):
        if names.count(gate) > 1:
            findings.append(Finding(gate_line, "gate", f"hard gate `{gate}` is duplicated"))
    if not failed:
        findings.append(
            Finding(gate_line, "gate", "blocked designs require at least one failed hard gate"),
        )

    open_decisions = section_text(parsed.body, "Open Decisions")
    open_decisions_line = _section_line(parsed, "Open Decisions")
    decision_matches = list(
        re.finditer(
            r"^[ \t]*(?:- )?Decision needed:[ \t]*(.*)$",
            open_decisions,
            flags=re.MULTILINE,
        ),
    )
    if not decision_matches:
        findings.append(
            Finding(
                open_decisions_line,
                "open-decisions",
                "Open Decisions requires `Decision needed:`",
            ),
        )
    for index, match in enumerate(decision_matches):
        group_end = (
            decision_matches[index + 1].start()
            if index + 1 < len(decision_matches)
            else len(open_decisions)
        )
        group = open_decisions[match.start() : group_end]
        for field in _OPEN_DECISION_FIELDS:
            values = _open_decision_values(group, field)
            if len(values) != 1:
                findings.append(
                    Finding(
                        open_decisions_line,
                        "open-decisions",
                        f"Open Decisions group requires `{field}:` exactly once",
                    ),
                )
            elif not values[0]:
                message = (
                    "Open Decisions has an empty blocker explanation"
                    if field == "Blocks because"
                    else f"Open Decisions field `{field}` must not be empty"
                )
                findings.append(Finding(open_decisions_line, "open-decisions", message))
    return findings


def lint_text(text: str, template: bool = False) -> list[Finding]:
    schema = load_schema()
    vocabulary = load_vocabulary(schema)
    parsed, findings = parse_frontmatter(text)
    if findings or parsed is None:
        return findings

    findings = _validate_frontmatter(parsed, schema, template)
    if findings:
        return findings
    findings = _validate_h1(parsed)
    if findings:
        return findings
    findings = _validate_sections(parsed, schema)
    if findings:
        return findings
    findings = _validate_placeholders(text, schema, template)
    if findings:
        return findings
    findings = _validate_fields(parsed, schema, template)
    if findings:
        return findings
    findings = _validate_tables(parsed, schema, template)
    if findings:
        return findings
    findings = _validate_classification(parsed, vocabulary, schema, template)
    if findings:
        return findings
    findings = _validate_evidence(parsed)
    if findings:
        return findings

    diagram_types = schema["diagram_types"]
    assert isinstance(diagram_types, list)
    diagram_rows = _rows_for_table(parsed, "Diagram Requirements")
    diagram_line = _section_line(parsed, "Diagram Requirements")
    findings = []
    kinds = [row[0] for row in diagram_rows if len(row) == 3]
    for kind in kinds:
        if kind not in diagram_types:
            findings.append(Finding(diagram_line, "diagram", f"unknown diagram type `{kind}`"))
    if "none" in kinds and (len(kinds) != 1 or kinds.count("none") != 1):
        findings.append(
            Finding(diagram_line, "diagram", "diagram type `none` must be a single exclusive row"),
        )
    if findings:
        return findings

    disposition = parsed.frontmatter["disposition"]
    if template:
        return []
    if disposition in {"READY_FOR_CONTRACT", "DESIGN_NOT_REQUIRED"}:
        return _validate_ready_disposition(parsed, schema)
    if disposition in {"ARCHITECTURE_GATE", "NEEDS_RESEARCH"}:
        return _validate_blocked_disposition(parsed, schema)
    return [
        Finding(
            1,
            "disposition",
            f"schema-defined disposition `{disposition}` has no semantic validator",
        ),
    ]


def lint_file(path: Path, template: bool = False) -> list[Finding]:
    return lint_text(path.read_text(encoding="utf-8"), template)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lint an active architecture design artifact.")
    parser.add_argument("design", nargs="?", type=Path, help="Path to an active design")
    parser.add_argument("--template", type=Path, help="Path to a design template")
    try:
        args = parser.parse_args(argv)
    except SystemExit as error:
        return int(error.code) if isinstance(error.code, int) else 2
    if (args.design is None) == (args.template is None):
        parser.print_usage(sys.stderr)
        return 2
    path = args.template if args.template is not None else args.design
    assert path is not None
    try:
        findings = lint_file(path, template=args.template is not None)
    except (OSError, ValueError, json.JSONDecodeError, re.error) as error:
        print(f"design_lint: {error}", file=sys.stderr)
        return 2
    for finding in findings:
        print(f"{path}:{finding.line}: {finding.code}: {finding.message}", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
