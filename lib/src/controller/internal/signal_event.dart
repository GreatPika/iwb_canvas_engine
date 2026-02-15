import '../../core/immutable_collections.dart';
import '../../public/snapshot.dart';

class BufferedSignal {
  factory BufferedSignal({
    required String type,
    required List<NodeId> nodeIds,
    Map<String, Object?>? payload,
  }) {
    return BufferedSignal._(
      type: type,
      nodeIds: freezeList<NodeId>(nodeIds),
      payload: freezePayloadMap(payload),
    );
  }

  const BufferedSignal._({
    required this.type,
    required this.nodeIds,
    required this.payload,
  });

  final String type;
  final List<NodeId> nodeIds;
  final Map<String, Object?>? payload;
}

class CommittedSignal {
  factory CommittedSignal({
    required String signalId,
    required String type,
    required List<NodeId> nodeIds,
    required int commitRevision,
    Map<String, Object?>? payload,
  }) {
    return CommittedSignal._(
      signalId: signalId,
      type: type,
      nodeIds: freezeList<NodeId>(nodeIds),
      commitRevision: commitRevision,
      payload: freezePayloadMap(payload),
    );
  }

  const CommittedSignal._({
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
