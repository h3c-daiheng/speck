---
description: "执行测试脚本并输出详细的测试过程和结果报告"
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
   - Verify `spec_test/{feature}/scripts/` exists and contains test files
   - If not found: ERROR: "Test scripts not found. Run `speckit.systemtest.generate-test-scripts` first."
   - Create `spec_test/{feature}/reports/` directory if it does not exist

3. **Detect test framework**:
   - Read the test files in `spec_test/{feature}/scripts/` to determine which framework they use (check imports, syntax, file extensions)
   - Cross-reference with project dependency files (`package.json`, `pyproject.toml`, `go.mod`, etc.) to confirm the correct run command
   - If framework cannot be determined: Ask the user to specify the test run command

4. **Read timeout config** (if available):
   - Check `.specify/extensions/systemtest/systemtest-config.yml` for `timeout` value
   - Default: 300 seconds

5. **Execute tests**:
   - Run the detected test command targeting `spec_test/{feature}/scripts/`
   - Capture both stdout and stderr completely
   - Record start time and end time
   - Handle timeout if execution exceeds configured limit
   - Common commands:
     - pytest: `pytest spec_test/{feature}/scripts/ -v --tb=long 2>&1`
     - jest: `npx jest spec_test/{feature}/scripts/ --verbose 2>&1`
     - go test: `go test ./spec_test/{feature}/scripts/ -v 2>&1`
     - vitest: `npx vitest run spec_test/{feature}/scripts/ --reporter=verbose 2>&1`

6. **Generate report**: Write detailed test report to `spec_test/{feature}/reports/report-{timestamp}.md`

   The report MUST contain ALL of the following sections:

   ```markdown
   # System Test Report — {feature}

   Generated: {ISO timestamp}
   Test framework: {framework}
   Execution command: {actual command run}

   ---

   ## Execution Summary

   | Metric | Value |
   |--------|-------|
   | Total cases | {n} |
   | Passed | {n} |
   | Failed | {n} |
   | Skipped | {n} |
   | Errors | {n} |
   | Duration | {seconds}s |
   | **Verdict** | **PASS/FAIL** |

   ## Test Process

   ### Execution Command
   ```text
   {exact command that was run}
   ```

   ### Standard Output
   ```text
   {complete stdout output}
   ```

   ### Standard Error
   ```text
   {complete stderr output}
   ```

   ## Per-Case Results

   | Case ID | Description | Status | Duration |
   |---------|-------------|--------|----------|
   | TC-001 | {title} | PASS | {time} |
   | TC-002 | {title} | FAIL | {time} |
   | ... | ... | ... | ... |

   ## Failure Details

   ### TC-{NNN}: {title}
   ```text
   {full error traceback / assertion message}
   ```
   {repeat for each failure}

   ---

   Verdict: **{PASS/FAIL}**
   ```

7. **Output summary to user**:

   ```text
   ## Test Execution Complete

   - **Report**: spec_test/{feature}/reports/report-{timestamp}.md
   - **Result**: {PASS/FAIL}
   - **Cases**: {passed}/{total} passed
   - **Duration**: {time}

   {If FAIL}: Review failure details in the report and fix issues before re-running.
   ```
