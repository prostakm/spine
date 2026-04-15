---
dependencies: []
dependents: []
---

# Spec: {FEATURE_NAME}

<!-- Keep prose hard-wrapped at 100 chars.
     Bold only the smallest crucial fragment. -->

**Role:** {product-owner | architect}

## Problem
{What's broken or missing - one short paragraph.}

## Requirements
- REQ-1: {testable requirement}
- REQ-2: {testable requirement}

## Boundaries
<!-- NOT: = exclusions. DO NOT: = anti-patterns. -->
- NOT: {explicitly excluded}
- DO NOT: {wrong approach to avoid}

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

## Invariants
<!-- Categories: range | relational | stability | preservation | structural -->
- {category}: {plain English invariant}

## Open Questions
- {unresolved - decide before planning}

## Resume
- Source: spec
- Phase: spec
- Gate: pending
- Current Slice: refine requirements, scope, and invariants
- Next Step: approve the spec or request changes before planning
- Open Questions: {current open question or none}
- Files in Play: `.spine/features/{slug}/spec.md`
