#!/usr/bin/env pwsh
# phase-checkpoint.ps1 — Create a phase report + git commit after each Phase completion.
#
# Usage: phase-checkpoint.ps1 -PhaseNumber <int> -PhaseName <string> -PhaseSummary <string>
#   -PhaseNumber    Numeric phase index (e.g. 1, 2, 3)
#   -PhaseName      Human-readable name (e.g. "setup", "foundational", "user-story-1")
#   -PhaseSummary   One-line summary used in git commit message
#
# Example:
#   ./scripts/powershell/phase-checkpoint.ps1 -PhaseNumber 2 -PhaseName "foundational" -PhaseSummary "Implement core infrastructure and auth framework"
#
# IMPORTANT: This script is called AFTER all code changes have been committed and
# code review has passed. It generates the phase report and commits the report itself.

$ErrorActionPreference = 'Stop'

# --- Dot-source common.ps1 ---
. "$PSScriptRoot/common.ps1"

# --- Parameters ---
param(
    [Parameter(Mandatory = $true)]
    [int]$PhaseNumber,

    [Parameter(Mandatory = $true)]
    [string]$PhaseName,

    [Parameter(Mandatory = $true)]
    [string]$PhaseSummary
)

# --- Validate git availability ---
$hasGit = Test-HasGit

if (-not $hasGit) {
    Write-Warning "[phase-checkpoint] Warning: git not available — skipping commit"
}

# --- Create spec_logs directory ---
$REPO_ROOT = Get-RepoRoot
$featureEnv = Get-FeaturePathsEnv
$FEATURE_DIR = $featureEnv.FEATURE_DIR
$FEATURE_NAME = ''
if (Test-Path -LiteralPath $FEATURE_DIR -PathType Container) {
    $FEATURE_NAME = Split-Path -Leaf $FEATURE_DIR
}

if ($FEATURE_NAME) {
    $LOGS_DIR = Join-Path $REPO_ROOT "spec_logs/$FEATURE_NAME"
} else {
    $LOGS_DIR = Join-Path $REPO_ROOT 'spec_logs'
}
New-Item -ItemType Directory -Force -Path $LOGS_DIR | Out-Null

# --- Gather file change stats for the report (from the most recent commit) ---
$GIT_STATS = ''
if ($hasGit) {
    try {
        $GIT_STATS = git log -1 --stat --format='' 2>$null
    } catch {
        $GIT_STATS = '(无 git 统计信息)'
    }
}

# --- Generate report file ---
$REPORT_FILE = Join-Path $LOGS_DIR "phase-${PhaseNumber}-${PhaseName}.md"

$reportContent = @"
# 阶段 ${PhaseNumber} 报告：${PhaseName}

**日期**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**摘要**: ${PhaseSummary}

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

```
${GIT_STATS}
```

## 代码理解指南

<!-- AI: 用中文引导读者理解本阶段实现的关键概念 -->

- [入口点]: [从哪里开始阅读代码]
- [关键决策]: [为什么选择某种实现方式]
- [注意事项]: [任何令人意外或容易踩坑的地方]

## 下一阶段

- **下一步**: 阶段 $($PhaseNumber + 1) — [名称，来自 tasks.md]
- **前置条件已满足**: [确认本阶段的产出已为下一阶段做好准备]
"@

$reportContent | Out-File -LiteralPath $REPORT_FILE -Encoding UTF8

Write-Host "[phase-checkpoint] Report written to: $REPORT_FILE"

# --- Verify code review was completed ---
$MISSING_REVIEWS = $false
foreach ($round in 1..3) {
    $REVIEW_FILE = Join-Path $LOGS_DIR "phase-${PhaseNumber}-review-round-${round}.md"
    if (-not (Test-Path -LiteralPath $REVIEW_FILE -PathType Leaf)) {
        [Console]::Error.WriteLine("[phase-checkpoint] ERROR: Missing review report: $REVIEW_FILE")
        $MISSING_REVIEWS = $true
    }
}

if ($MISSING_REVIEWS) {
    [Console]::Error.WriteLine('[phase-checkpoint] ERROR: Code review MUST be completed before checkpoint.')
    [Console]::Error.WriteLine('[phase-checkpoint] Run all 3 review rounds and ensure report files exist in spec_logs/.')
    exit 1
}

# --- Verify report content was filled in (no unreplaced placeholders) ---
# The AI must replace all placeholder comments with real content before we proceed.
$placeholderPatterns = @(
    '\[描述'
    '\[本阶段'
    '\[文件路径'
    '\[用途'
    '\[修改内容'
    '\[从哪里'
    '\[为什么'
    '\[任何'
    '\[名称，来自'
    '\[确认'
    '<!-- AI:'
)

$PLACEHOLDER_COUNT = 0
$rawContent = Get-Content -LiteralPath $REPORT_FILE -Raw
foreach ($pat in $placeholderPatterns) {
    $matches = [regex]::Matches($rawContent, $pat)
    $PLACEHOLDER_COUNT += $matches.Count
}

if ($PLACEHOLDER_COUNT -gt 0) {
    Write-Warning "[phase-checkpoint] WARNING: Report still contains $PLACEHOLDER_COUNT unreplaced placeholder(s)."
    Write-Warning "[phase-checkpoint] The report at $REPORT_FILE must be filled with real content before proceeding."
    Write-Warning "[phase-checkpoint] Continuing anyway — please fix this report manually or re-run this script."
}

# --- Git commit (report only) ---
if ($hasGit) {
    # Stage only the spec_logs report files, NOT source code
    git add $LOGS_DIR

    # Only commit if there's something to commit
    $stagedChanges = git diff --cached --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        $COMMIT_MSG = "[Phase ${PhaseNumber}] ${PhaseName}: ${PhaseSummary} (checkpoint report)"
        git commit -m $COMMIT_MSG
        Write-Host "[phase-checkpoint] Committed: $COMMIT_MSG"
    } else {
        Write-Host '[phase-checkpoint] No staged changes to commit'
    }
} else {
    Write-Host '[phase-checkpoint] Git not available — report saved but not committed'
}
