---
name: changelog-sync
description: Maintain `CHANGELOG.md`. Use when adding unreleased entries, normalizing changelog wording, cutting a release section, or auditing whether the changelog matches current user-visible package changes.
---

# Maintain CHANGELOG.md

Treat `CHANGELOG.md` as the user-facing release ledger for `iwb_canvas_engine`.
Do not treat it as a PR diary, refactor log, test journal, or implementation narrative.

## Outcome

Produce a `CHANGELOG.md` that is:

- accurate to current user-visible package changes
- concise enough to scan release-to-release
- structured consistently across unreleased and released sections
- focused on supported public behavior, package scope, and release artifacts
- synchronized with the rest of the repository docs without duplicating them

## Source of truth

Read these sources before editing changelog content:

1. `AGENTS.md`
2. the current `CHANGELOG.md`
3. `pubspec.yaml`
4. the current task diff or changed files relevant to the requested change
5. affected public contract code and tests when user impact is unclear
6. `README.md` and `API_GUIDE.md` only to keep terminology consistent, not to discover changes retroactively

When code and changelog wording disagree, prefer the checked-in public behavior and rewrite the entry so it matches reality.

## Work mode

Classify the task before editing.

### 1. Add or adjust unreleased entries

Use this mode when the task adds, removes, or sharpens changelog bullets for checked-in but unreleased work.
Patch only `## Unreleased` unless the user explicitly asks for release-cut work.

### 2. Normalize the unreleased section

Use this mode when `## Unreleased` has drifted into duplicate bullets, mixed categories, vague wording, or internal-only detail.
Rewrite the affected subsection so it reads cleanly.

### 3. Release cut

Use this mode when the package version is being cut or the user explicitly asks for a release section.
Move relevant unreleased bullets into a new versioned section and leave `## Unreleased` present at the top.
Do not invent a version number or date.

### 4. History cleanup

Use this mode only when the existing file is structurally inconsistent or clearly inaccurate.
Preserve historical sections whenever their meaning is still correct.
Do not rewrite history just to make the tone prettier.

Default to the smallest mode that preserves clarity.

## Section contract

Preserve the current top-level structure unless the changelog is genuinely broken.

### Title and intro

Keep a short title and a one- or two-line explanation that this file tracks user-facing changes.
Do not add policy essays here.

### `## Unreleased`

Keep `Unreleased` first.
It should always exist, even when empty.
Only include checked-in changes that are not yet represented by a released section.

### Versioned sections

Use this exact heading shape:

```md
## x.y.z (YYYY-MM-DD)
```

Keep sections newest-first.
Do not invent a release section without a concrete version and date.

### Allowed subsections

Use only the categories that actually have entries.
Preferred subsection order:

1. `### Breaking`
2. `### Added`
3. `### Changed`
4. `### Fixed`

In this repository, a dedicated `### Breaking` subsection satisfies the requirement to clearly mark breaking changes.
If a breaking item must appear outside that subsection for a special reason, prefix the bullet with `Breaking:`.

## Entry rules

Each bullet should describe one logical user-visible change.
Prefer the integrator-visible effect first, then the specific symbol or contract term when needed.

Good patterns:

- `Added public validated boundary-value types for ids, offsets, and bounded doubles.`
- `Removed legacy JSON schema 6. Current mainline reads and writes only schemaVersion = 7.`
- `Fixed move-mode listener noise so selected-node taps without drag no longer emit scene-change notifications.`

Avoid patterns like:

- internal refactor summaries with no user effect
- lists of touched files
- test-only or tooling-only notes without public consequence
- vague bullets such as `Improved internals` or `Various fixes`

## Writing rules

Follow these rules on every edit.

1. Record only user-visible changes: supported public API, schema contract, runtime behavior, integration semantics, package requirements, or release artifacts that affect users.
2. Do not include internal refactors, test reorganizations, or tooling cleanups unless users or integrators can observe the effect.
3. Use exact public type and contract names when they help a reader map the change.
4. Prefer short, parallel bullets over paragraphs.
5. Keep wording factual and release-note oriented, not promotional.
6. Merge duplicate or overlapping unreleased bullets instead of accumulating near-copies.
7. Preserve the meaning of historical entries unless there is concrete evidence they are wrong.
8. Do not invent dates, versions, migration claims, or compatibility guarantees.
9. Keep file paths, plan step ids, and private implementation vocabulary out of the changelog unless they are themselves user-facing.
10. When a release is cut, move the relevant `Unreleased` items into the versioned section in the same edit.

## Anti-bloat rules

Never add:

- PR numbers, commit hashes, or issue ids unless the repository already uses them in changelog sections
- touched-file inventories
- code-organization notes with no public effect
- architecture commentary
- roadmap or future plans
- long migration essays
- speculative risk language without a concrete shipped change
- duplicated bullets that say the same thing in different words

When a section feels crowded, merge related bullets or delete stale/internal-only detail.

## Cross-document boundaries

Respect the documentation split:

- `CHANGELOG.md` owns released and unreleased user-visible changes
- `README.md` owns package overview and onboarding
- `API_GUIDE.md` owns public API and runtime contract detail
- `ARCHITECTURE.md` owns structure, invariants, and enforcement
- `PLAN.md` owns future work and execution tracking

If a requested change belongs primarily in another document, update `CHANGELOG.md` only if a real user-visible package change happened.

## Synchronization rules

Apply these linked updates together.

- If a change alters supported public API, runtime semantics, schema versions, or error contract, update `CHANGELOG.md` in the same change.
- If `pubspec.yaml` version is being bumped for release, create or update the matching versioned section in the same edit.
- If the change only clarifies docs without changing supported behavior, usually do not add a changelog entry.
- If a breaking change lands, make the user-visible break explicit in `### Breaking` rather than hiding it in `### Changed`.
- If multiple bullets describe the same public change from different internal angles, collapse them into one clearer user-facing entry.

## Repository-specific signals

For `iwb_canvas_engine`, keep these signals especially tight:

- The changelog should talk in terms of the supported public surface, especially the single public import path and exported contract types.
- JSON schema changes are changelog-worthy when `schemaVersionWrite` or `schemaVersionsRead` changes, or when payload rules change in a user-visible way.
- Changes around `SceneSnapshot`, `SceneController`, `SceneView`, `SceneWriteTxn`, `SceneBuilder`, and `SceneDataException` are often changelog-worthy because they shape the public integration contract.
- Docs-only cleanup is normally not notable unless it changes the supported interpretation of the package contract.

If repository evidence no longer supports any of these heuristics, keep the changelog tied to actual user-visible effect rather than to internal implementation work.

## Editing discipline

Before finalizing, run this checklist.

- Every new bullet maps to a concrete checked-in user-visible change.
- `## Unreleased` is still present and still first.
- Version headings use the `x.y.z (YYYY-MM-DD)` format.
- Breaking changes are called out clearly and not buried in another category.
- No internal-only refactor or test-only item slipped into the changelog.
- Duplicate or near-duplicate bullets were merged.
- The file stayed concise and readable.

If uncertain, leave the changelog narrower and more user-facing rather than more exhaustive.
