<!-- CONTEXT:BEGIN -->
Registry id: `section_07_resource_lifecycle`
Source: `docs/split/_registry/sections.yaml / section 7`
Canonical source: `docs/split/_registry/sections.yaml`
Owns:
- 7. Resource lifecycle contract
Must read before editing:
- `section_04_public_api_v1`
- `section_10_runtime_data_model`
- `section_15_frame_render_contract`
Depends on:
- `section_04_public_api_v1`
- `section_10_runtime_data_model`
- `section_15_frame_render_contract`
Feeds phases:
- `P4`
- `P10`
Related donors:
- `none`
Related diagrams:
- docs/split/diagrams/README.md#dfd_resource_resolution -> docs/split/diagrams/generated/dfd_resource_resolution.mmd
- docs/split/diagrams/README.md#seq_resource_resolution -> docs/split/diagrams/generated/seq_resource_resolution.mmd
- docs/split/diagrams/README.md#state_resource_resolution -> docs/split/diagrams/generated/state_resource_resolution.mmd
Required tests:
- `test.schema_v1.resources_appkey_only`
- `test.schema_v1.reject_unknown_resource_source_kind`
- `test.resources.sync_image_resolver`
- `test.resources.app_owned_image_not_disposed`
- `test.resources.resource_dirty`
- `test.resources.mark_all_resources_dirty`
Guardrails:
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
Do not infer:
- no engine IO
- no asset-bundle loading
- no file loading
- no remote/network loading
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 7. Resource lifecycle contract

### 7.1 Resource state

`DocumentStoreKernel` owns resource descriptors as part of committed document. `ResourceKernel` owns runtime caches.

```text
Committed document:
  resource descriptors only.

Runtime cache:
  resolved app-provided image references;
  dirty resource ids.
```

### 7.2 Atomic operations

Resource mutation is inside `CanvasEdit`:

```dart
runtime.edits.edit((edit) {
  edit.upsertResource(CanvasImageResource(...));
  edit.addElement(CanvasImageElement(resourceId: ...));
});
```

If any operation throws, both resource and element changes roll back.

### 7.3 Removal

`removeUnusedResource(id)`:

```text
- returns false if resource does not exist;
- returns false if any element references it;
- references include background elements, hidden elements, locked elements and non-deletable elements;
- removes resource and invalidates resource cache if unused;
- emits no action event;
- increments document/resource revision if removed.
```

### 7.4 External visual resource repaint

Old `notifySceneChanged()` is replaced by:

```dart
runtime.resources.markResourceDirty(resourceId);
runtime.resources.markAllResourcesDirty();
```

Semantics:

```text
- does not change document revision;
- increments resourceVisualRevision;
- invalidates resolved cache entries for target resource;
- schedules main repaint;
- does not emit action event;
- does not clear selection;
- does not clear preview;
- after dispose throws StateError.
```

`markAllResourcesDirty` applies the same rule to every registered resource.

### 7.5 v1 resource boundary

```text
- mandatory v1 supports appKey resource descriptors and dirty invalidation;
- resource mutation remains inside CanvasEdit;
- resolver calls are synchronous and app-owned;
- no engine IO;
- no asset-bundle loading;
- no file loading;
- no remote/network loading.
```

### 7.6 Missing resource placeholder

If an image element references a missing or unresolved resource, FrameEngine
paints a bounded placeholder rectangle.

```text
image size determines placeholder bounds;
no full-document repaint loop;
no repeated resolver retry in same frame;
diagnostic emitted only if verbose diagnostics enabled or schema missing reference occurs at load time.
```

---

<!-- ORIGINAL-SECTION:END -->
