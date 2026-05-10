---
description: "基于设计文档生成系统测试用例，输出到 spec_test/{feature}/test-cases.md"
scripts:
  sh: scripts/bash/check-prerequisites.sh --json
  ps: scripts/powershell/check-prerequisites.ps1 -Json
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `{SCRIPT}` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute.

2. **Resolve spec_test directory**:
   - Extract feature name from FEATURE_DIR (basename of the feature directory)
   - Create `spec_test/{feature}/` directory if it does not exist
   - This is the output directory for all system test artifacts

3. **Load design documents** from FEATURE_DIR:
   - **Required**: spec.md (user stories, acceptance criteria)
   - **Required**: plan.md (tech stack, architecture, file structure)
   - **If exists**: data-model.md (entities, relationships, constraints)
   - **If exists**: contracts/ (API specifications, request/response schemas)
   - **If exists**: quickstart.md (validation scenarios)
   - **If exists**: research.md (technical decisions, constraints)

4. **Load user context** (if exists):
   - Read `spec_test/{feature}/context.md` — user's test preferences and focus areas
   - Scan `spec_test/{feature}/references/*.md` — historical test case documents for style reference
   - If neither exists, proceed with default test case generation strategy

5. **Generate test cases** covering:
   - **Normal flow**: Happy path scenarios for each user story
   - **Boundary conditions**: Edge cases from data-model constraints (min/max values, empty strings, null fields)
   - **Error handling**: Invalid inputs, unauthorized access, missing resources
   - **Data constraints**: Unique constraints, format validation, referential integrity
   - **Integration scenarios**: Cross-component interactions from contracts/

   Each test case MUST follow this format:

   ```text
   ## TC-{NNN}: {title}
   - **Priority**: P1/P2/P3
   - **Source**: {US1/US2/etc.} ({source file})
   - **Preconditions**: {what must be set up}
   - **Steps**:
     1. {action with specific inputs}
     2. {verification point}
     3. ...
   - **Expected Result**: {clear pass/fail criteria}
   ```

6. **Write output**: Save generated test cases to `spec_test/{feature}/test-cases.md`

   The file header MUST be:

   ```markdown
   # System Test Cases — {feature}

   Generated: {ISO timestamp}
   Source: specs/{feature}/
   Total cases: {count}

   ---
   ```

7. **Review Phase**: Launch parallel subagents to review the generated test cases from multiple dimensions, then analyze and fix issues.

   Read the review prompt templates from `extensions/systemtest/prompts/review-test-cases.md`. Use the Agent tool to dispatch 3 review subagents **in parallel**, constructing each prompt by replacing the placeholders in the templates with actual file paths:

   - **Subagent A — 需求覆盖率与可测试性**: Verify every user story and acceptance criterion has test cases, and each TC has concrete, actionable steps.
   - **Subagent B — 边界异常与数据约束**: Verify boundary values, error handling scenarios, and data model constraints are adequately covered.
   - **Subagent C — 优先级与预期结果**: Verify priority assignments are reasonable, expected results provide unambiguous pass/fail criteria, and preconditions are complete.

   **Main Agent Analysis**: After all subagents complete, analyze the collected review opinions:

   a. **Aggregate scores** — compute average score per dimension; flag any dimension scoring below 7/10.

   b. **Classify each ISSUE** by severity:
      - **CRITICAL** (must fix): Missing test cases for a user story or acceptance criterion; test case steps that cannot be executed.
      - **MAJOR** (should fix): Ambiguous expected result; missing boundary or error handling tests for documented constraints; untestable steps.
      - **MINOR** (report only): Priority misassignment; minor precondition gap; style suggestions.

   c. **Fix**:
      - Fix ALL CRITICAL issues immediately by updating `spec_test/{feature}/test-cases.md`.
      - Fix MAJOR issues unless the subagent's concern is based on a misunderstanding of the design intent.
      - Do NOT fix MINOR issues — only report them.

   d. **Report review results** to the user:
      ```text
      ### Review Summary

      | Dimension | Score | Issues |
      |-----------|-------|--------|
      | 需求覆盖率 | X/10 | Critical: N, Major: N |
      | 可测试性 | X/10 | Critical: N, Major: N |
      | 边界值覆盖 | X/10 | Critical: N, Major: N |
      | 异常处理覆盖 | X/10 | Critical: N, Major: N |
      | 数据约束覆盖 | X/10 | Critical: N, Major: N |
      | 优先级合理性 | X/10 | Critical: N, Major: N |
      | 预期结果明确性 | X/10 | Critical: N, Major: N |
      | 前置条件完备性 | X/10 | Critical: N, Major: N |

      - **Fixed**: {count} critical/major issues
      - **Remaining**: {count} minor issues (see details above)
      ```

   e. If fixes were applied, summarize what was changed and why.

8. **Report**: Output final summary to the user:

   ```text
   ## Test Cases Generated

   - **Output**: spec_test/{feature}/test-cases.md
   - **Total cases**: {count}
   - **By priority**: P1: {n}, P2: {n}, P3: {n}
   - **By source**: {breakdown by user story}

   **Next**: Run `speckit.systemtest.generate-test-scripts` to generate executable test scripts.
   ```
