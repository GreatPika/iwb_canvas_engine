import 'dart:io';

import '../verification_contract/verification_contract_registry.dart';
import 'coverage_models.dart';

class CoverageTestTargetLocator {
  List<String>? _allTestFilesCache;

  TestTargetResolution resolve(String sourcePath) {
    final preferredVerificationScope = _preferredVerificationScope(sourcePath);
    final candidateRoots = _candidateTestRoots(sourcePath);
    final sourceStem = _basenameWithoutExtension(sourcePath);
    final sourceTokens = _tokens(sourceStem);
    final candidates = <_ScoredCandidate>[];

    for (final testPath in _allTestFiles.where(
      (path) => candidateRoots.any(
        (root) => path == root || path.startsWith('$root/'),
      ),
    )) {
      final score = _scoreCandidate(
        sourcePath: sourcePath,
        testPath: testPath,
        sourceStem: sourceStem,
        sourceTokens: sourceTokens,
      );
      if (score <= 0) {
        continue;
      }
      candidates.add(_ScoredCandidate(path: testPath, score: score));
    }

    candidates.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return left.path.compareTo(right.path);
    });

    final selected = <String>[];
    for (final candidate in candidates) {
      if (selected.length == 5) {
        break;
      }
      selected.add(candidate.path);
    }

    return TestTargetResolution(
      testTargets: List<String>.unmodifiable(selected),
      preferredVerificationScope: preferredVerificationScope,
    );
  }

  List<String> get _allTestFiles =>
      _allTestFilesCache ??= _collectAllTestFiles();

  List<String> _collectAllTestFiles() {
    final root = Directory('test');
    if (!root.existsSync()) {
      return const <String>[];
    }
    final files = <String>[];
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) {
        continue;
      }
      files.add(entity.path.replaceAll('\\', '/'));
    }
    files.sort();
    return List<String>.unmodifiable(files);
  }

  List<String> _candidateTestRoots(String sourcePath) {
    if (sourcePath.startsWith('lib/src/core/')) {
      return const <String>['test/core'];
    }
    if (sourcePath.startsWith('lib/src/controller/internal/')) {
      return const <String>['test/controller/internal'];
    }
    if (sourcePath.startsWith('lib/src/controller/')) {
      return const <String>[
        'test/controller',
        'test/controller/core',
        'test/controller/commands',
      ];
    }
    if (sourcePath.startsWith('lib/src/interactive/')) {
      return const <String>['test/interactive'];
    }
    if (sourcePath.startsWith('lib/src/render/') ||
        sourcePath.startsWith('lib/src/view/')) {
      return const <String>['test/render', 'test/view'];
    }
    if (sourcePath.startsWith('lib/src/contract/') ||
        sourcePath.startsWith('lib/src/model/') ||
        sourcePath.startsWith('lib/src/serialization/')) {
      return const <String>[
        'test/model',
        'test/serialization',
        'test/contract',
        'test/public_api',
        'test/entrypoints',
      ];
    }
    return const <String>[];
  }

  String? _preferredVerificationScope(String sourcePath) {
    if (sourcePath.startsWith('lib/src/core/')) {
      return verificationScopeStepIds['core'];
    }
    if (sourcePath.startsWith('lib/src/controller/internal/')) {
      return verificationScopeStepIds['controller_internal'];
    }
    if (sourcePath.startsWith('lib/src/controller/')) {
      return verificationScopeStepIds['controller'];
    }
    if (sourcePath.startsWith('lib/src/interactive/')) {
      return verificationScopeStepIds['interactive'];
    }
    if (sourcePath.startsWith('lib/src/render/') ||
        sourcePath.startsWith('lib/src/view/')) {
      return verificationScopeStepIds['render_view'];
    }
    if (sourcePath.startsWith('lib/src/contract/') ||
        sourcePath.startsWith('lib/src/model/') ||
        sourcePath.startsWith('lib/src/serialization/')) {
      return verificationScopeStepIds['model_contract'];
    }
    return null;
  }

  int _scoreCandidate({
    required String sourcePath,
    required String testPath,
    required String sourceStem,
    required Set<String> sourceTokens,
  }) {
    final testStem = _basenameWithoutExtension(
      testPath,
    ).replaceAll(RegExp(r'_test$'), '');
    var score = 0;
    if (testStem == sourceStem) {
      score += 100;
    } else if (testStem.contains(sourceStem) || sourceStem.contains(testStem)) {
      score += 60;
    }

    final testTokens = _tokens(testStem);
    final sharedTokens = sourceTokens.intersection(testTokens).length;
    score += sharedTokens * 8;

    final sourceDirName = _lastDirectoryName(sourcePath);
    if (sourceDirName != null && testPath.contains('/$sourceDirName/')) {
      score += 10;
    }

    if (sourcePath.contains('/internal/') && testPath.contains('/internal/')) {
      score += 10;
    }

    return score;
  }

  String _basenameWithoutExtension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final basename = normalized.substring(normalized.lastIndexOf('/') + 1);
    final dotIndex = basename.lastIndexOf('.');
    return dotIndex == -1 ? basename : basename.substring(0, dotIndex);
  }

  String? _lastDirectoryName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.length < 2) {
      return null;
    }
    return parts[parts.length - 2];
  }

  Set<String> _tokens(String input) =>
      input.split('_').where((token) => token.isNotEmpty).toSet();
}

class _ScoredCandidate {
  const _ScoredCandidate({required this.path, required this.score});

  final String path;
  final int score;
}
