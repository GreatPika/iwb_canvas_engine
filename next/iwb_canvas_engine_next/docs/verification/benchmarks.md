<!-- CONTEXT:BEGIN -->
Registry id: `section_24_benchmarks`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/benchmarks.md`
Owns:
- 24. Benchmarks
Must read before editing:
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`
Feeds phases:
- `P12`
Related donors:
- `direct_scan_resistant_cache`
Related diagrams:
- `none`
Required tests:
- `test.benchmarks.required_cases`
Guardrails:
- `none`
Do not assume:
- no unapproved old feature path regression
<!-- CONTEXT:END -->

## 24. Benchmarks

Benchmark policy:

```text
equivalent old feature path -> no unapproved regression;
new-only feature path -> own baseline;
hot input path -> avg + P95 + max gates;
paint path -> bounded by candidate count, not total scene size;
memory path -> RSS + allocation budget.
```

Required benchmark cases:

| Case | Nodes | Metrics |
|---|---:|---|
| `edit.add_element` | 1k/10k/50k/100k | avg/P95/max us, alloc bytes |
| `edit.update_visual` | 1k/10k/50k/100k | avg/P95/max us, touched count |
| `edit.update_transform` | 1k/10k/50k/100k | spatial touched pages, alloc bytes |
| `edit.move_selection` | 1k/10k/50k | selected count, avg/P95/max |
| `edit.set_camera_offset` | 1k/10k/50k/100k | avg/P95/max us, ordinary paint-plan invalidations = 0 |
| `edit.add_line` | 1k/10k/50k | avg/P95/max us, alloc bytes |
| `input.selected_move_preview` | 1k/10k/50k | scene repaint count, avg/max |
| `frame.selected_move_preview_cached_ordinary_plan` | 1k/10k/50k | ordinary plan hit rate, supplement count, no cached previewDelta |
| `input.marquee_preview` | 1k/10k/50k | overlay repaint count, avg/max |
| `input.draw_preview` | 1k/10k | point count, avg/max |
| `input.line_preview` | 1k/10k/50k | overlay repaint count, avg/max |
| `input.eraser_preview` | 1k/10k/50k | candidate count, exact checks |
| `input.eraser_budget_exceeded` | dense 50k | budget-exceeded count, partial erase count = 0 |
| `frame.main_capture` | 1k/10k/50k/100k | avg/P95/max, alloc bytes |
| `frame.overlay_capture` | active previews | avg/P95/max, alloc bytes |
| `frame.paint_candidates` | 1k/10k/50k/100k | candidate count, saveLayer count |
| `resources.resolve_sync` | 1k resources | resolver calls, cache hits, repaint count |
| `resources.resolve_sync_cold_budget` | 1k uncached image records | resolver calls <= 128, budget placeholders, throttled repaint count |
| `resources.mark_dirty` | 1k resources | repaint count, cache invalidation cost |
| `resources.mark_all_dirty` | 1k resources | repaint count, cache invalidation cost |
| `projection.read_document` | 1k/10k/50k/100k | first read/cache hit |
| `codec.decode_v1` | all fixtures | avg/P95/max, error payload |
| `load_document.success` | 1k/10k/50k/100k | avg/P95/max, rebuild cost, alloc bytes |
| `load_document.failure` | invalid 1k/10k/50k inputs | avg/P95/max, committed mutation count = 0 |
| `spatial.query_point` | 1k/10k/50k/100k | tile count, fallback count |
| `spatial.touched_update` | 1k/10k/50k | rebuilt ids/pages |
| `runtime.dispose_during_gesture` | active selected/overlay previews | avg/P95/max, resolver calls = 0, action events = 0 |
| `diagnostics.disabled_pointer` | hot pointer | allocations = 0 records |

---
