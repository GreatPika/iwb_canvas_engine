import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/run_selection_control_diagnostics.dart'
    as selection_diagnostics;

void main() {
  group('tool/bench/run_selection_control_diagnostics.dart', () {
    test('parses default args', () {
      final options = selection_diagnostics.parseSelectionControlDiagnosticArgs(
        const <String>[],
      );

      expect(options.profile, 'smoke');
      expect(options.repeats, 7);
      expect(
        options.outputPath,
        'build/bench/selection_control_diagnostics_smoke.json',
      );
    });

    test('parses explicit args', () {
      final options = selection_diagnostics.parseSelectionControlDiagnosticArgs(
        const <String>[
          '--profile=full',
          '--repeats=5',
          '--output=build/custom.json',
        ],
      );

      expect(options.profile, 'full');
      expect(options.repeats, 5);
      expect(options.outputPath, 'build/custom.json');
    });

    test('extracts the expected benchmark result line', () {
      final result = selection_diagnostics.extractBenchResult(const <String>[
        'noise',
        'IWB_BENCH_RESULT {"name":"selection_path_painter_only","metrics":{"paint_no_selection":{"avgUs":10,"avgRssDeltaBytes":0},"paint_with_selection":{"avgUs":7,"avgRssDeltaBytes":0}},"probes":{"paint_no_selection":{"saveLayerCount":0,"unboundedSaveLayerCount":0,"saveLayerBoundsArea":0},"paint_with_selection":{"saveLayerCount":400,"unboundedSaveLayerCount":0,"saveLayerBoundsArea":100}}}',
      ], expectedCaseName: 'selection_path_painter_only');

      expect(result['name'], 'selection_path_painter_only');
    });

    test('parses a selection case run with probes', () {
      final run = selection_diagnostics.parseSelectionCaseRun(<String, Object?>{
        'metrics': <String, Object?>{
          'paint_no_selection': <String, Object?>{
            'avgUs': 100,
            'avgRssDeltaBytes': 0,
          },
          'paint_with_selection': <String, Object?>{
            'avgUs': 70,
            'avgRssDeltaBytes': 10,
          },
        },
        'probes': <String, Object?>{
          'paint_no_selection': <String, Object?>{
            'saveLayerCount': 0,
            'unboundedSaveLayerCount': 0,
            'saveLayerBoundsArea': 0,
          },
          'paint_with_selection': <String, Object?>{
            'saveLayerCount': 400,
            'unboundedSaveLayerCount': 0,
            'saveLayerBoundsArea': 1200,
          },
        },
      });

      expect(run.paintNoSelectionAvgUs, 100);
      expect(run.paintWithSelectionAvgUs, 70);
      expect(run.withOverNoRatio, 0.7);
      expect(run.paintWithSelectionProbe?.saveLayerBoundsArea, 1200);
    });

    test('does not keep a checked-in selection diagnostic baseline', () {
      final selectionDiagnosticBaselines = Directory('tool/bench/baselines')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where(
            (name) =>
                name.startsWith('selection_control_diagnostics') &&
                name.endsWith('.json'),
          )
          .toList(growable: false);

      expect(selectionDiagnosticBaselines, isEmpty);
    });

    test('stays an ad hoc report generator without baseline or diff args', () {
      final source = File(
        'tool/bench/run_selection_control_diagnostics.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('--baseline')));
      expect(source, isNot(contains('--diff')));
      expect(source, isNot(contains('diff_load_profiles')));
    });
  });
}
