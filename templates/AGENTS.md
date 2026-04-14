# <!-- BEGIN PROJECT SPINE -->

## Project Spine

Project Spine is installed as repo-local skills, but it is opt-in: only use it when the user explicitly asks for `$spine-brainstorm`, `$spine-spec`, `$spine-pwf`, or says to use Spine.
When Spine is invoked, load the matching skill under `.agents/skills/` and keep the workflow rules, gates, and planning details there; otherwise work normally.
Explicit chat approval (`approved`, `plan approved`, `spec approved`, `I approve`) counts during Spine review, but it must be mirrored into the active `plan.md` or `spec.md` before proceeding.

# <!-- END PROJECT SPINE -->
