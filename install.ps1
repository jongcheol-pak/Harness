# install.ps1
# pjc Claude Code Harness Plugin - 자동 설치 스크립트
#
# 사용법:
#   .\install.ps1
#   .\install.ps1 -Scope project    # 프로젝트별 설치 (.claude/settings.json)
#   .\install.ps1 -Uninstall        # 제거
#
# Claude Code REPL이 실행 중이면 종료 후 다시 시작해야 변경이 반영됩니다.

param(
    [ValidateSet('user', 'project')]
    [string]$Scope = 'user',

    [switch]$Uninstall,

    [switch]$SkipVerification
)

$ErrorActionPreference = 'Stop'

# 색상 헬퍼
function Write-Section($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok($t)      { Write-Host "  [OK] $t" -ForegroundColor Green }
function Write-Warn($t)    { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Write-Err($t)     { Write-Host "  [X]  $t" -ForegroundColor Red }
function Write-Info($t)    { Write-Host "  $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "pjc Claude Code Harness - Plugin Installer" -ForegroundColor Cyan
Write-Host ""

# ---- 1. claude CLI 확인 ----
Write-Section "Prerequisite Check"

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Err "claude CLI를 찾을 수 없습니다."
    Write-Info "Claude Code 설치 후 다시 실행하세요:"
    Write-Info "  npm install -g @anthropic-ai/claude-code"
    exit 1
}
Write-Ok "claude CLI 발견: $($claudeCmd.Source)"

# 버전 확인 (v2.0 이상 필요)
try {
    $versionOutput = & claude --version 2>&1 | Out-String
    Write-Info "Version: $($versionOutput.Trim())"
} catch {
    Write-Warn "버전 확인 실패. v2.0 이상이 필요합니다."
}

# ---- 2. marketplace 경로 확인 ----
$marketplacePath = $PSScriptRoot
$marketplaceManifest = Join-Path $marketplacePath ".claude-plugin\marketplace.json"

if (-not (Test-Path -LiteralPath $marketplaceManifest)) {
    Write-Err "marketplace.json을 찾을 수 없습니다: $marketplaceManifest"
    Write-Info "이 스크립트는 압축 해제된 패키지 root에서 실행되어야 합니다."
    exit 1
}
Write-Ok "Marketplace 경로: $marketplacePath"

# ---- 3. 제거 모드 ----
if ($Uninstall) {
    Write-Section "Uninstalling pjc Plugin"

    try {
        & claude plugin uninstall pjc 2>&1 | ForEach-Object { Write-Info $_ }
        Write-Ok "Plugin uninstalled"
    } catch {
        Write-Warn "Plugin 제거 실패 (이미 제거됨일 수 있음)"
    }

    try {
        & claude plugin marketplace remove pjc-harness 2>&1 | ForEach-Object { Write-Info $_ }
        Write-Ok "Marketplace removed"
    } catch {
        Write-Warn "Marketplace 제거 실패 (이미 제거됨일 수 있음)"
    }

    Write-Host ""
    Write-Host "Uninstall complete." -ForegroundColor Green
    Write-Host ""
    Write-Info "토글 상태 파일은 남아있습니다. 완전 제거하려면:"
    Write-Info "  Remove-Item -Recurse `"`$env:USERPROFILE\.claude\.disabled`""
    Write-Host ""
    return
}

# ---- 4. Claude Code 실행 중인지 확인 (참고용) ----
$claudeProc = Get-Process -Name claude -ErrorAction SilentlyContinue
if ($claudeProc) {
    Write-Section "Notice"
    Write-Warn "Claude Code REPL이 현재 실행 중입니다."
    Write-Info "설치 후 변경 사항을 반영하려면 종료 후 다시 시작하세요."
}

# ---- 5. Marketplace 추가 ----
Write-Section "Adding Marketplace"

try {
    $addOutput = & claude plugin marketplace add $marketplacePath 2>&1 | Out-String
    Write-Info $addOutput.Trim()
    Write-Ok "Marketplace 'pjc-harness' added"
} catch {
    # 이미 추가된 경우일 수 있음
    if ($_.Exception.Message -match "already") {
        Write-Warn "Marketplace 이미 추가되어 있음 (계속 진행)"
    } else {
        Write-Err "Marketplace 추가 실패: $($_.Exception.Message)"
        exit 1
    }
}

# ---- 6. Plugin 설치 ----
Write-Section "Installing Plugin"

try {
    $installOutput = & claude plugin install pjc@pjc-harness --scope $Scope 2>&1 | Out-String
    Write-Info $installOutput.Trim()
    Write-Ok "Plugin 'pjc' installed (scope: $Scope)"
} catch {
    if ($_.Exception.Message -match "already") {
        Write-Warn "Plugin 이미 설치되어 있음. 업데이트를 원하면:"
        Write-Info "  claude plugin update pjc"
    } else {
        Write-Err "Plugin 설치 실패: $($_.Exception.Message)"
        exit 1
    }
}

# ---- 7. 검증 ----
if (-not $SkipVerification) {
    Write-Section "Verification"

    try {
        $listOutput = & claude plugin list 2>&1 | Out-String
        if ($listOutput -match "pjc") {
            Write-Ok "pjc plugin 등록 확인"
        } else {
            Write-Warn "Plugin list에서 pjc를 찾지 못했습니다."
            Write-Info "수동 확인: claude plugin list"
        }
    } catch {
        Write-Warn "검증 실패 (수동 확인 권장): claude plugin list"
    }
}

# ---- 8. 실행 정책 안내 ----
Write-Section "PowerShell Execution Policy"

$policy = Get-ExecutionPolicy -Scope CurrentUser
Write-Info "Current user policy: $policy"

if ($policy -in @('Restricted', 'AllSigned')) {
    Write-Warn "Hook 스크립트가 차단될 수 있습니다."
    Write-Info "권장: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
    Write-Info "(hooks.json은 이미 -ExecutionPolicy Bypass를 포함하므로 그대로 두어도 동작)"
} else {
    Write-Ok "Execution policy 호환: $policy"
}

# ---- 9. AGENTS.md 안내 ----
Write-Section "Next Steps"

$templatePath = Join-Path $marketplacePath "AGENTS.md.template"
if (Test-Path $templatePath) {
    Write-Host "  각 프로젝트의 루트에 AGENTS.md를 배치하세요:" -ForegroundColor White
    Write-Host ""
    Write-Host "    cd C:\Repos\<your-project>" -ForegroundColor Yellow
    Write-Host "    Copy-Item `"$templatePath`" .\AGENTS.md" -ForegroundColor Yellow
    Write-Host "    notepad .\AGENTS.md   # 플레이스홀더 채우기" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "  Claude Code 사용:" -ForegroundColor White
Write-Host ""
Write-Host "    claude                          # 시작" -ForegroundColor Yellow
Write-Host "    /plugin list                    # pjc 확인" -ForegroundColor Yellow
Write-Host "    /                               # /pjc: 시작 명령들 자동완성" -ForegroundColor Yellow
Write-Host ""
Write-Host "  주요 명령:" -ForegroundColor White
Write-Host "    /pjc:plan-feature <설명>" -ForegroundColor Yellow
Write-Host "    /pjc:implement-task <T번호>" -ForegroundColor Yellow
Write-Host "    /pjc:systematic-debugging <증상>" -ForegroundColor Yellow
Write-Host "    /pjc:harness-toggle <hook> <on|off|toggle|status>" -ForegroundColor Yellow
Write-Host ""

Write-Host "Installation complete." -ForegroundColor Green
Write-Host ""

if ($claudeProc) {
    Write-Warn "실행 중이던 Claude Code를 재시작하세요."
    Write-Host ""
}
