import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../edit/commit_compiler.dart';
import 'committed_document.dart';
import 'revision_state.dart';
import 'store_revision_delta.dart';

final class StoreSparseCommit {
  StoreSparseCommit({
    required Iterable<StoreSparseMutation> mutations,
    required this.revisionDelta,
  }) : mutations = List.unmodifiable(mutations);

  final List<StoreSparseMutation> mutations;
  final StoreRevisionDelta revisionDelta;
}

final class PreparedSparseStoreCommit {
  const PreparedSparseStoreCommit({
    required this.baseRevisions,
    required this.document,
    required this.revisionDelta,
    this.admittedElementIds = const [],
    this.admittedLayerIds = const [],
    this.admittedResourceIds = const [],
  });

  final RevisionState baseRevisions;
  final CommittedDocument document;
  final StoreRevisionDelta revisionDelta;
  final List<String> admittedElementIds;
  final List<String> admittedLayerIds;
  final List<String> admittedResourceIds;

  bool get hasChanges => revisionDelta.hasChanges;
}

sealed class StoreSparseMutation {
  const StoreSparseMutation();
}

final class StoreSparseEnsureLayer extends StoreSparseMutation {
  const StoreSparseEnsureLayer(this.id, {this.index});

  final CanvasLayerId id;
  final int? index;
}

final class StoreSparseAddElement extends StoreSparseMutation {
  const StoreSparseAddElement({
    required this.element,
    this.layerId,
    this.index,
    this.background = false,
  });

  final CanvasElement element;
  final CanvasLayerId? layerId;
  final int? index;
  final bool background;
}

final class StoreSparseUpdateElement extends StoreSparseMutation {
  factory StoreSparseUpdateElement({
    required CanvasElement before,
    required CanvasElement element,
  }) {
    return StoreSparseUpdateElement._(
      before: before,
      element: element,
      compiledUpdate: const CommitCompiler().compileElementUpdate(
        before: before,
        after: element,
      ),
    );
  }

  const StoreSparseUpdateElement._({
    required this.before,
    required this.element,
    required this.compiledUpdate,
  });

  final CanvasElement before;
  final CanvasElement element;
  final ElementUpdateCompileResult compiledUpdate;
}

final class StoreSparseRemoveElement extends StoreSparseMutation {
  const StoreSparseRemoveElement(this.id);

  final CanvasElementId id;
}

final class StoreSparseUpsertResource extends StoreSparseMutation {
  const StoreSparseUpsertResource(this.resource);

  final CanvasResource resource;
}

final class StoreSparseRemoveUnusedResource extends StoreSparseMutation {
  const StoreSparseRemoveUnusedResource(this.id);

  final CanvasResourceId id;
}

final class StoreSparseClearContent extends StoreSparseMutation {
  const StoreSparseClearContent({this.removeUnusedResources = false});

  final bool removeUnusedResources;
}

final class StoreSparseSetBackground extends StoreSparseMutation {
  const StoreSparseSetBackground(this.background);

  final CanvasBackground background;
}

final class StoreSparseSetCamera extends StoreSparseMutation {
  const StoreSparseSetCamera(this.camera);

  final CanvasCamera camera;
}

final class StoreSparseSetPalette extends StoreSparseMutation {
  const StoreSparseSetPalette(this.palette);

  final CanvasPalette palette;
}
