import 'dart:io';

import 'invariant_registry.dart';
import 'src/verification_contract/verification_contract_registry.dart';

final RegExp _invRef = RegExp(r'\bINV:([A-Z0-9_-]+)\b');
final RegExp _explicitInvariantMarkerLine = RegExp(
  r'^\s*//\s*INV:([A-Z0-9_-]+)\s*$',
);
final RegExp _canonicalInvariantId = RegExp(
  r'^INV-(G|ENG|SER)-[A-Z0-9]+(?:-[A-Z0-9]+)*$',
);
final RegExp _requiredTestProofPathPattern = RegExp(
  r'^(test|example/test)/.+_test\.dart$',
);
final RegExp _requiredToolProofPathPattern = RegExp(r'^tool/[^/]+\.dart$');
final RegExp _regressionProofPathPattern = RegExp(
  r'^(test|example/test)/.+_test\.dart$',
);

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
  const _DeclaredProofSurface({
    required this.label,
    required this.path,
    this.stepId,
  });

  final String label;
  final String path;
  final String? stepId;
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
    required this.explicitMarkerFilesById,
    required this.explicitMarkerIdsByFile,
    required this.legacyRefs,
    required this.unknownRefs,
  });

  final Map<String, Set<String>> explicitMarkerFilesById;
  final Map<String, Set<String>> explicitMarkerIdsByFile;
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

bool _isRequiredProofReachableByStep({
  required String path,
  required String stepId,
}) {
  switch (stepId) {
    case 'import_boundaries':
      return path == 'tool/check_import_boundaries.dart';
    case 'public_api_surface':
      return path == 'tool/check_public_api_surface.dart';
    case 'guardrails':
      return path == 'tool/check_guardrails.dart';
    case 'invariant_coverage':
      return path == 'tool/check_invariant_coverage.dart';
    case 'verification_contract':
      return path == 'tool/check_verification_contract.dart';
    case 'scope_core':
      return path.startsWith('test/core/');
    case 'scope_model_contract':
      return path.startsWith('test/model/') ||
          path.startsWith('test/serialization/') ||
          path.startsWith('test/contract/') ||
          path.startsWith('test/public_api/') ||
          path.startsWith('test/entrypoints/');
    case 'scope_controller_internal':
      return path.startsWith('test/controller/internal/');
    case 'scope_controller':
      return path.startsWith('test/controller/core/') ||
          path.startsWith('test/controller/commands/') ||
          path == 'test/controller/scene_controller_randomized_txn_test.dart' ||
          path == 'test/controller/scene_invariants_test.dart' ||
          path ==
              'test/controller/scene_snapshot_invariant_assertions_test.dart';
    case 'scope_render_view':
      return path.startsWith('test/render/') || path.startsWith('test/view/');
    case 'scope_interactive':
      return path.startsWith('test/interactive/');
    case 'scope_example':
      return path.startsWith('example/test/');
    default:
      return false;
  }
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
  final requiredPreset = requiredCodeChangePresetDefinition;
  final requiredStepIds = requiredPreset.stepIds.toSet();

  for (final invariant in invariants) {
    if (!knownIds.add(invariant.id)) {
      issues.add('duplicate invariant id ${invariant.id}');
    }
    if (!_isCanonicalInvariantId(invariant.id)) {
      issues.add('non-canonical invariant id ${invariant.id}');
    }
    if (invariant.requiredProofs.isEmpty) {
      issues.add('${invariant.id} requiredProofs must not be empty');
    }
    for (var index = 0; index < invariant.requiredProofs.length; index++) {
      final proof = invariant.requiredProofs[index];
      final label = 'requiredProofs[$index].path';
      final path = proof.path;
      if (path.startsWith('tool/')) {
        _validateProofPath(
          issues: issues,
          invariantId: invariant.id,
          label: label,
          path: path,
          pattern: _requiredToolProofPathPattern,
          expectedShape: 'top-level tool/*.dart',
        );
      } else {
        _validateProofPath(
          issues: issues,
          invariantId: invariant.id,
          label: label,
          path: path,
          pattern: _requiredTestProofPathPattern,
          expectedShape: 'test/**/*_test.dart or top-level tool/*.dart',
        );
      }
      if (proof.stepId.isEmpty) {
        issues.add('${invariant.id} requiredProofs[$index].stepId is required');
        continue;
      }
      if (!verificationSteps.containsKey(proof.stepId)) {
        issues.add(
          '${invariant.id} requiredProofs[$index].stepId must reference '
          'a known verification step: ${proof.stepId}',
        );
        continue;
      }
      if (!requiredStepIds.contains(proof.stepId)) {
        issues.add(
          '${invariant.id} requiredProofs[$index].stepId must be reachable '
          'from $requiredCodeChangePreset: ${proof.stepId}',
        );
        continue;
      }
      if (!_isRequiredProofReachableByStep(path: path, stepId: proof.stepId)) {
        issues.add(
          '${invariant.id} requiredProofs[$index] must be reachable by '
          '${proof.stepId}: $path',
        );
      }
    }
    for (var index = 0; index < invariant.regressionProofs.length; index++) {
      _validateProofPath(
        issues: issues,
        invariantId: invariant.id,
        label: 'regressionProofs[$index].path',
        path: invariant.regressionProofs[index].path,
        pattern: _regressionProofPathPattern,
        expectedShape: 'test/**/*_test.dart',
      );
    }
  }

  return _RegistryContract(knownIds: knownIds, issues: issues);
}

List<Directory> _scanRoots() {
  return <Directory>[
    Directory('tool'),
    Directory('test'),
    Directory('example/test'),
  ].where((entry) => entry.existsSync()).toList(growable: false);
}

_ScanResult _scanReferenceFiles({
  required Set<String> knownIds,
  required Set<String> excludedRepoRel,
  required String rootAbsPosix,
}) {
  final explicitMarkerFilesById = <String, Set<String>>{
    for (final id in knownIds) id: <String>{},
  };
  final explicitMarkerIdsByFile = <String, Set<String>>{};
  final legacyRefs = <_Finding>[];
  final unknownRefs = <_Finding>[];

  for (final dir in _scanRoots()) {
    _scanDirectory(
      dir,
      explicitMarkerFilesById: explicitMarkerFilesById,
      explicitMarkerIdsByFile: explicitMarkerIdsByFile,
      legacyRefs: legacyRefs,
      unknownRefs: unknownRefs,
      knownIds: knownIds,
      excludedRepoRel: excludedRepoRel,
      rootAbsPosix: rootAbsPosix,
    );
  }

  return _ScanResult(
    explicitMarkerFilesById: explicitMarkerFilesById,
    explicitMarkerIdsByFile: explicitMarkerIdsByFile,
    legacyRefs: legacyRefs,
    unknownRefs: unknownRefs,
  );
}

void _scanDirectory(
  Directory dir, {
  required Map<String, Set<String>> explicitMarkerFilesById,
  required Map<String, Set<String>> explicitMarkerIdsByFile,
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
      explicitMarkerFilesById: explicitMarkerFilesById,
      explicitMarkerIdsByFile: explicitMarkerIdsByFile,
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
  required Map<String, Set<String>> explicitMarkerFilesById,
  required Map<String, Set<String>> explicitMarkerIdsByFile,
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
      explicitMarkerFilesById: explicitMarkerFilesById,
      explicitMarkerIdsByFile: explicitMarkerIdsByFile,
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
  required Map<String, Set<String>> explicitMarkerFilesById,
  required Map<String, Set<String>> explicitMarkerIdsByFile,
  required List<_Finding> legacyRefs,
  required List<_Finding> unknownRefs,
  required Set<String> knownIds,
}) {
  final explicitMarkerMatch = _explicitInvariantMarkerLine.firstMatch(line);
  final explicitMarkerId = explicitMarkerMatch?.group(1);

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

    if (id == explicitMarkerId) {
      explicitMarkerFilesById[id]!.add(fileRepoRel);
      explicitMarkerIdsByFile
          .putIfAbsent(fileRepoRel, () => <String>{})
          .add(id);
    }
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
  for (var index = 0; index < invariant.requiredProofs.length; index++) {
    final proof = invariant.requiredProofs[index];
    yield _DeclaredProofSurface(
      label: 'requiredProofs[$index]',
      path: proof.path,
      stepId: proof.stepId,
    );
  }
  for (var index = 0; index < invariant.regressionProofs.length; index++) {
    final proof = invariant.regressionProofs[index];
    yield _DeclaredProofSurface(
      label: 'regressionProofs[$index]',
      path: proof.path,
    );
  }
}

_CoverageReport _collectCoverageReport(
  Map<String, Set<String>> explicitMarkerFilesById,
) {
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
      if (!explicitMarkerFilesById[invariant.id]!.contains(proof.path)) {
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

const String _guardrailsEnforcementPath = 'tool/check_guardrails.dart';
const String _guardrailsTestPrefix = 'test/tool/guardrails/';

bool _isGuardrailsClaimSurface(String path) {
  return path == _guardrailsEnforcementPath ||
      (path.startsWith(_guardrailsTestPrefix) && path.endsWith('_test.dart'));
}

Map<String, Set<String>> _collectExpectedGuardrailsClaims() {
  final expectedByFile = <String, Set<String>>{};

  for (final invariant in invariants) {
    for (final proof in invariant.requiredProofs) {
      if (_isGuardrailsClaimSurface(proof.path)) {
        expectedByFile
            .putIfAbsent(proof.path, () => <String>{})
            .add(invariant.id);
      }
    }
    for (final proof in invariant.regressionProofs) {
      if (_isGuardrailsClaimSurface(proof.path)) {
        expectedByFile
            .putIfAbsent(proof.path, () => <String>{})
            .add(invariant.id);
      }
    }
  }

  return expectedByFile;
}

String _formatInvariantIdList(Set<String> ids) {
  final sortedIds = ids.toList()..sort();
  if (sortedIds.isEmpty) {
    return '<none>';
  }
  return sortedIds.join(', ');
}

List<String> _collectGuardrailsClaimHonestyIssues(
  Map<String, Set<String>> explicitMarkerIdsByFile,
) {
  final issues = <String>[];
  final expectedByFile = _collectExpectedGuardrailsClaims();
  final actualGuardrailsFiles = explicitMarkerIdsByFile.keys.where(
    _isGuardrailsClaimSurface,
  );
  final allFiles = <String>{...expectedByFile.keys, ...actualGuardrailsFiles}
    ..removeWhere((path) => !_isGuardrailsClaimSurface(path));

  final sortedFiles = allFiles.toList()..sort();
  for (final file in sortedFiles) {
    final expectedIds = expectedByFile[file] ?? const <String>{};
    final actualIds = explicitMarkerIdsByFile[file] ?? const <String>{};

    final extraIds = actualIds.difference(expectedIds).toList()..sort();
    for (final id in extraIds) {
      issues.add(
        '$file overclaims guardrails invariant INV:$id; '
        'registry-backed set for this file: ${_formatInvariantIdList(expectedIds)}',
      );
    }
  }

  return issues;
}

void _failOnCoverageGaps(_CoverageReport coverageReport) {
  final missingDetails = coverageReport.missingDetails;
  if (missingDetails.isEmpty) {
    return;
  }

  final covered = invariants.length - coverageReport.missingInvariantIds.length;
  final total = invariants.length;
  final pct = total == 0 ? 100.0 : (covered / total) * 100.0;

  stderr.writeln(
    'FAIL: invariant proof coverage '
    '${pct.toStringAsFixed(1)}% ($covered/$total). Missing:',
  );
  for (final entry in missingDetails) {
    stderr.writeln('- $entry');
  }
  stderr.writeln(
    'Declare canonical requiredProofs/regressionProofs surfaces in '
    'tool/invariant_registry.dart and keep matching // INV:<id> markers '
    'in every declared proof file.',
  );
  exit(1);
}

void _reportCoverageSuccess(_CoverageReport coverageReport) {
  final covered = invariants.length - coverageReport.missingInvariantIds.length;
  final total = invariants.length;
  final pct = total == 0 ? 100.0 : (covered / total) * 100.0;

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
  final coverageReport = _collectCoverageReport(
    scanResult.explicitMarkerFilesById,
  );
  _failOnCoverageGaps(coverageReport);
  final guardrailsClaimIssues = _collectGuardrailsClaimHonestyIssues(
    scanResult.explicitMarkerIdsByFile,
  );
  if (guardrailsClaimIssues.isNotEmpty) {
    _fail(
      'guardrails claim surfaces must match the registry-backed contour',
      guardrailsClaimIssues,
    );
  }
  _reportCoverageSuccess(coverageReport);
}
