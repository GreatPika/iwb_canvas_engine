import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/core/grid_safety_limits.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/scene_grid_renderer.dart';

// INV:INV-ENG-GRID-BOUNDED-ITERATION
Future<int> _countNonBackgroundPixelsOnColumn(
  Image image,
  int x,
  Color background,
) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }

  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgA = (argb >> 24) & 0xFF;
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;

  var count = 0;
  for (var y = 0; y < image.height; y++) {
    final index = (y * image.width + x) * 4;
    if (bytes[index] != bgR ||
        bytes[index + 1] != bgG ||
        bytes[index + 2] != bgB ||
        bytes[index + 3] != bgA) {
      count++;
    }
  }
  return count;
}

void main() {
  const renderer = SceneGridRenderer();

  test('SceneGridRenderer returns null for invalid drawable inputs', () {
    final grid = unsafeMaterializeSceneSnapshot(
      SceneSnapshotBacking(
        background: BackgroundSnapshotBacking(
          grid: GridSnapshotBacking(
            isEnabled: true,
            cellSize: 0.5,
            color: Color(0xFF000000),
          ),
        ),
      ),
    ).background.grid;

    final plan = renderer.plan(
      SceneGridRenderRequest(
        grid: grid,
        size: Size(120, 80),
        cameraOffset: Offset.zero,
        gridStrokeWidth: 1,
      ),
    );

    expect(plan, isNull);
  });

  test(
    'SceneGridRenderer keeps stride stable across near-threshold pan jitter',
    () {
      final grid = GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFF000000),
      );
      const size = Size(3980, 80);

      final basePlan = renderer.plan(
        SceneGridRenderRequest(
          grid: grid,
          size: size,
          cameraOffset: Offset.zero,
          gridStrokeWidth: 1,
        ),
      );
      final jitterPlan = renderer.plan(
        SceneGridRenderRequest(
          grid: grid,
          size: size,
          cameraOffset: Offset(5, 0),
          gridStrokeWidth: 1,
        ),
      );

      expect(basePlan, isNotNull);
      expect(jitterPlan, isNotNull);
      if (basePlan == null || jitterPlan == null) {
        fail('Expected renderer plans for drawable grid inputs.');
      }
      final resolvedBasePlan = basePlan;
      final resolvedJitterPlan = jitterPlan;
      expect(resolvedBasePlan.xAxis.stride, 1);
      expect(resolvedJitterPlan.xAxis.stride, 1);
      expect(resolvedBasePlan.xAxis.stride, resolvedJitterPlan.xAxis.stride);
    },
  );

  test('SceneGridRenderer keeps visible line cap bounded per axis', () {
    final grid = GridSnapshot(
      isEnabled: true,
      cellSize: 1,
      color: Color(0xFF000000),
    );

    final plan = renderer.plan(
      SceneGridRenderRequest(
        grid: grid,
        size: Size(600, 400),
        cameraOffset: Offset(0.5, 0.5),
        gridStrokeWidth: 1,
      ),
    );

    expect(plan, isNotNull);
    if (plan == null) {
      fail('Expected renderer plan for drawable dense grid.');
    }
    final resolvedPlan = plan;
    expect(
      resolvedPlan.xAxis.maxVisibleLines,
      lessThanOrEqualTo(kMaxGridLinesPerAxis),
    );
    expect(
      resolvedPlan.yAxis.maxVisibleLines,
      lessThanOrEqualTo(kMaxGridLinesPerAxis),
    );
  });

  test('SceneGridRenderer debugWorkForPlan stays bounded on dense grids', () {
    final grid = GridSnapshot(
      isEnabled: true,
      cellSize: 1,
      color: Color(0xFF000000),
    );

    final plan = renderer.plan(
      SceneGridRenderRequest(
        grid: grid,
        size: Size(600, 400),
        cameraOffset: Offset(0.5, 0.5),
        gridStrokeWidth: 1,
      ),
    );

    expect(plan, isNotNull);
    if (plan == null) {
      fail('Expected renderer plan for drawable dense grid.');
    }

    final work = renderer.debugWorkForPlan(plan);
    expect(work.xAxis.loopIterations, equals(work.xAxis.drawnLineCount));
    expect(work.yAxis.loopIterations, equals(work.yAxis.drawnLineCount));
    expect(work.loopIterations, equals(work.drawnLineCount));
    expect(work.xAxis.loopIterations, equals(plan.xAxis.maxVisibleLines));
    expect(work.yAxis.loopIterations, equals(plan.yAxis.maxVisibleLines));
    expect(work.toJson(), <String, Object?>{
      'loopIterations': work.loopIterations,
      'drawnLineCount': work.drawnLineCount,
      'xAxis': <String, int>{
        'loopIterations': work.xAxis.loopIterations,
        'drawnLineCount': work.xAxis.drawnLineCount,
      },
      'yAxis': <String, int>{
        'loopIterations': work.yAxis.loopIterations,
        'drawnLineCount': work.yAxis.drawnLineCount,
      },
    });
  });

  test(
    'SceneGridRenderer draws full-height vertical lines on wide viewports',
    () async {
      const background = Color(0xFFFFFFFF);
      final grid = GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFF000000),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 240, 80),
        Paint()..color = background,
      );
      renderer.draw(
        canvas,
        SceneGridRenderRequest(
          grid: grid,
          size: Size(240, 80),
          cameraOffset: Offset.zero,
          gridStrokeWidth: 1,
        ),
      );
      final image = await recorder.endRecording().toImage(240, 80);

      expect(
        await _countNonBackgroundPixelsOnColumn(image, 200, background),
        greaterThan(70),
      );
    },
  );
}
