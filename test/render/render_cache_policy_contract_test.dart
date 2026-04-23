import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-ENG-RENDER-CACHE-SCAN-RESISTANT
void main() {
  test('render caches share one scan-resistant policy owner', () {
    final helperSource = File(
      'lib/src/render/cache/scan_resistant_cache.dart',
    ).readAsStringSync();
    final geometrySource = File(
      'lib/src/render/render_geometry_cache.dart',
    ).readAsStringSync();
    final textSource = File(
      'lib/src/render/cache/scene_text_layout_cache.dart',
    ).readAsStringSync();
    final strokeSource = File(
      'lib/src/render/cache/scene_stroke_path_cache.dart',
    ).readAsStringSync();
    final pathSource = File(
      'lib/src/render/cache/scene_path_metrics_cache.dart',
    ).readAsStringSync();

    expect(helperSource, contains('class ScanResistantCache<'));
    expect(helperSource, contains('_protectedEntries'));
    expect(helperSource, contains('_probationaryEntries'));
    expect(helperSource, contains('_promoteToProtected'));
    expect(helperSource, contains('_prependProbationary'));
    expect(helperSource, isNot(contains('_protectedHistory')));
    expect(helperSource, isNot(contains('_probationaryHistory')));
    expect(helperSource, isNot(contains('ARC-style')));

    for (final source in <String>[
      geometrySource,
      textSource,
      strokeSource,
      pathSource,
    ]) {
      expect(source, contains('scan_resistant_cache.dart'));
      expect(source, contains('ScanResistantCache<'));
      expect(source, isNot(contains('LinkedHashMap<')));
      expect(source, isNot(contains('least recently used entry')));
      expect(source, isNot(contains('LRU')));
    }
  });
}
