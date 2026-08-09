import 'package:vm_service/vm_service.dart';

import 'vm_inbound_ownership_traversal.dart';
import 'vm_retention_connection.dart';
import 'vm_retention_models.dart';
import 'vm_retention_source_reader.dart';

const _maxRetainingPathDepth = 12;

final class VmRetentionObservationReader {
  VmRetentionObservationReader(VmRetentionConnection connection)
    : _retainingPathReader = _VmRetainingPathReader(
        connection,
        VmRetentionSourceReader(connection),
      ),
      _inboundCollector = VmInboundOwnershipTraversalCollector(connection);

  final _VmRetainingPathReader _retainingPathReader;
  final VmInboundOwnershipTraversalCollector _inboundCollector;

  Future<VmRetentionObservation> observe(
    String targetId, {
    required VmOwnershipTerminalPredicate isTerminalOwnershipRoot,
  }) async {
    final retainingPath = await _retainingPathReader.read(targetId);
    final inboundTraversal = await _inboundCollector.collect(
      targetId,
      isTerminalOwnershipRoot: isTerminalOwnershipRoot,
    );
    return VmRetentionObservation(
      targetId: targetId,
      retainingPathLength: retainingPath.length,
      retainingPathRoot: retainingPath.root,
      retainingPathSources: retainingPath.sources,
      retainingPathComplete: retainingPath.incompleteReasons.isEmpty,
      retainingPathIncompleteReasons: retainingPath.incompleteReasons,
      inboundOwnershipPaths: inboundTraversal.paths,
      inboundTraversalComplete: inboundTraversal.complete,
      inboundTraversalLimitReasons: inboundTraversal.limitReasons,
    );
  }
}

final class _VmRetainingPathReader {
  const _VmRetainingPathReader(this._connection, this._sourceReader);

  final VmRetentionConnection _connection;
  final VmRetentionSourceReader _sourceReader;

  Future<VmRetainingPathObservation> read(String targetId) async {
    try {
      final retainingPath = await _connection.service.getRetainingPath(
        _connection.isolateId,
        targetId,
        _maxRetainingPathDepth,
      );
      final elements = retainingPath.elements;
      final resolutions = await _sourceReader.readAll(
        elements?.map((element) => element.value).whereType<ObjRef>() ??
            const <ObjRef>[],
      );
      return _resolvedObservation(retainingPath, elements, resolutions);
    } on SentinelException catch (error) {
      return _unavailableObservation(targetId, error);
    } on RPCError catch (error) {
      return _unavailableObservation(targetId, error);
    }
  }

  VmRetainingPathObservation _resolvedObservation(
    RetainingPath retainingPath,
    List<RetainingObject>? elements,
    List<VmRetentionSourceResolution> resolutions,
  ) {
    final resolvedSources = _resolvedSources(resolutions);
    final length = retainingPath.length;
    final root = retainingPath.gcRootType?.trim();
    final incompleteReasons = [
      ..._responseShapeReasons(length: length, root: root, elements: elements),
      ...resolvedSources.incompleteReasons,
    ];
    return VmRetainingPathObservation(
      length: length ?? 0,
      root: root ?? '',
      sources: resolvedSources.sources,
      incompleteReasons: incompleteReasons,
    );
  }

  _ResolvedRetainingPathSources _resolvedSources(
    List<VmRetentionSourceResolution> resolutions,
  ) {
    final sources = <VmRetentionSource>[];
    final incompleteReasons = <String>[];
    for (final resolution in resolutions) {
      final source = resolution.source;
      if (source != null) {
        sources.add(source);
      }
      final reason = resolution.incompleteReason;
      if (reason != null) {
        incompleteReasons.add(reason);
      }
    }
    return _ResolvedRetainingPathSources(
      sources: sources,
      incompleteReasons: incompleteReasons,
    );
  }

  List<String> _responseShapeReasons({
    required int? length,
    required String? root,
    required List<RetainingObject>? elements,
  }) {
    final reasons = <String>[];
    _addPathMetadataReasons(reasons, length, root);
    if (elements == null) {
      reasons.add('retaining path elements missing');
      return reasons;
    }
    _addElementValueReasons(reasons, elements);
    _addTruncationReasons(reasons, length, elements.length);
    return reasons;
  }

  void _addPathMetadataReasons(
    List<String> reasons,
    int? length,
    String? root,
  ) {
    if (length == null) {
      reasons.add('retaining path length missing');
    } else if (length < 0) {
      reasons.add('retaining path length invalid: $length');
    }
    if (root == null || root.isEmpty) {
      reasons.add('retaining path root missing');
    } else if (root.toLowerCase() == 'unknown') {
      reasons.add('retaining path root unknown');
    }
  }

  void _addElementValueReasons(
    List<String> reasons,
    List<RetainingObject> elements,
  ) {
    if (elements.any((element) => element.value == null)) {
      reasons.add('retaining path element missing value');
    }
  }

  void _addTruncationReasons(
    List<String> reasons,
    int? length,
    int returnedElementCount,
  ) {
    if (length == null || length < 0) {
      return;
    }
    if (length > returnedElementCount) {
      reasons.add(
        'retaining path truncated: reported length $length exceeds '
        'returned elements $returnedElementCount',
      );
    }
  }

  VmRetainingPathObservation _unavailableObservation(
    String targetId,
    Object error,
  ) => VmRetainingPathObservation(
    length: 0,
    root: '',
    sources: const [],
    incompleteReasons: ['retaining path unavailable for $targetId: $error'],
  );
}

final class _ResolvedRetainingPathSources {
  const _ResolvedRetainingPathSources({
    required this.sources,
    required this.incompleteReasons,
  });

  final List<VmRetentionSource> sources;
  final List<String> incompleteReasons;
}
