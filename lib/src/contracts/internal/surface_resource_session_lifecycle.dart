import 'resource_session_release_sink.dart';

abstract interface class SurfaceResourceSessionLifecycle
    implements ResourceSessionReleaseSink {
  void resetForDocumentReplacement();
  void drop();
}
