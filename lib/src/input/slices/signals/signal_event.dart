import '../../../public/snapshot.dart';
import '../../../core/immutable_collections.dart';

class V2BufferedSignal {
  factory V2BufferedSignal({
    required String type,
    required List<NodeId> nodeIds,
    Map<String, Object?>? payload,
  }) {
    return V2BufferedSignal._(
      type: type,
      nodeIds: freezeList<NodeId>(nodeIds),
      payload: freezePayloadMap(payload),
    );
  }

  const V2BufferedSignal._({
    required this.type,
    required this.nodeIds,
    required this.payload,
  });

  final String type;
  final List<NodeId> nodeIds;
  final Map<String, Object?>? payload;
}

class V2CommittedSignal {
  factory V2CommittedSignal({
    required String signalId,
    required String type,
    required List<NodeId> nodeIds,
    required int commitRevision,
    Map<String, Object?>? payload,
  }) {
    return V2CommittedSignal._(
      signalId: signalId,
      type: type,
      nodeIds: freezeList<NodeId>(nodeIds),
      commitRevision: commitRevision,
      payload: freezePayloadMap(payload),
    );
  }

  const V2CommittedSignal._({
    required this.signalId,
    required this.type,
    required this.nodeIds,
    required this.commitRevision,
    required this.payload,
  });

  final String signalId;
  final String type;
  final List<NodeId> nodeIds;
  final int commitRevision;
  final Map<String, Object?>? payload;
}
