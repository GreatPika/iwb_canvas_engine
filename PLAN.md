language: english

# Plan

This file is the active plan index. Each step has a dedicated document so the
roadmap can be updated without mixing execution contracts.

Step entry template: `- [ ] [Step <number>. <Short step title>](plan/step_<number>_<short_snake_case_summary>.md)`

## General Notes

- Step order defines the intended implementation order.
- Detailed scope, closure rules, and verification live only in the linked step
  document.
- Completed step contracts are historical records. They may reference paths,
  APIs, or checks that were later retired; use the current document map and
  active step contracts for current navigation.
- When a step is completed, update both this index and the linked step
  document in the same change.

## Step Files

- [ ] [Step 1. P0 package skeleton and hard boundaries](plan/step_1_package_skeleton_and_hard_boundaries.md)
- [x] [Step 2. Public readable union variants](plan/step_2_public_readable_union_variants.md)
- [x] [Step 3. CanvasFieldUpdate patch semantics](plan/step_3_canvas_field_update_patch_semantics.md)
