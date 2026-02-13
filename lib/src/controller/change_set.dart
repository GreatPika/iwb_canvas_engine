import '../core/nodes.dart';

class ChangeSet {
  bool documentReplaced = false;
  bool structuralChanged = false;
  // True when hit candidate bounds changed (or scene structure changed).
  bool boundsChanged = false;
  bool visualChanged = false;
  bool selectionChanged = false;
  bool gridChanged = false;

  final Set<NodeId> addedNodeIds = <NodeId>{};
  final Set<NodeId> removedNodeIds = <NodeId>{};
  final Set<NodeId> updatedNodeIds = <NodeId>{};
  final Set<NodeId> hitGeometryChangedIds = <NodeId>{};

  bool get txnHasAnyChange =>
      documentReplaced ||
      structuralChanged ||
      boundsChanged ||
      visualChanged ||
      selectionChanged ||
      gridChanged ||
      addedNodeIds.isNotEmpty ||
      removedNodeIds.isNotEmpty ||
      updatedNodeIds.isNotEmpty;

  void txnMarkDocumentReplaced() {
    documentReplaced = true;
    structuralChanged = true;
    boundsChanged = true;
    visualChanged = true;
  }

  void txnMarkStructuralChanged() {
    structuralChanged = true;
    boundsChanged = true;
    visualChanged = true;
  }

  void txnMarkBoundsChanged() {
    boundsChanged = true;
    visualChanged = true;
  }

  void txnMarkVisualChanged() {
    visualChanged = true;
  }

  void txnMarkSelectionChanged() {
    selectionChanged = true;
  }

  void txnMarkGridChanged() {
    gridChanged = true;
    visualChanged = true;
  }

  void txnTrackAdded(NodeId nodeId) {
    addedNodeIds.add(nodeId);
    removedNodeIds.remove(nodeId);
    updatedNodeIds.remove(nodeId);
    hitGeometryChangedIds.remove(nodeId);
  }

  void txnTrackRemoved(NodeId nodeId) {
    removedNodeIds.add(nodeId);
    addedNodeIds.remove(nodeId);
    updatedNodeIds.remove(nodeId);
    hitGeometryChangedIds.remove(nodeId);
  }

  void txnTrackUpdated(NodeId nodeId) {
    if (addedNodeIds.contains(nodeId)) return;
    if (removedNodeIds.contains(nodeId)) return;
    updatedNodeIds.add(nodeId);
  }

  void txnTrackHitGeometryChanged(NodeId nodeId) {
    if (addedNodeIds.contains(nodeId)) return;
    if (removedNodeIds.contains(nodeId)) return;
    hitGeometryChangedIds.add(nodeId);
  }

  ChangeSet txnClone() {
    final out = ChangeSet();
    out.documentReplaced = documentReplaced;
    out.structuralChanged = structuralChanged;
    out.boundsChanged = boundsChanged;
    out.visualChanged = visualChanged;
    out.selectionChanged = selectionChanged;
    out.gridChanged = gridChanged;
    out.addedNodeIds.addAll(addedNodeIds);
    out.removedNodeIds.addAll(removedNodeIds);
    out.updatedNodeIds.addAll(updatedNodeIds);
    out.hitGeometryChangedIds.addAll(hitGeometryChangedIds);
    return out;
  }
}
