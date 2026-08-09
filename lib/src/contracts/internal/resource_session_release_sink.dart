import '../public/canvas_ids.dart';

abstract interface class ResourceSessionReleaseSink {
  void releaseResource(CanvasResourceId id);
  void releaseAllResources();
}
