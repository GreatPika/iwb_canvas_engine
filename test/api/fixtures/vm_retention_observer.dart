// The VM service protocol needs these direct imports for connection, object
// identity, retaining paths, inbound references, and typed-data inspection.
// ignore_for_file: number-of-external-imports

import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate' as dart_isolate;
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

typedef VmOwnershipTerminalPredicate = bool Function(VmRetentionSource source);

// This class owns one bounded VM protocol traversal; splitting it would hide
// the connection, object identity, and retaining/inbound ownership ordering.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class VmRetentionObserver {
  VmRetentionObserver._(this._service, this._isolateId);

  final VmService _service;
  final String _isolateId;

  static Future<VmRetentionObserver> connect() async {
    final serviceInfo = await developer.Service.getInfo();
    final serverUri = serviceInfo.serverUri;
    final isolateId = developer.Service.getIsolateId(
      dart_isolate.Isolate.current,
    );
    if (serverUri == null || isolateId == null) {
      throw StateError(
        'The VM service must be enabled for retention evidence.',
      );
    }

    final service = await vmServiceConnectUri(
      serverUri.replace(scheme: 'ws').toString(),
    );
    return VmRetentionObserver._(service, isolateId);
  }

  String objectId(Object object) {
    final objectId = developer.Service.getObjectId(object);
    if (objectId == null) {
      throw StateError('The VM service did not assign an object identity.');
    }
    return objectId;
  }

  Future<VmRetentionObservation> observe(Object object) =>
      observeObjectId(objectId(object));

  Future<VmRetentionObservation> observeObjectId(String targetId) =>
      _observeObjectId(targetId, isTerminalOwnershipRoot: (_) => false);

  /// Observes a service-identified target after callers release Dart references.
  Future<VmRetentionObservation> observeReleasedObjectId(
    String targetId, {
    required VmOwnershipTerminalPredicate isTerminalOwnershipRoot,
  }) => _observeObjectId(
    targetId,
    isTerminalOwnershipRoot: isTerminalOwnershipRoot,
  );

  Future<VmRetentionObservation> _observeObjectId(
    String targetId, {
    required VmOwnershipTerminalPredicate isTerminalOwnershipRoot,
  }) async {
    final retainingPath = await _service.getRetainingPath(
      _isolateId,
      targetId,
      _maxOwnershipDepth,
    );
    final inboundTraversal = await _collectInboundOwnership(
      targetId,
      isTerminalOwnershipRoot: isTerminalOwnershipRoot,
    );

    return VmRetentionObservation(
      targetId: targetId,
      retainingPathLength: retainingPath.length ?? 0,
      retainingPathRoot: retainingPath.gcRootType ?? '',
      retainingPath: await _describeReferences(
        retainingPath.elements
                ?.map((element) => element.value)
                .whereType<ObjRef>()
                .toList() ??
            const <ObjRef>[],
      ),
      inboundOwnershipPaths: inboundTraversal.paths,
      inboundTraversalComplete: inboundTraversal.complete,
      inboundTraversalLimitReasons: inboundTraversal.limitReasons,
    );
  }

  // The observation records each bounded inbound ownership chain in full.
  // Keeping source context beside queued objects makes release evidence legible.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  Future<_InboundOwnershipTraversal> _collectInboundOwnership(
    String targetId, {
    required VmOwnershipTerminalPredicate isTerminalOwnershipRoot,
  }) async {
    final queue = Queue<_InboundOwnershipBranch>()
      ..add(_InboundOwnershipBranch(targetId, const []));
    final visitedObjectIds = <String>{targetId};
    final paths = <VmOwnershipPath>[];
    final limitReasons = <String>{};
    final sampledSources = <String>{};
    var visitedNodes = 0;

    while (queue.isNotEmpty) {
      if (visitedNodes == _maxOwnershipNodes) {
        limitReasons.add('max nodes $_maxOwnershipNodes');
        break;
      }
      final branch = queue.removeFirst();
      visitedNodes++;
      final inbound = await _service.getInboundReferences(
        _isolateId,
        branch.objectId,
        _maxInboundReferences,
      );
      final references = inbound.references ?? const <InboundReference>[];
      if (references.length >= _maxInboundReferences) {
        limitReasons.add('max inbound references $_maxInboundReferences');
      }
      if (references.isEmpty) {
        paths.add(VmOwnershipPath(branch.sources));
        continue;
      }

      for (final reference in references.take(_maxInboundReferences)) {
        final source = reference.source;
        final sourceId = source?.id;
        if (source == null || sourceId == null) {
          limitReasons.add('source without an object id');
          continue;
        }
        final sourceDescription = await _describeReference(source);
        if (sampledSources.length < _maxSampledOwnershipSources) {
          sampledSources.add(
            '${sourceDescription.className}@${sourceDescription.libraryUri}',
          );
        }
        final sources = [...branch.sources, sourceDescription];
        if (isTerminalOwnershipRoot(sourceDescription)) {
          paths.add(VmOwnershipPath(sources));
          continue;
        }
        if (sources.length == _maxOwnershipDepth) {
          limitReasons.add(
            'max depth $_maxOwnershipDepth through '
            '${sources.map(_sourceLabel).join(' -> ')}',
          );
          paths.add(VmOwnershipPath(sources));
          continue;
        }
        if (!visitedObjectIds.add(sourceId)) {
          paths.add(VmOwnershipPath(sources));
          continue;
        }
        queue.add(_InboundOwnershipBranch(sourceId, sources));
      }
    }

    if (limitReasons.isNotEmpty) {
      limitReasons.add('sampled sources: ${sampledSources.join(', ')}');
    }

    return _InboundOwnershipTraversal(
      paths: paths,
      limitReasons: limitReasons.toList(growable: false),
    );
  }

  Future<void> collectGarbage() async {
    await _service.getAllocationProfile(_isolateId, gc: true);
  }

  Future<void> dispose() => _service.dispose();

  // The census reads anchor identity, exact bytes, and all bounded candidates
  // atomically; splitting it would hide the snapshot-identity comparison.
  // ignore: cyclomatic-complexity, halstead-volume
  Future<VmTypedDataCensus> censusUint8ListsWithBytes(
    Uint8List expected,
  ) async {
    const instanceLimit = 2048;
    final anchor = await _readTypedDataInstance(objectId(expected));
    final anchorClassId = anchor.classId;
    if (anchorClassId == null) {
      throw StateError('The VM service did not expose the anchor class.');
    }

    final classes = await _service.getClassList(_isolateId);
    final uint8ListClass = classes.classes
        ?.where((candidate) => candidate.id == anchorClassId)
        .singleOrNull;
    if (uint8ListClass == null) {
      throw StateError('The VM service did not list the anchor class.');
    }

    final instances = await _service.getInstances(
      _isolateId,
      anchorClassId,
      instanceLimit,
    );
    final totalCount = instances.totalCount ?? 0;
    if (totalCount > instanceLimit) {
      throw StateError(
        'Uint8List census exceeded the bounded limit: $totalCount.',
      );
    }

    final expectedBytes = base64Encode(expected);
    if (anchor.bytes != expectedBytes) {
      throw StateError('The VM service did not expose the exact anchor bytes.');
    }
    final matches = <VmTypedDataInstance>[];
    for (final instance in instances.instances ?? const <ObjRef>[]) {
      final objectId = instance.id;
      if (objectId == null) {
        continue;
      }
      final typedData = await _readTypedDataInstance(objectId);
      if (typedData.bytes == expectedBytes) {
        matches.add(typedData);
      }
    }
    return VmTypedDataCensus(anchor: anchor, matchingInstances: matches);
  }

  Future<List<VmRetentionSource>> _describeReferences(List<ObjRef> references) {
    return Future.wait(references.map(_describeReference));
  }

  Future<VmRetentionSource> _describeReference(ObjRef reference) async {
    final objectId = reference.id;
    if (objectId == null) {
      return const VmRetentionSource(
        objectId: '',
        className: '',
        libraryUri: '',
      );
    }

    try {
      final object = await _service.getObject(_isolateId, objectId);
      final classReference = object.classRef;
      final classId = classReference?.id;
      if (classId == null) {
        return VmRetentionSource(
          objectId: objectId,
          className: '',
          libraryUri: '',
        );
      }
      final classObject = await _service.getObject(_isolateId, classId);
      return VmRetentionSource(
        objectId: objectId,
        className: classReference?.name ?? '',
        libraryUri: (classObject as Class).library?.uri ?? '',
      );
    } on SentinelException {
      return VmRetentionSource(
        objectId: objectId,
        className: '',
        libraryUri: '',
      );
    } on RPCError {
      return VmRetentionSource(
        objectId: objectId,
        className: '',
        libraryUri: '',
      );
    }
  }

  Future<VmTypedDataInstance> _readTypedDataInstance(String objectId) async {
    final object = await _service.getObject(_isolateId, objectId);
    if (object is! Instance) {
      throw StateError('The VM object was not typed data.');
    }
    final identityHashCode = object.identityHashCode;
    if (identityHashCode == null) {
      throw StateError('The VM service did not expose typed-data identity.');
    }
    return VmTypedDataInstance(
      objectId: objectId,
      classId: object.classRef?.id,
      identityHashCode: identityHashCode,
      bytes: object.bytes,
    );
  }
}

String _sourceLabel(VmRetentionSource source) =>
    '${source.className}@${source.libraryUri}';

final class VmRetentionObservation {
  const VmRetentionObservation({
    required this.targetId,
    required this.retainingPathLength,
    required this.retainingPathRoot,
    required this.retainingPath,
    required this.inboundOwnershipPaths,
    required this.inboundTraversalComplete,
    required this.inboundTraversalLimitReasons,
  });

  final String targetId;
  final int retainingPathLength;
  final String retainingPathRoot;
  final List<VmRetentionSource> retainingPath;
  final List<VmOwnershipPath> inboundOwnershipPaths;
  final bool inboundTraversalComplete;
  final List<String> inboundTraversalLimitReasons;

  Iterable<VmRetentionSource> get ownershipSources sync* {
    yield* retainingPath;
    for (final path in inboundOwnershipPaths) {
      yield* path.sources;
    }
  }
}

final class VmOwnershipPath {
  const VmOwnershipPath(this.sources);

  final List<VmRetentionSource> sources;
}

final class VmRetentionSource {
  const VmRetentionSource({
    required this.objectId,
    required this.className,
    required this.libraryUri,
  });

  final String objectId;
  final String className;
  final String libraryUri;
}

final class VmTypedDataInstance {
  const VmTypedDataInstance({
    required this.objectId,
    required this.classId,
    required this.identityHashCode,
    required this.bytes,
  });

  final String objectId;
  final String? classId;
  final int identityHashCode;
  final String? bytes;
}

final class VmTypedDataCensus {
  const VmTypedDataCensus({
    required this.anchor,
    required this.matchingInstances,
  });

  final VmTypedDataInstance anchor;
  final List<VmTypedDataInstance> matchingInstances;
}

final class _InboundOwnershipBranch {
  const _InboundOwnershipBranch(this.objectId, this.sources);

  final String objectId;
  final List<VmRetentionSource> sources;
}

final class _InboundOwnershipTraversal {
  const _InboundOwnershipTraversal({
    required this.paths,
    required this.limitReasons,
  });

  final List<VmOwnershipPath> paths;
  final List<String> limitReasons;

  bool get complete => limitReasons.isEmpty;
}

const _maxInboundReferences = 64;
const _maxOwnershipDepth = 12;
const _maxOwnershipNodes = 256;
const _maxSampledOwnershipSources = 12;
