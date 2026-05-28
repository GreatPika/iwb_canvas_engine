import '../public/canvas_ids.dart';
import '../public/canvas_resource.dart';

abstract interface class ResourceCatalogPort {
  int get resourceCount;
  List<CanvasResource> get resources;
  CanvasResource? resourceById(CanvasResourceId id);
}
