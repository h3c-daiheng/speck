# System Test Extension 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 speckit 新增 systemtest 扩展，提供 3 个手动命令完成系统测试全流程：生成测试用例 → 生成测试脚本 → 执行测试脚本。

**Architecture:** 标准 speckit extension 结构，extension.yml 定义 3 个命令，每个命令是一个 .md 模板文件，遵循现有 extension 的 frontmatter 和 body 模式。命令模板通过 `$ARGUMENTS` 接收用户输入，通过 `check-prerequisites.sh --json` 解析 FEATURE_DIR，读取 specs/{feature}/ 和 spec_test/{feature}/ 下的文件完成任务。

**Tech Stack:** Markdown 命令模板、Bash 脚本（框架检测）、YAML 配置

---

## File Structure

```
extensions/systemtest/
├── extension.yml                         # 扩展清单
├── commands/
│   ├── generate-test-cases.md            # 命令1：生成测试用例
│   ├── generate-test-scripts.md          # 命令2：生成测试脚本
│   └── run-test-scripts.md              # 命令3：执行测试脚本
├── scripts/
│   └── bash/
│       └── detect-test-framework.sh      # 框架自动检测
├── config-template.yml                   # 配置模板
└── README.md                             # 扩展文档
```

---

### Task 1: 创建 extension.yml 清单文件

**Files:**
- Create: `extensions/systemtest/extension.yml`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p extensions/systemtest/commands
mkdir -p extensions/systemtest/scripts/bash
```

- [ ] **Step 2: 创建 extension.yml**

参考 `extensions/git/extension.yml` 和 `extensions/selftest/extension.yml` 的格式：

```yaml
schema_version: "1.0"

extension:
  id: systemtest
  name: "System Test"
  version: "1.0.0"
  description: "系统测试扩展：生成测试用例、测试脚本，执行并报告结果"
  author: spec-kit-core
  repository: https://github.com/github/spec-kit
  license: MIT

requires:
  speckit_version: ">=0.2.0"

provides:
  commands:
    - name: speckit.systemtest.generate-test-cases
      file: commands/generate-test-cases.md
      description: "基于设计文档生成系统测试用例"

    - name: speckit.systemtest.generate-test-scripts
      file: commands/generate-test-scripts.md
      description: "基于测试用例生成可执行的测试脚本"

    - name: speckit.systemtest.run-test-scripts
      file: commands/run-test-scripts.md
      description: "执行测试脚本并输出详细的过程和结果报告"

  config:
    - name: "systemtest-config.yml"
      template: "config-template.yml"
      description: "系统测试配置"
      required: false

tags:
  - "testing"
  - "system-test"
  - "e2e"

defaults:
  test_framework: auto
  timeout: 300
```

- [ ] **Step 3: 验证 YAML 格式**

```bash
python3 -c "import yaml; yaml.safe_load(open('extensions/systemtest/extension.yml')); print('YAML valid')"
```

Expected: `YAML valid`

- [ ] **Step 4: Commit**

```bash
git add extensions/systemtest/extension.yml
git commit -m "feat(systemtest): add extension manifest"
```

---

### Task 2: 创建 config-template.yml 配置模板

**Files:**
- Create: `extensions/systemtest/config-template.yml`

- [ ] **Step 1: 创建配置模板**

参考 `extensions/template/config-template.yml` 的风格：

```yaml
# System Test Extension Configuration
# Copy to systemtest-config.yml and customize for your project

# Test framework settings
test_framework: auto  # auto | pytest | jest | go-test | unittest | vitest | mocha
# auto = detect from project (references/ → existing tests → plan.md tech stack)

# Test execution timeout in seconds
timeout: 300

# Test report settings
reports:
  # Output directory (relative to spec_test/{feature}/)
  directory: "reports"

  # Report filename pattern
  filename_pattern: "report-{timestamp}"

# Test case generation settings
generation:
  # Include boundary value tests
  include_boundary: true

  # Include error handling tests
  include_error_handling: true

  # Include concurrency tests
  include_concurrency: false

  # Default test case priority levels to generate
  priorities:
    - P1  # Critical path
    - P2  # Important scenarios
    - P3  # Edge cases
```

- [ ] **Step 2: Commit**

```bash
git add extensions/systemtest/config-template.yml
git commit -m "feat(systemtest): add configuration template"
```

---

### Task 3: 创建 detect-test-framework.sh 脚本

**Files:**
- Create: `extensions/systemtest/scripts/bash/detect-test-framework.sh`

- [ ] **Step 1: 创建框架检测脚本**

```bash
#!/usr/bin/env bash
# detect-test-framework.sh — Detect the test framework used by the project.
#
# Usage: detect-test-framework.sh [--json] [--project-root <path>]
#   --json              Output results as JSON
#   --project-root      Path to project root (default: auto-detect)
#
# Detection order:
#   1. User-provided reference scripts in spec_test/{feature}/references/
#   2. Existing test files and dependency manifests in the project
#   3. Tech stack from plan.md
#
# Output (JSON mode):
#   {"framework":"pytest","command":"pytest","file_pattern":"test_*.py","dir":"tests/"}

set -euo pipefail

JSON_MODE=false
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Auto-detect project root
if [[ -z "$PROJECT_ROOT" ]]; then
    SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

# --- Framework detection ---
FRAMEWORK="unknown"
COMMAND=""
FILE_PATTERN=""
TEST_DIR=""

# Helper: detect from dependency files
detect_from_deps() {
    # Python: pytest
    if [[ -f "$PROJECT_ROOT/pytest.ini" ]] || [[ -f "$PROJECT_ROOT/pyproject.toml" ]] || [[ -f "$PROJECT_ROOT/setup.cfg" ]]; then
        if grep -q "pytest" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null || \
           grep -q "pytest" "$PROJECT_ROOT/setup.cfg" 2>/dev/null || \
           [[ -f "$PROJECT_ROOT/pytest.ini" ]]; then
            FRAMEWORK="pytest"
            COMMAND="pytest"
            FILE_PATTERN="test_*.py"
            TEST_DIR="tests/"
            return 0
        fi
    fi

    # Python: unittest
    if [[ -f "$PROJECT_ROOT/setup.py" ]] && grep -q "unittest" "$PROJECT_ROOT/setup.py" 2>/dev/null; then
        FRAMEWORK="unittest"
        COMMAND="python -m unittest"
        FILE_PATTERN="test_*.py"
        TEST_DIR="tests/"
        return 0
    fi

    # JavaScript/TypeScript: check package.json
    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        local deps
        deps=$(cat "$PROJECT_ROOT/package.json" 2>/dev/null || echo "{}")

        if echo "$deps" | grep -q '"jest"'; then
            FRAMEWORK="jest"
            COMMAND="npx jest"
            FILE_PATTERN="*.test.js"
            TEST_DIR="tests/"
            return 0
        fi

        if echo "$deps" | grep -q '"vitest"'; then
            FRAMEWORK="vitest"
            COMMAND="npx vitest run"
            FILE_PATTERN="*.test.js"
            TEST_DIR="tests/"
            return 0
        fi

        if echo "$deps" | grep -q '"mocha"'; then
            FRAMEWORK="mocha"
            COMMAND="npx mocha"
            FILE_PATTERN="*.test.js"
            TEST_DIR="tests/"
            return 0
        fi
    fi

    # Go
    if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
        FRAMEWORK="go-test"
        COMMAND="go test"
        FILE_PATTERN="*_test.go"
        TEST_DIR=""
        return 0
    fi

    # Rust
    if [[ -f "$PROJECT_ROOT/Cargo.toml" ]]; then
        FRAMEWORK="rust-test"
        COMMAND="cargo test"
        FILE_PATTERN="*.rs"
        TEST_DIR="tests/"
        return 0
    fi

    # Java
    if [[ -f "$PROJECT_ROOT/pom.xml" ]]; then
        FRAMEWORK="junit"
        COMMAND="mvn test"
        FILE_PATTERN="*Test.java"
        TEST_DIR="src/test/java/"
        return 0
    fi

    return 1
}

# Helper: detect from existing test files
detect_from_files() {
    # Look for existing test files as clues
    if find "$PROJECT_ROOT" -maxdepth 3 -name "test_*.py" -not -path "*/spec_test/*" 2>/dev/null | head -1 | grep -q .; then
        FRAMEWORK="pytest"
        COMMAND="pytest"
        FILE_PATTERN="test_*.py"
        TEST_DIR="tests/"
        return 0
    fi

    if find "$PROJECT_ROOT" -maxdepth 3 -name "*.test.js" -not -path "*/spec_test/*" 2>/dev/null | head -1 | grep -q .; then
        FRAMEWORK="jest"
        COMMAND="npx jest"
        FILE_PATTERN="*.test.js"
        TEST_DIR="tests/"
        return 0
    fi

    if find "$PROJECT_ROOT" -maxdepth 3 -name "*_test.go" -not -path "*/spec_test/*" 2>/dev/null | head -1 | grep -q .; then
        FRAMEWORK="go-test"
        COMMAND="go test"
        FILE_PATTERN="*_test.go"
        TEST_DIR=""
        return 0
    fi

    return 1
}

# Helper: detect from reference scripts
detect_from_references() {
    local ref_dir="$1"
    if [[ ! -d "$ref_dir" ]]; then
        return 1
    fi

    # Check for Python test files
    if find "$ref_dir" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
        FRAMEWORK="pytest"
        COMMAND="pytest"
        FILE_PATTERN="test_*.py"
        TEST_DIR="tests/"
        return 0
    fi

    # Check for JS test files
    if find "$ref_dir" -name "*.test.js" -o -name "*.spec.js" 2>/dev/null | head -1 | grep -q .; then
        FRAMEWORK="jest"
        COMMAND="npx jest"
        FILE_PATTERN="*.test.js"
        TEST_DIR="tests/"
        return 0
    fi

    # Check for Go test files
    if find "$ref_dir" -name "*_test.go" 2>/dev/null | head -1 | grep -q .; then
        FRAMEWORK="go-test"
        COMMAND="go test"
        FILE_PATTERN="*_test.go"
        TEST_DIR=""
        return 0
    fi

    return 1
}

# --- Main detection logic ---
# Priority 1: Reference scripts (if path provided via env)
REF_DIR="${SPEC_TEST_REFERENCES_DIR:-}"
if [[ -n "$REF_DIR" ]] && detect_from_references "$REF_DIR"; then
    : # found
# Priority 2: Dependency manifests
elif detect_from_deps; then
    : # found
# Priority 3: Existing test files
elif detect_from_files; then
    : # found
else
    FRAMEWORK="unknown"
    COMMAND=""
    FILE_PATTERN=""
    TEST_DIR=""
fi

# --- Output ---
if [[ "$JSON_MODE" == "true" ]]; then
    echo "{\"framework\":\"${FRAMEWORK}\",\"command\":\"${COMMAND}\",\"file_pattern\":\"${FILE_PATTERN}\",\"test_dir\":\"${TEST_DIR}\"}"
else
    echo "Framework: $FRAMEWORK"
    echo "Command: $COMMAND"
    echo "File pattern: $FILE_PATTERN"
    echo "Test dir: $TEST_DIR"
fi
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x extensions/systemtest/scripts/bash/detect-test-framework.sh
```

- [ ] **Step 3: 验证脚本可运行**

```bash
./extensions/systemtest/scripts/bash/detect-test-framework.sh --json
```

Expected: JSON 输出包含 framework 字段（具体值取决于当前项目）

- [ ] **Step 4: Commit**

```bash
git add extensions/systemtest/scripts/bash/detect-test-framework.sh
git commit -m "feat(systemtest): add test framework detection script"
```

---

### Task 4: 创建 generate-test-cases.md 命令模板

**Files:**
- Create: `extensions/systemtest/commands/generate-test-cases.md`

- [ ] **Step 1: 创建命令模板**

参考 `templates/commands/phase.md` 和 `extensions/git/commands/speckit.git.feature.md` 的结构模式：

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add extensions/systemtest/commands/generate-test-cases.md
git commit -m "feat(systemtest): add generate-test-cases command template"
```

---

### Task 5: 创建 generate-test-scripts.md 命令模板

**Files:**
- Create: `extensions/systemtest/commands/generate-test-scripts.md`

- [ ] **Step 1: 创建命令模板**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add extensions/systemtest/commands/generate-test-scripts.md
git commit -m "feat(systemtest): add generate-test-scripts command template"
```

---

### Task 6: 创建 run-test-scripts.md 命令模板

**Files:**
- Create: `extensions/systemtest/commands/run-test-scripts.md`

- [ ] **Step 1: 创建命令模板**

```markdown
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
   - Run `extensions/systemtest/scripts/bash/detect-test-framework.sh --json --project-root {repo_root}`
   - Parse framework and command from JSON output
   - If framework is "unknown": ERROR: "Cannot detect test framework. Specify in config or provide reference scripts."

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
```

- [ ] **Step 2: Commit**

```bash
git add extensions/systemtest/commands/run-test-scripts.md
git commit -m "feat(systemtest): add run-test-scripts command template"
```

---

### Task 7: 创建 README.md

**Files:**
- Create: `extensions/systemtest/README.md`

- [ ] **Step 1: 创建扩展文档**

```markdown
# System Test Extension

系统测试扩展：基于功能设计文档自动生成系统测试用例和可执行脚本，并执行测试输出详细报告。

## 命令

| 命令 | 说明 |
|------|------|
| `speckit.systemtest.generate-test-cases` | 基于 specs/{feature}/ 设计文档生成测试用例 |
| `speckit.systemtest.generate-test-scripts` | 基于测试用例生成可执行测试代码 |
| `speckit.systemtest.run-test-scripts` | 执行测试脚本并输出详细报告 |

## 工作流

```text
specs/{feature}/          spec_test/{feature}/
设计文档                    用户上下文 + 参考材料
      │                          │
      └──────────┬───────────────┘
                 ▼
     generate-test-cases
                 │
                 ▼
         test-cases.md
                 │
                 ▼
    generate-test-scripts
                 │
                 ▼
        scripts/ (测试代码)
                 │
                 ▼
      run-test-scripts
                 │
                 ▼
     reports/report-*.md
```

## 用户注入

在 `spec_test/{feature}/` 下提供上下文和参考材料：

- `context.md` — 测试倾向说明（如"重点关注错误处理"）
- `references/*.md` — 历史测试用例文档（影响用例风格）
- `references/*.py/*.js/...` — 参考测试脚本（影响框架选择和代码风格）

## 配置

在 `.specify/extensions/systemtest/systemtest-config.yml` 中配置：

```yaml
test_framework: auto  # auto | pytest | jest | go-test | vitest | mocha
timeout: 300
```

## 框架检测

当 `test_framework: auto` 时，按以下优先级检测：

1. `spec_test/{feature}/references/` 中的参考脚本
2. 项目已有的测试文件和依赖配置
3. plan.md 中的技术栈信息

## 安装

```bash
specify extension add systemtest
```
```

- [ ] **Step 2: Commit**

```bash
git add extensions/systemtest/README.md
git commit -m "feat(systemtest): add extension README"
```

---

### Task 8: 验证 extension 完整性

**Files:**
- Verify all created files

- [ ] **Step 1: 验证文件结构完整**

```bash
find extensions/systemtest -type f | sort
```

Expected:
```
extensions/systemtest/README.md
extensions/systemtest/commands/generate-test-cases.md
extensions/systemtest/commands/generate-test-scripts.md
extensions/systemtest/commands/run-test-scripts.md
extensions/systemtest/config-template.yml
extensions/systemtest/extension.yml
extensions/systemtest/scripts/bash/detect-test-framework.sh
```

- [ ] **Step 2: 验证 extension.yml 中的所有命令文件都存在**

```bash
grep "file:" extensions/systemtest/extension.yml | sed 's/.*file: //' | tr -d '"' | while read f; do
  path="extensions/systemtest/$f"
  if [ -f "$path" ]; then echo "OK: $path"; else echo "MISSING: $path"; fi
done
```

Expected: all OK

- [ ] **Step 3: 验证所有命令模板有正确的 frontmatter**

```bash
for f in extensions/systemtest/commands/*.md; do
  if head -1 "$f" | grep -q "^---"; then
    echo "OK: $f has frontmatter"
  else
    echo "ERROR: $f missing frontmatter"
  fi
done
```

Expected: all OK

- [ ] **Step 4: 验证检测脚本可执行**

```bash
./extensions/systemtest/scripts/bash/detect-test-framework.sh --json
```

Expected: valid JSON output

- [ ] **Step 5: Final commit (if any fixes)**

```bash
git add -A extensions/systemtest/
git commit -m "feat(systemtest): complete systemtest extension v1.0.0"
```
```

---

## Self-Review Checklist

**1. Spec coverage:**

| Spec 要求 | 对应 Task |
|-----------|----------|
| Extension ID/Name/Version | Task 1 |
| 3 个命令定义 | Task 1 (yml) + Task 4/5/6 (.md) |
| config-template.yml | Task 2 |
| detect-test-framework.sh | Task 3 |
| spec_test/{feature}/ 产出目录 | Task 4/5/6 (命令模板中定义) |
| context.md 用户注入 | Task 4 (步骤 4) |
| references/ 参考材料 | Task 4/5 (步骤 4/4) |
| 用例格式 (TC-XXX) | Task 4 (步骤 5) |
| 框架检测优先级 | Task 3 (脚本) + Task 5 (步骤 3) |
| TC-XXX 追溯 | Task 5 (步骤 6) |
| 报告必须包含过程和结果 | Task 6 (步骤 6) |
| 不绑定 hook | Task 1 (extension.yml 无 hooks) |
| README | Task 7 |

**2. Placeholder scan:** 无 TBD/TODO。所有步骤含具体代码和命令。

**3. Type consistency:** 命令名称在 extension.yml 和各 .md 文件中保持一致。
