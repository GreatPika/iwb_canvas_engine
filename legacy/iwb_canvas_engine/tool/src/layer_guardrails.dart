library;

import 'dart:io';

const Set<String> approvedTopLevelLibSrcLayers = <String>{
  'contract',
  'core',
  'model',
  'controller',
  'interactive',
  'render',
  'serialization',
  'view',
};

const Set<String> deletedTopLevelLibSrcLayers = <String>{'public'};

const Set<String> sanctionedTopLevelLibSrcLeafFiles = <String>{};

class LibSrcLayoutViolation {
  const LibSrcLayoutViolation({
    required this.path,
    required this.entry,
    required this.message,
  });

  final String path;
  final String entry;
  final String message;
}

String? topLevelLibSrcEntryForRepoRelPosixPath(String repoRelPosixPath) {
  if (!repoRelPosixPath.startsWith('/lib/src/')) {
    return null;
  }

  final remainder = repoRelPosixPath.substring('/lib/src/'.length);
  if (remainder.isEmpty) {
    return null;
  }

  final slashIndex = remainder.indexOf('/');
  if (slashIndex == -1) {
    return remainder;
  }

  final topLevelEntry = remainder.substring(0, slashIndex);
  return topLevelEntry.isEmpty ? null : topLevelEntry;
}

String? directChildUnderLibSrcForRepoRelPosixPath(String repoRelPosixPath) {
  if (!repoRelPosixPath.startsWith('/lib/src/')) {
    return null;
  }

  final remainder = repoRelPosixPath.substring('/lib/src/'.length);
  if (remainder.isEmpty || remainder.contains('/')) {
    return null;
  }

  return remainder;
}

bool isTopLevelLibSrcLeafFilePath(String repoRelPosixPath) {
  final entry = directChildUnderLibSrcForRepoRelPosixPath(repoRelPosixPath);
  return entry != null && entry.endsWith('.dart');
}

String? topLevelLibSrcLayerForRepoRelPosixPath(String repoRelPosixPath) {
  if (!repoRelPosixPath.startsWith('/lib/src/')) {
    return null;
  }

  if (isTopLevelLibSrcLeafFilePath(repoRelPosixPath)) {
    return null;
  }

  return topLevelLibSrcEntryForRepoRelPosixPath(repoRelPosixPath);
}

bool isApprovedTopLevelLibSrcLayer(String layer) =>
    approvedTopLevelLibSrcLayers.contains(layer);

bool isDeletedTopLevelLibSrcLayer(String layer) =>
    deletedTopLevelLibSrcLayers.contains(layer);

bool isSanctionedTopLevelLibSrcLeafFile(String fileName) =>
    sanctionedTopLevelLibSrcLeafFiles.contains(fileName);

String? describeLibSrcLayoutViolation(String repoRelPosixPath) {
  if (isTopLevelLibSrcLeafFilePath(repoRelPosixPath)) {
    final topLevelLeaf = directChildUnderLibSrcForRepoRelPosixPath(
      repoRelPosixPath,
    );
    if (topLevelLeaf == null) {
      return null;
    }
    if (isSanctionedTopLevelLibSrcLeafFile(topLevelLeaf)) {
      return null;
    }
    return 'layer layout violation: $repoRelPosixPath uses unapproved '
        'top-level lib/src leaf "$topLevelLeaf"';
  }

  final topLevelLayer = topLevelLibSrcLayerForRepoRelPosixPath(
    repoRelPosixPath,
  );
  if (topLevelLayer == null) {
    return null;
  }
  if (isDeletedTopLevelLibSrcLayer(topLevelLayer)) {
    return 'layer layout violation: $repoRelPosixPath uses deleted '
        'top-level layer "$topLevelLayer"';
  }
  if (!isApprovedTopLevelLibSrcLayer(topLevelLayer)) {
    return 'layer layout violation: $repoRelPosixPath uses '
        'unapproved top-level layer "$topLevelLayer"';
  }
  return null;
}

List<LibSrcLayoutViolation> collectTopLevelLibSrcLayoutViolations({
  required Directory srcRoot,
  required String rootAbsPosixPath,
  required String Function(String path) toPosixPath,
  required String Function({
    required String absPosixPath,
    required String rootAbsPosixPath,
  })
  toRepoRelPosixPath,
}) {
  if (!srcRoot.existsSync()) {
    return const <LibSrcLayoutViolation>[];
  }

  final violations = <LibSrcLayoutViolation>[];
  for (final entity in srcRoot.listSync(recursive: false, followLinks: false)) {
    if (entity is! Directory && entity is! File) {
      continue;
    }
    if (entity is File && !entity.path.endsWith('.dart')) {
      continue;
    }

    final repoRelPosixPath = toRepoRelPosixPath(
      absPosixPath: toPosixPath(entity.absolute.path),
      rootAbsPosixPath: rootAbsPosixPath,
    );
    final violationMessage = describeLibSrcLayoutViolation(repoRelPosixPath);
    if (violationMessage == null) {
      continue;
    }

    final layer = topLevelLibSrcLayerForRepoRelPosixPath(repoRelPosixPath);
    final leaf = directChildUnderLibSrcForRepoRelPosixPath(repoRelPosixPath);
    final entry = layer ?? leaf;
    if (entry == null) {
      continue;
    }
    violations.add(
      LibSrcLayoutViolation(
        path: repoRelPosixPath,
        entry: entry,
        message: violationMessage,
      ),
    );
  }

  return violations;
}
