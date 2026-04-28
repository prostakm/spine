# <!-- BEGIN PROJECT SPINE -->

## Project Spine

Project Spine is installed as repo-local skills, but it is opt-in: only use it when the user explicitly asks for `$spine-brainstorm`, `$spine-spec`, `$spine-pwf`, or says to use Spine.
When Spine is invoked, load the matching skill under `.agents/skills/` and keep the workflow rules, gates, and planning details there; otherwise work normally.
Explicit chat approval (`approved`, `plan approved`, `spec approved`, `I approve`) counts during Spine review, but it must be mirrored into the active `plan.md` or `spec.md` before proceeding.

### Plan format

Plans use the v15 shape:
- Above trust boundary: Overview + Context + Chapters (each with Why grouped
  / What changes / Decisions / Provisions) + Contracts.
- Below trust boundary: Implementation tracks (Constraints / Code as full diff
  snippets with file/line locations / Tests as In/Assert specs / Verify /
  Green when) + Verification evidence + Acceptance gate.
- Strategy: CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION.
- Reviewer reads top-to-bottom and stops at the trust boundary.
- Cross-links use `[label](#slug)` heading-anchored navigation.
- See `docs/EXAMPLE-PLAN.md` for the canonical worked example.

# <!-- END PROJECT SPINE -->
