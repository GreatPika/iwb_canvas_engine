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

class LibSrcLayoutViolation {
  const LibSrcLayoutViolation({
    required this.path,
    required this.layer,
    required this.message,
  });

  final String path;
  final String layer;
  final String message;
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

String? topLevelLibSrcLayerForRepoRelPosixPath(String repoRelPosixPath) {
  if (!repoRelPosixPath.startsWith('/lib/src/')) {
    return null;
  }

  final remainder = repoRelPosixPath.substring('/lib/src/'.length);
  if (remainder.isEmpty) {
    return null;
  }

  final slashIndex = remainder.indexOf('/');
  final topLevelLayer = slashIndex == -1
      ? remainder
      : remainder.substring(0, slashIndex);
  if (topLevelLayer.isEmpty) {
    return null;
  }

  return topLevelLayer;
}

bool isApprovedTopLevelLibSrcLayer(String layer) =>
    approvedTopLevelLibSrcLayers.contains(layer);

bool isDeletedTopLevelLibSrcLayer(String layer) =>
    deletedTopLevelLibSrcLayers.contains(layer);

String? describeLibSrcLayoutViolation(String repoRelPosixPath) {
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
    if (entity is! Directory) {
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
    if (layer == null) {
      continue;
    }

    violations.add(
      LibSrcLayoutViolation(
        path: repoRelPosixPath,
        layer: layer,
        message: violationMessage,
      ),
    );
  }

  return violations;
}
