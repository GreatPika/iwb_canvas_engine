import 'dart:io';

import 'invariant_registry.dart';

final RegExp _invRef = RegExp(r'\bINV:([A-Z0-9_-]+)\b');
final RegExp _canonicalInvariantId = RegExp(
  r'^INV-(G|ENG|SER)-[A-Z0-9]+(?:-[A-Z0-9]+)*$',
);
final RegExp _primaryProofPathPattern = RegExp(r'^test/.+_test\.dart$');
final RegExp _toolEnforcementPathPattern = RegExp(r'^tool/[^/]+\.dart$');
final RegExp _toolRegressionPathPattern = RegExp(r'^test/tool/.+_test\.dart$');

class _Finding {
  _Finding(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

class _RegistryContract {
  const _RegistryContract({required this.knownIds, required this.issues});

  final Set<String> knownIds;
  final List<String> issues;
}

class _DeclaredProofSurface {
  const _DeclaredProofSurface({required this.label, required this.path});

  final String label;
  final String path;
}

class _CoverageReport {
  const _CoverageReport({
    required this.missingDetails,
    required this.missingInvariantIds,
  });

  final List<String> missingDetails;
  final Set<String> missingInvariantIds;
}

class _ScanResult {
  const _ScanResult({
    required this.refsById,
    required this.legacyRefs,
    required this.unknownRefs,
  });

  final Map<String, Set<String>> refsById;
  final List<_Finding> legacyRefs;
  final List<_Finding> unknownRefs;
}

bool _isDartFile(FileSystemEntity entity) {
  return entity is File && entity.path.endsWith('.dart');
}

bool _isCanonicalInvariantId(String id) {
  return _canonicalInvariantId.hasMatch(id);
}

bool _isRepoRelativePosixPath(String path) {
  return path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.startsWith('./') &&
      !path.contains(r'\') &&
      !path.contains('/./') &&
      !path.contains('../') &&
      !path.contains('/..');
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

String _normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  final out = <String>[];

  for (final part in parts) {
    if (part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(part);
  }

  return '${isAbs ? '/' : ''}${out.join('/')}';
}

String _toRepoRelPosixPath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = _normalizePosixPath(absPosixPath);
  final root = _normalizePosixPath(rootAbsPosixPath);
  if (abs == root) return '.';
  final rootPrefix = root.endsWith('/') ? root : '$root/';
  if (!abs.startsWith(rootPrefix)) return abs;
  return abs.substring(rootPrefix.length);
}

void _fail(String header, List<String> details) {
  stderr.writeln('FAIL: $header');
  for (final detail in details) {
    stderr.writeln('- $detail');
  }
  exit(1);
}

void _validateProofPath({
  required List<String> issues,
  required String invariantId,
  required String label,
  required String? path,
  required RegExp pattern,
  required String expectedShape,
}) {
  if (path == null || path.isEmpty) {
    issues.add('$invariantId $label is required');
    return;
  }
  if (!_isRepoRelativePosixPath(path)) {
    issues.add('$invariantId $label must be a repo-relative POSIX path: $path');
    return;
  }
  if (!pattern.hasMatch(path)) {
    issues.add('$invariantId $label must match $expectedShape: $path');
  }
}

_RegistryContract _readRegistryContract() {
  final knownIds = <String>{};
  final issues = <String>[];

  for (final invariant in invariants) {
    if (!knownIds.add(invariant.id)) {
      issues.add('duplicate invariant id ${invariant.id}');
    }
    if (!_isCanonicalInvariantId(invariant.id)) {
      issues.add('non-canonical invariant id ${invariant.id}');
    }
    _validateProofPath(
      issues: issues,
      invariantId: invariant.id,
      label: 'primaryProof.path',
      path: invariant.primaryProof.path,
      pattern: _primaryProofPathPattern,
      expectedShape: 'test/**/*_test.dart',
    );
    final toolProof = invariant.toolProof;
    if (toolProof == null) {
      continue;
    }
    _validateProofPath(
      issues: issues,
      invariantId: invariant.id,
      label: 'toolProof.enforcementPath',
      path: toolProof.enforcementPath,
      pattern: _toolEnforcementPathPattern,
      expectedShape: 'top-level tool/*.dart',
    );
    _validateProofPath(
      issues: issues,
      invariantId: invariant.id,
      label: 'toolProof.regressionPath',
      path: toolProof.regressionPath,
      pattern: _toolRegressionPathPattern,
      expectedShape: 'test/tool/**/*_test.dart',
    );
  }

  return _RegistryContract(knownIds: knownIds, issues: issues);
}

List<Directory> _scanRoots() {
  return <Directory>[
    Directory('tool'),
    Directory('test'),
  ].where((entry) => entry.existsSync()).toList(growable: false);
}

_ScanResult _scanReferenceFiles({
  required Set<String> knownIds,
  required Set<String> excludedRepoRel,
  required String rootAbsPosix,
}) {
  final refsById = <String, Set<String>>{
    for (final id in knownIds) id: <String>{},
  };
  final legacyRefs = <_Finding>[];
  final unknownRefs = <_Finding>[];

  for (final dir in _scanRoots()) {
    _scanDirectory(
      dir,
      refsById: refsById,
      legacyRefs: legacyRefs,
      unknownRefs: unknownRefs,
      knownIds: knownIds,
      excludedRepoRel: excludedRepoRel,
      rootAbsPosix: rootAbsPosix,
    );
  }

  return _ScanResult(
    refsById: refsById,
    legacyRefs: legacyRefs,
    unknownRefs: unknownRefs,
  );
}

void _scanDirectory(
  Directory dir, {
  required Map<String, Set<String>> refsById,
  required List<_Finding> legacyRefs,
  required List<_Finding> unknownRefs,
  required Set<String> knownIds,
  required Set<String> excludedRepoRel,
  required String rootAbsPosix,
}) {
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (!_isDartFile(entity)) continue;
    _scanFile(
      entity as File,
      refsById: refsById,
      legacyRefs: legacyRefs,
      unknownRefs: unknownRefs,
      knownIds: knownIds,
      excludedRepoRel: excludedRepoRel,
      rootAbsPosix: rootAbsPosix,
    );
  }
}

void _scanFile(
  File file, {
  required Map<String, Set<String>> refsById,
  required List<_Finding> legacyRefs,
  required List<_Finding> unknownRefs,
  required Set<String> knownIds,
  required Set<String> excludedRepoRel,
  required String rootAbsPosix,
}) {
  final fileRepoRel = _toRepoRelPosixPath(
    absPosixPath: _toPosixPath(file.absolute.path),
    rootAbsPosixPath: rootAbsPosix,
  );
  if (excludedRepoRel.contains(fileRepoRel)) return;

  final lines = file.readAsStringSync().split('\n');
  for (var index = 0; index < lines.length; index++) {
    _scanLine(
      lines[index],
      fileRepoRel: fileRepoRel,
      lineNo: index + 1,
      refsById: refsById,
      legacyRefs: legacyRefs,
      unknownRefs: unknownRefs,
      knownIds: knownIds,
    );
  }
}

void _scanLine(
  String line, {
  required String fileRepoRel,
  required int lineNo,
  required Map<String, Set<String>> refsById,
  required List<_Finding> legacyRefs,
  required List<_Finding> unknownRefs,
  required Set<String> knownIds,
}) {
  for (final match in _invRef.allMatches(line)) {
    final id = match.group(1);
    if (id == null) continue;
    if (!_isCanonicalInvariantId(id)) {
      legacyRefs.add(
        _Finding(
          fileRepoRel,
          lineNo,
          'non-canonical invariant reference INV:$id',
        ),
      );
      continue;
    }
    if (!knownIds.contains(id)) {
      unknownRefs.add(
        _Finding(fileRepoRel, lineNo, 'unknown invariant reference INV:$id'),
      );
      continue;
    }
    refsById[id]!.add(fileRepoRel);
  }
}

void _failOnReferenceFindings(_ScanResult scanResult) {
  if (scanResult.legacyRefs.isNotEmpty) {
    _fail(
      'legacy invariant ids are forbidden; use canonical UPPER-KEBAB-CASE',
      scanResult.legacyRefs
          .map((finding) => finding.toString())
          .toList(growable: false),
    );
  }

  if (scanResult.unknownRefs.isNotEmpty) {
    _fail(
      'unknown invariant references',
      scanResult.unknownRefs
          .map((finding) => finding.toString())
          .toList(growable: false),
    );
  }
}

Iterable<_DeclaredProofSurface> _declaredProofSurfaces(
  Invariant invariant,
) sync* {
  final primaryPath = invariant.primaryProof.path;
  if (primaryPath != null && primaryPath.isNotEmpty) {
    yield _DeclaredProofSurface(label: 'primaryProof', path: primaryPath);
  }
  final toolProof = invariant.toolProof;
  if (toolProof == null) {
    return;
  }
  final enforcementPath = toolProof.enforcementPath;
  if (enforcementPath != null && enforcementPath.isNotEmpty) {
    yield _DeclaredProofSurface(
      label: 'toolProof.enforcementPath',
      path: enforcementPath,
    );
  }
  final regressionPath = toolProof.regressionPath;
  if (regressionPath != null && regressionPath.isNotEmpty) {
    yield _DeclaredProofSurface(
      label: 'toolProof.regressionPath',
      path: regressionPath,
    );
  }
}

_CoverageReport _collectCoverageReport(Map<String, Set<String>> refsById) {
  final missingDetails = <String>[];
  final missingInvariantIds = <String>{};

  for (final invariant in invariants) {
    for (final proof in _declaredProofSurfaces(invariant)) {
      final proofFile = File(proof.path);
      if (!proofFile.existsSync()) {
        missingDetails.add(
          '${invariant.id} ${proof.label} missing: ${proof.path}',
        );
        missingInvariantIds.add(invariant.id);
        continue;
      }
      if (!refsById[invariant.id]!.contains(proof.path)) {
        missingDetails.add(
          '${invariant.id} is missing explicit proof marker in '
          '${proof.label} ${proof.path}',
        );
        missingInvariantIds.add(invariant.id);
      }
    }
  }

  return _CoverageReport(
    missingDetails: missingDetails,
    missingInvariantIds: missingInvariantIds,
  );
}

void _reportCoverage(_CoverageReport coverageReport) {
  final missingDetails = coverageReport.missingDetails;
  final covered = invariants.length - coverageReport.missingInvariantIds.length;
  final total = invariants.length;
  final pct = total == 0 ? 100.0 : (covered / total) * 100.0;

  if (missingDetails.isNotEmpty) {
    stderr.writeln(
      'FAIL: invariant proof coverage '
      '${pct.toStringAsFixed(1)}% ($covered/$total). Missing:',
    );
    for (final entry in missingDetails) {
      stderr.writeln('- $entry');
    }
    stderr.writeln(
      'Declare canonical primaryProof/toolProof surfaces in '
      'tool/invariant_registry.dart and keep matching // INV:<id> markers '
      'in every declared proof file.',
    );
    exit(1);
  }

  stdout.writeln(
    'OK: invariant proof coverage '
    '${pct.toStringAsFixed(1)}% ($covered/$total)',
  );
}

void main(List<String> _) {
  final registry = _readRegistryContract();
  if (registry.issues.isNotEmpty) {
    _fail('invalid invariant registry contract', registry.issues);
  }

  final scanResult = _scanReferenceFiles(
    knownIds: registry.knownIds,
    excludedRepoRel: <String>{
      'tool/invariant_registry.dart',
      'tool/check_invariant_coverage.dart',
    },
    rootAbsPosix: _toPosixPath(Directory.current.absolute.path),
  );
  _failOnReferenceFindings(scanResult);
  _reportCoverage(_collectCoverageReport(scanResult.refsById));
}
