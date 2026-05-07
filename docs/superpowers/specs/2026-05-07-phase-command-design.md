# Design: phase.md Command Template

**Date**: 2026-05-07
**Status**: Approved
**Author**: claudecode

## Overview

Create `templates/commands/phase.md` — a single-phase execution command that runs exactly one Phase from `tasks.md` per invocation. Derived from `implement.md` with phase-scoped execution and additional hook support.

## Motivation

`implement.md` executes all phases sequentially in one session, which causes:

- Context window pressure on long implementations
- No pause point between phases for human review
- Cannot re-run a single failed phase in isolation

`phase.md` solves this by executing one phase at a time, returning control to the user after each phase completes (including code review, checkpoint, and summary).

## Key Differences from implement.md

| Dimension | implement.md | phase.md |
|-----------|-------------|----------|
| Scope | All phases sequentially | Single auto-detected phase |
| Phase detection | Parse all phases for roadmap table | Scan for first incomplete phase |
| Dependency check | None (runs in order) | Verify previous phase checkpoint exists |
| Extension hooks | before/after_implement | before/after_phase |
| Post-completion | Continue to next phase | Report + suggest next invocation |

## New Logic

### Phase Auto-Detection

1. Parse all `## Phase N: <name>` headings from tasks.md
2. For each phase, count `[X]` (complete) vs `[ ]` (incomplete) tasks
3. Return first phase with incomplete tasks
4. If all complete, report "All phases complete"

### Dependency Validation

- Phase 1: No prerequisite check
- Phase N > 1: Verify `spec_logs/{FEATURE}/phase-(N-1)-*.md` checkpoint report exists
- Missing: ERROR with instructions to complete previous phase first

### Extension Hooks

- `hooks.before_phase` — fires before phase execution
- `hooks.after_phase` — fires after phase completion (post-checkpoint + summary)

## Preserved from implement.md

- Checklists status scanning (step 2)
- Project setup / ignore file verification (step 4)
- Phase Gate Rules: 2-round code review + fix cycles (step 6)
- `phase-checkpoint.sh` invocation and report filling
- Phase Summary in Chinese at `spec_logs/{FEATURE}/summary/{phase}_summary.md`
- `review-prompt-template.md` usage with placeholder substitution
- Task marking `[X]` in tasks.md

## Output

After completion, reports:
- Phase number and name
- Task completion count
- Code review result (PASS/FAIL)
- Checkpoint and summary file paths
- Suggestion to run next phase

## File Location

`templates/commands/phase.md`
