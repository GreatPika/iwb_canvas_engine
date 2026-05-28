import '../public/canvas_ids.dart';

abstract interface class ResourceSessionInvalidationSink {
  void invalidateResourceImage(CanvasResourceId id);
  void invalidateAllResourceImages();
}
