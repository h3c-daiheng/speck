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

7. **Report**: Output summary to the user:

   ```text
   ## Test Cases Generated

   - **Output**: spec_test/{feature}/test-cases.md
   - **Total cases**: {count}
   - **By priority**: P1: {n}, P2: {n}, P3: {n}
   - **By source**: {breakdown by user story}

   **Next**: Run `speckit.systemtest.generate-test-scripts` to generate executable test scripts.
   ```
