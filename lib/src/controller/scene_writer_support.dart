import '../core/nodes.dart';

List<NodeId> sortWriterNodeIds(Iterable<NodeId> nodeIds) {
  final sortedIds = nodeIds.toList(growable: false);
  if (sortedIds.length < 2) {
    return sortedIds;
  }
  sortedIds.sort((a, b) => a.compareTo(b));
  return sortedIds;
}
