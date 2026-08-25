import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'accept_deletion_commit.dart';

CanvasRuntime runtimeWithDocument(
  CanvasDocument document, {
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(
    deletionCommitResolver: acceptDeletionCommit,
  ),
}) {
  final runtime = CanvasRuntime(config: config);
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}
