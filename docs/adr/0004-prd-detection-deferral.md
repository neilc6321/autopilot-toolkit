# Orchestrator must detect PRDs and defer them to child-issue completion

PRDs (Product Requirement Documents) describe architecture, design decisions, and global constraints. They are reference documents for implementers and reviewers, not directly implementable work units. However, PRDs can carry `ready-for-agent` labels (GitHub) or `Status: ready-for-agent` frontmatter (local markdown), causing the orchestrator to dispatch them to an implementer — which then speculatively implements all child issues in one undifferentiated pass, bypassing per-issue review.

We decided the orchestrator must detect PRDs at dispatch time and skip them. PRDs are resolved only after all their child issues are resolved and the global meta-review passes.

## Detection

Two signals, both required for confidence:

| Signal | GitHub | Local markdown |
|--------|--------|----------------|
| **Explicit marker** | label `prd` | frontmatter `Type: prd` |
| **Content heuristic** | body contains `## Problem Statement` + `## Solution`, does NOT contain `## Acceptance Criteria` or `## What to build` | same |

Both signals must be positive to classify an issue as a PRD. The content heuristic prevents false positives from the label/frontmatter alone.

Detection runs for every issue before dispatch — both explicit targets and scan-mode candidates.

## Behavior on PRD detection

- **Skip dispatch**. Reply: "This is a PRD, not directly implementable. Process its child issues instead."
- **Do not change status/labels**. PRD stays in its current state (typically `ready-for-agent`).
- **Track for later resolution**. Record the PRD in a `pending_prds` list keyed by PRD issue number.

## PRD resolution (Phase 2 post-meta-review)

After Phase 2 meta-review passes:

1. Iterate `pending_prds` — the PRDs whose child issues were processed in this run.
2. For each PRD, find all issues that reference it as `Parent`:
   - GitHub: search issues with body containing the PRD URL or `#N`
   - Local: glob `.scratch/*/issues/*/issue.md` for `Parent:` frontmatter matching the PRD slug
3. If ALL child issues have status `resolved` (label or frontmatter) → mark PRD as `resolved`.
4. If ANY child issue is not `resolved` → leave PRD as-is, note remaining children in a comment.

## Rationale

- PRDs are design artifacts, not work units. Dispatching them directly collapses multiple independent review cycles into one.
- Detection uses both explicit marker and content heuristic to avoid depending on any single convention.
- Resolution at Phase 2 end ties PRD lifecycle to child completion — a PRD is "done" when everything it describes is done and the meta-review confirms consistency.
