import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/render/cache/scan_resistant_cache.dart';

void main() {
  test('ScanResistantCache rejects non-positive maxEntries', () {
    expect(
      () => ScanResistantCache<String, int>(maxEntries: 0),
      throwsArgumentError,
    );
    expect(
      () => ScanResistantCache<String, int>(maxEntries: -1),
      throwsArgumentError,
    );
  });

  test(
    'ScanResistantCache avoids full churn on a stable maxEntries plus one scan',
    () {
      final cache = ScanResistantCache<String, String>(maxEntries: 2);

      String read(String key) {
        return cache.getOrBuild(
          key: key,
          isValid: (_) => true,
          build: () {
            return key;
          },
        );
      }

      read('A');
      read('B');
      read('C');

      expect(cache.debugBuildCount, 3);
      expect(cache.debugHitCount, 0);
      expect(cache.debugSize, 2);
      expect(cache.debugEvictCount, 1);

      read('A');
      read('B');
      read('C');

      expect(cache.debugBuildCount, 4);
      expect(cache.debugHitCount, 2);
      expect(cache.debugSize, 2);
      expect(cache.debugEvictCount, 2);
    },
  );

  test(
    'ScanResistantCache promotes reused probationary entries and demotes protected overflow',
    () {
      final cache = ScanResistantCache<String, String>(maxEntries: 3);

      String read(String key) {
        return cache.getOrBuild(
          key: key,
          isValid: (_) => true,
          build: () {
            return key;
          },
        );
      }

      for (final key in <String>['A', 'B', 'C']) {
        read(key);
      }
      expect(cache.debugBuildCount, 3);
      expect(cache.debugHitCount, 0);
      expect(cache.debugSize, 3);
      expect(cache.debugEvictCount, 0);

      read('A');
      read('B');
      read('C');

      expect(cache.debugBuildCount, 3);
      expect(cache.debugSize, 3);
      expect(cache.debugHitCount, 3);
      expect(cache.debugEvictCount, 0);

      read('A');

      expect(cache.debugBuildCount, 3);
      expect(cache.debugSize, 3);
      expect(cache.debugHitCount, 4);
      expect(cache.debugEvictCount, 0);
    },
  );

  test(
    'ScanResistantCache stays bounded after promotion at maxEntries one',
    () {
      final cache = ScanResistantCache<String, String>(maxEntries: 1);

      String read(String key) {
        return cache.getOrBuild(
          key: key,
          isValid: (_) => true,
          build: () {
            return key;
          },
        );
      }

      read('A');
      expect(cache.debugBuildCount, 1);
      expect(cache.debugHitCount, 0);
      expect(cache.debugSize, 1);
      expect(cache.debugEvictCount, 0);

      read('B');
      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 0);
      expect(cache.debugSize, 1);
      expect(cache.debugEvictCount, 1);

      read('A');

      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 1);
      expect(cache.debugSize, 1);
      expect(cache.debugEvictCount, 1);

      read('A');

      expect(cache.debugBuildCount, 2);
      expect(cache.debugSize, 1);
      expect(cache.debugHitCount, 2);
      expect(cache.debugEvictCount, 1);
    },
  );

  test('ScanResistantCache clear drops both queues', () {
    final cache = ScanResistantCache<String, String>(maxEntries: 2);
    cache.getOrBuild(key: 'A', isValid: (_) => true, build: () => 'A');
    cache.getOrBuild(key: 'B', isValid: (_) => true, build: () => 'B');
    expect(cache.debugSize, 2);
    cache.clear();
    expect(cache.debugSize, 0);
  });
}
