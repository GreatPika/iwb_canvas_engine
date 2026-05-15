# Architecture rebuild mode

The repository root is the canonical target package for the `iwb_canvas_engine`
architecture rebuild. The current task is to build the new engine described in
`docs/`, not to maintain or extend the legacy package.


## Entry points

- `docs/README.md` is the documentation entry point.
- `PLAN.md` is the working plan for all rebuild phases. Update its checkboxes
  after completing plan items.


## Verification

After each code change, run these checks from the repository root:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`

Do not run these checks for documentation-only changes.
