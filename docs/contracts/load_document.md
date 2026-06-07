<!-- CONTEXT:BEGIN -->
Registry id: `section_12_load_document`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/load_document.md`
Owns:
- 12. Schema v1 JSON load contract
Must read before editing:
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
Feeds phases:
- `P6`
- `P10`
- `P11`
- `P12`
Related donors:
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `interaction_mutation_boundary`
Related diagrams:
- `dfd_load_document_success_failure`
- `seq_load_document_success`
- `seq_load_document_failure`
Required tests:
- `test.edit.staged_document_load_success_failure`
- `test.runtime.load_document_state_publication`
Guardrails:
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
Do not assume:
- no interrupt before successful preparation
- no public CanvasDocument load input
<!-- CONTEXT:END -->

## 12. Schema v1 JSON load contract

`CanvasEditPort.loadDocumentFromJson(json)` is the canonical public external
document replacement operation. Applications call it on an existing
`CanvasRuntime` with schema v1 JSON. `CanvasRuntime` construction has no
document or JSON load input, and public `CanvasDocument` remains only a
read/output projection. The public API facade delegates orchestration to
`RuntimeRoot`; it does not read from or install into `DocumentStoreKernel`
directly. `RuntimeRoot` owns the atomic cross-owner replacement operation after
all fallible JSON validation, dependency-neutral import, store row/table
preparation, and prepared interaction cleanup have succeeded.

P6 owns only the minimal early interaction boundary needed by staged
replacement:

```text
PreparedDocumentLoad success -> RuntimeRoot requests prepared load cleanup;
the target InteractionEngine boundary routes that cleanup through the internal
PointerToolCleanupCoordinator;
the `contracts/internal/**` boundary returns a LoadInteractionCleanupOutcome before document install;
the load outcome records only prepared-load publication facts;
the boundary must not read from or mutate DocumentStoreKernel;
the boundary must not execute terminal resolver or commit paths;
RuntimeRoot must not call the interaction boundary again after document install
to finish load cleanup;
failure before PreparedDocumentLoad success must not call the boundary.
```

The full `InteractionEngine` pointer-session state machines remain owned by
P10-P12 and consume this ordering instead of being prerequisites for P6.

Success ordering:

```text
1. check raw JSON length;
2. parse JSON and validate schema v1 root, fields, metadata, enums, resources, elements, and invertible element transforms through codec-owned policy;
3. emit dependency-neutral schema import events without constructing CanvasDocument, CanvasImageResource, store rows, or a retained validated fact graph;
4. let DocumentStoreKernel-owned preparation consume the import events into store-owned rows/tables, resource descriptor rows, id admission facts, reference checks, revision facts, runtime camera facts, and projection invalidation facts;
5. if import and store preparation succeed, request prepared interaction cleanup;
6. produce the LoadInteractionCleanupOutcome before the document install commit
   point; the outcome records whether prepared cleanup changed public preview
   publication state, while full pointer cleanup policy remains owned by
   PointerToolCleanupCoordinator;
7. atomically install the replacement document and clear selection through the
   runtime/applier boundary;
8. initialize runtime view camera from the persisted schema v1 document camera;
9. increment `state.revisions.epoch`, `state.revisions.document`,
   `state.revisions.selection`, `state.revisions.viewCamera`, and
   `state.revisions.preview` if active preview cleanup changed preview state
   inside the same atomic runtime result;
10. invalidate projection/spatial/frame/resource caches without building public projection;
11. schedule main repaint and overlay repaint;
12. publish one `CanvasRuntimeState` after install.
```

The prepared store load owns replacement committed tables, resource descriptor
rows, generated id admission state, and replacement revision facts. The
runtime/applier boundary combines that prepared store payload with a
selection-owner clear effect. Selection clearing is not a separate post-install
mutation. Pointer normalization and pending tap cleanup are also not separate
post-install owner calls; they are carried by the prepared interaction cleanup
outcome before document install.
The public `CanvasRuntimeState` published after install is the first public
observation of the replacement document, cleared selection, optional preview
cleanup, incremented epoch, and runtime view camera initialized from the
persisted document camera.

Failure ordering:

```text
1. raw length check, JSON parse, schema validation, import event emission, store row/table preparation, id admission, reference checks, or prepared cleanup fails;
2. active gesture is not interrupted;
3. preview remains unchanged;
4. pending line remains unchanged;
5. pointer normalization remains unchanged;
6. committed document owner remains unchanged;
7. selection owner remains unchanged;
8. runtime view camera remains unchanged;
9. no repaint;
10. no public state publication;
11. no action event;
12. exception is rethrown as CanvasDataException or StateError.
```

Failed load must not materialize a public `CanvasDocument`, build
`DocumentProjectionCache`, create public `CanvasImageResource`, install partial
store rows, clear selection, change runtime view camera, increment revisions,
publish effects/actions, or notify state listeners. Successful load may
invalidate public projection, but the first `CanvasDocument` projection is built
only when an explicit read/projection path asks for it.

`CanvasEdit.replaceDraftDocument(document)` is different:

```text
- only valid inside edit callback;
- no external gesture interruption;
- rollback-safe;
- participates in same atomic edit session;
- external JSON load tests do not prove replaceDraftDocument behavior.
```

---
