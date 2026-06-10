---
date: 2026-06-09
researcher: Codex
commit: fdefe361
branch: new-architecture
research_question: "Confirm all P1 issues in iwb_canvas_engine_12_stage_reports.md against the current codebase."
post_research_update: "Pruned after quick-fix commits through 7d56e6f8 and compact overlay frame capture completion; retained commit records the original static research snapshot."
---

# Research: P1 Stage Report Confirmation

## Summary

1 P1 entry from `iwb_canvas_engine_12_stage_reports.md` remains documented here after the implemented fixes were removed from this remaining-problems document.

The original research was static. This document now tracks only the remaining P1 entry after the implemented fixes were removed.

## Remaining Problem Groups

The remaining P1 entry maps to 1 unique problem group. The original report ID stays listed for traceability.

| Group | Remaining report IDs | Owning code path | Grouping basis |
| --- | --- | --- | --- |
| 1 | `TEST-001` | Release benchmark baseline gate | Release benchmark diff runs against an approved baseline file whose current status is `unapproved`, and diff fails closed. |

## Detailed Findings

### 1. Release Readiness

- **Location**: primary `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`; additional `.github/workflows/release_benchmarks.yml:30`, `tool/bench/src/benchmark_diff.dart:168`.
- **Description**: `TEST-001` is confirmed. Release benchmark workflow runs release benchmarks and diffs against the approved baseline path (`.github/workflows/release_benchmarks.yml:30`, `.github/workflows/release_benchmarks.yml:34`). The committed approved baseline exists and has `"status": "unapproved"` (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`) with a message that no measured release baseline has been approved (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:5`). Diff code treats `status == 'unapproved'` as a failure (`tool/bench/src/benchmark_diff.dart:168`, `tool/bench/src/benchmark_diff.dart:174`), and the CLI returns exit code 1 when diff is not passed (`tool/bench/src/benchmark_diff.dart:235`, `tool/bench/src/benchmark_diff.dart:240`). Tests and docs also describe this fail-closed placeholder (`test/benchmarks/benchmark_diff_test.dart:36`, `test/benchmarks/benchmark_diff_test.dart:58`, `docs/verification/benchmarks.md:111`, `docs/verification/benchmarks.md:115`).
- **Dependencies**: release benchmark workflow, approved baseline file, benchmark diff implementation.
- **Data flow**: Release workflow -> current benchmark run -> diff against approved baseline -> unapproved baseline status -> diff failure.

## Code References

- `iwb_canvas_engine_12_stage_reports.md` - remaining P1 report entry:
  `TEST-001`.
- `tool/bench/src/benchmark_diff.dart:168` - unapproved baseline status creates failure.

## Search Coverage

- Inspected: `iwb_canvas_engine_12_stage_reports.md` completely; all P1 blocks and surrounding report context.
- Inspected: `docs/contracts/public_api_v1.md`, `docs/contracts/schema_v1.md`, `docs/contracts/validation_limits.md`, `docs/contracts/resources.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/geometry.md`, `docs/contracts/spatial_kernel.md`, `docs/verification/benchmarks.md`, `docs/verification/release_gates.md`.
- Inspected: production files under `lib/src/runtime`, `lib/src/interaction`, `lib/src/edit`, `lib/src/store`, `lib/src/resources`, `lib/src/frame`, `lib/src/geometry`, `lib/src/surface`, `lib/src/contracts/public`, `lib/src/codec`.
- Inspected: guardrail and architecture tools under `tool/guardrails/src` and `tool/architecture_graph/src`.
- Inspected: release benchmark workflow and approved baseline under `.github/workflows/release_benchmarks.yml`, `.github/workflows/update_benchmark_baseline.yml`, and `tool/bench/**`.
- Inspected: relevant fixtures/tests under `test/api`, `test/api_contract`, `test/codec`, `test/runtime`, `test/interaction`, `test/resources`, `test/surface`, `test/spatial`, `test/frame`, `test/diagnostics`, `test/guardrails`, `test/architecture_graph`, and `test/benchmarks`.
- Searched: `rg -n "^ID: .*|^Приоритет: P1|^Название проблемы:" iwb_canvas_engine_12_stage_reports.md`.
- Searched: `rg -n "handleDoubleTap|UnsupportedError|contextActionRequests|CanvasContextActionRequested" lib test docs`.
- Searched: `rg -n "metadata.*budget|aggregate|canvasMetadataEncodedByteLength|canvasMetadataMaxEncodedBytes|CanvasMetadata.fromMap|invalidMetadata" lib test docs`.
- Searched: `rg -n "resourceRevision|SurfaceResourceSession|beginFrameResourcePass|resolveImage\\(|CommittedDocument\\(" lib test docs`.
- Searched: `rg -n "CanvasContextActionRequested|loadDocumentFromJson|skippedCandidateCount|RejectedContextTargetRead|MarqueeCommitFacts|_withPointerCleanupEffects|_deliverPendingContextRequests" lib test docs`.
- Searched: `rg -n "invert\\(|CanvasTransform\\(|validateOffset\\(|_hitBox|_hitPath|_eraserHitsPath|spatialCandidateResultWithinBudget|CapturedOverlayFrame|captureOverlayFrame|_captureSnapshot" lib test docs`.
- Searched: `rg -n "unapproved|approved baseline is not initialized|release_ubuntu_24_04_flutter_3_38_0|release_benchmarks" .github tool docs test`.
- Not found: measured approved release baseline replacing the unapproved placeholder at the approved release baseline path.

## Observed Architecture Facts

- Release benchmark gate state: the current approved baseline path is intentionally present but unapproved, and diff code fails closed on that status (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`, `tool/bench/src/benchmark_diff.dart:168`).

## Open Questions

- This research did not execute Dart, Flutter, DCM, guardrail, docs, or benchmark commands.
- This research did not evaluate P2 entries from `iwb_canvas_engine_12_stage_reports.md`.
- This research did not choose remediation order or implementation ownership for the confirmed P1 entry.
