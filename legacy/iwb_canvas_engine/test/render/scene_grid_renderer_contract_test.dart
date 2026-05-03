import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-ENG-GRID-BOUNDED-ITERATION
void main() {
  test('scene grid renderer uses one bounded axis plan for draw and work', () {
    final source = File(
      'lib/src/render/scene_grid_renderer.dart',
    ).readAsStringSync();

    expect(source, contains('class SceneGridAxisPlan'));
    expect(source, contains('required this.firstPosition,'));
    expect(source, contains('required this.positionStep,'));
    expect(source, contains('required this.iterationCount,'));
    expect(source, contains('final double firstPosition;'));
    expect(source, contains('final double positionStep;'));
    expect(source, contains('final int iterationCount;'));
    expect(source, contains('int get maxVisibleLines => iterationCount;'));
    expect(source, contains('loopIterations: axis.iterationCount,'));
    expect(source, contains('drawnLineCount: axis.iterationCount,'));
    expect(source, contains('iteration < axis.iterationCount;'));
    expect(source, contains('position += axis.positionStep'));
    expect(source, isNot(contains('lineUpperBound')));
    expect(source, isNot(contains('index % axis.stride')));
    expect(source, isNot(contains('position += frame.cellSize')));
  });
}
