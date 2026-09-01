import '../contracts/internal/command_facts_port.dart';
import '../contracts/internal/deletion_entry_projection_port.dart';
import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/resource_catalog_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/geometry_policy.dart';
import 'selection_transform_facts_reader.dart';

typedef CommandDocumentSummaryReader = CanvasDocumentSummary Function();

// This adapter is the runtime-owned command read boundary: it intentionally
// gathers frame, selection, resource, document-summary, and geometry facts in
// one auditable place instead of scattering command eligibility reads.
// ignore: coupling-between-object-classes
final class RuntimeCommandFactsAdapter implements CommandFactsPort {
  const RuntimeCommandFactsAdapter({
    required FrameFactsPort frame,
    required SelectionFactsPort selection,
    required ResourceCatalogPort resources,
    required DeletionEntryProjectionPort deletionEntryProjection,
    required CommandDocumentSummaryReader documentSummary,
    GeometryPolicy geometryPolicy = const GeometryPolicy(),
  }) : _frame = frame,
       _selection = selection,
       _resources = resources,
       _deletionEntryProjection = deletionEntryProjection,
       _documentSummary = documentSummary,
       _geometryPolicy = geometryPolicy;

  final FrameFactsPort _frame;
  final SelectionFactsPort _selection;
  final ResourceCatalogPort _resources;
  final DeletionEntryProjectionPort _deletionEntryProjection;
  final CommandDocumentSummaryReader _documentSummary;
  final GeometryPolicy _geometryPolicy;

  @override
  SelectionTransformFacts selectionTransformFacts() =>
      readSelectionTransformFacts(
        frame: _frame,
        selection: _selection,
        geometryPolicy: _geometryPolicy,
      );

  @override
  SelectionDeleteFacts selectionDeleteFacts() {
    final selected = _selection.selectionFacts.selectedElementIds;
    final projected = _deletionEntryProjection.projectDeletionEntries(selected);
    final projectedEntries = projected.entries;
    final deletableEntries = <DeletionEntryFacts>[];
    for (final entry in projectedEntries) {
      if (entry.layerId != null && entry.element.isDeletable) {
        deletableEntries.add(entry);
      }
    }
    final orderedDeletableEntries =
        deletableEntries.length == projectedEntries.length
        ? projectedEntries
        : List<DeletionEntryFacts>.unmodifiable(deletableEntries);
    final distinctSelected = selected.toSet();

    return SelectionDeleteFacts(
      hasSelection: selected.isNotEmpty,
      allSelectedElementsDeletable:
          selected.isNotEmpty &&
          projectedEntries.length == distinctSelected.length &&
          orderedDeletableEntries.length == distinctSelected.length,
      deletableEntries: orderedDeletableEntries,
    );
  }

  @override
  RemoveElementFacts removeElementFacts(CanvasElementId id) {
    final structuralRevision = _frame.frameRevisions.structuralRevision;
    final handle = _frame.elementHandleForId(structuralRevision, id);
    if (handle == null) {
      return const RemoveElementFacts(canRemove: false);
    }
    final facts = _frame.resolveElement(handle);

    return RemoveElementFacts(canRemove: facts != null);
  }

  @override
  ClearContentFacts clearContentFacts({required bool removeUnusedResources}) {
    final structuralRevision = _frame.frameRevisions.structuralRevision;
    final handles = _frame.elementHandles(structuralRevision);
    final contentIds = <CanvasElementId>[];
    final backgroundResourceIds = <CanvasResourceId>{};
    for (final handle in handles) {
      final facts = _frame.resolveElement(handle);
      if (facts == null) {
        continue;
      }
      if (facts.locationKind == FrameElementLocationKind.content) {
        contentIds.add(handle.id);
        continue;
      }
      final resourceId = facts.resourceId;
      if (resourceId != null) {
        backgroundResourceIds.add(resourceId);
      }
    }

    return ClearContentFacts(
      summary: _documentSummary(),
      removableElementIds: contentIds,
      removableResourceIds: removeUnusedResources
          ? [
              for (final resource in _resources.resources)
                if (!backgroundResourceIds.contains(resource.id)) resource.id,
            ]
          : const [],
    );
  }
}
