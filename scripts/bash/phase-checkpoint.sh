#!/usr/bin/env bash
# phase-checkpoint.sh — Verify phase completion and commit the phase summary report.
#
# Usage: phase-checkpoint.sh <phase-number> "<phase-name>" "<summary>"
#   <phase-number>  Numeric phase index (e.g. 1, 2, 3)
#   <phase-name>     Human-readable name (e.g. "setup", "foundational", "user-story-1")
#   <summary>        One-line summary used in git commit message
#
# Example:
#   ./scripts/bash/phase-checkpoint.sh 2 "foundational" "Implement core infrastructure and auth framework"
#
# IMPORTANT: This script is called AFTER all code changes have been committed,
# code review has passed, and the phase summary has been written to the report file.
# It verifies the summary exists, checks review reports, and commits the summary.

set -euo pipefail

# --- Arguments ---
PHASE_NUM="${1:?Phase number required}"
PHASE_NAME="${2:?Phase name required}"
PHASE_SUMMARY="${3:?Phase summary required}"

# --- Locate repo root ---
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
REPO_ROOT="$(get_repo_root)"

# --- Validate git availability ---
if ! has_git; then
    echo "[phase-checkpoint] Warning: git not available — skipping commit" >&2
fi

# --- Resolve spec_logs directory ---
FEATURE_DIR="$(cd "$REPO_ROOT" && readlink -f "$(dirname "${BASH_SOURCE[0]}")/../../../specs/$(get_current_branch)")"
FEATURE_NAME=""
if [[ -d "$FEATURE_DIR" ]]; then
    FEATURE_NAME="$(basename "$FEATURE_DIR")"
fi

if [[ -n "$FEATURE_NAME" ]]; then
    LOGS_DIR="$REPO_ROOT/spec_logs/$FEATURE_NAME"
else
    LOGS_DIR="$REPO_ROOT/spec_logs"
fi
mkdir -p "$LOGS_DIR"

# --- Resolve report file path (must match phase-summary-template.md output path) ---
REPORT_FILE="$LOGS_DIR/phase-${PHASE_NUM}-${PHASE_NAME}.md"

# --- Verify phase summary report exists ---
if [ ! -f "$REPORT_FILE" ]; then
    echo "[phase-checkpoint] ERROR: Phase summary report not found: $REPORT_FILE" >&2
    echo "[phase-checkpoint] The phase summary must be generated before running checkpoint." >&2
    exit 1
fi

# --- Verify code review was completed ---
ROUND=1
MISSING_REVIEWS=0
while [ $ROUND -le 2 ]; do
    REVIEW_FILE="$LOGS_DIR/phase-${PHASE_NUM}-review-round-${ROUND}.md"
    if [ ! -f "$REVIEW_FILE" ]; then
        echo "[phase-checkpoint] ERROR: Missing review report: $REVIEW_FILE" >&2
        MISSING_REVIEWS=1
    fi
    ROUND=$((ROUND + 1))
done

if [ "$MISSING_REVIEWS" = "1" ]; then
    echo "[phase-checkpoint] ERROR: Code review MUST be completed before checkpoint." >&2
    echo "[phase-checkpoint] Run all 2 review rounds and ensure report files exist in spec_logs/." >&2
    exit 1
fi

# --- Verify report content was filled in (no unreplaced placeholders) ---
PLACEHOLDER_COUNT=$(grep -c -E '\[描述|\[本阶段|\[文件路径|\[用途|\[修改内容|\[从哪里|\[为什么|\[任何|\[名称，来自|\[确认|\[验收标准|\[具体交付物|\[决策内容|\[风险描述|\[入口点|\[关键决策|\[注意事项|\[框架名称|\[工具名称|<!-- ACTION REQUIRED:|<!-- AI:' "$REPORT_FILE" 2>/dev/null || true)
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
    echo "[phase-checkpoint] WARNING: Report still contains $PLACEHOLDER_COUNT unreplaced placeholder(s)." >&2
    echo "[phase-checkpoint] The report at $REPORT_FILE must be filled with real content before proceeding." >&2
    echo "[phase-checkpoint] Continuing anyway — please fix this report manually or re-run this script." >&2
fi

# --- Git commit (report only) ---
if has_git; then
    # Stage only the spec_logs report files, NOT source code
    git add "$LOGS_DIR/"

    # Only commit if there's something to commit
    if ! git diff --cached --quiet 2>/dev/null; then
        COMMIT_MSG="[Phase ${PHASE_NUM}] ${PHASE_NAME}: ${PHASE_SUMMARY}"
        git commit -m "$COMMIT_MSG"
        echo "[phase-checkpoint] Committed: $COMMIT_MSG"
    else
        echo "[phase-checkpoint] No staged changes to commit"
    fi
else
    echo "[phase-checkpoint] Git not available — report saved but not committed"
fi
