import '../core/nodes.dart';
import 'scene_writer.dart';
import 'internal/signal_event.dart';

void sceneWriterWriteSignalEnqueue(
  SceneWriter writer, {
  required String type,
  Iterable<NodeId> nodeIds = const <NodeId>[],
  Map<String, Object?>? payload,
}) {
  writer.runtime.ensureTxnActive();
  sceneWriterWriteOwnedSignalEnqueue(
    writer,
    type: type,
    nodeIds: List<NodeId>.of(nodeIds),
    payload: payload,
  );
}

void sceneWriterWriteOwnedSignalEnqueue(
  SceneWriter writer, {
  required String type,
  List<NodeId> nodeIds = const <NodeId>[],
  Map<String, Object?>? payload,
}) {
  writer.runtime.ensureTxnActive();
  writer.runtime.txnSignalSink(
    BufferedSignal(type: type, nodeIds: nodeIds, payload: payload),
  );
}
