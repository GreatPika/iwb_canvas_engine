import 'dart:io';

class _Violation {
  _Violation(this.filePath, this.message);

  final String filePath;
  final String message;

  @override
  String toString() => '$filePath: $message';
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

String? _extractImportTarget(String line) {
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('import ')) {
    return null;
  }

  final firstQuote = trimmed.indexOf("'");
  final firstDQuote = trimmed.indexOf('"');
  final quoteIndex = (firstQuote == -1)
      ? firstDQuote
      : (firstDQuote == -1
            ? firstQuote
            : (firstQuote < firstDQuote ? firstQuote : firstDQuote));
  if (quoteIndex == -1) {
    return null;
  }

  final quoteChar = trimmed[quoteIndex];
  final endQuote = trimmed.indexOf(quoteChar, quoteIndex + 1);
  if (endQuote == -1) {
    return null;
  }

  return trimmed.substring(quoteIndex + 1, endQuote);
}

bool _containsPartDirective(String content) {
  for (final line in content.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('part ') ||
        t.startsWith('part\t') ||
        t.startsWith('part;')) {
      return true;
    }
    if (t.startsWith('part of ')) {
      return true;
    }
  }
  return false;
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

bool _isUnderPosix(String filePosixPath, String folderPosixPath) {
  final f = _normalizePosixPath(filePosixPath);
  final folder = _normalizePosixPath(folderPosixPath);
  return f == folder ||
      f.startsWith(folder.endsWith('/') ? folder : '$folder/');
}

void main(List<String> args) {
  final root = Directory.current;
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

    final filePosixPath = _toPosixPath(entity.absolute.path);
    final isSliceFile = filePosixPath.contains('/lib/src/input/slices/');
    final isInternalFile = filePosixPath.contains('/lib/src/input/internal/');

    if (!isSliceFile && !isInternalFile) {
      continue;
    }

    final content = entity.readAsStringSync();

    if (isSliceFile && _containsPartDirective(content)) {
      violations.add(
        _Violation(filePosixPath, 'must not use part/part of directives'),
      );
    }

    final fileDirPosix = _toPosixPath(entity.parent.absolute.path);
    final currentSlice = isSliceFile
        ? _sliceNameForFilePosix(filePosixPath)
        : null;

    for (final line in content.split('\n')) {
      final target = _extractImportTarget(line);
      if (target == null) {
        continue;
      }

      final targetPosix = _toPosixPath(target);

      final isDart = targetPosix.startsWith('dart:');
      final isPackage = targetPosix.startsWith('package:');
      final isRelative = !isDart && !isPackage;

      if (targetPosix.contains('scene_controller.dart')) {
        violations.add(
          _Violation(
            filePosixPath,
            "must not import 'scene_controller.dart' ($target)",
          ),
        );
      }

      if (isRelative) {
        final resolved = _posixJoin(fileDirPosix, targetPosix);

        if (isInternalFile && resolved.contains('/lib/src/input/slices/')) {
          violations.add(
            _Violation(
              filePosixPath,
              "internal/** must not import slices/** ($target)",
            ),
          );
        }

        if (isSliceFile && resolved.contains('/lib/src/input/slices/')) {
          final importedSlice = _sliceNameForFilePosix(resolved);
          if (currentSlice != null &&
              importedSlice != null &&
              importedSlice != currentSlice &&
              !_isUnderPosix(
                resolved,
                '/lib/src/input/slices/$currentSlice/',
              )) {
            violations.add(
              _Violation(
                filePosixPath,
                "slices/** must not import other slices (current=$currentSlice, import=$importedSlice, target=$target)",
              ),
            );
          }
        }

        continue;
      }

      if (isPackage) {
        final normalized = targetPosix.replaceFirst(
          'package:iwb_canvas_engine/',
          '/lib/',
        );
        if (isInternalFile && normalized.contains('/src/input/slices/')) {
          violations.add(
            _Violation(
              filePosixPath,
              "internal/** must not import slices/** ($target)",
            ),
          );
        }

        if (isSliceFile && normalized.contains('/src/input/slices/')) {
          final idx = normalized.indexOf('/src/input/slices/');
          final after = normalized.substring(idx + '/src/input/slices/'.length);
          final slash = after.indexOf('/');
          if (slash != -1) {
            final importedSlice = after.substring(0, slash);
            if (currentSlice != null && importedSlice != currentSlice) {
              violations.add(
                _Violation(
                  filePosixPath,
                  "slices/** must not import other slices (current=$currentSlice, import=$importedSlice, target=$target)",
                ),
              );
            }
          }
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
