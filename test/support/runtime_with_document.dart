import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasRuntime runtimeWithDocument(
  CanvasDocument document, {
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
}) {
  final runtime = CanvasRuntime(config: config);
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}
