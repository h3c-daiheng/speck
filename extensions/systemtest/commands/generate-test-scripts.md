---
description: "基于测试用例文档生成可执行的测试脚本代码"
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
   - Verify `spec_test/{feature}/test-cases.md` exists
   - If not found: ERROR: "Test cases not found. Run `speckit.systemtest.generate-test-cases` first."
   - Create `spec_test/{feature}/scripts/` directory if it does not exist

3. **Detect test framework**:
   - Set `SPEC_TEST_REFERENCES_DIR` to `spec_test/{feature}/references/` (if exists)
   - Run `extensions/systemtest/scripts/bash/detect-test-framework.sh --json --project-root {repo_root}`
   - Parse JSON output to get: framework, command, file_pattern, test_dir
   - If framework is "unknown": Ask the user to specify a framework or provide reference scripts in `spec_test/{feature}/references/`

4. **Load inputs**:
   - Read `spec_test/{feature}/test-cases.md` — the test case document
   - Read `spec_test/{feature}/references/` code files (if any) — extract test patterns, helper functions, fixtures, style
   - Read `specs/{feature}/plan.md` — for project structure and import paths

5. **Generate test scripts**:
   - Create one test file per logical group (by endpoint, by feature, or by user story — follow project conventions)
   - Each test function MUST reference its TC-XXX ID in a comment or docstring
   - Follow the detected framework's conventions:
     - **pytest**: `test_*.py`, `assert` statements, `@pytest.fixture`
     - **jest/vitest**: `*.test.js`, `expect()` matchers, `describe/it` blocks
     - **go-test**: `*_test.go`, `t.Error/T.Fatal` assertions
     - **unittest**: `test_*.py`, `self.assert*` methods
   - If reference scripts exist, reuse their helper functions, fixtures, and patterns
   - Include setup/teardown logic based on preconditions from test cases

6. **Test case traceability**: Each test function must include:
   - Comment or decorator linking to TC-XXX (e.g., `# TC-001: User registration success`)
   - Clear test name that maps to the test case title

7. **Write output**: Save generated scripts to `spec_test/{feature}/scripts/`

8. **Report**: Output summary to the user:

   ```text
   ## Test Scripts Generated

   - **Output dir**: spec_test/{feature}/scripts/
   - **Framework**: {detected framework}
   - **Files created**: {count}
   - **Test cases covered**: {n}/{total from test-cases.md}
   - **Command to run**: {detected command} spec_test/{feature}/scripts/

   **Next**: Run `speckit.systemtest.run-test-scripts` to execute tests and view results.
   ```
