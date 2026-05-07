---
description: Execute a single phase from the implementation plan by auto-detecting the next incomplete phase in tasks.md
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before phase execution)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_phase` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Phase Gate Rules

**These rules apply BEFORE any code is written and MUST be enforced throughout execution.**

1. **Parse phases BEFORE writing code**: After step 6, display the detected phase with its task range and status. This is your execution scope for this invocation.

2. **Mandatory Phase Checkpoint**: After completing ALL tasks in the current phase (all marked [X]), you MUST run the phase checkpoint script BEFORE reporting completion:

   ```sh
   ./scripts/bash/phase-checkpoint.sh <N> "<name>" "<one-line summary>"
   ```

   - `<N>`: Phase number (e.g. 1, 2, 3)
   - `<name>`: Phase name in lowercase-hyphenated form (e.g. "setup", "foundational", "user-story-1")
   - `<one-line summary>`: What this phase accomplished

3. **No skipping checkpoints**: You MUST NOT report completion until:
   - All tasks in the current phase are marked [X] in tasks.md
   - The phase checkpoint script has been executed successfully
   - The `spec_logs/{FEATURE_NAME}/phase-N-<name>.md` report file exists

4. **After the checkpoint script runs**: Fill in the report file with the actual details — what was done, quality measures, code changes, and how to understand the implementation. The script creates a skeleton; you MUST replace placeholder comments with real content.

5. **If you violate this rule**: Stop immediately, run the checkpoint script, then continue.

6. **Mandatory Code Review**: After all tasks in the current phase are marked [X] and BEFORE running the phase checkpoint script, you MUST conduct code review using independent subagents, plus any additional fix-verification rounds needed:

   a. **Commit code before review**: Before launching any review, commit all code changes for this phase with a descriptive commit message. This ensures review agents see a clean diff and protects against data loss if the session is interrupted.

   b. **Resolve feature name for output paths**: Before launching review rounds, determine the feature directory name:
      - The feature directory is `specs/<branch-name>/` — extract the `<branch-name>` portion as `{FEATURE_NAME}`
      - Use the same logic as `phase-checkpoint.sh`: call `get_current_branch` from `scripts/bash/common.sh` or use the `FEATURE_DIR` value from step 1 to derive the basename
      - If FEATURE_NAME cannot be determined, use `.` (no subdirectory)
      - All review report paths and phase summary paths below MUST use the resolved `{FEATURE_NAME}` value

   c. **Launch 2 review rounds sequentially**: For each round M = 1, 2:
      1. Read `.specify/templates/review-prompt-template.md` and extract the content under the `## Template Body` heading. If the file does not exist, ERROR: "Review template not found. Run `specify init` to install missing templates, then retry."
      2. Replace all placeholders in the extracted content:
         - `{FEATURE_NAME}` → the resolved feature directory name from step b
         - `{PHASE_NUM}` → current phase number (e.g. 1, 2, 3)
         - `{PHASE_NAME}` → current phase name (e.g. "setup", "foundational")
         - `{ROUND_NUM}` → M (the current round number)
         - `{COMMITS_COUNT}` → number of commits in this phase (from git log)
         - `{OUTPUT_PATH}` → `spec_logs/{FEATURE_NAME}/phase-{PHASE_NUM}-review-round-{ROUND_NUM}.md`
         - `{FEATURE_DIR}` → the feature directory path (e.g. `specs/{FEATURE_NAME}/`)
      3. Launch one subagent (type: `general-purpose`) with the rendered prompt

      - After each round completes, read the report file at `{OUTPUT_PATH}` (as constructed in step c) and check the Verdict:
        - **If PASS**: Proceed to the next round
        - **If FAIL** (Critical issues found):
          1. Read the "Critical Issues Detail" section
          2. Fix ALL Critical issues in the codebase
          3. Commit the fixes
          4. Launch an **additional review round** using the same template (`.specify/templates/review-prompt-template.md`) with an incremented `{ROUND_NUM}` (does not count toward the required 2 rounds)
          5. Repeat fix cycle until PASS, then proceed to the next round

      - After all 2 required rounds pass (plus any fix-verification rounds), proceed to checkpoint

7. **No skipping reviews**: You MUST NOT run `./scripts/bash/phase-checkpoint.sh` until:
   - All 2 required review rounds have PASS verdicts
   - All review report files exist at `spec_logs/{FEATURE_NAME}/phase-<N>-review-round-{1,2}.md`
   - Any fix-verification rounds also have PASS verdicts
   - Code changes have been committed

## Outline

1. Run `{SCRIPT}` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Check checklists status** (if FEATURE_DIR/checklists/ exists):
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count:
     - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
     - Completed items: Lines matching `- [X]` or `- [x]`
     - Incomplete items: Lines matching `- [ ]`
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
     - Wait for user response before continuing
     - If user says "no" or "wait" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `*.dll`, `autom4te.cache/`, `config.status`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. **Phase Auto-Detection**: Parse tasks.md and identify the target phase:

   a. **Scan phase headings**: Extract all `## Phase N: <name>` section headings from tasks.md.

   b. **Determine completion status**: For each phase, scan its task lines and count:
      - Completed tasks: Lines matching `- [X]` or `- [x]` with a task ID
      - Incomplete tasks: Lines matching `- [ ]` with a task ID

   c. **Select target phase**: Return the first phase that has at least one incomplete task. If all phases have all tasks marked complete, report "All phases in tasks.md are already complete" and exit.

   d. **Display detection result**:

      ```text
      | Phase | Name | Total | Complete | Incomplete | Status |
      |-------|------|-------|----------|------------|--------|
      | Phase 1 | Setup | 3 | 3 | 0 | ✓ DONE |
      | Phase 2 | Foundational | 6 | 2 | 4 | → TARGET |
      | Phase 3 | User Story 1 | 8 | 0 | 8 | PENDING |
      ```

      Target: Phase {N} — {name}

6. **Dependency Validation**: Before executing the target phase, verify prerequisites:

   a. **Phase 1**: No prerequisite check. Proceed to step 7.

   b. **Phase N > 1**: Check that the previous phase's checkpoint report exists:
      - Resolve `{FEATURE_NAME}` from FEATURE_DIR (basename of feature directory)
      - Search for `spec_logs/{FEATURE_NAME}/phase-{N-1}-*.md`
      - If the file does not exist:
        - ERROR: "Phase {N-1} checkpoint report not found. Complete Phase {N-1} first by running the phase command."
        - HALT execution
      - If the file exists: Proceed to step 7

7. **Execute tasks for the target phase**: Run all tasks within the detected phase:

   - **Sequential execution**: Complete tasks in order within the phase
   - **Respect parallel markers**: Tasks marked [P] that affect different files can run together
   - **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Report progress**: After each completed task, mark it as [X] in tasks.md
   - **Implementation execution rules**:
     - **Setup first**: Initialize project structure, dependencies, configuration (if Phase 1)
     - **Tests before code**: Write tests for contracts, entities, and integration scenarios before implementation
     - **Core development**: Implement models, services, CLI commands, endpoints
     - **Integration work**: Database connections, middleware, logging, external services
     - **Polish and validation**: Unit tests, performance optimization, documentation

8. **Code Review**: After all tasks in the current phase are marked [X]:

   a. **Commit code**: Commit all code changes for this phase with a descriptive commit message.

   b. **Launch 2 sequential review rounds**: Follow Phase Gate Rules #6 exactly — read `.specify/templates/review-prompt-template.md`, replace placeholders, launch review subagents.

   c. **Fix Critical issues**: If any round returns FAIL, fix all Critical issues, commit, and re-review until PASS.

9. **Phase Checkpoint**: After all review rounds pass:

   a. **Generate phase summary** (this is the unified report, replaces the old checkpoint report + summary):
      1. Read `.specify/templates/phase-summary-template.md` and extract the content under the `## Template Body` heading. If the file does not exist, ERROR: "Phase summary template not found at `.specify/templates/phase-summary-template.md`. Run `specify init` to install missing templates, then retry."
      2. Replace all placeholders in the extracted content:
         - `{FEATURE_NAME}` → the resolved feature directory name
         - `{PHASE_NUM}` → current phase number (e.g. 1, 2, 3)
         - `{PHASE_NAME}` → current phase name in lowercase-hyphenated form (e.g. "setup", "foundational")
         - `{TASKS_TOTAL}` → total number of tasks in this phase
         - `{TASKS_DONE}` → number of completed tasks in this phase
         - `{PHASE_GOAL}` → the goal and scope extracted from the phase heading in tasks.md
         - `{GIT_STATS}` → output of `git log -1 --stat --format=""`
         - `{NEXT_PHASE_NUM}` → current phase number + 1 (or "无" if last phase)
         - `{NEXT_PHASE_NAME}` → next phase name from tasks.md (or "无" if last phase)
         - `{OUTPUT_PATH}` → `spec_logs/{FEATURE_NAME}/phase-{PHASE_NUM}-{PHASE_NAME}.md`
      3. Write the rendered content to `{OUTPUT_PATH}`
      4. Replace all `<!-- ACTION REQUIRED: ... -->` comments with actual content based on the implementation work done in this phase

   b. **Run checkpoint script** (verifies summary + reviews exist, then commits):
      ```sh
      ./scripts/bash/phase-checkpoint.sh {N} "{phase-name}" "{one-line summary}"
      ```

10. **Completion Report**: Output a summary of the completed phase:

    ```text
    ## Phase {N} Complete

    - **Phase**: {N} — {name}
    - **Tasks**: {completed}/{total} completed
    - **Code Review**: 2 rounds — PASS
    - **Report**: spec_logs/{FEATURE_NAME}/phase-{N}-{name}.md
    - **Status**: ✓ DONE

    **Next**: Run the phase command again to execute Phase {N+1} ({next phase name})
    ```

    - If this was the last phase (no more incomplete phases): Report "All phases complete. Run a full verification pass before finalizing."
    - If more phases remain: Report the next phase name and suggest running the command again.

11. **Check for extension hooks**: After completion report, check if `.specify/extensions.yml` exists in the project root.
    - If it exists, read it and look for entries under the `hooks.after_phase` key
    - If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
    - Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
    - For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
      - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
      - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
    - For each executable hook, output the following based on its `optional` flag:
      - **Optional hook** (`optional: true`):
        ```
        ## Extension Hooks

        **Optional Hook**: {extension}
        Command: `/{command}`
        Description: {description}

        Prompt: {prompt}
        To execute: `/{command}`
        ```
      - **Mandatory hook** (`optional: false`):
        ```
        ## Extension Hooks

        **Automatic Hook**: {extension}
        Executing: `/{command}`
        EXECUTE_COMMAND: {command}
        ```
    - If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

Note: This command executes exactly ONE phase per invocation. To implement all phases, run this command repeatedly until all phases are complete. Each invocation includes full code review, checkpoint, and phase summary.
