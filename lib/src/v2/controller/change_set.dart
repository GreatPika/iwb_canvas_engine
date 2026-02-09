import '../../core/nodes.dart';

class ChangeSet {
  bool documentReplaced = false;
  bool structuralChanged = false;
  bool boundsChanged = false;
  bool visualChanged = false;
  bool selectionChanged = false;
  bool gridChanged = false;

  Set<NodeId> addedNodeIds = <NodeId>{};
  Set<NodeId> removedNodeIds = <NodeId>{};
  Set<NodeId> updatedNodeIds = <NodeId>{};

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
    addedNodeIds = <NodeId>{...addedNodeIds, nodeId};
    removedNodeIds = <NodeId>{
      for (final candidate in removedNodeIds)
        if (candidate != nodeId) candidate,
    };
    updatedNodeIds = <NodeId>{
      for (final candidate in updatedNodeIds)
        if (candidate != nodeId) candidate,
    };
  }

  void txnTrackRemoved(NodeId nodeId) {
    removedNodeIds = <NodeId>{...removedNodeIds, nodeId};
    addedNodeIds = <NodeId>{
      for (final candidate in addedNodeIds)
        if (candidate != nodeId) candidate,
    };
    updatedNodeIds = <NodeId>{
      for (final candidate in updatedNodeIds)
        if (candidate != nodeId) candidate,
    };
  }

  void txnTrackUpdated(NodeId nodeId) {
    if (addedNodeIds.contains(nodeId)) return;
    if (removedNodeIds.contains(nodeId)) return;
    updatedNodeIds = <NodeId>{...updatedNodeIds, nodeId};
  }

  ChangeSet txnClone() {
    final out = ChangeSet();
    out.documentReplaced = documentReplaced;
    out.structuralChanged = structuralChanged;
    out.boundsChanged = boundsChanged;
    out.visualChanged = visualChanged;
    out.selectionChanged = selectionChanged;
    out.gridChanged = gridChanged;
    out.addedNodeIds = Set<NodeId>.from(addedNodeIds);
    out.removedNodeIds = Set<NodeId>.from(removedNodeIds);
    out.updatedNodeIds = Set<NodeId>.from(updatedNodeIds);
    return out;
  }
}
