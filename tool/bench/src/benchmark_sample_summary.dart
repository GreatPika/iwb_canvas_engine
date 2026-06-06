import 'dart:io';

import 'package:crypto/crypto.dart';

Map<String, Object?> benchmarkSampleSummary(List<int>? samples) {
  if (samples == null) {
    return {'available': false};
  }
  if (samples.isEmpty) {
    return {
      'available': true,
      'count': 0,
      'min_us': null,
      'avg_us': null,
      'p50_us': null,
      'p95_us': null,
      'max_us': null,
    };
  }

  final sorted = [...samples]..sort();
  return {
    'available': true,
    'count': sorted.length,
    'min_us': sorted.first,
    'avg_us': _avgUs(samples),
    'p50_us': _percentileUs(sorted, 0.50),
    'p95_us': _percentileUs(sorted, 0.95),
    'max_us': sorted.last,
  };
}

Map<String, Object?> benchmarkSourceFingerprint(String path) {
  final file = File(path);
  return {
    'path': path,
    'sizeBytes': file.lengthSync(),
    'sha256': sha256.convert(file.readAsBytesSync()).toString(),
  };
}

int _avgUs(List<int> samples) {
  return (samples.reduce((a, b) => a + b) / samples.length).round();
}

int _percentileUs(List<int> sortedSamples, double percentile) {
  final index = ((sortedSamples.length - 1) * percentile).round();
  return sortedSamples[index];
}
