"""Public orchestration and compatibility facade for semantic validation."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import cast

from design_lint_model import ContractVocabulary, DesignSchema, Finding, ParsedDesign
from design_lint_validation_assurance import validate_assurance
from design_lint_validation_basis import validate_basis
from design_lint_validation_candidates import (
    _validate_checkpoint_pressure_references,
    validate_candidates,
)
from design_lint_validation_common import _schema_object
from design_lint_validation_contract import (
    validate_contract_interface,
    validate_diagrams,
)
from design_lint_validation_decisions import (
    validate_decisions,
    validate_durable_impact_correspondence,
)
from design_lint_validation_frontmatter import validate_frontmatter_and_profile
from design_lint_validation_readiness import validate_blockers, validate_readiness
from design_lint_validation_usage import validate_usage


_SECTION_RECORD_KINDS = {
    "Basis": frozenset({"S", "E", "R"}),
    "Candidate Analysis": frozenset({"F", "M", "P"}),
    "Decision Register": frozenset({"D"}),
    "Impact Register": frozenset({"I"}),
    "Assurance Register": frozenset({"A"}),
    "Stop Conditions": frozenset({"H"}),
    "Diagrams": frozenset({"DG"}),
    "Open Blockers": frozenset({"B"}),
}


@dataclass(frozen=True)
class _CheckpointContext:
    parsed: ParsedDesign
    schema: DesignSchema
    vocabulary: ContractVocabulary | None
    order: tuple[str, ...]
    positions: Mapping[str, int]
    index: int

    @property
    def name(self) -> str:
        return self.order[self.index]

    @property
    def is_final(self) -> bool:
        return self.index == len(self.order) - 1

    @property
    def carries_requirements(self) -> bool:
        if self.parsed.frontmatter.get("disposition") == "READY_FOR_CONTRACT":
            return self.index >= self.positions["Decision Register"]
        return self.is_final

    @property
    def available_kinds(self) -> frozenset[str]:
        available_sections = set(self.order[: self.index + 1])
        return frozenset(
            kind
            for section, section_kinds in _SECTION_RECORD_KINDS.items()
            if section in available_sections
            for kind in section_kinds
        )

    def reached(self, section: str) -> bool:
        return self.index >= self.positions[section]


_CheckpointValidator = Callable[[_CheckpointContext], list[Finding]]
_SemanticValidator = Callable[
    [ParsedDesign, DesignSchema, ContractVocabulary | None],
    list[Finding],
]


@dataclass(frozen=True)
class _CheckpointStage:
    section: str
    validator: _CheckpointValidator


def validate_design(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    validators = (
        validate_frontmatter_and_profile,
        validate_basis,
        validate_candidates,
        validate_decisions,
        validate_durable_impact_correspondence,
        validate_assurance,
        validate_contract_interface,
        validate_diagrams,
        validate_readiness,
        validate_blockers,
        validate_usage,
    )
    findings: list[Finding] = []
    for validator in validators:
        findings.extend(
            validator(
                parsed,
                schema,
                vocabulary,
                template=template,
            )
        )
    return findings


def validate_checkpoint_design(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    checkpoint: str,
) -> list[Finding]:
    sections = _schema_object(schema, "sections")
    order = tuple(cast(list[str], sections["order"]))
    positions: dict[str, int] = {}
    for index, section in enumerate(order):
        positions.setdefault(section, index)
    checkpoint_index = positions.get(checkpoint)
    if checkpoint_index is None:
        return [
            Finding(
                parsed.body_line, "checkpoint", f"unknown checkpoint `{checkpoint}`"
            )
        ]

    context = _CheckpointContext(
        parsed=parsed,
        schema=schema,
        vocabulary=vocabulary,
        order=order,
        positions=positions,
        index=checkpoint_index,
    )
    findings: list[Finding] = []
    for stage in _CHECKPOINT_STAGES:
        if context.reached(stage.section):
            findings.extend(stage.validator(context))
    findings.extend(_validate_checkpoint_pressure_references(parsed))
    findings.extend(
        validate_usage(
            parsed,
            schema,
            vocabulary,
            resolve_kinds=context.available_kinds,
            check_orphans=context.is_final,
        )
    )
    return findings


def _adapt_checkpoint_validator(
    validator: _SemanticValidator,
) -> _CheckpointValidator:
    def validate(context: _CheckpointContext) -> list[Finding]:
        return validator(context.parsed, context.schema, context.vocabulary)

    return validate


def _validate_checkpoint_frontmatter(
    context: _CheckpointContext,
) -> list[Finding]:
    return validate_frontmatter_and_profile(
        context.parsed,
        context.schema,
        context.vocabulary,
        checkpoint=context.name,
    )


def _validate_checkpoint_basis(context: _CheckpointContext) -> list[Finding]:
    return validate_basis(
        context.parsed,
        context.schema,
        context.vocabulary,
        requirement_carry=context.carries_requirements,
    )


def _validate_checkpoint_candidates(context: _CheckpointContext) -> list[Finding]:
    return validate_candidates(
        context.parsed,
        context.schema,
        context.vocabulary,
        checkpoint=True,
    )


def _validate_checkpoint_assurance(context: _CheckpointContext) -> list[Finding]:
    return validate_assurance(
        context.parsed,
        context.schema,
        context.vocabulary,
        checkpoint=not context.reached("Readiness Matrix"),
    )


_CHECKPOINT_STAGES = (
    _CheckpointStage("Basis", _validate_checkpoint_frontmatter),
    _CheckpointStage("Basis", _validate_checkpoint_basis),
    _CheckpointStage("Candidate Analysis", _validate_checkpoint_candidates),
    _CheckpointStage(
        "Decision Register",
        _adapt_checkpoint_validator(validate_decisions),
    ),
    _CheckpointStage(
        "Impact Register",
        _adapt_checkpoint_validator(validate_durable_impact_correspondence),
    ),
    _CheckpointStage("Assurance Register", _validate_checkpoint_assurance),
    _CheckpointStage(
        "Contract Interface",
        _adapt_checkpoint_validator(validate_contract_interface),
    ),
    _CheckpointStage("Diagrams", _adapt_checkpoint_validator(validate_diagrams)),
    _CheckpointStage(
        "Readiness Matrix",
        _adapt_checkpoint_validator(validate_readiness),
    ),
    _CheckpointStage(
        "Open Blockers",
        _adapt_checkpoint_validator(validate_blockers),
    ),
)


__all__ = [
    "validate_design",
    "validate_checkpoint_design",
    "validate_frontmatter_and_profile",
    "validate_basis",
    "validate_candidates",
    "validate_decisions",
    "validate_durable_impact_correspondence",
    "validate_assurance",
    "validate_contract_interface",
    "validate_diagrams",
    "validate_readiness",
    "validate_blockers",
    "validate_usage",
]
