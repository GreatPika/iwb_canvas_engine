import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/staged_document_load.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

DocumentStoreKernel documentStoreWithDocument(CanvasDocument document) {
  final store = DocumentStoreKernel();
  final pipeline = LoadDocumentPipeline(store: store);
  final prepared = pipeline.prepareFromJson(
    encodeCanvasDocumentToJson(document),
  );
  pipeline.consume(prepared);

  return store;
}
