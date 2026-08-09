import 'dart:collection';

import 'package:vm_service/vm_service.dart';

import 'vm_retention_connection.dart';
import 'vm_retention_models.dart';
import 'vm_retention_source_reader.dart';

const _maxInboundReferences = 64;
const _maxOwnershipDepth = 12;
const _maxOwnershipNodes = 256;
const _maxSampledOwnershipSources = 12;

final class VmInboundOwnershipTraversalCollector {
  const VmInboundOwnershipTraversalCollector(this._connection);

  final VmRetentionConnection _connection;

  Future<VmInboundOwnershipTraversal> collect(
    String targetId, {
    required VmOwnershipTerminalPredicate isTerminalOwnershipRoot,
  }) => _VmInboundOwnershipTraversalState(
    connection: _connection,
    referenceResolver: _InboundReferenceResolver(
      VmRetentionSourceReader(_connection),
    ),
    targetId: targetId,
    isTerminalOwnershipRoot: isTerminalOwnershipRoot,
  ).collect();
}

final class _VmInboundOwnershipTraversalState {
  _VmInboundOwnershipTraversalState({
    required VmRetentionConnection connection,
    required _InboundReferenceResolver referenceResolver,
    required String targetId,
    required this.isTerminalOwnershipRoot,
  }) : _connection = connection,
       _referenceResolver = referenceResolver,
       _queue = Queue<_InboundOwnershipBranch>()
         ..add(_InboundOwnershipBranch(targetId, const [])),
       _visitedObjectIds = {targetId};

  final VmRetentionConnection _connection;
  final _InboundReferenceResolver _referenceResolver;
  final VmOwnershipTerminalPredicate isTerminalOwnershipRoot;
  final Queue<_InboundOwnershipBranch> _queue;
  final Set<String> _visitedObjectIds;
  final List<VmOwnershipPath> _paths = [];
  final Set<String> _limitReasons = {};
  final Set<String> _sampledSources = {};
  var _visitedNodes = 0;

  Future<VmInboundOwnershipTraversal> collect() async {
    while (_queue.isNotEmpty) {
      if (_visitedNodes == _maxOwnershipNodes) {
        _limitReasons.add('max nodes $_maxOwnershipNodes');
        break;
      }
      await _visitBranch(_queue.removeFirst());
    }
    return _result();
  }

  Future<void> _visitBranch(_InboundOwnershipBranch branch) async {
    _visitedNodes++;
    final inbound = await _inboundReferencesFor(branch.objectId);
    if (inbound == null) {
      return;
    }
    final references = inbound.references ?? const <InboundReference>[];
    if (references.length >= _maxInboundReferences) {
      _limitReasons.add('max inbound references $_maxInboundReferences');
    }
    if (references.isEmpty) {
      _paths.add(VmOwnershipPath(branch.sources));
      return;
    }
    for (final reference in references.take(_maxInboundReferences)) {
      await _visitReference(branch, reference);
    }
  }

  Future<InboundReferences?> _inboundReferencesFor(String objectId) async {
    try {
      return await _connection.service.getInboundReferences(
        _connection.isolateId,
        objectId,
        _maxInboundReferences,
      );
    } on SentinelException catch (error) {
      _limitReasons.add('inbound references unavailable for $objectId: $error');
    } on RPCError catch (error) {
      _limitReasons.add('inbound references unavailable for $objectId: $error');
    }
    return null;
  }

  Future<void> _visitReference(
    _InboundOwnershipBranch branch,
    InboundReference reference,
  ) async {
    final source = await _referenceResolver.resolve(
      reference,
      incompleteReasons: _limitReasons,
    );
    if (source == null) {
      return;
    }
    _recordSample(source);
    final sources = [...branch.sources, source];
    if (isTerminalOwnershipRoot(source)) {
      _paths.add(VmOwnershipPath(sources));
      return;
    }
    _continueOrRecordBoundedPath(source, sources);
  }

  void _recordSample(VmRetentionSource source) {
    if (_sampledSources.length < _maxSampledOwnershipSources) {
      _sampledSources.add('${source.className}@${source.libraryUri}');
    }
  }

  void _continueOrRecordBoundedPath(
    VmRetentionSource source,
    List<VmRetentionSource> sources,
  ) {
    if (sources.length == _maxOwnershipDepth) {
      _limitReasons.add(
        'max depth $_maxOwnershipDepth through '
        '${sources.map(_sourceLabel).join(' -> ')}',
      );
      _paths.add(VmOwnershipPath(sources));
    } else if (!_visitedObjectIds.add(source.objectId)) {
      _paths.add(VmOwnershipPath(sources));
    } else {
      _queue.add(_InboundOwnershipBranch(source.objectId, sources));
    }
  }

  VmInboundOwnershipTraversal _result() {
    if (_limitReasons.isNotEmpty) {
      _limitReasons.add('sampled sources: ${_sampledSources.join(', ')}');
    }
    return VmInboundOwnershipTraversal(
      paths: _paths,
      limitReasons: _limitReasons.toList(growable: false),
    );
  }
}

final class _InboundReferenceResolver {
  const _InboundReferenceResolver(this._sourceReader);

  final VmRetentionSourceReader _sourceReader;

  Future<VmRetentionSource?> resolve(
    InboundReference reference, {
    required Set<String> incompleteReasons,
  }) async {
    final source = reference.source;
    if (source == null || source.id == null) {
      incompleteReasons.add('ownership source without an object id');
      return null;
    }
    final resolution = await _sourceReader.read(source);
    final reason = resolution.incompleteReason;
    if (reason != null) {
      incompleteReasons.add(reason);
    }
    return resolution.source;
  }
}

final class _InboundOwnershipBranch {
  const _InboundOwnershipBranch(this.objectId, this.sources);

  final String objectId;
  final List<VmRetentionSource> sources;
}

String _sourceLabel(VmRetentionSource source) =>
    '${source.className}@${source.libraryUri}';
