import 'dart:io';

// Invariants enforced by this tool:
// INV:INV-ENG-NO-EXTERNAL-MUTATION
// INV:INV-ENG-WRITE-ONLY-MUTATION
// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-EPOCH-INVALIDATION
// INV:INV-G-PUBLIC-ENTRYPOINTS
// INV:INV-ENG-SAFE-TXN-API
// INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY

class _Violation {
  _Violation({
    required this.filePath,
    required this.line,
    required this.message,
  });

  final String filePath;
  final int line;
  final String message;

  @override
  String toString() => '$filePath:$line: $message';
}

class _InteractiveEntrypointSignature {
  _InteractiveEntrypointSignature({
    required this.name,
    required this.bodyRemainder,
  });

  final String name;
  final String bodyRemainder;

  bool get isDispose => name == 'dispose';
}

const _fullyScannedExportedApiOwnerFiles = <String>{
  '/lib/src/core/action_events.dart',
  '/lib/src/core/interaction_types.dart',
  '/lib/src/core/pointer_input.dart',
  '/lib/src/interactive/scene_controller_interactive.dart',
  '/lib/src/model/scene_builder_api.dart',
};

String _normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
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

String _posixJoin(String a, String b) {
  if (b.startsWith('/')) return _normalizePosixPath(b);
  if (a.isEmpty) return _normalizePosixPath(b);
  return _normalizePosixPath('${a.endsWith('/') ? a : '$a/'}$b');
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

String _toRepoRelPosixPath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = _normalizePosixPath(absPosixPath);
  final root = _normalizePosixPath(rootAbsPosixPath);
  if (abs == root) return '/';
  final rootPrefix = root.endsWith('/') ? root : '$root/';
  if (!abs.startsWith(rootPrefix)) return abs;
  final rel = abs.substring(root.length);
  return rel.startsWith('/') ? rel : '/$rel';
}

String _posixDirname(String posixPath) {
  final n = _normalizePosixPath(posixPath);
  if (n == '/' || n.isEmpty) return n;
  final idx = n.lastIndexOf('/');
  if (idx <= 0) return n.startsWith('/') ? '/' : '';
  return n.substring(0, idx);
}

String _readPackageNameOrFallback(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) return 'iwb_canvas_engine';

  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(trimmed);
    if (match != null) return match.group(1)!;
  }
  return 'iwb_canvas_engine';
}

List<String> _extractAllQuotedStrings(String text) {
  final out = <String>[];
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch != "'" && ch != '"') continue;

    final quote = ch;
    final buf = StringBuffer();
    var escaped = false;
    var j = i + 1;
    for (; j < text.length; j++) {
      final c = text[j];
      if (escaped) {
        buf.write(c);
        escaped = false;
        continue;
      }
      if (c == r'\') {
        escaped = true;
        continue;
      }
      if (c == quote) break;
      buf.write(c);
    }
    if (j >= text.length) break;
    out.add(buf.toString());
    i = j;
  }
  return out;
}

List<String>? _extractDirectiveTargets(
  String line, {
  required String directive,
}) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return null;
  if (!trimmed.startsWith('$directive ')) return null;
  return _extractAllQuotedStrings(trimmed);
}

String? _resolveToRepoRelTargetPosix({
  required String targetPosix,
  required String packageName,
  required String fileDirRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) return null;
  if (targetPosix.startsWith('package:')) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) return null;
    final rest = targetPosix.substring(prefix.length);
    return _normalizePosixPath('/lib/$rest');
  }
  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

bool _looksMutatingSymbol(String symbol) {
  const prefixes = <String>[
    'add',
    'remove',
    'delete',
    'clear',
    'replace',
    'update',
    'set',
    'move',
    'insert',
    'mutate',
    'commit',
    'apply',
  ];
  return prefixes.any(symbol.startsWith);
}

Never _fail(_Violation violation) {
  stderr.writeln('FAIL: guardrails');
  stderr.writeln('- $violation');
  exit(1);
}

void _checkExportedApiImports({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
  required Set<String> exportedFiles,
}) {
  final disallowedPrefixes = <String>[
    '/lib/src/controller/',
    '/lib/src/render/',
    '/lib/src/view/',
    '/lib/src/serialization/',
  ];

  final filesToCheck = exportedFiles
      .where(
        (path) =>
            path.startsWith('/lib/src/contract/') ||
            path == '/lib/src/model/scene_builder_api.dart',
      )
      .toList(growable: false);
  if (filesToCheck.isEmpty) return;

  for (final filePosixPath in filesToCheck) {
    final absPath = _toPosixPath(
      _posixJoin(root.path, filePosixPath.substring(1)),
    );
    final file = File(absPath);
    if (!file.existsSync()) continue;

    final fileDirRepoRelPosix = _posixDirname(filePosixPath);
    final lines = file.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i];
      final importTargets = _extractDirectiveTargets(line, directive: 'import');
      final exportTargets = _extractDirectiveTargets(line, directive: 'export');
      final targets = importTargets ?? exportTargets;
      if (targets == null) continue;

      for (final target in targets) {
        final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
          targetPosix: _toPosixPath(target),
          packageName: packageName,
          fileDirRepoRelPosix: fileDirRepoRelPosix,
        );
        if (resolvedRepoRelPosix == null) continue;
        final isDisallowed = disallowedPrefixes.any(
          resolvedRepoRelPosix.startsWith,
        );
        if (isDisallowed) {
          _fail(
            _Violation(
              filePath: filePosixPath,
              line: lineNo,
              message:
                  'exported contract/model API must not import/export '
                  'controller/render/view/serialization internals '
                  '($resolvedRepoRelPosix)',
            ),
          );
        }
      }
    }
  }
}

Set<String> _collectEntrypointExportTargets({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
}) {
  final entrypointFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}iwb_canvas_engine.dart',
  );
  if (!entrypointFile.existsSync()) {
    return const <String>{};
  }

  final entrypointAbsPosixPath = _toPosixPath(entrypointFile.absolute.path);
  final entrypointPosixPath = _toRepoRelPosixPath(
    absPosixPath: entrypointAbsPosixPath,
    rootAbsPosixPath: rootAbsPosix,
  );
  final entrypointDirRepoRelPosix = _posixDirname(entrypointPosixPath);
  final targets = <String>{};
  final lines = entrypointFile.readAsLinesSync();

  for (final line in lines) {
    final exportTargets = _extractDirectiveTargets(line, directive: 'export');
    if (exportTargets == null) continue;

    for (final target in exportTargets) {
      final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
        targetPosix: _toPosixPath(target),
        packageName: packageName,
        fileDirRepoRelPosix: entrypointDirRepoRelPosix,
      );
      if (resolvedRepoRelPosix != null) {
        targets.add(resolvedRepoRelPosix);
      }
    }
  }
  return targets;
}

Set<String> _checkEntrypointGuardrails({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
}) {
  final advancedFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}advanced.dart',
  );
  if (advancedFile.existsSync()) {
    _fail(
      _Violation(
        filePath: '/lib/advanced.dart',
        line: 1,
        message: 'advanced.dart entrypoint is forbidden.',
      ),
    );
  }

  final exports = _collectEntrypointExportTargets(
    root: root,
    rootAbsPosix: rootAbsPosix,
    packageName: packageName,
  );
  if (exports.isEmpty) {
    return exports;
  }

  const forbiddenExports = <String>{
    '/lib/src/core/scene.dart',
    '/lib/src/core/nodes.dart',
  };
  for (final path in forbiddenExports) {
    if (exports.contains(path)) {
      _fail(
        _Violation(
          filePath: '/lib/iwb_canvas_engine.dart',
          line: 1,
          message:
              'iwb_canvas_engine.dart must not export mutable core model ($path).',
        ),
      );
    }
  }
  return exports;
}

bool _isAllowedRootLibStatement(String statement) {
  final trimmed = statement.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed == 'library;') return true;
  if (RegExp(r'^library\s+[A-Za-z_][A-Za-z0-9_\.]*\s*;$').hasMatch(trimmed)) {
    return true;
  }
  return trimmed.startsWith('export ') && trimmed.endsWith(';');
}

void _checkRootLibFilesAreExportOnly({
  required Directory root,
  required String rootAbsPosix,
}) {
  final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
  if (!libDir.existsSync()) return;

  final rootLibFiles = libDir
      .listSync(recursive: false, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  for (final file in rootLibFiles) {
    final filePosixPath = _toRepoRelPosixPath(
      absPosixPath: _toPosixPath(file.absolute.path),
      rootAbsPosixPath: rootAbsPosix,
    );
    final lines = file.readAsLinesSync();
    var inBlockComment = false;
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var singleQuoteEscaped = false;
    var doubleQuoteEscaped = false;
    final statementBuffer = StringBuffer();
    int? statementStartLine;

    void appendStatementChar(String char, int lineNo) {
      if (statementBuffer.isEmpty && char.trim().isEmpty) {
        return;
      }
      statementStartLine ??= lineNo;
      statementBuffer.write(char);
    }

    Never failStatement(int lineNo) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: statementStartLine ?? lineNo,
          message:
              'root lib/*.dart files must contain only library/docs/comments/export directives.',
        ),
      );
    }

    void validateCompletedStatement(int lineNo) {
      final statement = statementBuffer.toString().trim();
      if (statement.isEmpty) {
        statementBuffer.clear();
        statementStartLine = null;
        return;
      }
      if (!_isAllowedRootLibStatement(statement)) {
        failStatement(lineNo);
      }
      statementBuffer.clear();
      statementStartLine = null;
    }

    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i];
      var index = 0;
      while (index < line.length) {
        final char = line[index];
        final hasNext = index + 1 < line.length;
        final nextChar = hasNext ? line[index + 1] : '';

        if (inBlockComment) {
          if (char == '*' && nextChar == '/') {
            inBlockComment = false;
            index += 2;
            continue;
          }
          index++;
          continue;
        }

        if (inSingleQuote) {
          appendStatementChar(char, lineNo);
          if (singleQuoteEscaped) {
            singleQuoteEscaped = false;
          } else if (char == r'\') {
            singleQuoteEscaped = true;
          } else if (char == "'") {
            inSingleQuote = false;
          }
          index++;
          continue;
        }

        if (inDoubleQuote) {
          appendStatementChar(char, lineNo);
          if (doubleQuoteEscaped) {
            doubleQuoteEscaped = false;
          } else if (char == r'\') {
            doubleQuoteEscaped = true;
          } else if (char == '"') {
            inDoubleQuote = false;
          }
          index++;
          continue;
        }

        if (char == '/' && nextChar == '/') {
          break;
        }
        if (char == '/' && nextChar == '*') {
          inBlockComment = true;
          index += 2;
          continue;
        }
        if (char == "'") {
          appendStatementChar(char, lineNo);
          inSingleQuote = true;
          singleQuoteEscaped = false;
          index++;
          continue;
        }
        if (char == '"') {
          appendStatementChar(char, lineNo);
          inDoubleQuote = true;
          doubleQuoteEscaped = false;
          index++;
          continue;
        }

        appendStatementChar(char, lineNo);
        if (char == ';') {
          validateCompletedStatement(lineNo);
        }
        index++;
      }

      if (!inBlockComment &&
          !inSingleQuote &&
          !inDoubleQuote &&
          statementBuffer.isNotEmpty) {
        statementBuffer.write('\n');
      }
    }

    if (statementBuffer.toString().trim().isNotEmpty) {
      failStatement(lines.isEmpty ? 1 : lines.length);
    }
  }
}

void _checkSceneWriteTxnContract({
  required Directory root,
  required String rootAbsPosix,
}) {
  final txnApiFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}contract${Platform.pathSeparator}scene_write_txn.dart',
  );
  if (!txnApiFile.existsSync()) return;

  final fileAbsPosixPath = _toPosixPath(txnApiFile.absolute.path);
  final filePosixPath = _toRepoRelPosixPath(
    absPosixPath: fileAbsPosixPath,
    rootAbsPosixPath: rootAbsPosix,
  );
  final lines = txnApiFile.readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    final lineNo = i + 1;
    final line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;

    if (RegExp(r'\bget\s+scene\b').hasMatch(line) ||
        RegExp(r'\bscene\s*=>').hasMatch(line)) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: lineNo,
          message: 'exported SceneWriteTxn must not expose raw scene access.',
        ),
      );
    }
    if (RegExp(r'\bwriteFindNode\s*\(').hasMatch(line)) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: lineNo,
          message: 'exported SceneWriteTxn must not expose writeFindNode.',
        ),
      );
    }
    if (RegExp(r'\bwriteMark[A-Za-z0-9_]*\s*\(').hasMatch(line)) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: lineNo,
          message:
              'exported SceneWriteTxn must not expose writeMark* escape hatches.',
        ),
      );
    }
    if (RegExp(r'\bwriteNewNodeId\s*\(').hasMatch(line) ||
        RegExp(r'\bwriteContainsNodeId\s*\(').hasMatch(line) ||
        RegExp(r'\bwriteRegisterNodeId\s*\(').hasMatch(line) ||
        RegExp(r'\bwriteUnregisterNodeId\s*\(').hasMatch(line) ||
        RegExp(r'\bwriteRebuildNodeIdIndex\s*\(').hasMatch(line)) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: lineNo,
          message:
              'exported SceneWriteTxn must not expose node-id bookkeeping methods.',
        ),
      );
    }
  }
}

void _checkExportedApiMutableTypeLeak({
  required Directory root,
  required String rootAbsPosix,
  required Set<String> exportedFiles,
}) {
  if (exportedFiles.isEmpty) return;
  final filesToCheck = exportedFiles
      .where((path) {
        return path.startsWith('/lib/src/contract/') ||
            _fullyScannedExportedApiOwnerFiles.contains(path);
      })
      .toList(growable: false);
  if (filesToCheck.isEmpty) return;

  const mutableTypePattern = r'\b(?:Scene|ContentLayer|SceneNode|NodeType)\b';
  final mutableTypeRegex = RegExp(mutableTypePattern);
  const skipPrefixes = <String>[
    '//',
    'import ',
    'export ',
    'part ',
    '@',
    'if ',
    'for ',
    'while ',
    'switch ',
    'return ',
  ];

  for (final repoRel in filesToCheck) {
    final absPath = _toPosixPath(_posixJoin(root.path, repoRel.substring(1)));
    final file = File(absPath);
    if (!file.existsSync()) continue;

    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (!mutableTypeRegex.hasMatch(line)) continue;
      if (skipPrefixes.any(trimmed.startsWith)) continue;

      final isPublicDeclarationLine =
          RegExp(
            r'^\s*(?:class|typedef|enum|mixin|extension)\s+[A-Za-z]',
          ).hasMatch(line) ||
          RegExp(r'\bget\s+[A-Za-z][A-Za-z0-9_]*\b').hasMatch(line) ||
          RegExp(r'\bset\s+[A-Za-z][A-Za-z0-9_]*\s*\(').hasMatch(line) ||
          RegExp(
            r'\b[A-Za-z][A-Za-z0-9_]*\s*\([^)]*\)\s*(?:=>|{|;)',
          ).hasMatch(line) ||
          RegExp(
            r'^\s*(?:final|const|late|static|var)\s+[A-Za-z0-9_<>,? ]+\s+[A-Za-z][A-Za-z0-9_]*\s*(?:=|;)',
          ).hasMatch(line);
      if (!isPublicDeclarationLine) continue;

      final publicNameMatch =
          RegExp(
            r'\b(?:get|set|class|typedef|enum|mixin|extension)\s+([A-Za-z][A-Za-z0-9_]*)\b',
          ).firstMatch(line) ??
          RegExp(r'\b([A-Za-z][A-Za-z0-9_]*)\s*\(').firstMatch(line);
      final publicName = publicNameMatch?.group(1);
      if (publicName != null && publicName.startsWith('_')) continue;

      _fail(
        _Violation(
          filePath: repoRel,
          line: lineNo,
          message:
              'public API must not expose mutable core types (Scene/ContentLayer/SceneNode/NodeType).',
        ),
      );
    }
  }
}

void _checkControllerGuardrails({
  required Directory root,
  required String rootAbsPosix,
}) {
  final controllerDir = Directory(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}controller',
  );
  if (!controllerDir.existsSync()) return;

  final dartFiles = controllerDir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList(growable: false);
  if (dartFiles.isEmpty) return;

  var hasControllerEpoch = false;
  const allowedMutationPrefixes = <String>['write', 'txn'];
  final symbolPattern = RegExp(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(');
  const ignoredSymbols = <String>{
    'if',
    'for',
    'while',
    'switch',
    'assert',
    'return',
    'super',
    'this',
  };

  for (final file in dartFiles) {
    final fileAbsPosixPath = _toPosixPath(file.absolute.path);
    final filePosixPath = _toRepoRelPosixPath(
      absPosixPath: fileAbsPosixPath,
      rootAbsPosixPath: rootAbsPosix,
    );
    final lines = file.readAsLinesSync();
    final fullText = lines.join('\n');

    if (fullText.contains('controllerEpoch')) {
      hasControllerEpoch = true;
    }

    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue;

      if (line.contains('replaceScene(') &&
          !fullText.contains('controllerEpoch')) {
        _fail(
          _Violation(
            filePath: filePosixPath,
            line: lineNo,
            message:
                'replaceScene-like entrypoints must preserve epoch invalidation (missing controllerEpoch usage in file)',
          ),
        );
      }

      for (final match in symbolPattern.allMatches(line)) {
        final symbol = match.group(1)!;
        final symbolStart = match.start;
        if (symbolStart > 0) {
          final prev = line[symbolStart - 1];
          if (prev == '.') {
            continue;
          }
        }
        if (ignoredSymbols.contains(symbol)) continue;
        if (allowedMutationPrefixes.any(symbol.startsWith)) continue;
        if (_looksMutatingSymbol(symbol)) {
          _fail(
            _Violation(
              filePath: filePosixPath,
              line: lineNo,
              message:
                  'mutating symbol "$symbol" must be routed through write*/txn* transaction API',
            ),
          );
        }
      }
    }
  }

  if (!hasControllerEpoch) {
    _fail(
      _Violation(
        filePath: '/lib/src/controller',
        line: 1,
        message:
            'controllerEpoch symbol is required for epoch invalidation guardrails',
      ),
    );
  }
}

int _braceDelta(String line) {
  var delta = 0;
  for (final codeUnit in line.codeUnits) {
    if (codeUnit == 123) {
      delta = delta + 1;
    } else if (codeUnit == 125) {
      delta = delta - 1;
    }
  }
  return delta;
}

bool _isSkippableBodyLine(String text) {
  final trimmed = text.trimLeft();
  return trimmed.isEmpty ||
      trimmed.startsWith('//') ||
      trimmed.startsWith('/*') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('*/');
}

_InteractiveEntrypointSignature? _parseInteractiveEntrypointSignature(
  String trimmed, {
  required String filePath,
  required int lineNo,
}) {
  if (trimmed.isEmpty ||
      trimmed.startsWith('//') ||
      trimmed.startsWith('@') ||
      trimmed.startsWith('static ') ||
      trimmed.startsWith('factory ')) {
    return null;
  }
  if (trimmed.startsWith('set ')) {
    final setterMatch = RegExp(
      r'^set\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',
    ).firstMatch(trimmed);
    if (setterMatch == null) {
      return null;
    }
    final name = setterMatch.group(1)!;
    if (name.startsWith('_')) {
      return null;
    }
    final arrowBody = RegExp(r'\)\s*=>').firstMatch(trimmed);
    if (arrowBody != null) {
      _fail(
        _Violation(
          filePath: filePath,
          line: lineNo,
          message:
              'public interactive entrypoint "$name" must use a block body guarded by _ensurePublicSideEffectAllowed(...).',
        ),
      );
    }
    final bodyOpen = RegExp(r'\)\s*\{').firstMatch(trimmed);
    if (bodyOpen == null) {
      _fail(
        _Violation(
          filePath: filePath,
          line: lineNo,
          message:
              'public interactive entrypoint "$name" must keep its signature on one line so guardrails can verify _ensurePublicSideEffectAllowed(...).',
        ),
      );
    }
    return _InteractiveEntrypointSignature(
      name: name,
      bodyRemainder: trimmed.substring(bodyOpen.end),
    );
  }

  if (trimmed.startsWith('get ') || trimmed.contains(' get ')) {
    return null;
  }
  final parenIndex = trimmed.indexOf('(');
  if (parenIndex < 0) {
    return null;
  }
  final beforeParen = trimmed.substring(0, parenIndex).trimRight();
  if (beforeParen.contains('=')) {
    return null;
  }
  final nameMatch = RegExp(
    r'([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^<>]*>)?$',
  ).firstMatch(beforeParen);
  if (nameMatch == null) {
    return null;
  }
  final name = nameMatch.group(1)!;
  if (name == 'SceneControllerInteractive' || name.startsWith('_')) {
    return null;
  }
  final arrowBody = RegExp(r'\)\s*=>').firstMatch(trimmed);
  if (arrowBody != null) {
    _fail(
      _Violation(
        filePath: filePath,
        line: lineNo,
        message:
            'public interactive entrypoint "$name" must use a block body guarded by _ensurePublicSideEffectAllowed(...).',
      ),
    );
  }
  final bodyOpen = RegExp(r'\)\s*\{').firstMatch(trimmed);
  if (bodyOpen == null) {
    _fail(
      _Violation(
        filePath: filePath,
        line: lineNo,
        message:
            'public interactive entrypoint "$name" must keep its signature on one line so guardrails can verify _ensurePublicSideEffectAllowed(...).',
      ),
    );
  }
  return _InteractiveEntrypointSignature(
    name: name,
    bodyRemainder: trimmed.substring(bodyOpen.end),
  );
}

void _validateInteractiveEntrypointGuard({
  required _InteractiveEntrypointSignature signature,
  required List<String> lines,
  required int signatureLineIndex,
  required String filePath,
}) {
  var guardLineIndex = signatureLineIndex;
  var guardLine = signature.bodyRemainder.trimLeft();

  while (_isSkippableBodyLine(guardLine)) {
    guardLineIndex = guardLineIndex + 1;
    if (guardLineIndex >= lines.length) {
      _fail(
        _Violation(
          filePath: filePath,
          line: signatureLineIndex + 1,
          message:
              'public interactive entrypoints must guard resolver purity with _ensurePublicSideEffectAllowed(...).',
        ),
      );
    }
    guardLine = lines[guardLineIndex].trimLeft();
  }

  if (!guardLine.startsWith('_ensurePublicSideEffectAllowed(')) {
    _fail(
      _Violation(
        filePath: filePath,
        line: guardLineIndex + 1,
        message:
            'public interactive entrypoints must guard resolver purity with _ensurePublicSideEffectAllowed(...).',
      ),
    );
  }

  final hasAllowAfterDispose = guardLine.contains('allowAfterDispose: true');
  if (signature.isDispose) {
    if (!hasAllowAfterDispose) {
      _fail(
        _Violation(
          filePath: filePath,
          line: guardLineIndex + 1,
          message:
              'dispose() must guard resolver purity with allowAfterDispose: true.',
        ),
      );
    }
    return;
  }

  if (hasAllowAfterDispose) {
    _fail(
      _Violation(
        filePath: filePath,
        line: guardLineIndex + 1,
        message:
            'only dispose() may call _ensurePublicSideEffectAllowed(..., allowAfterDispose: true).',
      ),
    );
  }
}

void _checkInteractiveResolverPurityGuardrails({
  required Directory root,
  required String rootAbsPosix,
}) {
  final file = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}interactive${Platform.pathSeparator}scene_controller_interactive.dart',
  );
  if (!file.existsSync()) {
    return;
  }

  final filePosixPath = _toRepoRelPosixPath(
    absPosixPath: _toPosixPath(file.absolute.path),
    rootAbsPosixPath: rootAbsPosix,
  );
  final lines = file.readAsLinesSync();

  var seenInteractiveClass = false;
  var classBraceDepth = 0;
  var ignoringConstructorDeclaration = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimLeft();

    if (!seenInteractiveClass) {
      if (!line.contains('class SceneControllerInteractive')) {
        continue;
      }
      seenInteractiveClass = true;
    }

    if (classBraceDepth == 0) {
      classBraceDepth = classBraceDepth + _braceDelta(line);
      continue;
    }

    if (classBraceDepth == 1) {
      if (ignoringConstructorDeclaration) {
        if (RegExp(r'\)\s*\{').hasMatch(trimmed)) {
          ignoringConstructorDeclaration = false;
        }
      } else if (trimmed.startsWith('SceneControllerInteractive(')) {
        if (!RegExp(r'\)\s*\{').hasMatch(trimmed)) {
          ignoringConstructorDeclaration = true;
        }
      } else {
        final signature = _parseInteractiveEntrypointSignature(
          trimmed,
          filePath: filePosixPath,
          lineNo: i + 1,
        );
        if (signature != null) {
          _validateInteractiveEntrypointGuard(
            signature: signature,
            lines: lines,
            signatureLineIndex: i,
            filePath: filePosixPath,
          );
        }
      }
    }

    classBraceDepth = classBraceDepth + _braceDelta(line);
    if (classBraceDepth == 0) {
      break;
    }
  }
}

void main(List<String> args) {
  final root = Directory.current;
  final rootAbsPosix = _toPosixPath(root.absolute.path);
  final packageName = _readPackageNameOrFallback(root);
  final exportedFiles = _checkEntrypointGuardrails(
    root: root,
    rootAbsPosix: rootAbsPosix,
    packageName: packageName,
  );

  _checkExportedApiImports(
    root: root,
    rootAbsPosix: rootAbsPosix,
    packageName: packageName,
    exportedFiles: exportedFiles,
  );
  _checkRootLibFilesAreExportOnly(root: root, rootAbsPosix: rootAbsPosix);
  _checkSceneWriteTxnContract(root: root, rootAbsPosix: rootAbsPosix);
  _checkExportedApiMutableTypeLeak(
    root: root,
    rootAbsPosix: rootAbsPosix,
    exportedFiles: exportedFiles,
  );
  _checkInteractiveResolverPurityGuardrails(
    root: root,
    rootAbsPosix: rootAbsPosix,
  );
  _checkControllerGuardrails(root: root, rootAbsPosix: rootAbsPosix);

  stdout.writeln('OK: guardrails');
}
