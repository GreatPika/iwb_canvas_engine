import 'dart:io';

import 'invariant_registry.dart';

class _Finding {
  _Finding(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

final RegExp _invRef = RegExp(r'\bINV:([A-Z0-9_-]+)\b');

bool _isDartFile(FileSystemEntity entity) {
  return entity is File && entity.path.endsWith('.dart');
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

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

void main(List<String> args) {
  final root = Directory.current;
  final rootAbsPosix = _toPosixPath(root.absolute.path);

  final excludedRepoRel = <String>{
    '/tool/invariant_registry.dart',
    '/tool/check_invariant_coverage.dart',
  };

  final scanRoots = <Directory>[
    Directory('tool'),
    Directory('test'),
  ].where((d) => d.existsSync()).toList(growable: false);

  final knownIds = invariants.map((i) => i.id).toSet();
  if (knownIds.length != invariants.length) {
    stderr.writeln(
      'FAIL: duplicate invariant IDs in tool/invariant_registry.dart',
    );
    exit(1);
  }

  final refsById = <String, Set<String>>{
    for (final id in knownIds) id: <String>{},
  };

  final unknownRefs = <_Finding>[];

  for (final dir in scanRoots) {
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (!_isDartFile(entity)) continue;

      final file = entity as File;
      final fileAbsPosix = _toPosixPath(file.absolute.path);
      final fileRepoRel = _toRepoRelPosixPath(
        absPosixPath: fileAbsPosix,
        rootAbsPosixPath: rootAbsPosix,
      );
      if (excludedRepoRel.contains(fileRepoRel)) continue;

      final content = file.readAsStringSync();
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final lineNo = i + 1;
        final line = lines[i];
        for (final match in _invRef.allMatches(line)) {
          final id = match.group(1)!;
          if (!knownIds.contains(id)) {
            unknownRefs.add(
              _Finding(
                fileRepoRel,
                lineNo,
                'unknown invariant reference INV:$id',
              ),
            );
            continue;
          }
          refsById[id]!.add(fileRepoRel);
        }
      }
    }
  }

  final missing = <Invariant>[];
  for (final inv in invariants) {
    final refs = refsById[inv.id]!;
    if (refs.isEmpty) missing.add(inv);
  }

  if (unknownRefs.isNotEmpty) {
    stderr.writeln(
      'FAIL: unknown invariant references (${unknownRefs.length})',
    );
    for (final f in unknownRefs) {
      stderr.writeln('- $f');
    }
    exit(1);
  }

  final covered = invariants.length - missing.length;
  final total = invariants.length;
  final pct = total == 0 ? 100.0 : (covered / total) * 100.0;

  if (missing.isNotEmpty) {
    stderr.writeln(
      'FAIL: invariant enforcement coverage '
      '${pct.toStringAsFixed(1)}% ($covered/$total). Missing:',
    );
    for (final inv in missing) {
      stderr.writeln('- ${inv.id} (${inv.scope}): ${inv.title}');
    }
    stderr.writeln(
      'Add at least one marker comment in a test/tool file: // INV:<id>',
    );
    exit(1);
  }

  stdout.writeln(
    'OK: invariant enforcement coverage '
    '${pct.toStringAsFixed(1)}% ($covered/$total)',
  );
}
