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

3. **Detect test framework** (priority order):
   - **Priority 1**: Read `spec_test/{feature}/references/` code files — if reference scripts exist, use the same framework and follow their patterns
   - **Priority 2**: Scan project root for dependency/config files and infer framework:
     - Read `package.json` (look for jest, vitest, mocha in dependencies/devDependencies)
     - Read `pyproject.toml` / `setup.cfg` / `pytest.ini` (look for pytest, unittest)
     - Read `go.mod` (go test)
     - Read `Cargo.toml` (cargo test)
     - Read `pom.xml` / `build.gradle` (junit)
   - **Priority 3**: Read `specs/{feature}/plan.md` tech stack section and infer the default framework for that language
   - **Priority 4**: Scan project for existing test files (`test_*.py`, `*.test.js`, `*_test.go`, etc.)
   - If framework still cannot be determined: Ask the user to specify a framework or provide reference scripts in `spec_test/{feature}/references/`
   - Record the detected: framework name, run command, file naming pattern

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

8. **Review Phase**: Launch parallel subagents to review the generated test scripts from multiple dimensions, then analyze and fix issues.

   Read the review prompt templates from `extensions/systemtest/prompts/review-test-scripts.md`. Use the Agent tool to dispatch 3 review subagents **in parallel**, constructing each prompt by replacing the placeholders in the templates with actual file paths:

   - **Subagent A — 用例映射与断言充分性**: Verify every TC-XXX has a corresponding test function with adequate assertions.
   - **Subagent B — 框架规范与代码质量**: Verify scripts follow framework conventions and maintain good code quality.
   - **Subagent C — 可运行性与测试隔离性**: Verify scripts can actually run and tests are properly isolated.

   **Main Agent Analysis**: After all subagents complete, analyze the collected review opinions:

   a. **Aggregate scores** — compute average score per dimension; flag any dimension scoring below 7/10.

   b. **Classify each ISSUE** by severity:
      - **CRITICAL** (must fix): Missing test function for a TC-XXX; test function with no assertions; import errors that prevent execution.
      - **MAJOR** (should fix): Weak assertions that don't verify the expected result; framework convention violations; test order dependencies; missing setup/teardown.
      - **MINOR** (report only): Code style issues; minor naming improvements; optimization suggestions.

   c. **Fix**:
      - Fix ALL CRITICAL issues immediately by updating the affected files in `spec_test/{feature}/scripts/`.
      - Fix MAJOR issues unless the subagent's concern is based on a misunderstanding of the project context.
      - Do NOT fix MINOR issues — only report them.

   d. **Report review results** to the user:
      ```text
      ### Review Summary

      | Dimension | Score | Issues |
      |-----------|-------|--------|
      | 用例映射完整性 | X/10 | Critical: N, Major: N |
      | 断言充分性 | X/10 | Critical: N, Major: N |
      | 框架规范 | X/10 | Critical: N, Major: N |
      | 代码质量 | X/10 | Critical: N, Major: N |
      | 可运行性 | X/10 | Critical: N, Major: N |
      | 测试隔离性 | X/10 | Critical: N, Major: N |
      | 错误处理与健壮性 | X/10 | Critical: N, Major: N |

      - **Fixed**: {count} critical/major issues
      - **Remaining**: {count} minor issues (see details above)
      ```

   e. If fixes were applied, summarize what was changed and why.

9. **Report**: Output final summary to the user:

   ```text
   ## Test Scripts Generated

   - **Output dir**: spec_test/{feature}/scripts/
   - **Framework**: {detected framework}
   - **Files created**: {count}
   - **Test cases covered**: {n}/{total from test-cases.md}
   - **Command to run**: {detected command} spec_test/{feature}/scripts/

   **Next**: Run `speckit.systemtest.run-test-scripts` to execute tests and view results.
   ```
