import 'dart:io';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const releaseBenchmarkReadinessGuardrailId = 'release.benchmark_readiness';

Future<List<GuardrailViolation>> checkReleaseBenchmarkReadiness() async {
  return checkReleaseBenchmarkReadinessSources(
    publicSurfaceSources: [
      GuardrailSourceSnapshot(
        path: 'lib/iwb_canvas_engine.dart',
        content: _readFile('lib/iwb_canvas_engine.dart'),
      ),
      for (final file in dartSourceFilesUnder('lib/src/api'))
        GuardrailSourceSnapshot(
          path: file.path,
          content: File(file.absolutePath).readAsStringSync(),
        ),
    ],
    productionSources: [
      for (final file in dartSourceFilesUnder('lib'))
        GuardrailSourceSnapshot(
          path: file.path,
          content: File(file.absolutePath).readAsStringSync(),
        ),
    ],
    benchmarkSources: [
      for (final file in dartSourceFilesUnder('tool/bench'))
        GuardrailSourceSnapshot(
          path: file.path,
          content: File(file.absolutePath).readAsStringSync(),
        ),
    ],
  );
}

List<GuardrailViolation> checkReleaseBenchmarkReadinessSources({
  required Iterable<GuardrailSourceSnapshot> publicSurfaceSources,
  required Iterable<GuardrailSourceSnapshot> productionSources,
  required Iterable<GuardrailSourceSnapshot> benchmarkSources,
}) {
  final violations = <GuardrailViolation>[];

  _checkPublicSurfaceSources(publicSurfaceSources, violations);
  _checkProductionSources(productionSources, violations);
  _checkBenchmarkSources(benchmarkSources, violations);

  return violations;
}

final class GuardrailSourceSnapshot {
  const GuardrailSourceSnapshot({required this.path, required this.content});

  final String path;
  final String content;
}

void _checkPublicSurfaceSources(
  Iterable<GuardrailSourceSnapshot> publicSurfaceSources,
  List<GuardrailViolation> violations,
) {
  for (final source in publicSurfaceSources) {
    for (final forbidden in const [
      'ReleaseReadiness',
      'tool/bench',
      'benchmark',
      'Benchmark',
      'bench',
      'Bench',
    ]) {
      if (source.content.contains(forbidden)) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: source.path,
            message: 'public surface must not expose release benchmark tooling',
          ),
        );
      }
    }
  }
}

void _checkProductionSources(
  Iterable<GuardrailSourceSnapshot> productionSources,
  List<GuardrailViolation> violations,
) {
  for (final source in productionSources) {
    for (final forbidden in const [
      'AppCanvasPort',
      'LegacyEngineAdapter',
      'NextEngineAdapter',
      'ReleaseReadiness',
      'tool/bench',
      'benchmark',
      'Benchmark',
      'bench',
      'Bench',
      'releaseMeasurement',
      'ReleaseMeasurement',
    ]) {
      if (source.content.contains(forbidden)) {
        violations.add(
          GuardrailViolation(
            guardrailId: releaseBenchmarkReadinessGuardrailId,
            path: source.path,
            message: 'production source must not contain $forbidden',
          ),
        );
      }
    }
  }
}

void _checkBenchmarkSources(
  Iterable<GuardrailSourceSnapshot> benchmarkSources,
  List<GuardrailViolation> violations,
) {
  final retiredPackageImport = RegExp(
    r'''^\s*(import|export)\s+['"][^'"]*legacy''',
    multiLine: true,
  );
  for (final source in benchmarkSources) {
    if (retiredPackageImport.hasMatch(source.content) ||
        source.content.contains('legacy/')) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: source.path,
          message:
              'benchmark release proof must not invoke retired package paths',
        ),
      );
    }
    if (_containsForbiddenBenchmarkBaselineWriter(source)) {
      violations.add(
        GuardrailViolation(
          guardrailId: releaseBenchmarkReadinessGuardrailId,
          path: source.path,
          message: 'approved baseline writes must stay behind update_baseline',
        ),
      );
    }
  }
}

bool _containsForbiddenBenchmarkBaselineWriter(GuardrailSourceSnapshot source) {
  if (_approvedBaselineImplementationPaths.contains(source.path)) {
    return false;
  }
  if (_containsApprovedBaselineNamespace(source.content)) {
    return true;
  }
  for (final forbidden in const [
    _approvedReleaseBaselinePath,
    'approvedReleaseBaselinePath',
    'runBenchmarkBaselineUpdateCli',
    '--approved=',
  ]) {
    if (source.content.contains(forbidden)) {
      return true;
    }
  }

  return false;
}

bool _containsApprovedBaselineNamespace(String content) {
  if (content.contains(_approvedBaselineRootPath)) {
    return true;
  }

  final compactSource = content.replaceAll(
    RegExp(r'''[\s'"`+,\[\]\(\)]'''),
    '',
  );
  return compactSource.contains(_approvedBaselineRootPath) ||
      compactSource.contains('toolbenchbaselinesapproved');
}

String _readFile(String path) {
  return File(path).readAsStringSync();
}

const _approvedReleaseBaselinePath =
    'tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_44_0.json';

const _approvedBaselineRootPath = 'tool/bench/baselines/approved/';

const _approvedBaselineImplementationPaths = {
  'tool/bench/update_baseline.dart',
  'tool/bench/src/benchmark_diff.dart',
};
