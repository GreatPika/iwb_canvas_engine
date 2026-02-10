import 'package:flutter/foundation.dart';

import 'snapshot.dart';

/// Read-only state contract consumed by scene painters.
abstract interface class SceneRenderState implements Listenable {
  SceneSnapshot get snapshot;
  Set<NodeId> get selectedNodeIds;
}
