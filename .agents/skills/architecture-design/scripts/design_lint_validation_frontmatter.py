from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from typing import cast

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
)

from design_lint_validation_common import (
    _SYNTHETIC_KINDS,
    _is_meaningful,
    _ordered_records,
    _schema_object,
)


_ALLOWED_RECORD_KINDS: Mapping[str, frozenset[str]] = {
    "READY_FOR_CONTRACT": frozenset(
        {"S", "E", "R", "F", "M", "P", "D", "A", "I", "H", "DG"}
    ),
    "BLOCKED": frozenset(
        {"S", "E", "R", "F", "M", "P", "D", "A", "DG", "B"}
    ),
    "DESIGN_NOT_REQUIRED": frozenset({"S", "E", "R", "F", "M", "P", "DG"}),
}


@dataclass(frozen=True)
class _SectionProfile:
    disposition: str
    required: tuple[str, ...]
    allowed: frozenset[str]

    @classmethod
    def from_schema(
        cls,
        schema: DesignSchema,
        disposition: str,
    ) -> _SectionProfile | None:
        sections = _schema_object(schema, "sections")
        required_map = cast(Mapping[str, object], sections["required"])
        optional_map = cast(Mapping[str, object], sections["optional"])
        raw_required = required_map.get(disposition)
        raw_optional = optional_map.get(disposition)
        if not isinstance(raw_required, list) or not isinstance(raw_optional, list):
            return None
        required = tuple(cast(list[str], raw_required))
        optional = tuple(cast(list[str], raw_optional))
        return cls(disposition, required, frozenset((*required, *optional)))

    def findings(
        self,
        parsed: ParsedDesign,
        checkpoint: str | None,
    ) -> list[Finding]:
        findings: list[Finding] = []
        present = set(parsed.sections)
        if checkpoint is None:
            for section_name in self.required:
                if section_name not in present:
                    findings.append(
                        Finding(
                            parsed.body_line,
                            "disposition-profile",
                            f"{self.disposition} requires section {section_name}",
                        )
                    )
        elif checkpoint not in self.allowed:
            findings.append(
                Finding(
                    parsed.body_line,
                    "checkpoint",
                    f"checkpoint `{checkpoint}` is not allowed for {self.disposition}",
                )
            )

        for section_name, section in parsed.sections.items():
            if section_name not in self.allowed:
                findings.append(
                    Finding(
                        section.line,
                        "disposition-profile",
                        f"section {section_name} is not allowed for {self.disposition}",
                    )
                )
        return findings


def _canonical_identity_findings(parsed: ParsedDesign) -> list[Finding]:
    findings: list[Finding] = []
    seen: set[str] = set()
    for mapping_key, record in parsed.records.items():
        if record.kind in _SYNTHETIC_KINDS:
            continue
        if mapping_key != record.identifier:
            findings.append(
                Finding(
                    record.line,
                    "graph-identity",
                    f"record mapping key {mapping_key} must equal identifier "
                    f"{record.identifier}",
                )
            )
        if record.identifier in seen:
            findings.append(
                Finding(
                    record.line,
                    "graph-identity",
                    f"duplicate canonical record identifier {record.identifier}",
                )
            )
        else:
            seen.add(record.identifier)
    return findings


def _meaningful_field_findings(
    parsed: ParsedDesign,
    schema: DesignSchema,
) -> list[Finding]:
    configured = cast(
        Mapping[str, object],
        _schema_object(schema, "forbidden_tokens")["meaningful_fields"],
    )
    findings: list[Finding] = []
    for record in parsed.records.values():
        raw_fields = configured.get(record.kind)
        if not isinstance(raw_fields, list):
            continue
        for field_name in cast(list[str], raw_fields):
            if not _is_meaningful(record.fields.get(field_name, ""), schema):
                findings.append(
                    Finding(
                        record.field_lines.get(field_name, record.line),
                        "meaningful-field",
                        f"{record.identifier}.{field_name} must be meaningful",
                    )
                )
    return findings


def _record_profile_findings(
    parsed: ParsedDesign,
    disposition: str,
) -> list[Finding]:
    allowed_kinds = _ALLOWED_RECORD_KINDS.get(disposition)
    if allowed_kinds is None:
        return []

    findings: list[Finding] = []
    for record in parsed.records.values():
        if record.kind in _SYNTHETIC_KINDS:
            if record.kind == "contract" and disposition != "READY_FOR_CONTRACT":
                findings.append(
                    Finding(
                        record.line,
                        "disposition-profile",
                        f"Contract Interface is not allowed for {disposition}",
                    )
                )
            continue
        if record.kind not in allowed_kinds:
            findings.append(
                Finding(
                    record.line,
                    "disposition-profile",
                    f"record {record.identifier} is not allowed for {disposition}",
                )
            )
    return findings


def validate_frontmatter_and_profile(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
    checkpoint: str | None = None,
) -> list[Finding]:
    del vocabulary
    if template:
        return []

    disposition = parsed.frontmatter.get("disposition", "")
    findings = _canonical_identity_findings(parsed)
    findings.extend(_validate_outcome_identity(parsed))
    findings.extend(_meaningful_field_findings(parsed, schema))
    profile = _SectionProfile.from_schema(schema, disposition)
    if profile is not None:
        findings.extend(profile.findings(parsed, checkpoint))
    findings.extend(_record_profile_findings(parsed, disposition))
    return findings


def _validate_outcome_identity(parsed: ParsedDesign) -> list[Finding]:
    requirements = _ordered_records(parsed, "R", "Basis")
    outcomes = [
        record for record in requirements if record.fields.get("Kind") == "outcome"
    ]
    if len(outcomes) != 1:
        basis = parsed.sections.get("Basis")
        return [
            Finding(
                basis.line if basis is not None else parsed.body_line,
                "outcome",
                "exactly one outcome requirement is required",
            )
        ]
    if parsed.frontmatter.get("outcome") != outcomes[0].identifier:
        return [
            Finding(
                parsed.body_line,
                "outcome",
                "frontmatter outcome must reference the unique outcome requirement",
            )
        ]
    return []
