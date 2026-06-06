import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/element_revision_delta.dart';
import 'package:iwb_canvas_engine/src/edit/element_update_application.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

DocumentStoreKernel documentStoreKernel(CanvasDocument document) {
  return DocumentStoreKernel(
    document,
    elementRevisionDeltaClassifier: elementRevisionDelta,
    sameElement: sameCanvasElement,
  );
}
