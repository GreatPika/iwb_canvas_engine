import '../contracts/public/canvas_document.dart';
import 'committed_document.dart';

final class DocumentProjectionCache {
  CanvasDocument? _cachedDocument;
  int? _cachedProjectionRevision;
  int _buildCount = 0;

  int get buildCount => _buildCount;

  CanvasDocument projectionFor(CommittedDocument document) {
    final projectionRevision = document.revisions.projectionRevision;
    final cachedDocument = _cachedDocument;
    if (cachedDocument != null &&
        _cachedProjectionRevision == projectionRevision) {
      return cachedDocument;
    }

    _buildCount += 1;
    final projection = _buildProjection(document);
    _cachedDocument = projection;
    _cachedProjectionRevision = projectionRevision;

    return projection;
  }
}

CanvasDocument _buildProjection(CommittedDocument document) {
  return CanvasDocument(
    camera: document.camera,
    background: document.background,
    palette: _copyPalette(document.palette),
    resources: document.resourceTable.projectResources(),
    backgroundElements: document.elements.backgroundElementIds.map(
      (id) => document.elements.familyTables.elementById(id.value),
    ),
    layers: document.elements.layerTable.rows.map((row) {
      return CanvasLayer(
        id: row.id,
        elements: row.elementIds.map(
          (id) => document.elements.familyTables.elementById(id.value),
        ),
        metadata: row.metadata,
      );
    }),
    metadata: document.metadata,
  );
}

CanvasPalette _copyPalette(CanvasPalette palette) {
  return CanvasPalette(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
  );
}
