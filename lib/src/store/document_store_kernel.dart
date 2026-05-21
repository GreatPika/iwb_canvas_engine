import '../api/canvas_document.dart';
import '../api/canvas_ids.dart';
import 'committed_document.dart';
import 'document_projection_cache.dart';

final class DocumentStoreKernel {
  DocumentStoreKernel(CanvasDocument initialDocument)
    : _document = CommittedDocument(initialDocument);

  final CommittedDocument _document;
  final DocumentProjectionCache _projectionCache = DocumentProjectionCache();
  final _IdAdmission _elementIds = _IdAdmission(prefix: 'e');
  final _IdAdmission _layerIds = _IdAdmission(prefix: 'l');
  final _IdAdmission _resourceIds = _IdAdmission(prefix: 'r');

  CanvasDocument readDocument() => _projectionCache.projectionFor(_document);

  CanvasDocumentSummary get documentSummary => _document.summary;
  int get documentRevision => _document.revisions.documentRevision;
  int get projectionBuildCount => _projectionCache.buildCount;

  CanvasElementId generateElementId() {
    return CanvasElementId(_elementIds.nextValue(_document.admittedElementIds));
  }

  CanvasLayerId generateLayerId() {
    return CanvasLayerId(_layerIds.nextValue(_document.admittedLayerIds));
  }

  CanvasResourceId generateResourceId() {
    return CanvasResourceId(
      _resourceIds.nextValue(_document.admittedResourceIds),
    );
  }
}

final class _IdAdmission {
  _IdAdmission({required this.prefix});

  final String prefix;
  final Set<String> _generated = {};
  int _next = 0;

  String nextValue(Set<String> committedIds) {
    while (true) {
      final candidate = '$prefix$_next';
      _next += 1;
      if (committedIds.contains(candidate) || _generated.contains(candidate)) {
        continue;
      }
      _generated.add(candidate);

      return candidate;
    }
  }
}
