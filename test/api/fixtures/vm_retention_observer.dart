import 'dart:typed_data';

import 'vm_retention_connection.dart';
import 'vm_retention_models.dart';
import 'vm_retention_observation_reader.dart';
import 'vm_typed_data_census.dart';

export 'vm_retention_models.dart';

final class VmRetentionObserver {
  VmRetentionObserver._(
    this._connection,
    this._observationReader,
    this._typedDataCensusReader,
  );

  final VmRetentionConnection _connection;
  final VmRetentionObservationReader _observationReader;
  final VmTypedDataCensusReader _typedDataCensusReader;

  static Future<VmRetentionObserver> connect() async {
    final connection = await VmRetentionConnection.connect();
    return VmRetentionObserver._(
      connection,
      VmRetentionObservationReader(connection),
      VmTypedDataCensusReader(connection),
    );
  }

  String objectId(Object object) => _connection.objectId(object);

  Future<VmRetentionObservation> observe(Object object) =>
      observeObjectId(objectId(object));

  Future<VmRetentionObservation> observeObjectId(String targetId) =>
      _observationReader.observe(
        targetId,
        isTerminalOwnershipRoot: (_) => false,
      );

  /// Observes a service-identified target after callers release Dart references.
  Future<VmRetentionObservation> observeReleasedObjectId(
    String targetId, {
    required VmOwnershipTerminalPredicate isTerminalOwnershipRoot,
  }) => _observationReader.observe(
    targetId,
    isTerminalOwnershipRoot: isTerminalOwnershipRoot,
  );

  Future<void> collectGarbage() => _connection.collectGarbage();

  Future<void> dispose() => _connection.dispose();

  Future<VmTypedDataCensus> censusUint8ListsWithBytes(Uint8List expected) =>
      _typedDataCensusReader.censusUint8ListsWithBytes(expected);
}
