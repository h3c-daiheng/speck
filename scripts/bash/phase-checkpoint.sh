#!/usr/bin/env bash
# phase-checkpoint.sh — Create a phase report + git commit after each Phase completion.
#
# Usage: phase-checkpoint.sh <phase-number> "<phase-name>" "<summary>"
#   <phase-number>  Numeric phase index (e.g. 1, 2, 3)
#   <phase-name>     Human-readable name (e.g. "setup", "foundational", "user-story-1")
#   <summary>        One-line summary used in git commit message
#
# Example:
#   ./scripts/bash/phase-checkpoint.sh 2 "foundational" "Implement core infrastructure and auth framework"
#
# IMPORTANT: This script is called AFTER all code changes have been committed and
# code review has passed. It generates the phase report and commits the report itself.

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

# --- Create spec_logs directory ---
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

# --- Generate report file ---
REPORT_FILE="$LOGS_DIR/phase-${PHASE_NUM}-${PHASE_NAME}.md"

# Gather file change stats for the report (from the most recent commit)
GIT_STATS=""
if has_git; then
    GIT_STATS=$(git log -1 --stat --format="" 2>/dev/null || echo "(无 git 统计信息)")
fi

cat > "$REPORT_FILE" <<REPORT_EOF
# 阶段 ${PHASE_NUM} 报告：${PHASE_NAME}

**日期**: $(date '+%Y-%m-%d %H:%M:%S')
**摘要**: ${PHASE_SUMMARY}

## 本阶段完成的工作

<!-- AI: 用中文总结本阶段已完成的任务和成果 -->

- [描述本阶段实现的功能]
- [列出创建或修改的关键文件]
- [记录与计划的偏差（如有）]

## 质量保证

<!-- AI: 描述本阶段的工作是如何被验证的 -->

- **任务完成度**: [本阶段 N/M 项任务]
- **测试执行**: [描述编写/运行的测试及结果]
- **手动验证**: [执行的手动检查]
- **已知问题**: [遗留的未解决问题]

## 代码变更

<!-- AI: 用中文总结创建/修改的文件及其用途 -->

### 新增文件

- [文件路径] — [用途说明]

### 修改文件

- [文件路径] — [修改内容及原因]

### Git Diff 摘要

\`\`\`
${GIT_STATS}
\`\`\`

## 代码理解指南

<!-- AI: 用中文引导读者理解本阶段实现的关键概念 -->

- [入口点]: [从哪里开始阅读代码]
- [关键决策]: [为什么选择某种实现方式]
- [注意事项]: [任何令人意外或容易踩坑的地方]

## 下一阶段

- **下一步**: 阶段 $((PHASE_NUM + 1)) — [名称，来自 tasks.md]
- **前置条件已满足**: [确认本阶段的产出已为下一阶段做好准备]
REPORT_EOF

echo "[phase-checkpoint] Report written to: $REPORT_FILE"

# --- Verify code review was completed ---
ROUND=1
MISSING_REVIEWS=0
while [ $ROUND -le 3 ]; do
    REVIEW_FILE="$LOGS_DIR/phase-${PHASE_NUM}-review-round-${ROUND}.md"
    if [ ! -f "$REVIEW_FILE" ]; then
        echo "[phase-checkpoint] ERROR: Missing review report: $REVIEW_FILE" >&2
        MISSING_REVIEWS=1
    fi
    ROUND=$((ROUND + 1))
done

if [ "$MISSING_REVIEWS" = "1" ]; then
    echo "[phase-checkpoint] ERROR: Code review MUST be completed before checkpoint." >&2
    echo "[phase-checkpoint] Run all 3 review rounds and ensure report files exist in spec_logs/." >&2
    exit 1
fi

# --- Verify report content was filled in (no unreplaced placeholders) ---
# The AI must replace all placeholder comments with real content before we proceed.
PLACEHOLDER_COUNT=$(grep -c -E '\[描述|\[本阶段|\[文件路径|\[用途|\[修改内容|\[从哪里|\[为什么|\[任何|\[名称，来自|\[确认|<!-- AI:' "$REPORT_FILE" 2>/dev/null || true)
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
        COMMIT_MSG="[Phase ${PHASE_NUM}] ${PHASE_NAME}: ${PHASE_SUMMARY} (checkpoint report)"
        git commit -m "$COMMIT_MSG"
        echo "[phase-checkpoint] Committed: $COMMIT_MSG"
    else
        echo "[phase-checkpoint] No staged changes to commit"
    fi
else
    echo "[phase-checkpoint] Git not available — report saved but not committed"
fi
