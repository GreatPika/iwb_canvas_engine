import 'package:vm_service/vm_service.dart';

import 'vm_retention_connection.dart';
import 'vm_retention_models.dart';

final class VmRetentionSourceReader {
  const VmRetentionSourceReader(this._connection);

  final VmRetentionConnection _connection;

  Future<List<VmRetentionSourceResolution>> readAll(
    Iterable<ObjRef> references,
  ) => Future.wait(references.map(read));

  Future<VmRetentionSourceResolution> read(ObjRef reference) async {
    final objectId = reference.id;
    if (objectId == null) {
      return const VmRetentionSourceResolution.unresolved(
        'ownership source without an object id',
      );
    }
    return _readSource(objectId);
  }

  Future<VmRetentionSourceResolution> _readSource(String objectId) async {
    try {
      final object = await _connection.service.getObject(
        _connection.isolateId,
        objectId,
      );
      return await _describeObject(objectId, object);
    } on SentinelException catch (error) {
      return _unavailableSource(objectId, error);
    } on RPCError catch (error) {
      return _unavailableSource(objectId, error);
    }
  }

  Future<VmRetentionSourceResolution> _describeObject(
    String objectId,
    Obj object,
  ) async {
    final classReference = object.classRef;
    final classId = classReference?.id;
    if (classId == null) {
      return VmRetentionSourceResolution.unresolved(
        'ownership source $objectId without a class id',
      );
    }
    final classObject = await _connection.service.getObject(
      _connection.isolateId,
      classId,
    );
    return _describeClass(objectId, classReference, classId, classObject);
  }

  VmRetentionSourceResolution _describeClass(
    String objectId,
    ClassRef? classReference,
    String classId,
    Obj classObject,
  ) {
    if (classObject is! Class) {
      return VmRetentionSourceResolution.unresolved(
        'ownership source $objectId resolved to a non-class $classId',
      );
    }
    final libraryUri = classObject.library?.uri?.trim();
    if (libraryUri == null || libraryUri.isEmpty) {
      return VmRetentionSourceResolution.unresolved(
        'ownership source $objectId without a library uri',
      );
    }
    return VmRetentionSourceResolution.resolved(
      VmRetentionSource(
        objectId: objectId,
        className: classReference?.name ?? '',
        libraryUri: libraryUri,
      ),
    );
  }

  VmRetentionSourceResolution _unavailableSource(
    String objectId,
    Object error,
  ) => VmRetentionSourceResolution.unresolved(
    'ownership source $objectId was unavailable: $error',
  );
}
