<!-- CONTEXT:BEGIN -->
Registry id: `section_11_edit_kernel`
Source: `docs/split/_registry/sections.yaml / section 11`
Canonical source: `docs/split/_registry/sections.yaml`
Owns:
- 11. EditKernel implementation contract
Must read before editing:
- `section_04_public_api_v1`
- `section_10_runtime_data_model`
- `section_12_load_document`
- `section_13_operation_matrix`
Depends on:
- `section_04_public_api_v1`
- `section_10_runtime_data_model`
- `section_12_load_document`
- `section_13_operation_matrix`
Feeds phases:
- `P6`
Related donors:
- `interaction_mutation_boundary`
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `dto_document_helpers`
Related diagrams:
- docs/split/diagrams/README.md#c4_code_edit_kernel -> docs/split/diagrams/generated/c4_code_edit_kernel.mmd
- docs/split/diagrams/README.md#dfd_public_edit -> docs/split/diagrams/generated/dfd_public_edit.mmd
- docs/split/diagrams/README.md#seq_edit_success -> docs/split/diagrams/generated/seq_edit_success.mmd
- docs/split/diagrams/README.md#seq_edit_rollback -> docs/split/diagrams/generated/seq_edit_rollback.mmd
- docs/split/diagrams/README.md#state_edit_session -> docs/split/diagrams/generated/state_edit_session.mmd
Required tests:
- `test.events.low_level_mutations_do_not_emit_actions`
- `test.edit_kernel.sync_non_nested_async_stale`
- `test.edit_kernel.rollback`
Guardrails:
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `events.low_level_edit_no_user_actions`
Do not infer:
- no old SceneWriteTxn
- no old controller shell
- no async nested edit
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 11. EditKernel implementation contract

### 11.1 Write sequence

```mermaid
sequenceDiagram
  participant Caller
  participant API as CanvasEditPort
  participant EK as EditKernel
  participant Draft as DraftDocument
  participant CC as CommitCompiler
  participant Store as DocumentStoreKernel
  participant Frame as FrameEngine
  participant Events as EventBuffer

  Caller->>API: edit(fn)
  API->>EK: open session
  EK->>EK: reject disposed/nested
  EK->>Draft: create draft from committed revision
  EK-->>Caller: CanvasEdit handle
  Caller->>Draft: synchronous mutations
  EK->>EK: reject Future result
  EK->>CC: compile touched set + invalidation
  CC->>Store: preflight invariants
  CC->>Frame: prepare repaint masks
  Store->>Store: atomic install
  Store->>Events: commit buffered events
  Store->>Frame: publish repaint buses
  EK->>EK: close handle
  EK-->>Caller: return callback result
```

### 11.2 Rollback sequence

```mermaid
sequenceDiagram
  participant Caller
  participant EK as EditKernel
  participant Draft as DraftDocument
  participant Events as EventBuffer
  participant Repaint as RepaintBuffer

  Caller->>EK: edit(fn)
  EK->>Draft: create draft
  Caller->>Draft: mutation throws / Future returned
  EK->>Events: discard buffered events
  EK->>Repaint: discard repaint requests
  EK->>EK: close edit handle
  EK-->>Caller: rethrow
```

Rollback obligations:

```text
- committed document identity unchanged;
- all revisions unchanged;
- projection cache unchanged;
- spatial index unchanged;
- resource cache unchanged;
- selection unchanged;
- preview unchanged unless the public operation itself was a successful external mutation;
- no actions emitted;
- no text edit event emitted;
- no public notify;
- no scene repaint;
- no overlay repaint.
```

### 11.3 Touched set

```text
TouchedSet
  addedElementIds
  removedElementIds
  updatedElementIds
  transformedElementIds
  geometryChangedElementIds
  visualChangedElementIds
  resourceDescriptorChangedIds
  resourceVisualChangedIds
  layerOrderChanged
  backgroundLayerChanged
  selectionChanged
  cameraChanged
  backgroundChanged
  gridChanged
  paletteChanged
  documentReplaced
```

CommitCompiler must produce exact invalidation. Generic global invalidation is forbidden except `documentReplaced`.

---

<!-- ORIGINAL-SECTION:END -->
