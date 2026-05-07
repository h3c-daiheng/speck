#!/usr/bin/env pwsh
# phase-checkpoint.ps1 — Verify phase completion and commit the phase summary report.
#
# Usage: phase-checkpoint.ps1 -PhaseNumber <int> -PhaseName <string> -PhaseSummary <string>
#   -PhaseNumber    Numeric phase index (e.g. 1, 2, 3)
#   -PhaseName      Human-readable name (e.g. "setup", "foundational", "user-story-1")
#   -PhaseSummary   One-line summary used in git commit message
#
# Example:
#   ./scripts/powershell/phase-checkpoint.ps1 -PhaseNumber 2 -PhaseName "foundational" -PhaseSummary "Implement core infrastructure and auth framework"
#
# IMPORTANT: This script is called AFTER all code changes have been committed,
# code review has passed, and the phase summary has been written to the report file.
# It verifies the summary exists, checks review reports, and commits the summary.

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

# --- Resolve spec_logs directory ---
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

# --- Resolve report file path (must match phase-summary-template.md output path) ---
$REPORT_FILE = Join-Path $LOGS_DIR "phase-${PhaseNumber}-${PhaseName}.md"

# --- Verify phase summary report exists ---
if (-not (Test-Path -LiteralPath $REPORT_FILE -PathType Leaf)) {
    [Console]::Error.WriteLine("[phase-checkpoint] ERROR: Phase summary report not found: $REPORT_FILE")
    [Console]::Error.WriteLine('[phase-checkpoint] The phase summary must be generated before running checkpoint.')
    exit 1
}

# --- Verify code review was completed ---
$MISSING_REVIEWS = $false
foreach ($round in 1..2) {
    $REVIEW_FILE = Join-Path $LOGS_DIR "phase-${PhaseNumber}-review-round-${round}.md"
    if (-not (Test-Path -LiteralPath $REVIEW_FILE -PathType Leaf)) {
        [Console]::Error.WriteLine("[phase-checkpoint] ERROR: Missing review report: $REVIEW_FILE")
        $MISSING_REVIEWS = $true
    }
}

if ($MISSING_REVIEWS) {
    [Console]::Error.WriteLine('[phase-checkpoint] ERROR: Code review MUST be completed before checkpoint.')
    [Console]::Error.WriteLine('[phase-checkpoint] Run all 2 review rounds and ensure report files exist in spec_logs/.')
    exit 1
}

# --- Verify report content was filled in (no unreplaced placeholders) ---
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
    '\[验收标准'
    '\[具体交付物'
    '\[决策内容'
    '\[风险描述'
    '\[入口点'
    '\[关键决策'
    '\[注意事项'
    '\[框架名称'
    '\[工具名称'
    '<!-- ACTION REQUIRED:'
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
        $COMMIT_MSG = "[Phase ${PhaseNumber}] ${PhaseName}: ${PhaseSummary}"
        git commit -m $COMMIT_MSG
        Write-Host "[phase-checkpoint] Committed: $COMMIT_MSG"
    } else {
        Write-Host '[phase-checkpoint] No staged changes to commit'
    }
} else {
    Write-Host '[phase-checkpoint] Git not available — report saved but not committed'
}
