---
dependencies: []
dependents: []
---

# Spec: {FEATURE_NAME}

**Role:** {product-owner | architect}

## Problem
{What's broken or missing — one paragraph.}

## Requirements
- REQ-1: {testable requirement}
- REQ-2: {testable requirement}

## Out of Scope
- {explicitly excluded}

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
