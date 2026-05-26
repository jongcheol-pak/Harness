# PreCompact hook - PowerShell
# 컨텍스트 compaction 직전에 plan.md를 스냅샷으로 백업.
# compact로 대화 컨텍스트가 압축되어도 진행 상황이 디스크에 보존됨.
#
# 토글: harness-toggle 로 비활성 가능 (backup-on-compact)

$ErrorActionPreference = 'SilentlyContinue'

# ---- 토글 체크 ----
$disableFile = Join-Path $env:USERPROFILE ".claude\.disabled\backup-on-compact"
if (Test-Path -LiteralPath $disableFile) { exit 0 }

# stdin JSON 읽기 (PreCompact 이벤트 정보)
$inputJson = [Console]::In.ReadToEnd()

# 프로젝트 루트에서 plan.md 검색
$planCandidates = @(
    "plan.md",
    "docs\plan.md"
)

$planFile = $null
foreach ($candidate in $planCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $planFile = $candidate
        break
    }
}

# docs/plans/ 디렉터리에서 가장 최근 plan 찾기
if (-not $planFile -and (Test-Path -LiteralPath "docs\plans" -PathType Container)) {
    $latest = Get-ChildItem -LiteralPath "docs\plans" -Filter "*.md" -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { $planFile = $latest.FullName }
}

if (-not $planFile) {
    # plan.md 없음 — 백업할 것 없음
    exit 0
}

# 스냅샷 디렉터리
$snapshotDir = "docs\plans\.snapshots"
if (-not (Test-Path -LiteralPath $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
}

# 타임스탬프 스냅샷
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$snapshotPath = Join-Path $snapshotDir "plan-precompact-$timestamp.md"

try {
    Copy-Item -LiteralPath $planFile -Destination $snapshotPath -Force

    # git 상태도 함께 기록 (있으면)
    $gitDir = & git rev-parse --git-dir 2>$null
    if ($gitDir -and $LASTEXITCODE -eq 0) {
        $gitLog = & git log --oneline -5 2>$null
        $gitStatus = & git status --short 2>$null
        $metaPath = Join-Path $snapshotDir "git-state-$timestamp.txt"
        @(
            "=== PreCompact 시점 git 상태 ===",
            "Timestamp: $timestamp",
            "",
            "Recent commits:",
            $gitLog,
            "",
            "Working tree:",
            $gitStatus
        ) | Out-File -FilePath $metaPath -Encoding utf8
    }

    # Claude에게 알림 (stderr)
    [Console]::Error.WriteLine("[PRE-COMPACT BACKUP] plan.md 스냅샷 저장: $snapshotPath")
    [Console]::Error.WriteLine("컨텍스트 압축 후에도 진행 상황은 plan.md와 이 스냅샷에 보존됩니다.")
    [Console]::Error.WriteLine("압축 후 작업 재개 시 plan.md의 Progress Log와 git log를 확인하세요.")
} catch {
    # 백업 실패해도 compact 자체는 막지 않음
    [Console]::Error.WriteLine("[PRE-COMPACT BACKUP] 스냅샷 저장 실패: $($_.Exception.Message)")
}

exit 0
