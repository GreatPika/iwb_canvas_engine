import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

// The helper seeds RuntimeRoot.test from committed store state so call sites do
// not confuse this setup seam with the public JSON load path.
// ignore: number-of-parameters
RuntimeRoot runtimeRootWithCommittedDocumentSeed(
  CanvasDocument document, {
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
  LoadInteractionBoundary? loadInteractionBoundary,
  TextEditPrepareOverride? textEditPrepareOverride,
  CommitEffectObserver? commitEffectObserver,
}) {
  var isLoadingInitialDocument = true;
  final root = RuntimeRoot.test(
    config: config,
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(document),
    ),
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
  isLoadingInitialDocument = false;

  return root;
}
