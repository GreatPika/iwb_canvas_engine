import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

// The helper mirrors RuntimeRoot.test setup seams so call sites can name only
// the collaborator they exercise instead of introducing fixture-specific
// wrappers for each load-boundary/observer combination.
// ignore: number-of-parameters
RuntimeRoot runtimeRootWithDocument(
  CanvasDocument document, {
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
  LoadInteractionBoundary? loadInteractionBoundary,
  TextEditPrepareOverride? textEditPrepareOverride,
  CommitEffectObserver? commitEffectObserver,
}) {
  var isLoadingInitialDocument = true;
  final root = RuntimeRoot.test(
    config: config,
    loadInteractionBoundary: loadInteractionBoundary,
    textEditPrepareOverride: textEditPrepareOverride,
    commitEffectObserver: commitEffectObserver == null
        ? null
        : (effects) {
            if (!isLoadingInitialDocument) {
              commitEffectObserver(effects);
            }
          },
  );
  root.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));
  isLoadingInitialDocument = false;

  return root;
}
