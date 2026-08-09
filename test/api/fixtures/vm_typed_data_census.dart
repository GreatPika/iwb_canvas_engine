import 'dart:convert';
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';

import 'vm_retention_connection.dart';
import 'vm_retention_models.dart';

const _instanceLimit = 2048;

final class VmTypedDataCensusReader {
  const VmTypedDataCensusReader(this._connection);

  final VmRetentionConnection _connection;

  Future<VmTypedDataCensus> censusUint8ListsWithBytes(
    Uint8List expected,
  ) async {
    final anchor = await _readTypedDataInstance(_connection.objectId(expected));
    final classId = anchor.classId;
    if (classId == null) {
      throw StateError('The VM service did not expose the anchor class.');
    }
    final expectedBytes = base64Encode(expected);
    if (anchor.bytes != expectedBytes) {
      throw StateError('The VM service did not expose the exact anchor bytes.');
    }
    final instances = await _boundedInstancesFor(classId);
    final matchingInstances = await _matchingInstances(
      instances,
      expectedBytes,
    );
    return VmTypedDataCensus(
      anchor: anchor,
      matchingInstances: matchingInstances,
    );
  }

  Future<List<ObjRef>> _boundedInstancesFor(String classId) async {
    final classes = await _connection.service.getClassList(
      _connection.isolateId,
    );
    final uint8ListClass = classes.classes
        ?.where((candidate) => candidate.id == classId)
        .singleOrNull;
    if (uint8ListClass == null) {
      throw StateError('The VM service did not list the anchor class.');
    }
    final instances = await _connection.service.getInstances(
      _connection.isolateId,
      classId,
      _instanceLimit,
    );
    final totalCount = instances.totalCount ?? 0;
    if (totalCount > _instanceLimit) {
      throw StateError(
        'Uint8List census exceeded the bounded limit: $totalCount.',
      );
    }
    return instances.instances ?? const <ObjRef>[];
  }

  Future<List<VmTypedDataInstance>> _matchingInstances(
    Iterable<ObjRef> instances,
    String expectedBytes,
  ) async {
    final matches = <VmTypedDataInstance>[];
    for (final instance in instances) {
      final objectId = instance.id;
      if (objectId == null) {
        continue;
      }
      final typedData = await _readTypedDataInstance(objectId);
      if (typedData.bytes == expectedBytes) {
        matches.add(typedData);
      }
    }
    return matches;
  }

  Future<VmTypedDataInstance> _readTypedDataInstance(String objectId) async {
    final object = await _connection.service.getObject(
      _connection.isolateId,
      objectId,
    );
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
