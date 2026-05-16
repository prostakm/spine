# <!-- BEGIN PROJECT SPINE -->

## Project Spine

Project Spine is installed as repo-local skills, but it is opt-in: only use it when the user explicitly asks for `$spine-brainstorm`, `$spine-spec`, `$spine-pwf`, or says to use Spine.
When Spine is invoked, load the matching skill under `.agents/skills/`; `$spine-pwf` is the orchestrator and delegates phase detail to `spine-plan`, `spine-implement`, `spine-verify`, and `spine-closeout`. Otherwise work normally.
Explicit chat approval (`approved`, `plan approved`, `spec approved`, `I approve`) counts during Spine review, but it must be mirrored into the active `plan.md` or `spec.md` before proceeding.
**Gate enforcement:** A PreToolUse hook blocks writes to non-`.spine` files when `plan.md` is unapproved. Spec approval is not plan approval — after spec approval, you must stop and invoke `spine-plan`; only after plan approval (`R> APPROVED` in plan.md) may implementation begin.

### Plan detail
Plans have two zones separated by a trust boundary:
- **Above** (reviewer reads): system view → behaviors (per-flow walkthroughs)
  with decisions, properties, and rules colocated at the flow step they govern;
  acceptance matrix at the end as the index view
- **Below** (agent executes): file manifest, implementation steps as unified
  diffs (each with Intent + References + stable anchor), acceptance gate
- Strategy selector: CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
- Reviewer reads top-to-bottom following data flow; stops at trust boundary
- Voice is telegraphed cavemen bullets; rationale folds into <details>
- Properties at write/guard sites carry `never:` negative constraints
- `R>` annotations go in the review zone (above trust boundary)
- See `docs/EXAMPLE-PLAN.md` for the canonical example

# <!-- END PROJECT SPINE -->
