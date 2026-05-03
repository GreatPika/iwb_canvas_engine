<!-- CONTEXT:BEGIN -->
Registry id: `section_12_load_document`
Source: `iwb_canvas_engine_next_full_implementation_plan_v2.md / section 12`
Canonical original: `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`
Owns:
- 12. `loadDocument` staged contract
Must read before editing:
- `section_10_runtime_data_model`
- `section_11_edit_kernel`
- `section_13_operation_matrix`
- `section_14_interaction_engine`
Depends on:
- `section_10_runtime_data_model`
- `section_11_edit_kernel`
- `section_13_operation_matrix`
- `section_14_interaction_engine`
Feeds phases:
- `P6`
- `P9`
Related donors:
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `interaction_mutation_boundary`
Related diagrams:
- docs/split/diagrams/README.md#dfd_load_document_success_failure -> tool/diagrams/dfd_load_document_success_failure.mmd
- docs/split/diagrams/README.md#seq_load_document_success -> tool/diagrams/seq_load_document_success.mmd
- docs/split/diagrams/README.md#seq_load_document_failure -> tool/diagrams/seq_load_document_failure.mmd
Required tests:
- `test.load_document.staged_success_failure`
Guardrails:
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
Do not infer:
- no interrupt before successful preparation
- no prepared replacement in public API
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 12. `loadDocument` staged contract

`CanvasEditPort.loadDocument(document)` is the new public external document replacement operation.

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

<!-- ORIGINAL-SECTION:END -->
