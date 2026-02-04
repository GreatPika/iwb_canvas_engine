import 'dart:io';

class _Violation {
  _Violation({
    required this.filePath,
    required this.line,
    required this.directive,
    required this.target,
    required this.message,
  });

  final String filePath;
  final int line;
  final String directive;
  final String target;
  final String message;

  @override
  String toString() => '$filePath:$line: $message ($directive: $target)';
}

String _normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final out = <String>[];

  for (final part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (out.isNotEmpty) {
        out.removeLast();
      }
      continue;
    }
    out.add(part);
  }

  return '${isAbs ? '/' : ''}${out.join('/')}';
}

String _posixJoin(String a, String b) {
  if (b.startsWith('/')) {
    return _normalizePosixPath(b);
  }
  if (a.isEmpty) {
    return _normalizePosixPath(b);
  }
  return _normalizePosixPath('${a.endsWith('/') ? a : '$a/'}$b');
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

String _posixDirname(String posixPath) {
  final n = _normalizePosixPath(posixPath);
  if (n == '/' || n.isEmpty) {
    return n;
  }
  final idx = n.lastIndexOf('/');
  if (idx <= 0) {
    return n.startsWith('/') ? '/' : '';
  }
  return n.substring(0, idx);
}

String _toRepoRelPosixPath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = _normalizePosixPath(absPosixPath);
  final root = _normalizePosixPath(rootAbsPosixPath);
  if (abs == root) {
    return '/';
  }
  final rootPrefix = root.endsWith('/') ? root : '$root/';
  if (!abs.startsWith(rootPrefix)) {
    return abs;
  }
  final rel = abs.substring(root.length);
  return rel.startsWith('/') ? rel : '/$rel';
}

String _readPackageNameOrFallback(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'iwb_canvas_engine';
  }
  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!;
    }
  }
  return 'iwb_canvas_engine';
}

List<String> _extractAllQuotedStrings(String text) {
  final out = <String>[];

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch != "'" && ch != '"') {
      continue;
    }

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
      if (c == quote) {
        break;
      }
      buf.write(c);
    }
    if (j >= text.length) {
      break;
    }

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
  if (trimmed.startsWith('//')) {
    return null;
  }
  if (!trimmed.startsWith('$directive ')) {
    return null;
  }
  return _extractAllQuotedStrings(trimmed);
}

String? _sliceNameForFilePosix(String filePosixPath) {
  const marker = '/lib/src/input/slices/';
  final idx = filePosixPath.indexOf(marker);
  if (idx == -1) {
    return null;
  }
  final after = filePosixPath.substring(idx + marker.length);
  final slash = after.indexOf('/');
  if (slash == -1) {
    return null;
  }
  return after.substring(0, slash);
}

String? _resolveToRepoRelTargetPosix({
  required String targetPosix,
  required String packageName,
  required String fileDirRepoRelPosix,
}) {
  final isDart = targetPosix.startsWith('dart:');
  if (isDart) {
    return null;
  }

  final isPackage = targetPosix.startsWith('package:');
  if (isPackage) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) {
      return null;
    }
    final rest = targetPosix.substring(prefix.length);
    return _normalizePosixPath('/lib/$rest');
  }

  // Relative (including "file:"-like oddities is intentionally not supported).
  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

bool _isAllowedForSlice({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
  required String currentSlice,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }
  if (targetPosix.startsWith('package:flutter/')) {
    return true;
  }
  if (targetPosix.startsWith('package:meta/')) {
    return true;
  }

  if (resolvedRepoRelPosix == null) {
    return false;
  }

  if (resolvedRepoRelPosix.startsWith('/lib/src/core/')) {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/input/types.dart') {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/input/action_events.dart') {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/input/pointer_input.dart') {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/input/internal/')) {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/input/slices/$currentSlice/')) {
    return true;
  }

  return false;
}

bool _isAllowedForInternal({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }
  if (targetPosix.startsWith('package:flutter/')) {
    return true;
  }
  if (targetPosix.startsWith('package:meta/')) {
    return true;
  }

  if (resolvedRepoRelPosix == null) {
    return false;
  }

  if (resolvedRepoRelPosix.startsWith('/lib/src/core/')) {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/input/types.dart') {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/input/action_events.dart') {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/input/pointer_input.dart') {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/input/internal/')) {
    return true;
  }

  return false;
}

void main(List<String> args) {
  final root = Directory.current;
  final rootAbsPosix = _toPosixPath(root.absolute.path);
  final packageName = _readPackageNameOrFallback(root);
  final inputRoot = Directory(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}input',
  );

  if (!inputRoot.existsSync()) {
    stderr.writeln('No lib/src/input directory found. Nothing to check.');
    exit(0);
  }

  final violations = <_Violation>[];

  for (final entity in inputRoot.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    if (!entity.path.endsWith('.dart')) {
      continue;
    }

    final fileAbsPosixPath = _toPosixPath(entity.absolute.path);
    final filePosixPath = _toRepoRelPosixPath(
      absPosixPath: fileAbsPosixPath,
      rootAbsPosixPath: rootAbsPosix,
    );
    final isSliceFile = filePosixPath.startsWith('/lib/src/input/slices/');
    final isInternalFile = filePosixPath.startsWith('/lib/src/input/internal/');

    if (!isSliceFile && !isInternalFile) {
      continue;
    }

    final content = entity.readAsStringSync();

    final currentSlice = isSliceFile
        ? _sliceNameForFilePosix(filePosixPath)
        : null;
    final fileDirRepoRelPosix = _posixDirname(filePosixPath);

    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final line = lines[i];

      final partTargets = _extractDirectiveTargets(line, directive: 'part');
      final partOfTargets = _extractDirectiveTargets(
        line,
        directive: 'part of',
      );
      if (isSliceFile && (partTargets != null || partOfTargets != null)) {
        violations.add(
          _Violation(
            filePath: filePosixPath,
            line: lineNo,
            directive: 'part',
            target: line.trim(),
            message: 'slices/** must not use part/part of directives',
          ),
        );
      }

      final importTargets = _extractDirectiveTargets(line, directive: 'import');
      final exportTargets = _extractDirectiveTargets(line, directive: 'export');
      final directive = importTargets != null
          ? 'import'
          : (exportTargets != null ? 'export' : null);
      final targets = importTargets ?? exportTargets;
      if (directive == null || targets == null) {
        continue;
      }

      for (final target in targets) {
        final targetPosix = _toPosixPath(target);
        final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
          targetPosix: targetPosix,
          packageName: packageName,
          fileDirRepoRelPosix: fileDirRepoRelPosix,
        );

        var hasSpecificViolation = false;

        if (resolvedRepoRelPosix == '/lib/src/input/scene_controller.dart') {
          violations.add(
            _Violation(
              filePath: filePosixPath,
              line: lineNo,
              directive: directive,
              target: target,
              message: "must not $directive 'scene_controller.dart'",
            ),
          );
          hasSpecificViolation = true;
        }

        if (resolvedRepoRelPosix != null) {
          if (isInternalFile &&
              resolvedRepoRelPosix.startsWith('/lib/src/input/slices/')) {
            violations.add(
              _Violation(
                filePath: filePosixPath,
                line: lineNo,
                directive: directive,
                target: target,
                message: 'internal/** must not $directive slices/**',
              ),
            );
            hasSpecificViolation = true;
          }

          if (isSliceFile &&
              resolvedRepoRelPosix.startsWith('/lib/src/input/slices/')) {
            final importedSlice = _sliceNameForFilePosix(resolvedRepoRelPosix);
            if (currentSlice != null &&
                importedSlice != null &&
                importedSlice != currentSlice) {
              violations.add(
                _Violation(
                  filePath: filePosixPath,
                  line: lineNo,
                  directive: directive,
                  target: target,
                  message:
                      'slices/** must not $directive other slices '
                      '(current=$currentSlice, import=$importedSlice)',
                ),
              );
              hasSpecificViolation = true;
            }
          }
        }

        final allowed = isSliceFile
            ? (currentSlice != null &&
                  _isAllowedForSlice(
                    targetPosix: targetPosix,
                    resolvedRepoRelPosix: resolvedRepoRelPosix,
                    currentSlice: currentSlice,
                  ))
            : _isAllowedForInternal(
                targetPosix: targetPosix,
                resolvedRepoRelPosix: resolvedRepoRelPosix,
              );
        if (!allowed && !hasSpecificViolation) {
          final scope = isSliceFile ? 'slices/**' : 'internal/**';
          final details = resolvedRepoRelPosix ?? targetPosix;
          final isExternalPackage =
              resolvedRepoRelPosix == null &&
              targetPosix.startsWith('package:');
          final message = isExternalPackage
              ? '$scope has a disallowed external package $directive'
              : '$scope has a disallowed $directive target';
          violations.add(
            _Violation(
              filePath: filePosixPath,
              line: lineNo,
              directive: directive,
              target: target,
              message: '$message ($details)',
            ),
          );
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('OK: input import boundaries');
    exit(0);
  }

  stderr.writeln(
    'FAIL: input import boundary violations (${violations.length})',
  );
  for (final v in violations) {
    stderr.writeln('- $v');
  }
  exit(1);
}
