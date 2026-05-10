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

# Helper: detect from plan.md tech stack
detect_from_plan() {
    local plan_file="$PROJECT_ROOT/specs/$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')/plan.md"
    if [[ ! -f "$plan_file" ]]; then
        # Try any plan.md under specs/
        plan_file=$(find "$PROJECT_ROOT/specs" -maxdepth 2 -name "plan.md" 2>/dev/null | head -1)
    fi
    if [[ -z "$plan_file" ]] || [[ ! -f "$plan_file" ]]; then
        return 1
    fi

    local content
    content=$(cat "$plan_file" 2>/dev/null || echo "")

    # Python
    if echo "$content" | grep -qiE "python|flask|django|fastapi"; then
        FRAMEWORK="pytest"
        COMMAND="pytest"
        FILE_PATTERN="test_*.py"
        TEST_DIR="tests/"
        return 0
    fi

    # JavaScript/TypeScript
    if echo "$content" | grep -qiE "node\.js|typescript|javascript|react|express|next\.js|nestjs"; then
        FRAMEWORK="jest"
        COMMAND="npx jest"
        FILE_PATTERN="*.test.js"
        TEST_DIR="tests/"
        return 0
    fi

    # Go
    if echo "$content" | grep -qiE "\bgo\b|golang|gin|echo"; then
        FRAMEWORK="go-test"
        COMMAND="go test"
        FILE_PATTERN="*_test.go"
        TEST_DIR=""
        return 0
    fi

    # Rust
    if echo "$content" | grep -qiE "rust|cargo|actix|rocket"; then
        FRAMEWORK="rust-test"
        COMMAND="cargo test"
        FILE_PATTERN="*.rs"
        TEST_DIR="tests/"
        return 0
    fi

    # Java
    if echo "$content" | grep -qiE "java|spring|maven|gradle"; then
        FRAMEWORK="junit"
        COMMAND="mvn test"
        FILE_PATTERN="*Test.java"
        TEST_DIR="src/test/java/"
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
# Priority 4: plan.md tech stack
elif detect_from_plan; then
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
