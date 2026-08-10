---
date: 2026-08-10
researcher: Codex
commit: 81095e33
branch: main
research_question: "How does the current committed store represent and update element membership and resource-reference facts, and what call paths and verification constraints determine the work performed by sparse relationship filtering and resource-touch classification?"
---

# Research: Element Membership and Resource Reference Lookup Facts

## Summary

The committed store represents elements in seven immutable family maps owned by
`FamilyTables`: image, vector, path, text, stroke, line, and rect
(`lib/src/store/family_tables.dart:59`, `lib/src/store/family_tables.dart:69`).
`ElementRegistry` retains a separate element-id admission set together with
frame order, order tokens, and location facts
(`lib/src/store/element_registry.dart:54`,
`lib/src/store/element_registry.dart:109`). That retained admission set is
initially built from background and layer order; append-at-end updates can
represent it as chained read-only overlays
(`lib/src/store/element_registry.dart:270`,
`lib/src/store/element_registry.dart:519`). `containsElement` delegates to a
different path that reconstructs a set from all seven family-map key sets on
every call (`lib/src/store/element_registry.dart:143`,
`lib/src/store/family_tables.dart:77`,
`lib/src/store/family_tables.dart:143`).

Sparse relationship validation collects resource-backed element ids while it
applies mutations, then filters those ids against the final candidate
(`lib/src/store/document_store_kernel.dart:410`,
`lib/src/store/document_store_kernel.dart:480`). If `K` ids reach that filter
and the candidate contains `N` family rows, the source performs `K` calls that
each construct a set from `N` map keys; the resulting source-level work is
`O(K x N)` with up to `K` temporary full element-id sets
(`lib/src/store/document_store_kernel.dart:480`,
`lib/src/store/family_tables.dart:143`).

Resource-reference membership is computed separately. For each changed
resource descriptor, accepted-fact classification asks whether the base or
candidate registry contains an image/vector row with that resource id
(`lib/src/store/document_store_kernel.dart:1129`,
`lib/src/store/document_store_kernel.dart:1138`). Each registry query scans
image rows and then vector rows (`lib/src/store/family_tables.dart:79`). For `R`
changed resource ids and `N` resource-backed rows per compared snapshot, the
worst-case source-level work is `O(R x N)`, with up to two registry scans per
changed id because the base/candidate expression short-circuits
(`lib/src/store/document_store_kernel.dart:1138`). The resulting accepted facts
contain changed resource ids, not the ids of elements that reference them
(`lib/src/store/store_commit_finalization.dart:30`,
`lib/src/store/store_commit_finalization.dart:60`).

## Detailed Findings

### 1. Committed Element Storage and Retained Derived Facts

- **Location**: `lib/src/store/element_registry.dart:14`
- **Description**: `ElementRegistry` is the committed aggregate for
  `FamilyTables`, `LayerTable`, background ids, content/frame order, frame-order
  tokens, element locations, admitted element ids, and admitted layer ids
  (`lib/src/store/element_registry.dart:109`). Its ordinary private constructor
  builds the order-derived collections together from background ids and layer
  rows (`lib/src/store/element_registry.dart:49`,
  `lib/src/store/element_registry.dart:54`).
- **Dependencies**: `_ElementRegistryOrderAccumulator._admit` writes the order
  token, location, string id, and frame-order entry in one operation; `freeze`
  publishes unmodifiable lists, maps, and the admitted-id set
  (`lib/src/store/element_registry.dart:368`,
  `lib/src/store/element_registry.dart:375`).
- **Data flow**: background ids -> layer element ids -> order accumulator ->
  retained `frameElementOrder`, `frameOrderTokensById`,
  `elementLocationFacts`, and `admittedElementIds`
  (`lib/src/store/element_registry.dart:330`,
  `lib/src/store/element_registry.dart:336`,
  `lib/src/store/element_registry.dart:339`).
- **Evidence consequence**: `CommittedDocument.admittedElementIds` returns the
  retained registry set, and kernel id-admission reset/install paths consume
  that set (`lib/src/store/committed_document.dart:100`,
  `lib/src/store/document_store_kernel.dart:46`,
  `lib/src/store/document_store_kernel.dart:260`). Element membership therefore
  already has a retained string-id representation in the committed registry,
  separate from the family-map-derived getter described below.
- **Append representation**: an append-at-end content add publishes
  `admittedElementIds` as `_AppendedReadOnlySet(previousSet, newId)` rather than
  materializing a flat replacement set
  (`lib/src/store/element_registry.dart:270`,
  `lib/src/store/element_registry.dart:293`,
  `lib/src/store/element_registry.dart:519`). Its `contains` first compares the
  appended value and otherwise delegates to the wrapped base set
  (`lib/src/store/element_registry.dart:525`). Consecutive append snapshots pass
  the prior admitted set into the next wrapper, so the retained representation
  can be a chain until a path rebuilds order facts
  (`lib/src/store/element_registry.dart:277`,
  `lib/src/store/element_registry.dart:293`).

### 2. Family Maps and Element Membership Lookup

- **Location**: `lib/src/store/family_tables.dart:19`
- **Description**: `FamilyTables` stores seven maps keyed by the string value of
  `CanvasElementId` (`lib/src/store/family_tables.dart:69`). Constructors publish
  `Map.unmodifiable` or `UnmodifiableMapView` maps
  (`lib/src/store/family_tables.dart:37`,
  `lib/src/store/family_tables.dart:48`).
- **Dependencies**: `ElementRegistry.containsElement` delegates to
  `FamilyTables.contains`; `FamilyTables.contains` calls
  `admittedElementIds.contains(id.value)`
  (`lib/src/store/element_registry.dart:143`,
  `lib/src/store/family_tables.dart:77`).
- **Data flow**: candidate element id -> `ElementRegistry.containsElement` ->
  `FamilyTables.contains` -> new set literal containing all image/vector/path/
  text/stroke/line/rect keys -> `Set.contains`
  (`lib/src/store/family_tables.dart:143`).
- **Evidence consequence**: the getter body creates a new set on every access;
  it does not return `ElementRegistry.admittedElementIds`
  (`lib/src/store/family_tables.dart:143`,
  `lib/src/store/element_registry.dart:116`). The two production callers found
  are final sparse relationship-id filtering and sparse remove-element
  existence checking (`lib/src/store/document_store_kernel.dart:480`,
  `lib/src/store/document_store_kernel.dart:736`).
- **Additional repeated-membership path**: every
  `StoreSparseRemoveElement` mutation calls this membership method against the
  then-current candidate before removal (`lib/src/store/document_store_kernel.dart:736`).
  Multiple removal mutations therefore repeat the family-key-set construction
  independently of the later relationship-id filter.
- **Admission invariant**: ordinary add rejects an id already present in any
  family row; materialized and Schema v1 construction use the shared
  `_AdmittedRows.ids` set to reject duplicate element ids before row insertion
  (`lib/src/store/family_tables.dart:99`,
  `lib/src/store/family_tables.dart:541`,
  `lib/src/store/family_tables.dart:551`,
  `lib/src/store/family_tables.dart:579`).
- **Related lookups**: `elementByCanvasId` performs explicit map lookups in the
  order image -> vector -> path -> text -> stroke -> line -> rect and
  materializes the first row as a public element
  (`lib/src/store/family_tables.dart:87`). Frame-fact lookup follows the same
  family order (`lib/src/store/family_tables.dart:164`).

### 3. Sparse Resource-Relationship Candidate Validation

- **Location**: `lib/src/store/document_store_kernel.dart:404`
- **Description**: `prepareSparseCommit` starts from the current committed
  document and sequentially applies an immutable list of sparse mutations to a
  candidate (`lib/src/store/sparse_store_commit.dart:10`,
  `lib/src/store/document_store_kernel.dart:405`). Contiguous element updates
  are grouped into batches (`lib/src/store/document_store_kernel.dart:414`).
- **Batch collapse**: `_prepareSparseElementUpdateBatch` stores changed elements
  in a map keyed by element id. A later update to the same id reads the prior
  changed value as its `before` value and replaces the map entry; missing ids and
  source-level no-ops do not enter the final replacement iterable
  (`lib/src/store/document_store_kernel.dart:701`,
  `lib/src/store/document_store_kernel.dart:705`,
  `lib/src/store/document_store_kernel.dart:710`,
  `lib/src/store/document_store_kernel.dart:712`,
  `lib/src/store/document_store_kernel.dart:716`,
  `lib/src/store/document_store_kernel.dart:726`). The family-table update
  receives `changedById.values`, so one contiguous batch publishes at most one
  final row per element id (`lib/src/store/document_store_kernel.dart:729`).
- **Dependencies**: a successful resource-backed add contributes its element id
  to `resourceRelationshipElementIds`; a successful update batch contributes
  ids whose image/vector `resourceId` changed
  (`lib/src/store/document_store_kernel.dart:433`,
  `lib/src/store/document_store_kernel.dart:456`,
  `lib/src/store/document_store_kernel.dart:1932`,
  `lib/src/store/document_store_kernel.dart:1943`). Image and vector are the two
  resource-backed element families in this classification
  (`lib/src/store/document_store_kernel.dart:1958`).
- **Data flow**: sparse add/update mutations -> unique relationship element-id
  set -> apply all later mutations -> remove ids absent from final candidate ->
  validate either the remaining ids or the full frame order
  (`lib/src/store/document_store_kernel.dart:410`,
  `lib/src/store/document_store_kernel.dart:480`,
  `lib/src/store/document_store_kernel.dart:483`).
- **Full-validation branch**: an upsert of an existing resource descriptor sets
  the full-validation flag only when the descriptor kind changes between image
  and vector (`lib/src/store/document_store_kernel.dart:460`,
  `lib/src/store/document_store_kernel.dart:1962`). Full validation iterates the
  candidate `frameElementOrder`; selective validation iterates the supplied id
  set (`lib/src/store/document_store_kernel.dart:1978`,
  `lib/src/store/document_store_kernel.dart:1982`).
- **Validation outputs**: a missing image/vector descriptor produces
  `missingResourceReference`; an existing descriptor of the other sealed kind
  produces `resourceKindMismatch`; an element-order id without a family row
  produces `StateError` (`lib/src/store/document_store_kernel.dart:1984`,
  `lib/src/store/document_store_kernel.dart:1988`,
  `lib/src/store/document_store_kernel.dart:2013`).
- **Preparation order**: final-candidate resource relationship validation runs
  before deferred sparse element-update validation and revision-coverage
  acceptance; installation remains a separate later operation
  (`lib/src/store/document_store_kernel.dart:480`,
  `lib/src/store/document_store_kernel.dart:491`,
  `lib/src/store/document_store_kernel.dart:513`,
  `lib/src/store/document_store_kernel.dart:575`).
- **Evidence consequence**: with `K` unique ids in the post-mutation set and `N`
  total family rows, the filter invokes the full-key-set membership path `K`
  times (`lib/src/store/document_store_kernel.dart:480`,
  `lib/src/store/family_tables.dart:143`). The relationship validator that
  follows then resolves only the ids retained by that filter unless descriptor
  kind change selected the full-order branch
  (`lib/src/store/document_store_kernel.dart:483`).

### 4. Resource Reference Membership

- **Location**: `lib/src/store/family_tables.dart:79`
- **Description**: `FamilyTables.referencesResource` tests image-row values
  with `Iterable.any` and, if no image matches, tests vector-row values. It does
  not inspect path, text, stroke, line, or rect rows
  (`lib/src/store/family_tables.dart:79`).
- **Dependencies**: `ElementRegistry.referencesResource` delegates directly to
  this method (`lib/src/store/element_registry.dart:151`). `ImageRow` and
  `VectorRow` each retain a `CanvasResourceId` copied from the public element or
  schema import event (`lib/src/store/family_tables.dart:681`,
  `lib/src/store/family_tables.dart:688`,
  `lib/src/store/family_tables.dart:719`,
  `lib/src/store/family_tables.dart:726`).
- **Data flow**: resource id -> scan image rows -> optional scan vector rows ->
  boolean referenced/not referenced (`lib/src/store/family_tables.dart:79`).
- **Production call sites**: the boolean is used by the kernel read port,
  sparse removal of an unused resource, and resource accepted-fact
  classification (`lib/src/store/document_store_kernel.dart:116`,
  `lib/src/store/document_store_kernel.dart:766`,
  `lib/src/store/document_store_kernel.dart:1116`). Runtime forwards the read
  port to edit facts (`lib/src/runtime/runtime_root.dart:2607`), and sparse edit
  resource removal consults those facts when no local overlay settles the
  answer (`lib/src/edit/edit_session.dart:1025`,
  `lib/src/edit/edit_session.dart:1036`).
- **Additional repeated-scan path**: each
  `StoreSparseRemoveUnusedResource` mutation checks the current candidate's
  resource table and then calls `referencesResource` before deciding whether
  removal is a no-op (`lib/src/store/document_store_kernel.dart:766`). A sparse
  commit containing multiple such mutations can therefore invoke the
  image/vector row scan once per removal attempt before accepted-fact resource
  classification runs.
- **Observed retained state**: the fully inspected fields of `FamilyTables` and
  `ElementRegistry` include family maps and order/location/admission
  collections, but no collection keyed by `CanvasResourceId`
  (`lib/src/store/family_tables.dart:69`,
  `lib/src/store/element_registry.dart:109`). Search for resource-reference
  lookups found the scan implementation and the delegating/caller sites listed
  above; no other production resource-reference membership implementation was
  found.

### 5. Resource-Touch Classification and Downstream Shape

- **Location**: `lib/src/store/document_store_kernel.dart:1116`
- **Description**: `_resourceTouchedFacts` compares descriptors for a selected
  id iterable. An id enters `descriptorChangedIds` when one side is absent or
  `hasSameResourceFacts` is false; unchanged descriptors skip reference
  membership checks (`lib/src/store/document_store_kernel.dart:1129`,
  `lib/src/store/document_store_kernel.dart:1132`).
- **Dependencies**: a descriptor-changed id enters `visualChangedIds` when the
  base or candidate registry reports a reference
  (`lib/src/store/document_store_kernel.dart:1137`). Descriptor fact equality
  compares the sealed descriptor type and persisted descriptor fields, not the
  accepted `resourceRevision` (`lib/src/store/resource_table.dart:357`,
  `lib/src/store/resource_table.dart:396`).
- **Sparse data flow**: sparse mutation taxonomy records upsert/remove ids in
  `touched.resourceIds`; `StoreSparseClearContent(removeUnusedResources: true)`
  sets `allResources` (`lib/src/store/document_store_kernel.dart:2144`,
  `lib/src/store/document_store_kernel.dart:2148`). Sparse accepted facts pass
  the touched ids as `limitedToIds`, or pass `null` for all resources
  (`lib/src/store/document_store_kernel.dart:1551`,
  `lib/src/store/document_store_kernel.dart:1556`).
- **Materialized data flow**: full committed-document touched-fact comparison
  calls `_resourceTouchedFacts` without a limit, so the helper uses the union of
  base and candidate resource descriptor ids
  (`lib/src/store/document_store_kernel.dart:1058`,
  `lib/src/store/document_store_kernel.dart:1121`).
- **Evidence consequence**: for `R` descriptor-changed ids, the classifier may
  scan all image/vector rows in base and candidate for each id
  (`lib/src/store/document_store_kernel.dart:1138`,
  `lib/src/store/family_tables.dart:79`). Short-circuiting can stop after an
  image match or after a base match; when no match is present, both family
  sequences in both registries are traversed.
- **Downstream facts**: accepted finalization stores
  `resourceDescriptorChangedIds` and `resourceVisualChangedIds` as immutable
  resource-id sets (`lib/src/store/store_commit_finalization.dart:21`,
  `lib/src/store/store_commit_finalization.dart:45`). `TouchedSet.resourceIds`
  is their union (`lib/src/contracts/internal/touched_set.dart:63`). A nonempty
  `resourceVisualChangedIds` set requests main-canvas repaint, while a resource
  revision requests `ResourceEffect`
  (`lib/src/edit/commit_compiler.dart:57`,
  `lib/src/edit/commit_compiler.dart:80`). These structures do not carry the ids
  of elements that reference a changed resource
  (`lib/src/store/store_commit_finalization.dart:53`,
  `lib/src/store/store_commit_finalization.dart:60`).
- **Delivery consequence**: runtime resource delivery releases all resource
  state for a document-wide visual change; otherwise it releases the union of
  touched resource ids when that set is nonempty
  (`lib/src/runtime/runtime_root.dart:1990`,
  `lib/src/runtime/runtime_root.dart:2002`,
  `lib/src/runtime/runtime_root.dart:2006`). The delivery path consumes resource
  ids rather than referring element ids.

### 6. Atomic State Construction and Mutation Paths

- **Location**: `lib/src/store/committed_document.dart:31`
- **Description**: materialized construction builds `ResourceTable` from public
  resources and `ElementRegistry` from public background elements and layers
  (`lib/src/store/committed_document.dart:35`,
  `lib/src/store/committed_document.dart:44`). The registry constructor builds
  family rows, layer rows, and order-derived facts from the same input graph
  (`lib/src/store/element_registry.dart:27`).
- **Public update input**: image and vector update DTOs carry
  `CanvasFieldUpdate<CanvasResourceId>` fields
  (`lib/src/contracts/public/canvas_element_update.dart:76`,
  `lib/src/contracts/public/canvas_element_update.dart:107`). Update application
  dispatches by the current element family and materializes the next image or
  vector element with the resulting required `resourceId`, the same element id,
  and the next element revision
  (`lib/src/edit/element_update_application.dart:25`,
  `lib/src/edit/element_update_application.dart:113`,
  `lib/src/edit/element_update_application.dart:120`,
  `lib/src/edit/element_update_application.dart:136`,
  `lib/src/edit/element_update_application.dart:143`).
- **Edit routing**: a non-materialized edit session publishes a
  `StoreSparseCommit`, which `EditKernel` sends to `prepareSparseCommit`; a
  materialized session sends `readDraftDocument()` to
  `prepareMaterializedCommit`
  (`lib/src/edit/edit_session.dart:431`,
  `lib/src/edit/edit_kernel.dart:206`,
  `lib/src/edit/edit_kernel.dart:221`). Whole-document materialized application
  constructs `CommittedDocument(document)` and selects `replaceDocument` or
  `installDocument` from the commit plan's replacement flag
  (`lib/src/edit/commit_applier.dart:129`,
  `lib/src/edit/commit_applier.dart:131`).
- **Add path**: `ElementRegistry.addElement` first creates the next family
  tables, then the next layer table. Append-at-end cases extend retained order,
  token, location, and admission collections with read-only overlays; other
  placements rebuild order facts (`lib/src/store/element_registry.dart:167`,
  `lib/src/store/element_registry.dart:179`,
  `lib/src/store/element_registry.dart:270`). Background addition rebuilds order
  facts after adding the family row (`lib/src/store/element_registry.dart:196`).
  `FamilyTables.addElement` copies and republishes the target family map while
  reusing the other six family maps
  (`lib/src/store/family_tables.dart:302`,
  `lib/src/store/family_tables.dart:306`,
  `lib/src/store/family_tables.dart:317`).
- **Update path**: sparse update validation rejects an element-family change
  (`lib/src/store/document_store_kernel.dart:1918`).
  `ElementRegistry.updateElements` replaces family rows while retaining the
  existing order, location, and admission collections
  (`lib/src/store/element_registry.dart:210`,
  `lib/src/store/element_registry.dart:217`). `FamilyTables.replaceElements`
  copies all seven maps into one mutable batch snapshot, replaces rows by
  runtime family, and republishes seven unmodifiable maps
  (`lib/src/store/family_tables.dart:120`,
  `lib/src/store/family_tables.dart:383`,
  `lib/src/store/family_tables.dart:401`,
  `lib/src/store/family_tables.dart:421`). An image/vector `resourceId` change is
  therefore represented by a replacement `ImageRow`/`VectorRow`
  (`lib/src/store/family_tables.dart:404`,
  `lib/src/store/family_tables.dart:406`).
- **Remove and clear paths**: registry removal updates background order,
  `FamilyTables`, and `LayerTable`, then rebuilds order facts
  (`lib/src/store/element_registry.dart:230`). `_AdmittedRows.remove` removes the
  id from its admission set and every family map; `FamilyTables.removeElement`
  first copies all seven current maps and the computed admitted-id union into
  `_AdmittedRows`
  (`lib/src/store/family_tables.dart:110`,
  `lib/src/store/family_tables.dart:287`,
  `lib/src/store/family_tables.dart:607`). `clearContent` publishes empty
  family rows and empty element lists inside existing layers
  (`lib/src/store/element_registry.dart:241`,
  `lib/src/store/family_tables.dart:116`,
  `lib/src/store/layer_table.dart:119`).
- **Candidate acceptance and compensation**: sparse preparation marks a
  candidate accepted only when mutations changed facts and the computed
  accepted revision delta has changes. An unaccepted final candidate returns
  the original committed document, an empty revision delta, empty touched
  facts, and empty admitted-id lists
  (`lib/src/store/document_store_kernel.dart:498`,
  `lib/src/store/document_store_kernel.dart:505`,
  `lib/src/store/document_store_kernel.dart:520`,
  `lib/src/store/document_store_kernel.dart:526`). This is the path exercised by
  compensating sparse candidates in the store fixture
  (`test/store/fixtures/sparse_store_commit_fixture.dart:250`).
- **Accepted-row normalization**: accepted sparse construction calls
  `_acceptSparseElementRows`. For touched rows whose committed element delta is
  empty, that helper replaces the candidate row with the base row through
  `ElementRegistry.updateElements`; when no such replacements exist, it returns
  the candidate registry unchanged
  (`lib/src/store/document_store_kernel.dart:554`,
  `lib/src/store/document_store_kernel.dart:1016`,
  `lib/src/store/document_store_kernel.dart:1027`,
  `lib/src/store/document_store_kernel.dart:1039`). The same acceptance step
  preserves a prior resource revision when the descriptor facts are unchanged
  (`lib/src/store/document_store_kernel.dart:568`,
  `lib/src/store/resource_table.dart:78`,
  `lib/src/store/resource_table.dart:209`).
- **Sparse install boundary**: preparation returns a candidate plus admitted-id
  deltas; install checks the base revisions, swaps the prepared document, and
  admits the returned ids into kernel id generators
  (`lib/src/store/document_store_kernel.dart:520`,
  `lib/src/store/document_store_kernel.dart:575`).

### 7. Schema Import, Replacement, and Serialization Surface

- **Location**: `lib/src/store/schema_v1_store_import.dart:15`
- **Description**: direct Schema v1 store import owns separate resource,
  family, layer, and order builders. Each background/layer element event is sent
  to the family builder and the corresponding order/layer builder in the same
  event callback (`lib/src/store/schema_v1_store_import.dart:40`,
  `lib/src/store/schema_v1_store_import.dart:46`,
  `lib/src/store/schema_v1_store_import.dart:62`).
- **Public DTO decode path**: public Schema v1 decode uses a
  `_CanvasDocumentBuilderSink`, receives resource and element events, builds a
  `CanvasDocument`, and validates its completed resource relationships
  (`lib/src/codec/schema_v1_decoder.dart:15`,
  `lib/src/codec/schema_v1_decoder.dart:55`,
  `lib/src/codec/schema_v1_decoder.dart:183`,
  `lib/src/codec/schema_v1_decoder.dart:401`,
  `lib/src/codec/schema_v1_decoder.dart:463`). This path reaches committed
  family state through materialized `CommittedDocument` construction, unlike
  the store-direct import path below
  (`lib/src/store/committed_document.dart:24`,
  `lib/src/store/committed_document.dart:44`).
- **Data flow**: schema events -> `FamilyTablesSchemaV1ImportBuilder` plus layer
  and order builders -> consume all builders ->
  `ElementRegistry.fromSchemaV1ImportTables` ->
  `CommittedDocument.fromStoreTables`
  (`lib/src/store/schema_v1_store_import.dart:87`,
  `lib/src/store/schema_v1_store_import.dart:102`,
  `lib/src/store/schema_v1_store_import.dart:105`,
  `lib/src/store/schema_v1_store_import.dart:110`).
- **Dependencies**: the order import builder retains its own admitted-id set
  while events arrive and publishes it as an unmodifiable view
  (`lib/src/store/element_registry.dart:387`,
  `lib/src/store/element_registry.dart:433`,
  `lib/src/store/element_registry.dart:452`). The family import builder retains
  its row maps and duplicate-id admission set until `consume`
  (`lib/src/store/family_tables.dart:434`,
  `lib/src/store/family_tables.dart:541`,
  `lib/src/store/family_tables.dart:579`).
- **Validation boundary**: the kernel validates final resource relationships on
  prepared Schema v1 import, materialized commit, install, and replacement
  boundaries (`lib/src/store/document_store_kernel.dart:260`,
  `lib/src/store/document_store_kernel.dart:271`,
  `lib/src/store/document_store_kernel.dart:314`,
  `lib/src/store/document_store_kernel.dart:327`). The load contract records the
  same missing-reference versus wrong-kind classification
  (`docs/contracts/load_document.md:128`).
- **Serialization fact**: the retained registry/family collections are internal
  store facts. Public materialized construction derives them from
  `CanvasDocument`, while direct schema import derives them from schema events
  (`lib/src/store/committed_document.dart:31`,
  `lib/src/store/schema_v1_store_import.dart:105`). Schema v1 compatibility is
  write version `1` and readable version `{1}`; unknown non-metadata fields are
  ignored and omitted by canonical encode (`docs/contracts/schema_v1.md:35`,
  `docs/contracts/schema_v1.md:59`).

### 8. Limits and Existing Verification Surfaces

- **Location**: `docs/contracts/validation_limits.md:23`
- **Description**: the current validation contract sets the maximum total
  element count to `200000` and maximum resource count to `4096`
  (`docs/contracts/validation_limits.md:32`,
  `docs/contracts/validation_limits.md:33`). Validation applies at public DTO,
  edit/update, schema import, and store preparation boundaries
  (`docs/contracts/validation_limits.md:65`).
- **Sparse correctness coverage**: store fixtures cover resource relationship
  validation against the final sparse candidate, no-projection sparse install,
  batched updates, compensating no-ops, and empty admitted-id deltas for
  net-no-op final changes (`test/store/fixtures/sparse_store_commit_fixture.dart:24`,
  `test/store/fixtures/sparse_store_commit_fixture.dart:58`,
  `test/store/fixtures/sparse_store_commit_fixture.dart:77`,
  `test/store/fixtures/sparse_store_commit_fixture.dart:250`).
- **Accepted-overlay coverage**: sparse edit tests require resource-reference
  reads to follow the accepted element overlay
  (`test/edit/fixtures/sparse_edit_session_fixture.dart:21`). Edit-matrix tests
  cover sparse and materialized image reference/resource callback orders,
  referenced-resource removal as a no-op, materialized vector references,
  sparse vector overrides, and identical vector descriptor no-ops
  (`test/edit/fixtures/edit_matrix_effects_fixture.dart:45`,
  `test/edit/fixtures/edit_matrix_effects_fixture.dart:65`,
  `test/edit/fixtures/edit_matrix_effects_fixture.dart:69`,
  `test/edit/fixtures/edit_matrix_effects_fixture.dart:73`,
  `test/edit/fixtures/edit_matrix_effects_fixture.dart:77`).
- **Fixture lookup boundary**: the sparse edit fixture implements its own
  `isResourceReferenced` by iterating fixture element ids and resolving each
  element (`test/edit/fixtures/sparse_edit_session_fixture.dart:689`). That
  fixture exercises overlay/removal semantics but does not call
  `FamilyTables.referencesResource`; the production store tests and source
  searches remain the evidence for that implementation
  (`lib/src/store/family_tables.dart:79`,
  `lib/src/store/document_store_kernel.dart:116`).
- **Schema relationship coverage**: the external canonical round-trip fixture
  checks absent image/vector references and wrong-kind classification
  (`test/codec/schema_v1/canonical_encode_roundtrip_test.dart:481`,
  `test/codec/schema_v1/canonical_encode_roundtrip_test.dart:535`). Schema tests
  also reject unknown element and resource/source kinds
  (`test/codec/schema_v1/reject_unknown_element_kind_test.dart:6`,
  `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart:6`).
- **Mechanical sparse boundary**: `projection.only_explicit_read_paths` states
  that ordinary sparse accepted finalization does not build a public document
  projection (`docs/verification/guardrails.md:197`). Its executable guardrail
  checks for no full-document diff, no `readDocument`, no
  `DocumentProjectionCache`, and the presence of touched element/layer/resource
  sets (`test/guardrails/edit_accepted_finalization_guardrail_test.dart:285`,
  `test/guardrails/edit_accepted_finalization_guardrail_test.dart:314`).
- **Performance route**: the official Flutter route is a release-blocking
  completion/artifact gate without numeric pass/fail thresholds
  (`docs/verification/performance.md:28`). Its catalog includes
  `load_document.100k` and `camera_pan.100k`, limited to exact fixtures within
  current validation limits (`docs/verification/performance.md:95`,
  `docs/verification/performance.md:102`,
  `docs/verification/performance.md:133`). The former root benchmark route is
  explicitly retired (`docs/verification/performance.md:275`).
- **Observed coverage gap**: searches under `test/`, `docs/`, and `tool/` found
  no direct test of `FamilyTables.contains`, no test or scenario named for
  `200k`/`200000` elements, and no allocation/work-count probe for the two lookup
  chains. The current performance catalog contract lists scenarios through
  `100k` for load and camera pan
  (`test/performance/flutter_performance_route_contract_test.dart:6`,
  `test/performance/flutter_performance_route_contract_test.dart:44`).

## Code References

- `lib/src/store/document_store_kernel.dart:404` - sparse candidate preparation boundary.
- `lib/src/store/document_store_kernel.dart:480` - final-candidate filtering of resource-relationship element ids.
- `lib/src/store/document_store_kernel.dart:1116` - resource descriptor/visual touch classification.
- `lib/src/store/document_store_kernel.dart:1551` - sparse accepted-fact call with limited resource ids.
- `lib/src/store/document_store_kernel.dart:1932` - resource-relationship update-id collection.
- `lib/src/store/document_store_kernel.dart:1978` - final candidate resource-relationship validation.
- `lib/src/store/element_registry.dart:54` - retained order/admission fact construction.
- `lib/src/store/element_registry.dart:116` - retained admitted element-id set.
- `lib/src/store/element_registry.dart:143` - element membership delegation.
- `lib/src/store/element_registry.dart:151` - resource-reference delegation.
- `lib/src/store/family_tables.dart:69` - seven immutable family row maps.
- `lib/src/store/family_tables.dart:77` - family-table membership method.
- `lib/src/store/family_tables.dart:79` - image/vector resource-reference scan.
- `lib/src/store/family_tables.dart:143` - computed all-family admitted-id set.
- `lib/src/store/family_tables.dart:383` - batch family-row replacement snapshot.
- `lib/src/store/schema_v1_store_import.dart:105` - imported family/order facts joined into a registry.
- `lib/src/store/store_commit_finalization.dart:21` - accepted touched-fact output shape.
- `docs/contracts/validation_limits.md:32` - maximum total element count.

## Search Coverage

- **Inspected**: fully read
  `lib/src/store/document_store_kernel.dart`,
  `lib/src/store/element_registry.dart`,
  `lib/src/store/family_tables.dart`,
  `lib/src/store/committed_document.dart`,
  `lib/src/store/schema_v1_store_import.dart`,
  `lib/src/store/sparse_store_commit.dart`,
  `lib/src/store/store_commit_finalization.dart`,
  `lib/src/store/resource_table.dart`,
  `lib/src/store/layer_table.dart`,
  `lib/src/store/document_projection_cache.dart`,
  `lib/src/edit/edit_kernel.dart`,
  `lib/src/edit/commit_applier.dart`,
  `lib/src/edit/commit_compiler.dart`,
  `lib/src/contracts/internal/touched_set.dart`,
  `lib/src/codec/validated_import_draft.dart`,
  `lib/src/codec/schema_v1_decoder.dart`, and the public document/element/update
  contracts.
- **Searched**: `rg` queries for `ElementRegistry`, `FamilyTables`,
  `containsElement`, `admittedElementIds`, `referencesResource`, `imageRows`,
  `vectorRows`, resource touched facts, sparse/materialized commits, schema
  import, limits, performance scenarios, benchmarks, and related guardrails
  across `lib/`, `test/`, `docs/`, `tool/`, and `example/`.
- **Not found**: no retained `CanvasResourceId`-keyed reference collection in
  the fully inspected committed store classes; no additional production
  implementation of resource-reference membership; no direct
  `FamilyTables.contains` test; no root `benchmark/` directory; no `200k`/
  `200000` named scenario; no active design or Change Contract in the direct
  children of `docs/planning/designs/` or `docs/planning/plans/`. The directory
  and search absences are command-surface findings without stable source lines.
- **Not inspected**: `lib/src/runtime/runtime_root.dart` and
  `lib/src/edit/edit_session.dart` were inspected at the relevant wiring and
  resource-read ranges but were not read in full. Rendering, geometry, resource
  cache internals, platform integration code, and unrelated tests were outside
  this research question.

## Observed Architecture Facts

- **Pattern observed**: committed family rows and order/admission facts are
  published as immutable snapshot data; add/remove/clear rebuild or overlay the
  related snapshot components, while same-family element updates replace family
  rows and retain order/admission collections
  (`lib/src/store/element_registry.dart:167`,
  `lib/src/store/element_registry.dart:210`,
  `lib/src/store/element_registry.dart:230`).
- **Pattern observed**: element admission has two current representations: the
  retained order-derived set in `ElementRegistry` and the on-access union of
  family-map keys in `FamilyTables`
  (`lib/src/store/element_registry.dart:116`,
  `lib/src/store/family_tables.dart:143`).
- **Pattern observed**: resource references are stored only as forward
  `resourceId` fields on image/vector rows in the inspected committed model;
  reference membership is computed by scanning those row values
  (`lib/src/store/family_tables.dart:681`,
  `lib/src/store/family_tables.dart:719`,
  `lib/src/store/family_tables.dart:79`).
- **Adjacent index ownership**: the architecture graph separately identifies
  `geometry.spatial_index` as derived spatial state owned by `SpatialKernel`,
  including tile/outlier membership and stale-candidate rejection, and states
  that this state is not committed scene truth
  (`docs/architecture/architecture_graph.yaml:257`,
  `docs/architecture/architecture_graph.yaml:266`).
- **Data flow**: sparse mutations -> candidate family/order/resource snapshots
  -> final relationship validation -> accepted revision/touched facts ->
  prepared commit -> atomic install
  (`lib/src/store/document_store_kernel.dart:404`,
  `lib/src/store/document_store_kernel.dart:480`,
  `lib/src/store/document_store_kernel.dart:520`,
  `lib/src/store/document_store_kernel.dart:575`).
- **Data flow**: changed resource descriptors -> base/candidate reference
  membership -> changed resource-id sets -> `TouchedSet` -> resource effect and
  repaint classification (`lib/src/store/document_store_kernel.dart:1116`,
  `lib/src/store/store_commit_finalization.dart:30`,
  `lib/src/contracts/internal/touched_set.dart:63`,
  `lib/src/edit/commit_compiler.dart:57`).
- **Key dependencies**: final relationship validation depends on sealed image/
  vector element and descriptor kinds; accepted visual-resource classification
  depends only on boolean reference membership and publishes resource ids rather
  than referring element ids (`lib/src/store/document_store_kernel.dart:1988`,
  `lib/src/store/document_store_kernel.dart:1138`,
  `lib/src/store/store_commit_finalization.dart:60`).

## Open Questions

- No existing executable measurement was found for temporary set allocations or
  row comparisons in the two lookup chains at representative `K`, `R`, and `N`
  values; current sources establish the loop and collection shapes but not
  measured runtime constants. This is a search-absence finding recorded in
  Search Coverage and has no stable source line.
- The fully inspected registry and family-table files contain no explicit
  equality assertion between the retained order-derived admitted-id set and the
  family-map key union. The absence is recorded from full-file inspection in
  Search Coverage; both collections are populated through paired construction
  and mutation paths (`lib/src/store/element_registry.dart:27`,
  `lib/src/store/schema_v1_store_import.dart:46`,
  `lib/src/store/element_registry.dart:167`).
- Current accepted resource touched facts expose resource ids only. No inspected
  downstream contract requests the set of element ids referencing each changed
  resource (`lib/src/store/store_commit_finalization.dart:53`,
  `lib/src/store/store_commit_finalization.dart:60`).
