from __future__ import annotations

import re
from collections import defaultdict
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import cast

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
    Record,
    Table,
)

from design_lint_validation_common import (
    _code_tokens,
    _csv_tokens,
    _duplicates,
    _is_meaningful,
    _ordered_records,
    _schema_object,
    _selected_form,
    _single_reference,
    _strip_code,
)


@dataclass(frozen=True)
class _EvidenceBounds:
    start: int
    end: int


@dataclass(frozen=True)
class _SourceLocatorPolicy:
    repository_kinds: frozenset[str]
    external_kinds: frozenset[str]
    literals_by_kind: Mapping[str, object]

    @classmethod
    def from_mapping(cls, locators: Mapping[str, object]) -> _SourceLocatorPolicy:
        return cls(
            repository_kinds=frozenset(
                cast(list[str], locators["repository_relative_source_kinds"])
            ),
            external_kinds=frozenset(
                cast(list[str], locators["external_absolute_source_kinds"])
            ),
            literals_by_kind=cast(
                Mapping[str, object], locators["literal_source_locators"]
            ),
        )


@dataclass(frozen=True)
class _EvidenceLocatorPolicy:
    surface_exceptions: frozenset[str]
    line_pattern: str
    range_pattern: str

    @classmethod
    def from_mapping(cls, locators: Mapping[str, object]) -> _EvidenceLocatorPolicy:
        return cls(
            surface_exceptions=frozenset(
                cast(list[str], locators["evidence_surface_exceptions"])
            ),
            line_pattern=cast(str, locators["evidence_line_pattern"]),
            range_pattern=cast(str, locators["evidence_range_pattern"]),
        )


def _source_locator_finding(
    source: Record,
    *,
    code_message: str,
) -> Finding:
    return Finding(
        source.field_lines.get("Locator", source.line),
        "source-locator",
        f"{source.identifier}.Locator {code_message}",
    )


def _resolve_source(
    source: Record,
    policy: _SourceLocatorPolicy,
    repository_root: Path,
) -> tuple[Path | None, Finding | None]:
    kind = source.fields.get("Kind", "")
    raw_locator = source.fields.get("Locator", "").strip()
    locator = _strip_code(raw_locator)

    if kind in policy.repository_kinds:
        relative = Path(locator)
        candidate = (repository_root / relative).resolve()
        valid = (
            bool(locator)
            and not relative.is_absolute()
            and ".." not in relative.parts
            and candidate.is_relative_to(repository_root)
            and candidate.is_file()
        )
        if valid:
            return candidate, None
        return None, _source_locator_finding(
            source,
            code_message="must be a repository-relative accessible file",
        )

    if kind in policy.external_kinds:
        candidate = Path(locator)
        if candidate.is_absolute() and candidate.is_file():
            return candidate.resolve(), None
        return None, _source_locator_finding(
            source,
            code_message="must be an absolute accessible external file",
        )

    if kind in policy.literals_by_kind:
        expected = policy.literals_by_kind[kind]
        if raw_locator != expected:
            return None, _source_locator_finding(
                source,
                code_message=f"must equal literal {expected}",
            )
    return None, None


def _resolve_sources(
    source_records: list[Record],
    schema: DesignSchema,
    locators: Mapping[str, object],
) -> tuple[dict[str, Path | None], list[Finding]]:
    policy = _SourceLocatorPolicy.from_mapping(locators)
    repository_root = schema.repository_root.resolve()
    resolved_sources: dict[str, Path | None] = {}
    findings: list[Finding] = []
    for source in source_records:
        resolved, finding = _resolve_source(source, policy, repository_root)
        resolved_sources[source.identifier] = resolved
        if finding is not None:
            findings.append(finding)
    return resolved_sources, findings


def _canonical_sources_by_kind(
    source_records: list[Record],
    source_kinds: list[str],
) -> dict[str, list[str]]:
    canonical = {kind: [] for kind in source_kinds}
    for record in source_records:
        kind = record.fields.get("Kind")
        if kind in canonical:
            canonical[kind].append(record.identifier)
    return canonical


def _source_coverage_row_findings(
    kind: str,
    value: str,
    line: int,
    expected: list[str],
) -> list[Finding]:
    tokens = _csv_tokens(value)
    findings = [
        Finding(
            line,
            "source-coverage",
            f"Source Coverage {kind} contains duplicate source {duplicate}",
        )
        for duplicate in _duplicates(tokens)
    ]
    projected = [] if tokens == ["none"] else tokens
    if projected != expected:
        findings.append(
            Finding(
                line,
                "source-coverage",
                f"Source Coverage {kind} must equal canonical source order",
            )
        )
    return findings


def _source_coverage_findings(
    coverage: Table | None,
    *,
    source_records: list[Record],
    source_kinds: list[str],
    basis_line: int,
) -> list[Finding]:
    if coverage is None:
        return []

    findings: list[Finding] = []
    observed_kinds = [row[0] for row in coverage.rows if len(row) >= 2]
    if observed_kinds != source_kinds:
        findings.append(
            Finding(
                basis_line,
                "source-coverage",
                "Source Coverage must list every source kind exactly once in "
                "schema order",
            )
        )

    canonical_by_kind = _canonical_sources_by_kind(source_records, source_kinds)
    for row, line in zip(coverage.rows, coverage.row_lines):
        if len(row) < 2 or row[0] not in canonical_by_kind:
            continue
        kind, value = row[:2]
        findings.extend(
            _source_coverage_row_findings(
                kind,
                value,
                line,
                canonical_by_kind[kind],
            )
        )
    return findings


def _parse_evidence_bounds(
    locator: str,
    *,
    line_pattern: str,
    range_pattern: str,
) -> tuple[_EvidenceBounds | None, str | None]:
    if re.fullmatch(line_pattern, locator) is not None:
        line = int(locator.split()[1])
        return _EvidenceBounds(line, line), None

    if re.fullmatch(range_pattern, locator) is None:
        return None, "not-allowed"

    raw_start, raw_end = locator.split()[1].split("-", 1)
    start, end = int(raw_start), int(raw_end)
    if start > end:
        return None, "reversed"
    return _EvidenceBounds(start, end), None


def _source_line_count(
    path: Path,
    cache: dict[Path, int | None],
) -> int | None:
    if path not in cache:
        try:
            cache[path] = len(path.read_text(encoding="utf-8").splitlines())
        except (OSError, UnicodeDecodeError):
            cache[path] = None
    return cache[path]


def _evidence_finding(evidence: Record, message: str) -> Finding:
    return Finding(
        evidence.field_lines.get("Locator", evidence.line),
        "evidence-locator",
        f"{evidence.identifier}.Locator {message}",
    )


def _evidence_locator_finding(
    evidence: Record,
    source: Record,
    source_path: Path | None,
    policy: _EvidenceLocatorPolicy,
    line_counts: dict[Path, int | None],
) -> Finding | None:
    locator = _strip_code(evidence.fields.get("Locator", ""))
    source_locator = _strip_code(source.fields.get("Locator", ""))
    if (
        source_locator
        and source_locator != "user request"
        and source_locator in locator
    ):
        return _evidence_finding(evidence, "must not repeat source path")

    if locator in policy.surface_exceptions:
        source_kind = source.fields.get("Kind", "")
        if source_kind != "repository":
            return _evidence_finding(
                evidence,
                f"surface exception is incompatible with source kind {source_kind}",
            )
        return None

    bounds, error = _parse_evidence_bounds(
        locator,
        line_pattern=policy.line_pattern,
        range_pattern=policy.range_pattern,
    )
    if error == "not-allowed":
        return _evidence_finding(
            evidence,
            "is not an allowed line, range, or surface",
        )
    if error == "reversed":
        return _evidence_finding(evidence, "range must not be reversed")
    assert bounds is not None

    if source_path is None:
        return _evidence_finding(evidence, "requires a file-backed source")
    line_count = _source_line_count(source_path, line_counts)
    if line_count is None:
        return _evidence_finding(evidence, "source cannot be inspected")
    if bounds.end > line_count:
        return _evidence_finding(
            evidence,
            f"exceeds source line count {line_count}",
        )
    return None


def _evidence_locator_findings(
    evidence_records: list[Record],
    source_records: list[Record],
    resolved_sources: Mapping[str, Path | None],
    locators: Mapping[str, object],
) -> list[Finding]:
    source_by_id = {record.identifier: record for record in source_records}
    policy = _EvidenceLocatorPolicy.from_mapping(locators)
    line_counts: dict[Path, int | None] = {}
    findings: list[Finding] = []
    for evidence in evidence_records:
        source_id = _single_reference(evidence.fields.get("Source", ""))
        source = source_by_id.get(source_id or "")
        if source is None:
            continue
        finding = _evidence_locator_finding(
            evidence,
            source,
            resolved_sources.get(source.identifier),
            policy,
            line_counts,
        )
        if finding is not None:
            findings.append(finding)
    return findings


def _requirement_source_index(
    requirements: list[Record],
    evidence_records: list[Record],
    schema: DesignSchema,
) -> tuple[dict[str, set[str]], dict[str, bool], list[Finding]]:
    evidence_sources = {
        record.identifier: _single_reference(record.fields.get("Source", ""))
        for record in evidence_records
    }
    requirement_sources: dict[str, set[str]] = {}
    meaningful_requirements: dict[str, bool] = {}
    findings: list[Finding] = []

    meaningful = cast(
        Mapping[str, object],
        _schema_object(schema, "forbidden_tokens")["meaningful_fields"],
    )
    raw_requirement_fields = meaningful.get("R")
    requirement_fields = (
        cast(list[str], raw_requirement_fields)
        if isinstance(raw_requirement_fields, list)
        else []
    )

    for requirement in requirements:
        sources: set[str] = set()
        for reference in _csv_tokens(requirement.fields.get("Basis", "")):
            if reference.startswith("S-"):
                sources.add(reference)
            elif evidence_sources.get(reference) is not None:
                sources.add(cast(str, evidence_sources[reference]))
        requirement_sources[requirement.identifier] = sources

        statement_is_meaningful = _is_meaningful(
            requirement.fields.get("Statement", ""), schema
        )
        if not statement_is_meaningful:
            findings.append(
                Finding(
                    requirement.field_lines.get("Statement", requirement.line),
                    "meaningful-field",
                    f"{requirement.identifier}.Statement must be meaningful",
                )
            )
        meaningful_requirements[requirement.identifier] = all(
            _is_meaningful(requirement.fields.get(field_name, ""), schema)
            for field_name in requirement_fields
        )

    return requirement_sources, meaningful_requirements, findings


def _source_provenance_findings(
    source_records: list[Record],
    requirement_sources: Mapping[str, set[str]],
    meaningful_requirements: Mapping[str, bool],
) -> list[Finding]:
    meaningful_sources = {
        source_id
        for requirement_id, source_ids in requirement_sources.items()
        if meaningful_requirements[requirement_id]
        for source_id in source_ids
    }
    findings: list[Finding] = []
    for source in source_records:
        source_kind = source.fields.get("Kind", "")
        if source_kind in {"user", "other"} and source.identifier not in meaningful_sources:
            findings.append(
                Finding(
                    source.line,
                    "source-provenance",
                    f"{source_kind} source {source.identifier} must produce a "
                    "meaningful requirement",
                )
            )
    return findings


def _records_by_reference(
    records: list[Record],
    field_name: str,
) -> dict[str, list[Record]]:
    index: dict[str, list[Record]] = defaultdict(list)
    for record in records:
        for reference in dict.fromkeys(_csv_tokens(record.fields.get(field_name, ""))):
            index[reference].append(record)
    return dict(index)


def _requirement_carry_findings(
    parsed: ParsedDesign,
    requirements: list[Record],
) -> list[Finding]:
    selected = _selected_form(parsed)
    decisions = [
        record
        for record in _ordered_records(parsed, "D", "Decision Register")
        if selected is not None and record.fields.get("Form") == selected
    ]
    blockers = _ordered_records(parsed, "B", "Open Blockers")
    decisions_by_requirement = _records_by_reference(decisions, "Basis")
    blockers_by_requirement = _records_by_reference(blockers, "Related")

    findings: list[Finding] = []
    for requirement in requirements:
        carried_by = decisions_by_requirement.get(requirement.identifier, [])
        blocked_by = blockers_by_requirement.get(requirement.identifier, [])
        if not carried_by and not blocked_by:
            findings.append(
                Finding(
                    requirement.line,
                    "requirement-carry",
                    f"requirement {requirement.identifier} must reach a selected "
                    "decision or exact blocker",
                )
            )
        if (
            requirement.fields.get("Kind") == "exclusion"
            and not blocked_by
            and not any(
                "out_of_scope" in _code_tokens(record.fields.get("Concerns", ""))
                for record in carried_by
            )
        ):
            findings.append(
                Finding(
                    requirement.line,
                    "requirement-carry",
                    f"exclusion {requirement.identifier} requires an "
                    "out_of_scope selected decision",
                )
            )
    return findings


def validate_basis(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
    requirement_carry: bool = True,
) -> list[Finding]:
    del vocabulary
    if template:
        return []

    basis = _schema_object(schema, "basis")
    source_kinds = cast(list[str], basis["source_kinds"])
    basis_section = parsed.sections.get("Basis")
    basis_line = basis_section.line if basis_section is not None else parsed.body_line
    source_records = _ordered_records(parsed, "S", "Basis")
    evidence_records = _ordered_records(parsed, "E", "Basis")
    requirements = _ordered_records(parsed, "R", "Basis")
    locators = _schema_object(schema, "locators")

    resolved_sources, findings = _resolve_sources(source_records, schema, locators)
    findings.extend(
        _source_coverage_findings(
            parsed.tables.get("Source Coverage"),
            source_records=source_records,
            source_kinds=source_kinds,
            basis_line=basis_line,
        )
    )
    findings.extend(
        _evidence_locator_findings(
            evidence_records,
            source_records,
            resolved_sources,
            locators,
        )
    )

    requirement_sources, meaningful_requirements, requirement_findings = (
        _requirement_source_index(requirements, evidence_records, schema)
    )
    findings.extend(requirement_findings)
    findings.extend(
        _source_provenance_findings(
            source_records,
            requirement_sources,
            meaningful_requirements,
        )
    )

    disposition = parsed.frontmatter.get("disposition")
    if requirement_carry and disposition in {"READY_FOR_CONTRACT", "BLOCKED"}:
        findings.extend(_requirement_carry_findings(parsed, requirements))
    return findings
