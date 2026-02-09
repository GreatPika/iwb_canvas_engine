import '../../../../core/nodes.dart';

class V2BufferedSignal {
  const V2BufferedSignal({
    required this.type,
    required this.nodeIds,
    this.payload,
  });

  final String type;
  final List<NodeId> nodeIds;
  final Map<String, Object?>? payload;
}

class V2CommittedSignal {
  const V2CommittedSignal({
    required this.signalId,
    required this.type,
    required this.nodeIds,
    required this.commitRevision,
    this.payload,
  });

  final String signalId;
  final String type;
  final List<NodeId> nodeIds;
  final int commitRevision;
  final Map<String, Object?>? payload;
}
