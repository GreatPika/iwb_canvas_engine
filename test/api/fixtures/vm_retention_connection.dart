import 'dart:developer' as developer;
import 'dart:isolate' as dart_isolate;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

final class VmRetentionConnection {
  VmRetentionConnection._(this.service, this.isolateId);

  final VmService service;
  final String isolateId;

  static Future<VmRetentionConnection> connect() async {
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
    return VmRetentionConnection._(service, isolateId);
  }

  String objectId(Object object) {
    final objectId = developer.Service.getObjectId(object);
    if (objectId == null) {
      throw StateError('The VM service did not assign an object identity.');
    }
    return objectId;
  }

  Future<void> collectGarbage() =>
      service.getAllocationProfile(isolateId, gc: true);

  Future<void> dispose() => service.dispose();
}
