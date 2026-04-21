import 'dart:io';

String normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  final normalizedParts = <String>[];

  for (final part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (normalizedParts.isNotEmpty) {
        normalizedParts.removeLast();
      }
      continue;
    }
    normalizedParts.add(part);
  }

  return '${isAbs ? '/' : ''}${normalizedParts.join('/')}';
}

String posixJoin(String a, String b) {
  if (b.startsWith('/')) {
    return normalizePosixPath(b);
  }
  if (a.isEmpty) {
    return normalizePosixPath(b);
  }
  return normalizePosixPath('${a.endsWith('/') ? a : '$a/'}$b');
}

String posixDirname(String posixPath) {
  final normalized = normalizePosixPath(posixPath);
  if (normalized == '/' || normalized.isEmpty) {
    return normalized;
  }
  final slashIndex = normalized.lastIndexOf('/');
  if (slashIndex <= 0) {
    return normalized.startsWith('/') ? '/' : '';
  }
  return normalized.substring(0, slashIndex);
}

String toPosixPath(String path) => path.replaceAll('\\', '/');

String toRepoRelPosixPath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = normalizePosixPath(absPosixPath);
  final root = normalizePosixPath(rootAbsPosixPath);
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

String repoRelPosixToAbsPath({
  required String repoRelPosixPath,
  required String rootAbsPosixPath,
}) {
  final relPath = repoRelPosixPath.startsWith('/')
      ? repoRelPosixPath.substring(1)
      : repoRelPosixPath;
  return posixJoin(rootAbsPosixPath, relPath);
}

String readPackageNameOrFallback(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'iwb_canvas_engine';
  }

  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(trimmed);
    if (match != null) {
      final packageName = match.group(1);
      if (packageName != null) {
        return packageName;
      }
    }
  }
  return 'iwb_canvas_engine';
}

String? resolveToRepoRelTargetPosix({
  required String targetPosix,
  required String packageName,
  required String fileDirRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return null;
  }
  if (targetPosix.startsWith('package:')) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) {
      return null;
    }
    final rest = targetPosix.substring(prefix.length);
    return normalizePosixPath('/lib/$rest');
  }
  return posixJoin(fileDirRepoRelPosix, targetPosix);
}
