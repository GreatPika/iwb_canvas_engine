import '../layer_guardrails.dart';

enum ImportBoundaryLayer {
  contract,
  core,
  model,
  controller,
  interactive,
  render,
  serialization,
  view,
}

enum ImportBoundarySurfaceKind { public, internal, bridge }

class BridgeSurfaceDescriptor {
  const BridgeSurfaceDescriptor({
    required this.repoRelPosixPath,
    required this.ownerLayer,
    required this.friendLayers,
  });

  final String repoRelPosixPath;
  final ImportBoundaryLayer ownerLayer;
  final List<ImportBoundaryLayer> friendLayers;

  bool allowsImporter(ImportBoundaryLayer layer) =>
      layer == ownerLayer || friendLayers.contains(layer);
}

class ResolvedImportBoundarySurface {
  const ResolvedImportBoundarySurface._({
    required this.kind,
    required this.targetLayer,
    this.bridge,
  });

  const ResolvedImportBoundarySurface.public({
    required ImportBoundaryLayer targetLayer,
  }) : this._(kind: ImportBoundarySurfaceKind.public, targetLayer: targetLayer);

  const ResolvedImportBoundarySurface.internal({
    required ImportBoundaryLayer targetLayer,
  }) : this._(
         kind: ImportBoundarySurfaceKind.internal,
         targetLayer: targetLayer,
       );

  const ResolvedImportBoundarySurface.bridge({
    required ImportBoundaryLayer targetLayer,
    required BridgeSurfaceDescriptor bridge,
  }) : this._(
         kind: ImportBoundarySurfaceKind.bridge,
         targetLayer: targetLayer,
         bridge: bridge,
       );

  final ImportBoundarySurfaceKind kind;
  final ImportBoundaryLayer targetLayer;
  final BridgeSurfaceDescriptor? bridge;
}

const Map<ImportBoundaryLayer, Set<ImportBoundaryLayer>>
_allowedLayerDependencies = <ImportBoundaryLayer, Set<ImportBoundaryLayer>>{
  ImportBoundaryLayer.contract: <ImportBoundaryLayer>{},
  ImportBoundaryLayer.core: <ImportBoundaryLayer>{ImportBoundaryLayer.contract},
  ImportBoundaryLayer.model: <ImportBoundaryLayer>{
    ImportBoundaryLayer.contract,
    ImportBoundaryLayer.core,
  },
  ImportBoundaryLayer.controller: <ImportBoundaryLayer>{
    ImportBoundaryLayer.contract,
    ImportBoundaryLayer.core,
    ImportBoundaryLayer.model,
  },
  ImportBoundaryLayer.interactive: <ImportBoundaryLayer>{
    ImportBoundaryLayer.contract,
    ImportBoundaryLayer.core,
    ImportBoundaryLayer.controller,
  },
  ImportBoundaryLayer.render: <ImportBoundaryLayer>{
    ImportBoundaryLayer.contract,
    ImportBoundaryLayer.core,
  },
  ImportBoundaryLayer.serialization: <ImportBoundaryLayer>{
    ImportBoundaryLayer.contract,
    ImportBoundaryLayer.core,
    ImportBoundaryLayer.model,
  },
  ImportBoundaryLayer.view: <ImportBoundaryLayer>{
    ImportBoundaryLayer.contract,
    ImportBoundaryLayer.core,
    ImportBoundaryLayer.controller,
    ImportBoundaryLayer.interactive,
    ImportBoundaryLayer.render,
  },
};

const Map<ImportBoundaryLayer, Set<String>>
_allowedExternalPackagePrefixesByLayer = <ImportBoundaryLayer, Set<String>>{
  ImportBoundaryLayer.contract: <String>{
    'package:flutter/foundation.dart',
    'package:path_drawing/',
  },
  ImportBoundaryLayer.core: <String>{
    'package:flutter/painting.dart',
    'package:path_drawing/',
  },
  ImportBoundaryLayer.model: <String>{},
  ImportBoundaryLayer.controller: <String>{'package:flutter/foundation.dart'},
  ImportBoundaryLayer.interactive: <String>{'package:flutter/foundation.dart'},
  ImportBoundaryLayer.render: <String>{
    'package:flutter/foundation.dart',
    'package:flutter/rendering.dart',
  },
  ImportBoundaryLayer.serialization: <String>{},
  ImportBoundaryLayer.view: <String>{'package:flutter/widgets.dart'},
};

const Set<String> _globallyAllowedExternalPackagePrefixes = <String>{
  'package:meta/',
};

const Map<String, BridgeSurfaceDescriptor>
_bridgeSurfaceDescriptors = <String, BridgeSurfaceDescriptor>{
  '/lib/src/contract/internal/node_boundary_schema.dart':
      BridgeSurfaceDescriptor(
        repoRelPosixPath:
            '/lib/src/contract/internal/node_boundary_schema.dart',
        ownerLayer: ImportBoundaryLayer.contract,
        friendLayers: <ImportBoundaryLayer>[
          ImportBoundaryLayer.model,
          ImportBoundaryLayer.serialization,
        ],
      ),
  '/lib/src/contract/internal/snapshot_fast_path.dart': BridgeSurfaceDescriptor(
    repoRelPosixPath: '/lib/src/contract/internal/snapshot_fast_path.dart',
    ownerLayer: ImportBoundaryLayer.contract,
    friendLayers: <ImportBoundaryLayer>[
      ImportBoundaryLayer.model,
      ImportBoundaryLayer.serialization,
    ],
  ),
  '/lib/src/core/pointer_input.dart': BridgeSurfaceDescriptor(
    repoRelPosixPath: '/lib/src/core/pointer_input.dart',
    ownerLayer: ImportBoundaryLayer.core,
    friendLayers: <ImportBoundaryLayer>[
      ImportBoundaryLayer.contract,
      ImportBoundaryLayer.interactive,
      ImportBoundaryLayer.view,
    ],
  ),
};

ImportBoundaryLayer? layerForRepoRelPosixPath(String repoRelPosixPath) {
  switch (topLevelLibSrcLayerForRepoRelPosixPath(repoRelPosixPath)) {
    case 'contract':
      return ImportBoundaryLayer.contract;
    case 'core':
      return ImportBoundaryLayer.core;
    case 'model':
      return ImportBoundaryLayer.model;
    case 'controller':
      return ImportBoundaryLayer.controller;
    case 'interactive':
      return ImportBoundaryLayer.interactive;
    case 'render':
      return ImportBoundaryLayer.render;
    case 'serialization':
      return ImportBoundaryLayer.serialization;
    case 'view':
      return ImportBoundaryLayer.view;
    case null:
    case _:
      return null;
  }
}

String layerLabel(ImportBoundaryLayer layer) {
  switch (layer) {
    case ImportBoundaryLayer.contract:
      return 'contract';
    case ImportBoundaryLayer.core:
      return 'core';
    case ImportBoundaryLayer.model:
      return 'model';
    case ImportBoundaryLayer.controller:
      return 'controller';
    case ImportBoundaryLayer.interactive:
      return 'interactive';
    case ImportBoundaryLayer.render:
      return 'render';
    case ImportBoundaryLayer.serialization:
      return 'serialization';
    case ImportBoundaryLayer.view:
      return 'view';
  }
}

ResolvedImportBoundarySurface? classifyResolvedImportBoundarySurface(
  String resolvedRepoRelPosix,
) {
  final targetLayer = layerForRepoRelPosixPath(resolvedRepoRelPosix);
  if (targetLayer == null) {
    return null;
  }

  final bridge = _bridgeSurfaceDescriptors[resolvedRepoRelPosix];
  if (bridge != null) {
    return ResolvedImportBoundarySurface.bridge(
      targetLayer: targetLayer,
      bridge: bridge,
    );
  }

  final internalPrefix = '/lib/src/${layerLabel(targetLayer)}/internal/';
  if (resolvedRepoRelPosix.startsWith(internalPrefix)) {
    return ResolvedImportBoundarySurface.internal(targetLayer: targetLayer);
  }

  return ResolvedImportBoundarySurface.public(targetLayer: targetLayer);
}

bool isAllowedLayerDependency({
  required ImportBoundaryLayer from,
  required ImportBoundaryLayer to,
}) {
  if (from == to) {
    return true;
  }
  return _allowedLayerDependencies[from]?.contains(to) ?? false;
}

bool isAllowedExternalPackageImport({
  required ImportBoundaryLayer layer,
  required String targetPosix,
}) {
  if (_matchesAnyPrefix(targetPosix, _globallyAllowedExternalPackagePrefixes)) {
    return true;
  }
  final allowedPrefixes = _allowedExternalPackagePrefixesByLayer[layer];
  return allowedPrefixes != null &&
      _matchesAnyPrefix(targetPosix, allowedPrefixes);
}

bool isViewLayerFile(String repoRelPosixPath) {
  return repoRelPosixPath.startsWith('/lib/src/view/');
}

String? commandGroupForFilePosix(String filePosixPath) {
  const marker = '/lib/src/controller/commands/';
  final idx = filePosixPath.indexOf(marker);
  if (idx == -1) {
    return null;
  }
  final after = filePosixPath.substring(idx + marker.length);
  final slash = after.indexOf('/');
  if (slash == -1) {
    final dot = after.indexOf('.');
    if (dot <= 0) {
      return after.isEmpty ? null : after;
    }
    return after.substring(0, dot);
  }
  return after.substring(0, slash);
}

bool isAllowedForCommands({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
  required String currentCommand,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }
  if (resolvedRepoRelPosix == null) {
    return false;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/commands/')) {
    final importedCommand = commandGroupForFilePosix(resolvedRepoRelPosix);
    return importedCommand == null || importedCommand == currentCommand;
  }
  return isAllowedCommandRepoTarget(resolvedRepoRelPosix);
}

bool isAllowedForInternal({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }
  if (resolvedRepoRelPosix == null) {
    return false;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/core/')) {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/contract/')) {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/model/')) {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/controller/change_set.dart') {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/internal/')) {
    return true;
  }
  return false;
}

bool isLibSrcTarget(String? resolvedRepoRelPosix) =>
    resolvedRepoRelPosix != null &&
    resolvedRepoRelPosix.startsWith('/lib/src/');

bool isTopLevelLibFile(String repoRelPosixPath) {
  if (!repoRelPosixPath.startsWith('/lib/') ||
      repoRelPosixPath.startsWith('/lib/src/')) {
    return false;
  }
  final remainder = repoRelPosixPath.substring('/lib/'.length);
  return remainder.isNotEmpty && !remainder.contains('/');
}

bool isAllowedCommandRepoTarget(String resolvedRepoRelPosix) =>
    resolvedRepoRelPosix.startsWith('/lib/src/core/') ||
    resolvedRepoRelPosix.startsWith('/lib/src/contract/') ||
    resolvedRepoRelPosix.startsWith('/lib/src/controller/') ||
    resolvedRepoRelPosix.startsWith('/lib/src/model/') ||
    resolvedRepoRelPosix == '/lib/src/controller/change_set.dart' ||
    resolvedRepoRelPosix.startsWith('/lib/src/controller/internal/');

bool _matchesAnyPrefix(String value, Set<String> prefixes) {
  for (final prefix in prefixes) {
    if (value == prefix || value.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}
