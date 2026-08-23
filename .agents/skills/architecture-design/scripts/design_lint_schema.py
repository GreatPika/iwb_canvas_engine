from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, cast

from design_lint_model import ContractVocabulary, DesignSchema


EXPECTED_SCHEMA_KEYS = frozenset(
    {
        "version",
        "frontmatter",
        "sections",
        "ids",
        "basis",
        "candidate",
        "decision",
        "assurance",
        "impact",
        "guard",
        "contract",
        "coverage",
        "diagram",
        "blocker",
        "locators",
        "forbidden_tokens",
        "vocabulary",
    }
)

_FRONTMATTER_KEYS = frozenset(
    {"fields", "dispositions", "date_pattern", "commit_pattern", "outcome_pattern"}
)
_SECTION_KEYS = frozenset({"order", "required", "optional"})
_ID_KINDS = frozenset(
    {
        "source",
        "evidence",
        "requirement",
        "form",
        "material_obligation",
        "pressure",
        "decision",
        "assurance",
        "impact",
        "guard",
        "diagram",
        "blocker",
    }
)
_BASIS_KEYS = frozenset(
    {
        "source_header",
        "source_kinds",
        "evidence_header",
        "requirement_header",
        "requirement_kinds",
        "source_coverage_header",
    }
)
_CANDIDATE_KEYS = frozenset(
    {
        "fields",
        "comparison_values",
        "result_patterns",
        "forms_header",
        "material_prefix",
        "material_suffix",
        "future_pressure_header",
        "future_pressure_none_dispositions",
        "future_pressure_none_literal",
        "pressure_treatments",
        "yes_no",
    }
)
_DECISION_KEYS = frozenset(
    {
        "fields",
        "concerns",
        "contract_targets",
        "assurance_required_concerns",
        "concern_contract_target_map",
    }
)
_ASSURANCE_KEYS = frozenset({"fields", "verifies_patterns"})
_ASSURANCE_PATTERN_KEYS = frozenset({"requirement", "decision_concern", "impact"})
_IMPACT_KEYS = frozenset({"fields", "actions", "none_literal"})
_GUARD_KEYS = frozenset({"fields"})
_CONTRACT_KEYS = frozenset({"fields", "adr_pattern"})
_COVERAGE_KEYS = frozenset(
    {
        "architecture_header",
        "architecture_concerns",
        "ready_architecture_statuses",
        "existing_architecture_statuses",
        "gate_header",
        "core_gates",
        "conditional_gates",
        "ready_core_status",
        "ready_conditional_statuses",
        "existing_core_status",
        "existing_conditional_statuses",
        "blocking_failure_statuses",
        "gate_required_ref_groups",
        "concern_gate_map",
    }
)
_DIAGRAM_KEYS = frozenset({"fields", "types", "type_language_map"})
_BLOCKER_KEYS = frozenset(
    {"fields", "kinds", "additional_gates", "disposition_kinds_map"}
)
_LOCATOR_KEYS = frozenset(
    {
        "repository_relative_source_kinds",
        "external_absolute_source_kinds",
        "literal_source_locators",
        "evidence_line_pattern",
        "evidence_range_pattern",
        "evidence_surface_exceptions",
    }
)
_FORBIDDEN_TOKEN_KEYS = frozenset(
    {
        "active_tokens",
        "template_markers",
        "placeholder_values",
        "meaningful_fields",
    }
)
_MEANINGFUL_RECORD_KINDS = frozenset({"R", "D", "A", "I", "H", "B"})
_MARKER_PATTERN = re.compile(r"^\{\{[A-Z][A-Z0-9_]*\}\}$")


def _find_repository_root(path: Path) -> Path:
    resolved = path.resolve()
    for candidate in (resolved.parent, *resolved.parents[1:]):
        if (candidate / ".git").exists():
            return candidate
    raise ValueError(f"{path}: no repository root containing .git")


def _load_json_object(path: Path) -> dict[str, object]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: unable to read JSON object: {error}") from error
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: JSON root must be an object")
    return cast(dict[str, object], payload)


def _require_object(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    return cast(dict[str, object], value)


def _require_exact_keys(
    value: object,
    expected: frozenset[str] | set[str],
    label: str,
) -> dict[str, object]:
    payload = _require_object(value, label)
    actual = set(payload)
    missing = sorted(set(expected) - actual)
    unexpected = sorted(actual - set(expected))
    if missing:
        raise ValueError(f"{label} is missing keys: {', '.join(missing)}")
    if unexpected:
        raise ValueError(f"{label} has unexpected keys: {', '.join(unexpected)}")
    return payload


def _require_exact_value(
    payload: Mapping[str, object],
    key: str,
    expected: object,
) -> None:
    if payload.get(key) != expected:
        raise ValueError(f"{key} must be {expected}")


def _required_string(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty string")
    return value


def _unique_strings(
    value: object,
    label: str,
    *,
    allow_empty: bool = False,
) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise ValueError(f"{label} must be a list of unique non-empty strings")
    if not allow_empty and not value:
        raise ValueError(f"{label} must be a non-empty list")
    if not all(isinstance(item, str) and item.strip() for item in value):
        raise ValueError(f"{label} must contain unique strings")
    strings = cast(list[str], value)
    if len(strings) != len(set(strings)):
        raise ValueError(f"{label} must contain unique strings")
    return tuple(strings)


def _compile_pattern(value: object, label: str) -> re.Pattern[str]:
    pattern = _required_string(value, label)
    try:
        return re.compile(pattern)
    except re.error as error:
        raise ValueError(
            f"{label} must be a valid regular expression: {error}"
        ) from error


def _validate_frontmatter(value: object) -> None:
    frontmatter = _require_exact_keys(value, _FRONTMATTER_KEYS, "frontmatter")
    fields = _unique_strings(frontmatter["fields"], "frontmatter.fields")
    if fields[0] != "schema" or fields[-1] != "outcome":
        raise ValueError(
            "frontmatter.fields must start with schema and end with outcome"
        )
    dispositions = set(
        _unique_strings(frontmatter["dispositions"], "frontmatter.dispositions")
    )
    expected_dispositions = {
        "READY_FOR_CONTRACT",
        "BLOCKED",
        "DESIGN_NOT_REQUIRED",
    }
    if dispositions != expected_dispositions:
        raise ValueError(
            "frontmatter.dispositions must declare the three supported dispositions"
        )
    for name in ("date_pattern", "commit_pattern", "outcome_pattern"):
        _compile_pattern(frontmatter[name], f"frontmatter.{name}")


def _validate_section_profiles(value: object) -> None:
    sections = _require_exact_keys(value, _SECTION_KEYS, "sections")
    order = set(_unique_strings(sections["order"], "sections.order"))
    required = _require_object(sections["required"], "sections.required")
    optional = _require_object(sections["optional"], "sections.optional")
    expected_profiles = {
        "READY_FOR_CONTRACT",
        "BLOCKED",
        "DESIGN_NOT_REQUIRED",
    }
    if set(required) != expected_profiles or set(optional) != expected_profiles:
        raise ValueError("section profile maps must exactly cover all dispositions")
    for profile in sorted(expected_profiles):
        required_sections = set(
            _unique_strings(
                required[profile],
                f"sections.required.{profile}",
            )
        )
        optional_sections = set(
            _unique_strings(
                optional[profile],
                f"sections.optional.{profile}",
                allow_empty=True,
            )
        )
        unknown_required = sorted(required_sections - order)
        if unknown_required:
            raise ValueError(
                f"sections.required.{profile} references unknown section "
                f"{unknown_required[0]}"
            )
        unknown_optional = sorted(optional_sections - order)
        if unknown_optional:
            raise ValueError(
                f"sections.optional.{profile} references unknown section "
                f"{unknown_optional[0]}"
            )
        overlap = sorted(required_sections & optional_sections)
        if overlap:
            raise ValueError(
                f"sections profile {profile} declares {overlap[0]} as both required and optional"
            )


def _validate_id_patterns(value: object) -> None:
    identifiers = _require_exact_keys(value, _ID_KINDS, "ids")
    for name, pattern in identifiers.items():
        _compile_pattern(pattern, f"ids.{name}")


def _validate_string_fields(
    payload: Mapping[str, object],
    block: str,
    fields: tuple[str, ...],
    *,
    allow_empty: frozenset[str] = frozenset(),
) -> None:
    for field in fields:
        _unique_strings(
            payload[field],
            f"{block}.{field}",
            allow_empty=field in allow_empty,
        )


def _validate_basis(value: object) -> None:
    basis = _require_exact_keys(value, _BASIS_KEYS, "basis")
    _validate_string_fields(
        basis,
        "basis",
        (
            "source_header",
            "source_kinds",
            "evidence_header",
            "requirement_header",
            "requirement_kinds",
            "source_coverage_header",
        ),
    )
    if "other" not in cast(list[object], basis["source_kinds"]):
        raise ValueError("basis.source_kinds must preserve other")


def _validate_candidate(value: object) -> None:
    candidate = _require_exact_keys(value, _CANDIDATE_KEYS, "candidate")
    _validate_string_fields(
        candidate,
        "candidate",
        (
            "fields",
            "comparison_values",
            "forms_header",
            "material_prefix",
            "material_suffix",
            "future_pressure_header",
            "future_pressure_none_dispositions",
            "pressure_treatments",
            "yes_no",
        ),
    )
    if cast(list[str], candidate["future_pressure_none_dispositions"]) != [
        "DESIGN_NOT_REQUIRED"
    ]:
        raise ValueError(
            "candidate.future_pressure_none_dispositions must be "
            "exactly DESIGN_NOT_REQUIRED"
        )
    _require_exact_value(candidate, "future_pressure_none_literal", "None")
    for index, pattern in enumerate(
        _unique_strings(candidate["result_patterns"], "candidate.result_patterns")
    ):
        _compile_pattern(pattern, f"candidate.result_patterns[{index}]")


def _validate_decision(value: object) -> None:
    decision = _require_exact_keys(value, _DECISION_KEYS, "decision")
    _validate_string_fields(
        decision,
        "decision",
        ("fields", "concerns", "contract_targets", "assurance_required_concerns"),
    )
    concerns = set(cast(list[str], decision["concerns"]))
    required = set(cast(list[str], decision["assurance_required_concerns"]))
    if not required <= concerns:
        raise ValueError(
            "decision.assurance_required_concerns references unknown concern"
        )
    target_map = _require_exact_keys(
        decision["concern_contract_target_map"],
        concerns,
        "decision.concern_contract_target_map",
    )
    targets = set(cast(list[str], decision["contract_targets"]))
    for concern, values in target_map.items():
        mapped = set(
            _unique_strings(values, f"decision.concern_contract_target_map.{concern}")
        )
        unknown = sorted(mapped - targets)
        if unknown:
            raise ValueError(
                f"decision.concern_contract_target_map.{concern} references unknown target "
                f"{unknown[0]}"
            )


def _validate_assurance(value: object) -> None:
    assurance = _require_exact_keys(value, _ASSURANCE_KEYS, "assurance")
    _unique_strings(assurance["fields"], "assurance.fields")
    patterns = _require_exact_keys(
        assurance["verifies_patterns"],
        _ASSURANCE_PATTERN_KEYS,
        "assurance.verifies_patterns",
    )
    for name, pattern in patterns.items():
        _compile_pattern(pattern, f"assurance.verifies_patterns.{name}")


def _validate_impact(value: object) -> None:
    impact = _require_exact_keys(value, _IMPACT_KEYS, "impact")
    _validate_string_fields(impact, "impact", ("fields", "actions"))
    _require_exact_value(impact, "none_literal", "None")


def _validate_guard(value: object) -> None:
    guard = _require_exact_keys(value, _GUARD_KEYS, "guard")
    _unique_strings(guard["fields"], "guard.fields")


def _validate_contract(value: object) -> None:
    contract = _require_exact_keys(value, _CONTRACT_KEYS, "contract")
    _unique_strings(contract["fields"], "contract.fields")
    _compile_pattern(contract["adr_pattern"], "contract.adr_pattern")


@dataclass(frozen=True)
class _CoverageStatuses:
    ready: frozenset[str]
    existing: frozenset[str]
    failures: frozenset[str]

    @property
    def closure(self) -> frozenset[str]:
        return self.ready | self.existing


@dataclass(frozen=True)
class _CoverageGates:
    core: frozenset[str]
    conditional: frozenset[str]

    @property
    def all(self) -> frozenset[str]:
        return self.core | self.conditional


def _validate_coverage_statuses(coverage: Mapping[str, object]) -> None:
    ready_core = _required_string(
        coverage["ready_core_status"], "coverage.ready_core_status"
    )
    existing_core = _required_string(
        coverage["existing_core_status"], "coverage.existing_core_status"
    )
    ready_conditional = frozenset(
        cast(list[str], coverage["ready_conditional_statuses"])
    )
    existing_conditional = frozenset(
        cast(list[str], coverage["existing_conditional_statuses"])
    )
    if ready_core not in ready_conditional:
        raise ValueError("ready core status must be a ready conditional status")
    if existing_core not in existing_conditional:
        raise ValueError("existing core status must be an existing conditional status")
    if ready_core == existing_core:
        raise ValueError("ready and existing core statuses must be distinct")

    statuses = _CoverageStatuses(
        ready=frozenset(cast(list[str], coverage["ready_architecture_statuses"]))
        | ready_conditional,
        existing=frozenset(
            cast(list[str], coverage["existing_architecture_statuses"])
        )
        | existing_conditional,
        failures=frozenset(cast(list[str], coverage["blocking_failure_statuses"])),
    )
    if (statuses.ready & statuses.existing) - {"not_applicable"}:
        raise ValueError(
            "ready and existing status vocabularies may overlap only at not_applicable"
        )
    if statuses.closure & statuses.failures:
        raise ValueError("blocking failure statuses must not overlap closure statuses")


def _coverage_gates(coverage: Mapping[str, object]) -> _CoverageGates:
    gates = _CoverageGates(
        core=frozenset(cast(list[str], coverage["core_gates"])),
        conditional=frozenset(cast(list[str], coverage["conditional_gates"])),
    )
    if gates.core & gates.conditional:
        raise ValueError("core and conditional gates must be disjoint")
    return gates


def _validate_required_reference_groups(
    value: object,
    gates: frozenset[str],
) -> None:
    required_groups = _require_exact_keys(
        value,
        gates,
        "coverage.gate_required_ref_groups",
    )
    for gate, raw_groups in required_groups.items():
        if not isinstance(raw_groups, list) or not raw_groups:
            raise ValueError(
                f"coverage.gate_required_ref_groups.{gate} must be a non-empty list"
            )
        for index, group in enumerate(raw_groups):
            _unique_strings(
                group,
                f"coverage.gate_required_ref_groups.{gate}[{index}]",
            )


def _validate_concern_gate_map(
    value: object,
    declared_concerns: frozenset[str],
    gates: frozenset[str],
) -> None:
    concern_map = _require_object(value, "coverage.concern_gate_map")
    for concern, raw_gates in concern_map.items():
        if concern not in declared_concerns:
            raise ValueError(
                f"coverage.concern_gate_map references unknown concern {concern}"
            )
        mapped_gates = set(
            _unique_strings(raw_gates, f"coverage.concern_gate_map.{concern}")
        )
        unknown = sorted(mapped_gates - gates)
        if unknown:
            raise ValueError(
                f"coverage.concern_gate_map.{concern} references unknown gate "
                f"{unknown[0]}"
            )


def _validate_coverage(value: object) -> None:
    coverage = _require_exact_keys(value, _COVERAGE_KEYS, "coverage")
    _validate_string_fields(
        coverage,
        "coverage",
        (
            "architecture_header",
            "architecture_concerns",
            "ready_architecture_statuses",
            "existing_architecture_statuses",
            "gate_header",
            "core_gates",
            "conditional_gates",
            "ready_conditional_statuses",
            "existing_conditional_statuses",
            "blocking_failure_statuses",
        ),
    )
    _validate_coverage_statuses(coverage)
    gates = _coverage_gates(coverage).all
    _validate_required_reference_groups(
        coverage["gate_required_ref_groups"],
        gates,
    )
    _validate_concern_gate_map(
        coverage["concern_gate_map"],
        frozenset(cast(list[str], coverage["architecture_concerns"])),
        gates,
    )


def _validate_diagram(value: object) -> None:
    diagram = _require_exact_keys(value, _DIAGRAM_KEYS, "diagram")
    _unique_strings(diagram["fields"], "diagram.fields")
    types = set(_unique_strings(diagram["types"], "diagram.types"))
    languages = _require_exact_keys(
        diagram["type_language_map"], types, "diagram.type_language_map"
    )
    for diagram_type, language in languages.items():
        _required_string(language, f"diagram.type_language_map.{diagram_type}")


def _validate_blocker(value: object) -> None:
    blocker = _require_exact_keys(value, _BLOCKER_KEYS, "blocker")
    _validate_string_fields(
        blocker,
        "blocker",
        ("fields", "kinds", "additional_gates"),
    )
    disposition_map = _require_exact_keys(
        blocker["disposition_kinds_map"],
        {"BLOCKED"},
        "blocker.disposition_kinds_map",
    )
    kinds = set(cast(list[str], blocker["kinds"]))
    for disposition, raw_allowed_kinds in disposition_map.items():
        allowed_kinds = set(
            _unique_strings(
                raw_allowed_kinds,
                f"blocker.disposition_kinds_map.{disposition}",
            )
        )
        unknown_kinds = sorted(allowed_kinds - kinds)
        if unknown_kinds:
            raise ValueError(
                f"blocker.disposition_kinds_map.{disposition} references unknown kind "
                f"{unknown_kinds[0]}"
            )


def _validate_locators(value: object) -> None:
    locators = _require_exact_keys(value, _LOCATOR_KEYS, "locators")
    _validate_string_fields(
        locators,
        "locators",
        (
            "repository_relative_source_kinds",
            "external_absolute_source_kinds",
            "evidence_surface_exceptions",
        ),
    )
    literals = _require_object(
        locators["literal_source_locators"], "locators.literal_source_locators"
    )
    if not literals:
        raise ValueError("locators.literal_source_locators must not be empty")
    for kind, literal in literals.items():
        _required_string(kind, "locators.literal_source_locators key")
        _required_string(literal, f"locators.literal_source_locators.{kind}")
    _compile_pattern(
        locators["evidence_line_pattern"], "locators.evidence_line_pattern"
    )
    _compile_pattern(
        locators["evidence_range_pattern"], "locators.evidence_range_pattern"
    )


def _validate_forbidden_tokens(value: object) -> None:
    tokens = _require_exact_keys(value, _FORBIDDEN_TOKEN_KEYS, "forbidden_tokens")
    _unique_strings(tokens["active_tokens"], "forbidden_tokens.active_tokens")
    placeholders = _unique_strings(
        tokens["placeholder_values"], "forbidden_tokens.placeholder_values"
    )
    if any(item != item.strip().lower() for item in placeholders):
        raise ValueError("forbidden_tokens.placeholder_values must be normalized")

    markers = _require_object(
        tokens["template_markers"], "forbidden_tokens.template_markers"
    )
    if not markers:
        raise ValueError("forbidden_tokens.template_markers must not be empty")
    for marker, count in markers.items():
        if (
            _MARKER_PATTERN.fullmatch(marker) is None
            or not isinstance(count, int)
            or isinstance(count, bool)
            or count <= 0
        ):
            raise ValueError(
                f"forbidden_tokens.template_markers has invalid marker {marker}"
            )

    meaningful = _require_exact_keys(
        tokens["meaningful_fields"],
        _MEANINGFUL_RECORD_KINDS,
        "forbidden_tokens.meaningful_fields",
    )
    for kind, fields in meaningful.items():
        _unique_strings(fields, f"forbidden_tokens.meaningful_fields.{kind}")


def _validate_domain_blocks(payload: Mapping[str, object]) -> None:
    _validate_basis(payload["basis"])
    _validate_candidate(payload["candidate"])
    _validate_decision(payload["decision"])
    _validate_assurance(payload["assurance"])
    _validate_impact(payload["impact"])
    _validate_guard(payload["guard"])
    _validate_contract(payload["contract"])
    _validate_coverage(payload["coverage"])
    _validate_diagram(payload["diagram"])
    _validate_blocker(payload["blocker"])
    _validate_locators(payload["locators"])
    _validate_forbidden_tokens(payload["forbidden_tokens"])
    _required_string(payload["vocabulary"], "vocabulary")


def _string_set(payload: Mapping[str, object], key: str) -> set[str]:
    return set(cast(list[str], payload[key]))


def _sets_are_disjoint(*groups: set[str]) -> bool:
    seen: set[str] = set()
    for group in groups:
        if seen & group:
            return False
        seen.update(group)
    return True


def _validate_disposition_and_concern_references(
    frontmatter: Mapping[str, object],
    candidate: Mapping[str, object],
    decision: Mapping[str, object],
    coverage: Mapping[str, object],
) -> None:
    unknown_none_dispositions = _string_set(
        candidate, "future_pressure_none_dispositions"
    ) - _string_set(frontmatter, "dispositions")
    if unknown_none_dispositions:
        raise ValueError(
            "candidate.future_pressure_none_dispositions references unknown disposition"
        )

    unknown_architecture_concerns = _string_set(
        coverage, "architecture_concerns"
    ) - _string_set(decision, "concerns")
    if unknown_architecture_concerns:
        raise ValueError("coverage.architecture_concerns references unknown concern")


def _validate_gate_partitions(
    coverage: Mapping[str, object],
    blocker: Mapping[str, object],
) -> None:
    groups = (
        _string_set(coverage, "core_gates"),
        _string_set(coverage, "conditional_gates"),
        _string_set(blocker, "additional_gates"),
    )
    if not _sets_are_disjoint(*groups):
        raise ValueError("core, conditional, and blocker gates must be disjoint")


def _validate_locator_partition(
    basis: Mapping[str, object],
    locators: Mapping[str, object],
) -> None:
    groups = (
        _string_set(locators, "repository_relative_source_kinds"),
        _string_set(locators, "external_absolute_source_kinds"),
        set(cast(dict[str, str], locators["literal_source_locators"])),
    )
    if not _sets_are_disjoint(*groups):
        raise ValueError("locator source-kind groups must be disjoint")
    if set().union(*groups) != _string_set(basis, "source_kinds"):
        raise ValueError(
            "locator source-kind groups must exactly cover basis.source_kinds"
        )


def _validate_meaningful_field_references(
    basis: Mapping[str, object],
    decision: Mapping[str, object],
    assurance: Mapping[str, object],
    impact: Mapping[str, object],
    guard: Mapping[str, object],
    blocker: Mapping[str, object],
    tokens: Mapping[str, object],
) -> None:
    meaningful = cast(dict[str, object], tokens["meaningful_fields"])
    declarations = {
        "R": _string_set(basis, "requirement_header"),
        "D": _string_set(decision, "fields"),
        "A": _string_set(assurance, "fields"),
        "I": _string_set(impact, "fields"),
        "H": _string_set(guard, "fields"),
        "B": _string_set(blocker, "fields"),
    }
    for kind, raw_fields in meaningful.items():
        unknown = sorted(set(cast(list[str], raw_fields)) - declarations[kind])
        if unknown:
            raise ValueError(
                f"forbidden_tokens.meaningful_fields.{kind} references unknown field "
                f"{unknown[0]}"
            )


def _validate_cross_mappings(payload: Mapping[str, object]) -> None:
    frontmatter = cast(dict[str, object], payload["frontmatter"])
    basis = cast(dict[str, object], payload["basis"])
    candidate = cast(dict[str, object], payload["candidate"])
    decision = cast(dict[str, object], payload["decision"])
    coverage = cast(dict[str, object], payload["coverage"])
    blocker = cast(dict[str, object], payload["blocker"])
    locators = cast(dict[str, object], payload["locators"])
    tokens = cast(dict[str, object], payload["forbidden_tokens"])
    assurance = cast(dict[str, object], payload["assurance"])
    impact = cast(dict[str, object], payload["impact"])
    guard = cast(dict[str, object], payload["guard"])

    _validate_disposition_and_concern_references(
        frontmatter, candidate, decision, coverage
    )
    _validate_gate_partitions(coverage, blocker)
    _validate_locator_partition(basis, locators)
    _validate_meaningful_field_references(
        basis,
        decision,
        assurance,
        impact,
        guard,
        blocker,
        tokens,
    )


def _validate_vocabulary_route(
    schema_path: Path,
    repository_root: Path,
    route: object,
) -> Path:
    value = _required_string(route, "vocabulary")
    route_path = Path(value)
    if route_path.is_absolute() or route_path.suffix != ".json":
        raise ValueError("vocabulary route must be a repository-relative JSON path")
    resolved = (schema_path.resolve().parent / route_path).resolve()
    if not resolved.is_relative_to(repository_root):
        raise ValueError("vocabulary route must remain inside repository root")
    return resolved


def _build_schema(
    path: Path,
    repository_root: Path,
    payload: dict[str, object],
) -> DesignSchema:
    frontmatter = cast(dict[str, object], payload["frontmatter"])
    identifiers = cast(dict[str, object], payload["ids"])
    return DesignSchema(
        source_path=path,
        repository_root=repository_root,
        raw=payload,
        version=cast(str, payload["version"]),
        frontmatter_fields=tuple(cast(list[str], frontmatter["fields"])),
        dispositions=tuple(cast(list[str], frontmatter["dispositions"])),
        id_patterns={
            name: re.compile(cast(str, pattern))
            for name, pattern in identifiers.items()
        },
        vocabulary_route=cast(str, payload["vocabulary"]),
    )


def load_schema(path: Path) -> DesignSchema:
    repository_root = _find_repository_root(path)
    payload = _load_json_object(path)
    _require_exact_keys(payload, EXPECTED_SCHEMA_KEYS, "design schema")
    _require_exact_value(payload, "version", "architecture-design/v4")
    _validate_frontmatter(payload["frontmatter"])
    _validate_section_profiles(payload["sections"])
    _validate_id_patterns(payload["ids"])
    _validate_domain_blocks(payload)
    _validate_cross_mappings(payload)
    _validate_vocabulary_route(path, repository_root, payload["vocabulary"])
    return _build_schema(path, repository_root, payload)


def load_vocabulary(
    schema: DesignSchema,
    override: Path | None = None,
) -> ContractVocabulary:
    canonical_path = _validate_vocabulary_route(
        schema.source_path,
        schema.repository_root,
        schema.vocabulary_route,
    )
    path = override or canonical_path
    payload = _load_json_object(path)
    _require_exact_keys(
        payload,
        {"profiles", "obligations", "no_obligation"},
        "contract vocabulary",
    )
    profiles = frozenset(_unique_strings(payload["profiles"], "profiles"))
    obligations = frozenset(_unique_strings(payload["obligations"], "obligations"))
    no_obligation = _required_string(payload["no_obligation"], "no_obligation")
    if profiles & obligations:
        raise ValueError("profiles and obligations must be disjoint")
    if no_obligation in profiles or no_obligation in obligations:
        raise ValueError("no_obligation must not be a profile or material obligation")
    return ContractVocabulary(profiles, obligations, no_obligation)
