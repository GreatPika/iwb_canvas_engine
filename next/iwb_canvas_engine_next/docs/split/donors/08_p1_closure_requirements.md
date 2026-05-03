<!-- CONTEXT:BEGIN -->
Registry id: `donors_08_p1_closure_requirements`
Source: `docs/split/_registry/donors.yaml / P1 closure requirements`
Canonical source: `docs/split/_registry/donors.yaml`
Feeds registry: `docs/split/_registry/donors.yaml`
Feeds indexes:
- `docs/split/indexes/donor_to_phase.md`
- `docs/split/indexes/phase_to_donor.md`
Use rule: donor entries are phase-bound implementation inputs, not old architecture to copy.
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## P1 closure requirements

P1 donor inventory is closed only when:

- every donor intended for P2-P12 is represented in this file or a later
  machine-readable donor registry;
- every `copy` or `copy/adapt` donor has at least one named test to port;
- every `adapt` donor names the old behavior to preserve and the old shell to
  reject;
- every `rewrite-reference` donor is listed only as behavior/test evidence;
- the functional ledger links capabilities to donor files where reuse is
  expected;
- implementation phases do not import donor files from the old package at
  runtime.
<!-- ORIGINAL-SECTION:END -->
