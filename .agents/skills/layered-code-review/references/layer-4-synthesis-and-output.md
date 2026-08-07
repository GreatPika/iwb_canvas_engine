# Layer 4 — Synthesis and Output

Load this layer last. Convert layer candidate findings into one final response grouped by layer.

## Concrete Failure Mode Standard

A review concern becomes a finding only when it identifies the concrete missed failure mode, affected consumer, scenario, or behavior introduced by the reviewed diff or commit range. Inspect the full relevant diff before deciding that threshold is met.

Flag an issue only when all of these are true:

1. It meaningfully impacts accuracy, performance, security, reliability, maintainability, plan alignment, or verification confidence.
2. The issue is discrete and actionable.
3. The fix does not demand a level of rigor absent from the rest of the codebase.
4. The issue was introduced by the reviewed diff or commit range.
5. The author would likely fix it if made aware.
6. The issue does not rely on unstated assumptions about the codebase or intent.
7. The affected behavior or consumer can be identified from evidence.
8. The issue is not just an intentional change.

## Deduplication

Deduplicate by concrete failure mode, not by layer, rule, file, symbol, or symptom.

If multiple layers identify the same underlying defect, report one finding under the layer that gives the maintainer the clearest fix direction:

- Use Layer 1 when the core issue is runtime behavior, contract drift, state, ordering, failure handling, or implementation correctness.
- Use Layer 2 when the core issue is false confidence, missing proof, proxy-only verification, duplicated truth, weak guardrails, self-referential proof, or overclaimed completion.
- Use Layer 3 when the core issue is misleading ownership, file boundary, naming, directory cohesion, public API placement, or fixture placement.

Do not drop unique findings just because they mention the same file.

## Priorities

At the beginning of each finding, tag the issue with a priority level:

- `[P0]`: blocking release, operations, or major usage. Use only for universal issues that do not depend on assumptions about inputs.
- `[P1]`: urgent; should be addressed in the next cycle.
- `[P2]`: normal; should be fixed eventually.
- `[P3]`: low-impact concrete defect. Do not use P3 for optional hardening,
  personal preference, or speculative work.

Priority describes impact and urgency. Blocking status describes whether safe
completion under the accepted contract is possible. Priority does not determine
blocking status.

Do not include numeric priority fields, confidence scores, correctness verdicts, or JSON.
Do not emit `ACCEPTED_BLOCKING`, `ACCEPTED_ADVISORY`, or `REJECTED`; the lead
owns those dispositions after applying `superpowers:receiving-code-review`.

## Code Review Output Format

For code review, output exactly this structure. Keep findings grouped by layer:

```markdown
Findings

Layer 1 — Implementation correctness and contract alignment

[P2] path/to/file.ext:31 Explain the issue in one concise paragraph. Explain why this is a problem, name the scenario or input that exposes it, and point to the expected fix direction without writing the patch.

Layer 2 — Proof, verification, and anti-slop

No findings.

Layer 3 — Naming, ownership, and cohesion

No findings.

Review complete: after reviewing the full relevant diff, no further qualifying findings remain.
```

Rules:

- Use one paragraph per finding.
- Keep each finding self-contained and actionable.
- Start each finding with `[P0]`, `[P1]`, `[P2]`, or `[P3]`, then the shortest useful file path and line number from the diff.
- Reference only lines that overlap the reviewed diff.
- When a Change Contract governs a finding, cite its semantic outcome and
  evidence keys. When `Permanent artifact required` is `yes`, also cite the
  semantic admission key or identify the exact missing or incorrect admission.
  Do not use document position, test paths, or private hooks as semantic scope.
- Include only layers that were executed, unless the user explicitly asks to show every layer.
- If an executed layer has no qualifying findings, write `No findings.` under that layer.
- End every review response with the exact `Review complete:` line shown above.
- A review response without that line is incomplete.
- Do not wrap output in JSON or markdown fences.

If there are no findings in any executed layer, output the executed layer headings with `No findings.` under each, then the exact completion line.

## Standalone Anti-Slop Output Format

When the user asks for standalone anti-slop review rather than code-review findings, use:

```text
Verdict: Useful / Weak but valid / Misnamed / Slop / Harmful slop

Claim:
...

Concrete failure mode:
...

Acceptance oracle:
...

Proxy risk:
...

Evidence constraints:
...

Actual evidence or value:
...

Permanent artifact required: yes/no
...

Contract outcome: `<outcome-key>` [required when a Change Contract governs]

Evidence key: `<evidence-key>` [required when a Change Contract governs]

Recommendation:
...
```

When `Permanent artifact required` is `yes`, insert `Admission basis:` between
`Evidence key` and `Recommendation`. The basis must either cite an existing
admission as `Admission basis:` followed by its exact semantic key or identify
the exact missing or incorrect admission for a concrete new failure family.
When `Permanent artifact required` is `no`, omit `Admission basis`.

## Standalone Naming Output Format

When the user asks for standalone naming or cohesion review rather than full code review, use:

```markdown
Findings

Layer 3 — Naming, ownership, and cohesion

[P2] path/to/file.ext:31 Explain why the name or file boundary is misleading, name the scenario that makes it matter, and point to the expected ownership direction without writing a patch.

Review complete: after reviewing the full relevant diff, no further qualifying findings remain.
```

If there are no actionable naming or cohesion issues, write `No findings.` under Layer 3 and include the exact completion line.
