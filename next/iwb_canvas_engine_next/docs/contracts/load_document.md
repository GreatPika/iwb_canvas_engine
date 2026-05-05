<!-- CONTEXT:BEGIN -->
Registry id: `section_12_load_document`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/load_document.md`
Owns:
- 12. `loadDocument` staged contract
Must read before editing:
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
- `section_13_operation_matrix` -> `docs/contracts/operation_matrix.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
Feeds phases:
- `P6`
- `P9`
Related donors:
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `interaction_mutation_boundary`
Related diagrams:
- `dfd_load_document_success_failure`
- `seq_load_document_success`
- `seq_load_document_failure`
Required tests:
- `test.load_document.staged_success_failure`
Guardrails:
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
Do not assume:
- no interrupt before successful preparation
- no prepared replacement in public API
<!-- CONTEXT:END -->

## 12. `loadDocument` staged contract

`CanvasEditPort.loadDocument(document)` is the new public external document replacement operation.
The public API delegates orchestration to `RuntimeRoot`; it does not read from
or install into `DocumentStoreKernel` directly. `DocumentStoreKernel` owns the
atomic replacement install once validation and materialization have succeeded.

Success ordering:

```text
1. validate public CanvasDocument;
2. materialize PreparedDocumentLoad;
3. if validation/materialization succeeds, interrupt active interaction;
4. clear preview;
5. atomic install committed document;
6. clear selection;
7. increment controllerEpoch and all document-level revisions;
8. clear pointer normalization and pending tap history;
9. invalidate projection/spatial/frame/resource caches;
10. schedule main repaint and overlay repaint;
11. notify listeners after install.
```

Failure ordering:

```text
1. validate/materialize fails;
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
