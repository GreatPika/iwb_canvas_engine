import 'resource_session_invalidation_sink.dart';

abstract interface class SurfaceResourceSessionLifecycle
    implements ResourceSessionInvalidationSink {
  void resetForDocumentReplacement();
  void drop();
}
