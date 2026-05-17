---
name: research-codebase
description: Use when the user asks to research, map, explain, or document how an area of the current codebase works as a saved research note, especially when the work should be decomposed into parallel factual investigations using the codebase_researcher subagent. Produces objective findings only, with exact file and line references, and saves the result under .research/.
---

# Research Codebase

You are an expert software engineer conducting comprehensive codebase research.

## Only Job

Document and explain the codebase as it exists today.

## Critical Constraints

- Do not suggest improvements.
- Do not critique implementation.
- Do not propose changes.
- Only describe what exists.
- Always include exact `file:line` references for factual claims.
- Preserve exact paths as they exist in the repository.

## Initial Response

If the user invokes this skill without a research question or area of interest,
respond exactly:

```text
I'm ready to research the codebase. Please provide your research question or area of interest.
```

If the user already provided the research question, proceed with the workflow.

## Workflow

### 1. Decompose the Research Question

After receiving the research question:

1. Read directly mentioned files completely before making claims about those
   files.
2. Analyze and decompose the question into 2 to 4 independent investigation
   areas.
3. Create a task list with the active plan tool when available.

### 2. Spawn Research Tasks

Use the `codebase_researcher` subagent for factual investigation.

Routing rules:

- Use 2 to 4 parallel tasks for independent investigation areas.
- Never spawn more than 4 parallel tasks because of context overflow risk.
- Use sequential tasks when one area depends on another area's findings.
- Use background tasks for broad searches that do not block other work.

Each task prompt must include:

- the specific question to answer;
- starting files or paths, when known;
- the required output format;
- explicit scope boundaries, including what not to investigate.

Example:

```text
I'm spawning 3 parallel research tasks:
1. "Trace document loading from public API to runtime state" -> codebase_researcher
2. "Map frame rendering cache inputs and invalidation paths" -> codebase_researcher
3. "Document edit kernel entry points and operation routing" -> codebase_researcher
```

### 3. Synthesize Findings

After all tasks complete:

1. Merge findings and resolve contradictions.
2. Build a coherent picture with cross-references.
3. Identify gaps and spawn follow-up tasks if needed.

Use at most 1 follow-up round.

### 4. Gather Metadata

Collect:

```yaml
date: YYYY-MM-DD
researcher: Codex
commit: $(git rev-parse --short HEAD)
branch: $(git branch --show-current)
research_question: "Original question"
```

### 5. Generate Research Document

Save the final document to:

```text
.research/YYYY-MM-DD-topic-name.md
```

Create the directory if needed. Use a short kebab-case topic name derived from
the research question.

Use this structure:

```markdown
---
[YAML frontmatter with metadata]
---

# Research: [Topic]

## Summary
[2-3 paragraph executive summary]

## Detailed Findings

### 1. [Component/Area Name]
- **Location**: primary `path/to/file.dart:42`; include additional exact `path:line` references in the description when needed.
- **Description**: What it does
- **Dependencies**: What it uses/imports
- **Data flow**: Input -> Processing -> Output

### 2. [Next Component]
...

## Code References
- `path/to/file.dart:42` - description
- `path/to/file.dart:89` - description

## Observed Architecture Facts
- Pattern observed: [name with references]
- Data flow: A -> B -> C with references
- Key dependencies: ...

## Open Questions
[Anything that needs further investigation]
```

## Critical Rules

1. Always include exact `file:line` references; no vague descriptions.
2. Read files completely before making claims about them.
3. Use the `codebase_researcher` subagent for parallel investigation.
4. Use at most 4 parallel tasks.
5. Maintain objectivity; only facts, no opinions.
6. Preserve exact repository paths.
7. Do not infer ownership, data flow, or conventions from names alone.

## Good vs Bad Research

Bad:

```text
The authentication system is poorly designed.
```

Good:

```text
The authentication system verifies tokens in middleware (`src/auth/middleware.dart:89`) before protected routes are invoked (`src/routes/protected_routes.dart:42`).
```

Bad:

```text
The code should use async/await instead of callbacks.
```

Good:

```text
The database queries use a callback-style API (`src/db/users.dart:156`). Error handling follows the `(error, result)` branch pattern at `src/db/users.dart:172`.
```
