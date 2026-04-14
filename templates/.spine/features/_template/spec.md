---
dependencies: []
dependents: []
---

# Spec: {FEATURE_NAME}

**Role:** {product-owner | architect}

## Resume
- Source: spec
- Phase: spec
- Gate: pending
- Current Slice: refine requirements, scope, and invariants
- Next Step: approve the spec or request changes before planning
- Open Questions: {current open question or none}
- Files in Play: `.spine/features/{slug}/spec.md`

## Problem
{What's broken or missing — one paragraph.}

## Requirements
- REQ-1: {testable requirement}
- REQ-2: {testable requirement}

## Boundaries
<!-- NOT: = exclusions (someone else's problem).
     DO NOT: = anti-patterns (wrong approach, don't try it).
     Each DO NOT eliminates an entire solution space. -->
- NOT: {explicitly excluded}
- DO NOT: {anti-pattern — eliminates a wrong approach}

## Inputs & Outputs
- In: {what}
- Out: {what}

## Constraints
- {from .spine/project.md or feature-specific}

## Change type
- Type: {new-logic | refactor | new-endpoint | bugfix | performance | infrastructure}

## Acceptance Criteria
- [ ] {testable criterion}
- [ ] {testable criterion}
<!-- Include 1-2 trivially verifiable canaries:
     concrete values, exact strings, specific status codes.
     These calibrate trust in the rest of the implementation. -->

## Invariants
<!-- Properties that must ALWAYS hold. Carried into plan's proof sketch.
     Categories:
       range        — bounded output (e.g., "tax is never negative")
       relational   — A implies B (e.g., "increasing hours never decreases net pay")
       stability    — idempotent/deterministic (e.g., "same input always produces same output")
       preservation — before equals after (e.g., "refactor doesn't change API response shape")
       structural   — architecture rule (e.g., "no handler imports storage directly")
-->
- {category}: {plain English invariant}

## Open Questions
- {unresolved — decide before planning}
