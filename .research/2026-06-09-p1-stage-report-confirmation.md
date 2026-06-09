---
date: 2026-06-09
researcher: Codex
commit: fdefe361
branch: new-architecture
research_question: "Confirm all P1 issues in iwb_canvas_engine_12_stage_reports.md against the current codebase."
---

# Research: P1 Stage Report Confirmation

## Summary

4 P1 entries from `iwb_canvas_engine_12_stage_reports.md` remain documented here after the implemented quick fixes were removed from this remaining-problems document.

Several entries describe overlapping symptoms of the same underlying code path. `API-002` and `SURFACE-002` both trace to invalid terminal pointer cleanup being documented but not representable or routable through the current public/surface sample path.

The original research was static. This document now tracks only the remaining P1 entries after the implemented quick fixes were removed.

## Remaining Problem Groups

The 4 remaining P1 entries collapse into 3 unique problem groups when overlapping symptoms are grouped by owning code path. The original report IDs stay listed for traceability.

| Group | Remaining report IDs | Owning code path | Grouping basis |
| --- | --- | --- | --- |
| 1 | `API-002`, `SURFACE-002` | Pointer terminal cleanup boundary | Invalid terminal cleanup is documented, but public sample validation and surface event routing both block non-finite terminal events before cleanup routing. |
| 2 | `FRAME-001` | Overlay frame capture | Overlay capture uses a full main-frame snapshot instead of minimal overlay facts. |
| 3 | `TEST-001` | Release benchmark baseline gate | Release benchmark diff runs against an approved baseline file whose current status is `unapproved`, and diff fails closed. |

## Detailed Findings

### 1. Public API Boundary

- **Location**: primary `docs/contracts/public_api_v1.md:1782`; additional `lib/src/contracts/public/canvas_pointer.dart:92`, `lib/src/contracts/public/canvas_pointer.dart:100`, `lib/src/surface/pointer_adapter.dart:37`, `lib/src/surface/pointer_adapter.dart:38`.
- **Description**: `API-002` is confirmed. The contract says down/move positions are finite and invalid terminal samples route to cleanup logic (`docs/contracts/public_api_v1.md:1782`). `CanvasPointerSample` requires a `position` (`lib/src/contracts/public/canvas_pointer.dart:92`) and validates it before construction for every phase (`lib/src/contracts/public/canvas_pointer.dart:100`). `CanvasSurfacePointerAdapter` also returns before constructing a sample when `event.localPosition` is non-finite (`lib/src/surface/pointer_adapter.dart:35`, `lib/src/surface/pointer_adapter.dart:37`, `lib/src/surface/pointer_adapter.dart:38`, `lib/src/surface/pointer_adapter.dart:42`). Surface tests cover finite routing and non-finite down/move no-effect, not active-session invalid up/cancel cleanup (`test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:55`, `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:56`, `test/surface/pointer_adapter_finite_normalization_test.dart:9`).
- **Dependencies**: public pointer sample constructor, value validators, surface pointer adapter.
- **Data flow**: Flutter pointer event -> local position finite gate -> `CanvasPointerSample` factory -> runtime route only if finite.

### 2. Frame Capture

- **Location**: primary `lib/src/frame/frame_capture_service.dart:40`; additional `lib/src/frame/captured_frame.dart:90`.
- **Description**: `FRAME-001` is confirmed. Frame contract describes `CapturedOverlayFrame` as preview/camera/style facts (`docs/contracts/frame_rendering.md:85`, `docs/contracts/frame_rendering.md:88`, `docs/contracts/frame_rendering.md:94`) and says overlay primitives are admitted from `CapturedOverlayFrame` (`docs/contracts/frame_rendering.md:175`, `docs/contracts/frame_rendering.md:178`). Current `captureOverlayFrame` calls `_captureSnapshot(inputs)` (`lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/frame_capture_service.dart:41`). `_captureSnapshot` reads revisions, selection facts, spatial paint query, resolved elements/descriptors, background, and spatial candidates (`lib/src/frame/frame_capture_service.dart:52`, `lib/src/frame/frame_capture_service.dart:55`, `lib/src/frame/frame_capture_service.dart:56`, `lib/src/frame/frame_capture_service.dart:69`, `lib/src/frame/frame_capture_service.dart:76`, `lib/src/frame/frame_capture_service.dart:80`). `CapturedOverlayFrame` stores a full `CapturedFrameSnapshot` (`lib/src/frame/captured_frame.dart:90`, `lib/src/frame/captured_frame.dart:92`, `lib/src/frame/captured_frame.dart:96`), and that snapshot includes main-frame fields (`lib/src/frame/captured_frame.dart:56`, `lib/src/frame/captured_frame.dart:57`, `lib/src/frame/captured_frame.dart:58`, `lib/src/frame/captured_frame.dart:61`, `lib/src/frame/captured_frame.dart:62`). Existing fixture expects overlay snapshot spatial candidates and doubled reads (`test/frame/fixtures/main_overlay_capture_fixture.dart:76`, `test/frame/fixtures/main_overlay_capture_fixture.dart:115`, `test/frame/fixtures/main_overlay_capture_fixture.dart:132`).
- **Dependencies**: frame capture service, captured frame models, runtime frame facts, overlay planner.
- **Data flow**: Overlay frame request -> full snapshot capture -> overlay planner uses overlay preview plus snapshot inputs.

### 3. Surface Integration And Release Readiness

- **Location**: primary `lib/src/surface/pointer_adapter.dart:25`; additional `lib/src/surface/pointer_adapter.dart:38`.
- **Description**: `SURFACE-002` is confirmed and overlaps with `API-002`. Flutter `PointerUpEvent` and `PointerCancelEvent` route into `_route(...)` with terminal phases (`lib/src/surface/pointer_adapter.dart:25`, `lib/src/surface/pointer_adapter.dart:30`). `_route` returns on any non-finite `localPosition` before phase-specific handling or sample creation (`lib/src/surface/pointer_adapter.dart:35`, `lib/src/surface/pointer_adapter.dart:37`, `lib/src/surface/pointer_adapter.dart:38`, `lib/src/surface/pointer_adapter.dart:41`). Interaction tests show cleanup-only terminal behavior once a terminal sample exists (`test/interaction/pointer_session_test.dart:119`, `test/interaction/pointer_session_test.dart:147`), but surface adapter blocks invalid terminal events before runtime routing.
- **Dependencies**: Flutter pointer adapter, public pointer sample, interaction pointer session cleanup.
- **Data flow**: Pointer up/cancel event -> non-finite localPosition gate -> no runtime terminal cleanup sample.

- **Location**: primary `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`; additional `.github/workflows/release_benchmarks.yml:30`, `tool/bench/src/benchmark_diff.dart:168`.
- **Description**: `TEST-001` is confirmed. Release benchmark workflow runs release benchmarks and diffs against the approved baseline path (`.github/workflows/release_benchmarks.yml:30`, `.github/workflows/release_benchmarks.yml:34`). The committed approved baseline exists and has `"status": "unapproved"` (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`) with a message that no measured release baseline has been approved (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:5`). Diff code treats `status == 'unapproved'` as a failure (`tool/bench/src/benchmark_diff.dart:168`, `tool/bench/src/benchmark_diff.dart:174`), and the CLI returns exit code 1 when diff is not passed (`tool/bench/src/benchmark_diff.dart:235`, `tool/bench/src/benchmark_diff.dart:240`). Tests and docs also describe this fail-closed placeholder (`test/benchmarks/benchmark_diff_test.dart:36`, `test/benchmarks/benchmark_diff_test.dart:58`, `docs/verification/benchmarks.md:111`, `docs/verification/benchmarks.md:115`).
- **Dependencies**: release benchmark workflow, approved baseline file, benchmark diff implementation.
- **Data flow**: Release workflow -> current benchmark run -> diff against approved baseline -> unapproved baseline status -> diff failure.

## Code References

- `iwb_canvas_engine_12_stage_reports.md` - remaining P1 report entries:
  `API-002`, `FRAME-001`, `SURFACE-002`, and `TEST-001`.
- `lib/src/contracts/public/canvas_pointer.dart:100` - pointer sample validates position for every phase.
- `lib/src/frame/frame_capture_service.dart:40` - overlay capture uses `_captureSnapshot`.
- `lib/src/surface/pointer_adapter.dart:38` - surface drops non-finite pointer event before sample route.
- `tool/bench/src/benchmark_diff.dart:168` - unapproved baseline status creates failure.

## Search Coverage

- Inspected: `iwb_canvas_engine_12_stage_reports.md` completely; all P1 blocks and surrounding report context.
- Inspected: `docs/contracts/public_api_v1.md`, `docs/contracts/schema_v1.md`, `docs/contracts/validation_limits.md`, `docs/contracts/resources.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/geometry.md`, `docs/contracts/spatial_kernel.md`, `docs/verification/benchmarks.md`, `docs/verification/release_gates.md`.
- Inspected: production files under `lib/src/runtime`, `lib/src/interaction`, `lib/src/edit`, `lib/src/store`, `lib/src/resources`, `lib/src/frame`, `lib/src/geometry`, `lib/src/surface`, `lib/src/contracts/public`, `lib/src/codec`.
- Inspected: guardrail and architecture tools under `tool/guardrails/src` and `tool/architecture_graph/src`.
- Inspected: release benchmark workflow and approved baseline under `.github/workflows/release_benchmarks.yml`, `.github/workflows/update_benchmark_baseline.yml`, and `tool/bench/**`.
- Inspected: relevant fixtures/tests under `test/api`, `test/api_contract`, `test/codec`, `test/runtime`, `test/interaction`, `test/resources`, `test/surface`, `test/spatial`, `test/frame`, `test/diagnostics`, `test/guardrails`, `test/architecture_graph`, and `test/benchmarks`.
- Searched: `rg -n "^ID: .*|^Приоритет: P1|^Название проблемы:" iwb_canvas_engine_12_stage_reports.md`.
- Searched: `rg -n "handleDoubleTap|UnsupportedError|contextActionRequests|CanvasContextActionRequested|CanvasPointerSample|non-finite|invalid terminal|localPosition" lib test docs`.
- Searched: `rg -n "metadata.*budget|aggregate|canvasMetadataEncodedByteLength|canvasMetadataMaxEncodedBytes|CanvasMetadata.fromMap|invalidMetadata" lib test docs`.
- Searched: `rg -n "resourceRevision|SurfaceResourceSession|beginFrameResourcePass|resolveImage\\(|CommittedDocument\\(" lib test docs`.
- Searched: `rg -n "CanvasContextActionRequested|loadDocumentFromJson|skippedCandidateCount|RejectedContextTargetRead|MarqueeCommitFacts|_withPointerCleanupEffects|_deliverPendingContextRequests" lib test docs`.
- Searched: `rg -n "invert\\(|CanvasTransform\\(|validateOffset\\(|_hitBox|_hitPath|_eraserHitsPath|spatialCandidateResultWithinBudget|CapturedOverlayFrame|captureOverlayFrame|_captureSnapshot" lib test docs`.
- Searched: `rg -n "unapproved|approved baseline is not initialized|release_ubuntu_24_04_flutter_3_38_0|release_benchmarks" .github tool docs test`.
- Not found: tests requiring invalid terminal up/cancel cleanup through `CanvasSurfacePointerAdapter`.
- Not found: current zero-read overlay capture fixture.
- Not found: measured approved release baseline replacing the unapproved placeholder at the approved release baseline path.

## Observed Architecture Facts

- Boundary validation mismatch: invalid terminal pointer cleanup is documented but blocked by both public sample validation and surface finite-position gate (`docs/contracts/public_api_v1.md:1782`, `lib/src/contracts/public/canvas_pointer.dart:100`, `lib/src/surface/pointer_adapter.dart:38`).
- Overlay/main capture coupling: overlay frame capture currently owns a full main-frame snapshot, including spatial/resource/selection facts (`lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/captured_frame.dart:56`).
- Release benchmark gate state: the current approved baseline path is intentionally present but unapproved, and diff code fails closed on that status (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`, `tool/bench/src/benchmark_diff.dart:168`).

## Open Questions

- This research did not execute Dart, Flutter, DCM, guardrail, docs, or benchmark commands.
- This research did not evaluate P2 entries from `iwb_canvas_engine_12_stage_reports.md`.
- This research did not choose remediation order or implementation ownership for the confirmed P1 entries.
