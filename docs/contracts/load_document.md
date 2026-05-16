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
or install into `DocumentStoreKernel` directly. `DocumentStoreKernel` owns the
atomic replacement install once validation and materialization have succeeded.

P6 owns only the minimal early interaction boundary needed by staged
replacement:

```text
PreparedDocumentLoad success -> RuntimeRoot requests interrupt/preview cleanup;
the boundary may clear active preview state and pointer normalization facts;
the boundary must not read from or mutate DocumentStoreKernel;
the boundary must not execute terminal resolver or commit paths;
failure before PreparedDocumentLoad success must not call the boundary.
```

The full `InteractionEngine` pointer-session state machines remain owned by
P10-P12 and consume this ordering instead of being prerequisites for P6.

Success ordering:

```text
1. validate public CanvasDocument, including `CanvasMetadata` and frozen collection ownership;
2. materialize PreparedDocumentLoad;
3. if validation/materialization succeeds, interrupt active interaction;
4. clear preview;
5. atomic install replacement payload, including cleared selection;
6. increment controllerEpoch and all document-level revisions inside the same install boundary;
7. clear pointer normalization and pending tap history;
8. invalidate projection/spatial/frame/resource caches;
9. schedule main repaint and overlay repaint;
10. notify listeners after install.
```

`PreparedDocumentLoad` owns replacement committed tables, generated id admission
state, cleared selection, and replacement revision facts. Selection clearing is
not a separate post-install mutation.

Failure ordering:

```text
1. validate/materialize fails, including invalid `CanvasMetadata` or mutable DTO boundary input;
2. active gesture is not interrupted;
3. preview remains unchanged;
4. pending line remains unchanged;
5. pointer normalization remains unchanged;
6. committed document remains unchanged;
7. selection remains unchanged;
8. no repaint;
9. no action event;
10. exception is rethrown as CanvasDataException or StateError.
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
