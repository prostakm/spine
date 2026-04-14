# Conventions

## Sterile Zones
<!-- Paths/domains where ANY plan decision is automatically
     🔴 GATE — deep review required regardless of triage.
     Agent stops and asks on ANY ambiguity in these zones.
     Edit this list per project. -->
- {e.g., auth/, payments/, migrations/, PII handling}

## Active
- {convention 1}
- {convention 2}

## Backlog
Features moved to `.spine/features/backlog/` are deferred for later work.

### When to backlog
- Feature is spec'd/planned but not starting now
- Feature was split off from a larger feature
- Blocked by unfinished dependencies

### When to activate
- Ready to work on a backlogged feature
- All `dependencies` in spec.md frontmatter must be active (not in backlog)

### Splitting features
During spec or plan, if a feature is too complex or covers multiple concerns:
1. Propose splitting into smaller, focused features
2. Create spec for each split feature with YAML frontmatter `dependencies` referencing the parent
3. Move split-off features to backlog: `scripts/spine-backlog.sh move <slug>`
4. The parent feature's `dependents` list is auto-updated with backreferences

### Dependency tracking
- `dependencies` (forward ref): slugs this feature depends on — set manually
- `dependents` (back ref): slugs that depend on this feature — auto-managed by `spine-backlog.sh`

## Decisions
- {YYYY-MM-DD}: {decision} — {one-line rationale}
