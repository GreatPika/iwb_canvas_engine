from __future__ import annotations

from dataclasses import dataclass

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
    Record,
)

from design_lint_validation_common import (
    _SYNTHETIC_KINDS,
    _csv_tokens,
    _reference_type,
    _strip_code,
)


@dataclass(frozen=True)
class _ReferenceRule:
    field: str
    allowed: tuple[str, ...]
    allow_none: bool = False
    consuming_kinds: frozenset[str] | None = None


_ALL_RECORD_KINDS = (
    "S",
    "E",
    "R",
    "F",
    "M",
    "P",
    "D",
    "A",
    "I",
    "H",
    "DG",
    "B",
)
_TABLE_REFERENCE_KINDS = (*_ALL_RECORD_KINDS, "CONTRACT")
_CAUSAL_KINDS = frozenset({"S", "E", "R", "F", "M", "P", "D", "A", "I", "H", "B"})
_PROJECTION_CONSUMERS = frozenset({"R", "E", "F", "M", "P", "A", "I", "H"})

_RECORD_REFERENCE_RULES: dict[str, tuple[_ReferenceRule, ...]] = {
    "E": (_ReferenceRule("Source", ("S",)),),
    "R": (_ReferenceRule("Basis", ("S", "E")),),
    "F": (_ReferenceRule("Basis", ("R", "E")),),
    "M": (_ReferenceRule("Independent authority", ("R", "E"), allow_none=True),),
    "P": (
        _ReferenceRule("Basis", ("S", "E", "R")),
        _ReferenceRule("Closure refs", ("D", "A", "I", "B")),
    ),
    "D": (
        _ReferenceRule("Basis", ("R", "E")),
        _ReferenceRule("Form", ("F",)),
        _ReferenceRule("Realizes", ("M",), allow_none=True),
        _ReferenceRule("Depends on", ("D",), allow_none=True),
    ),
    "A": (_ReferenceRule("Verifies", ("R", "D", "I")),),
    "I": (_ReferenceRule("Required by", ("R", "D")),),
    "H": (_ReferenceRule("Invalidates", ("D", "A", "I")),),
    "DG": (_ReferenceRule("Supports", ("D", "A", "I")),),
    "B": (_ReferenceRule("Related", _ALL_RECORD_KINDS[:-1]),),
}


class _UsageGraph:
    def __init__(
        self,
        parsed: ParsedDesign,
        *,
        resolve_kinds: frozenset[str] | None,
    ) -> None:
        self.parsed = parsed
        self.resolve_kinds = resolve_kinds
        self.findings: list[Finding] = []
        self.canonical = {
            record.identifier: record
            for record in parsed.records.values()
            if record.kind not in _SYNTHETIC_KINDS
        }
        self.consumers: dict[str, set[str]] = {
            identifier: set() for identifier in self.canonical
        }

    def _owner_line(
        self,
        owner: Record | None,
        field_name: str,
        explicit_line: int | None,
    ) -> int:
        if explicit_line is not None:
            return explicit_line
        if owner is not None:
            return owner.field_lines.get(field_name, owner.line)
        return self.parsed.body_line

    def _add_token(
        self,
        token: str,
        *,
        owner_name: str,
        field_name: str,
        owner_line: int,
        allowed: tuple[str, ...],
        consuming_kinds: frozenset[str] | None,
    ) -> None:
        identifier = token.partition("/")[0]
        actual_kind = _reference_type(identifier)
        if actual_kind not in allowed:
            self.findings.append(
                Finding(
                    owner_line,
                    "typed-edge",
                    f"{owner_name}.{field_name} accepts only "
                    f"{'/'.join(allowed)} references",
                )
            )
            return
        if identifier == "CONTRACT":
            return

        target = self.canonical.get(identifier)
        if target is None or target.kind != actual_kind:
            if self.resolve_kinds is None or actual_kind in self.resolve_kinds:
                self.findings.append(
                    Finding(
                        owner_line,
                        "typed-edge",
                        f"unknown typed reference {identifier} from "
                        f"{owner_name}.{field_name}",
                    )
                )
            return
        if identifier == owner_name:
            return
        if consuming_kinds is None or actual_kind in consuming_kinds:
            self.consumers[identifier].add(f"{owner_name}.{field_name}")

    def add(
        self,
        owner: Record | None,
        owner_name: str,
        field_name: str,
        value: str,
        allowed: tuple[str, ...],
        *,
        allow_none: bool = False,
        consuming_kinds: frozenset[str] | None = None,
        line: int | None = None,
    ) -> None:
        tokens = _csv_tokens(value)
        if allow_none and tokens == ["none"]:
            return
        owner_line = self._owner_line(owner, field_name, line)
        for token in tokens:
            self._add_token(
                token,
                owner_name=owner_name,
                field_name=field_name,
                owner_line=owner_line,
                allowed=allowed,
                consuming_kinds=consuming_kinds,
            )

    def add_rule(self, record: Record, rule: _ReferenceRule) -> None:
        self.add(
            record,
            record.identifier,
            rule.field,
            record.fields.get(rule.field, ""),
            rule.allowed,
            allow_none=rule.allow_none,
            consuming_kinds=rule.consuming_kinds,
        )

    def validate_record(self, record: Record, schema: DesignSchema) -> None:
        for rule in _RECORD_REFERENCE_RULES.get(record.kind, ()):
            self.add_rule(record, rule)

        if record.kind == "M":
            obligation = _strip_code(record.fields.get("Material obligation", ""))
            if schema.id_patterns["requirement"].fullmatch(obligation) is not None:
                self.add(
                    record,
                    record.identifier,
                    "Material obligation",
                    obligation,
                    ("R",),
                )
        elif (
            record.kind == "I"
            and record.fields.get("Resulting authority") != "unchanged"
        ):
            self.add(
                record,
                record.identifier,
                "Resulting authority",
                record.fields.get("Resulting authority", ""),
                ("R", "D"),
            )

    def validate_candidate(self) -> None:
        candidate = self.parsed.records.get("CANDIDATE")
        if candidate is None:
            return

        result = _strip_code(candidate.fields.get("Result", ""))
        wrapper, separator, identifiers = result.partition(" ")
        if separator and wrapper in {"selected", "blocked"}:
            allowed = ("F",) if wrapper == "selected" else ("B",)
            self.add(
                candidate,
                candidate.identifier,
                "Result",
                identifiers,
                allowed,
            )
        self.add(
            candidate,
            candidate.identifier,
            "Result basis",
            candidate.fields.get("Result basis", ""),
            _ALL_RECORD_KINDS,
            consuming_kinds=frozenset({"F", "M", "P", "B"}),
        )

    def validate_projection_tables(self) -> None:
        for table_name in ("Architecture Closure", "Gate Closure"):
            table = self.parsed.tables.get(table_name)
            if table is None:
                continue
            for index, row in enumerate(table.rows):
                if len(row) < 3:
                    continue
                self.add(
                    None,
                    table_name,
                    row[0],
                    row[2],
                    _TABLE_REFERENCE_KINDS,
                    consuming_kinds=_PROJECTION_CONSUMERS,
                    line=table.row_lines[index],
                )

    def orphan_findings(self) -> list[Finding]:
        return [
            Finding(
                record.line,
                "orphan-record",
                f"orphan record {record.identifier} has no allowed typed consumer",
            )
            for record in self.canonical.values()
            if record.kind in _CAUSAL_KINDS and not self.consumers[record.identifier]
        ]


def validate_usage(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
    resolve_kinds: frozenset[str] | None = None,
    check_orphans: bool = True,
) -> list[Finding]:
    del vocabulary
    if template:
        return []

    graph = _UsageGraph(parsed, resolve_kinds=resolve_kinds)
    for record in graph.canonical.values():
        graph.validate_record(record, schema)
    graph.validate_candidate()
    graph.validate_projection_tables()
    if check_orphans:
        graph.findings.extend(graph.orphan_findings())
    return graph.findings
