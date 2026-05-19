<!-- CONTEXT:BEGIN -->
Registry id: `section_12_load_document`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/load_document.md`
Owns:
- 12. `loadDocument` staged contract
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
- no prepared replacement in public API
<!-- CONTEXT:END -->

## 12. `loadDocument` staged contract

`CanvasEditPort.loadDocument(document)` is the next public external document
replacement operation.
The public API delegates orchestration to `RuntimeRoot`; it does not read from
or install into `DocumentStoreKernel` directly. `RuntimeRoot` owns the atomic
cross-owner replacement operation once validation and materialization have
succeeded: document replacement is installed into `DocumentStoreKernel`, and
selection is cleared through the internal selection owner before any public
state notification is published.

P6 owns only the minimal early interaction boundary needed by staged
replacement:

```text
PreparedDocumentLoad success -> RuntimeRoot requests interrupt/preview cleanup;
the future InteractionEngine boundary routes that cleanup through the internal
PointerToolCleanupCoordinator;
the boundary may clear active preview state and pointer normalization facts;
the boundary must not read from or mutate DocumentStoreKernel;
the boundary must not execute terminal resolver or commit paths;
failure before PreparedDocumentLoad success must not call the boundary.
```

The full `InteractionEngine` pointer-session state machines remain owned by
P10-P12 and consume this ordering instead of being prerequisites for P6.

Success ordering:

```text
1. validate public CanvasDocument, including `CanvasMetadata`, frozen collection ownership, and invertible element transforms;
2. materialize PreparedDocumentLoad;
3. if validation/materialization succeeds, interrupt active interaction;
4. clear preview;
5. atomically install the replacement document and clear selection through the
   runtime/applier boundary;
6. initialize runtime view camera from the persisted document camera;
7. increment `state.revisions.epoch`, `state.revisions.document`,
   `state.revisions.selection`, `state.revisions.viewCamera`, and
   `state.revisions.preview` if active preview cleanup changed preview state
   inside the same atomic runtime result;
8. clear pointer normalization and pending tap history;
9. invalidate projection/spatial/frame/resource caches;
10. schedule main repaint and overlay repaint;
11. publish one `CanvasRuntimeState` after install.
```

`PreparedDocumentLoad` owns replacement committed tables, generated id admission
state, and replacement revision facts. The runtime/applier boundary combines
that prepared document payload with a selection-owner clear effect. Selection
clearing is not a separate post-install mutation.
The public `CanvasRuntimeState` published after install is the first public
observation of the replacement document, cleared selection, optional preview
cleanup, incremented epoch, and runtime view camera initialized from the
persisted document camera.

Failure ordering:

```text
1. validate/materialize fails, including invalid `CanvasMetadata`, mutable DTO boundary input, or non-invertible element transform input;
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

`CanvasEdit.replaceDraftDocument(document)` is different:

```text
- only valid inside edit callback;
- no external gesture interruption;
- rollback-safe;
- participates in same atomic edit session;
- external loadDocument tests do not prove replaceDraftDocument behavior.
```

---
