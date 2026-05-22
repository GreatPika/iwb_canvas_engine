<!-- CONTEXT:BEGIN -->
Registry id: `donors_08_p1_closure_requirements`
Source: `docs/_registry/donors.yaml / P1 closure requirements`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Generated navigation: `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## P1 scope-gate donor review requirements

P1 donor review is closed only when:

- every donor intended for P2-P12 is represented in this file or a later
  machine-readable donor registry;
- every `copy` or `copy/adapt` donor has at least one named test to port;
- every `adapt` donor names the legacy behavior to preserve and the legacy
  shell to reject;
- every `rewrite-reference` donor is listed only as behavior/test evidence;
- implementation phases do not import donor files from the legacy package at
  runtime.
