# PreToolUse hook - PowerShell 버전
# Write/Edit 호출 시 plan.md (또는 docs/plans/) 부재면 차단.
# 문서/설정 파일은 항상 허용.
# 우회: $env:CLAUDE_HARNESS_QUICK = '1'
# 토글: harness-toggle 로 비활성 가능
# exit 2 = block.

$ErrorActionPreference = 'SilentlyContinue'

# ---- 토글 체크 (harness-toggle skill로 on/off) ----
$disableFile = Join-Path $env:USERPROFILE ".claude\.disabled\require-plan-for-write"
if (Test-Path -LiteralPath $disableFile) { exit 0 }

# stdin JSON 읽기
$inputJson = [Console]::In.ReadToEnd()

try {
    $data = $inputJson | ConvertFrom-Json
    $targetPath = $data.tool_input.path
    if (-not $targetPath) { $targetPath = $data.tool_input.file_path }
} catch {
    # 파싱 실패 시 통과
    exit 0
}

# 파일 경로가 없으면 통과
if ([string]::IsNullOrWhiteSpace($targetPath)) { exit 0 }

# ---- 항상 허용되는 파일 타입 ----
# 문서, 설정, plan, 이미지·리소스는 plan 없이도 작성 가능
$alwaysAllowedExts = @(
    # 문서
    '.md', '.txt', '.rst',
    # 데이터/설정
    '.json', '.yml', '.yaml', '.toml', '.ini',
    '.editorconfig', '.gitignore', '.gitattributes',
    '.csproj', '.sln', '.props', '.targets',
    '.config',
    # 이미지
    '.svg', '.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.bmp',
    # 리소스
    '.resx', '.resw',
    # 환경설정
    '.env.example', '.env.sample'
)

$ext = [System.IO.Path]::GetExtension($targetPath).ToLower()
if ($alwaysAllowedExts -contains $ext) { exit 0 }

# 파일명 기반 예외 (확장자 없는 trivial 파일)
$baseName = [System.IO.Path]::GetFileName($targetPath)
$trivialFileNames = @('README', 'CHANGELOG', 'LICENSE', 'CONTRIBUTING', 'NOTICE', 'AUTHORS')
foreach ($name in $trivialFileNames) {
    if ($baseName -match "^$name(\..+)?$") { exit 0 }
}

# Android strings.xml, iOS Localizable.strings, .NET resx 같은 리소스 파일명
if ($baseName -match '^(strings\.xml|Localizable\.strings|Info\.plist)$') { exit 0 }

# .git, .vs, node_modules, bin, obj 등 시스템 디렉터리 — 허용
if ($targetPath -match '[\\/](\.git|\.vs|node_modules|bin|obj|dist|build)[\\/]') { exit 0 }

# Android 리소스 디렉터리 (res/values, res/drawable 등)
if ($targetPath -match '[\\/]res[\\/](values|drawable|mipmap|layout|raw|xml|color|font|menu|anim)') { exit 0 }

# 명시적으로 plan/docs 경로는 항상 허용
if ($targetPath -match '[\\/]docs[\\/]' -or
    $targetPath -match '[\\/]plans?[\\/]' -or
    $targetPath -match '[\\/]\.claude[\\/]') {
    exit 0
}

# ---- 작은 변경 통과 (Trivial Edit) ----
# Edit/MultiEdit의 변경 규모가 작으면 코드 파일이라도 plan 없이 허용.
# 문구 수정, 라벨 변경, 색상/값 1-2개 변경 등 1분이면 끝나는 작업.
# 시그니처/구조 변경의 cross-file 영향은 PostToolUse impact-warn hook이 별도 검출.
if ($data.tool_name -eq 'Edit' -or $data.tool_name -eq 'MultiEdit') {
    $oldStr = $data.tool_input.old_string
    $newStr = $data.tool_input.new_string

    # MultiEdit은 edits 배열 — 전체 합산
    if ($data.tool_name -eq 'MultiEdit' -and $data.tool_input.edits) {
        $oldStr = ($data.tool_input.edits | ForEach-Object { $_.old_string }) -join "`n"
        $newStr = ($data.tool_input.edits | ForEach-Object { $_.new_string }) -join "`n"
    }

    if ($null -ne $oldStr -and $null -ne $newStr) {
        $oldLines = ($oldStr -split "`n").Count
        $newLines = ($newStr -split "`n").Count
        $maxLines = [Math]::Max($oldLines, $newLines)
        $maxLen = [Math]::Max($oldStr.Length, $newStr.Length)

        # 새 정의(함수/클래스/메서드) 추가 패턴 — 이건 trivial 아님
        $definesNewSymbol = $newStr -match '(?m)\b(class|interface|struct|enum|record)\s+\w' -or
                            $newStr -match '(?m)\b(public|private|protected|internal|static)\s+[\w<>\[\],\s]+\s+\w+\s*\(' -or
                            $newStr -match '(?m)\b(def|func|fun|function)\s+\w+\s*\('

        # 작은 변경 (3줄 이내 + 300자 이내) + 새 심볼 정의 아님 → trivial 통과
        if ($maxLines -le 3 -and $maxLen -le 300 -and -not $definesNewSymbol) {
            [Console]::Error.WriteLine("[HARNESS] Trivial edit (<=3줄, 새 정의 없음): plan 검사 우회. 영향은 impact-warn hook이 검증합니다.")
            exit 0
        }
    }
}

# ---- 우회 환경변수 ----
if ($env:CLAUDE_HARNESS_QUICK -eq '1') {
    [Console]::Error.WriteLine("[HARNESS] QUICK 모드: plan 검사 우회")
    exit 0
}

# ---- plan 존재 확인 ----
$planExists = (Test-Path -LiteralPath 'plan.md' -PathType Leaf) -or `
              (Test-Path -LiteralPath 'docs/plans' -PathType Container)

if ($planExists) { exit 0 }

# ---- 차단 ----
[Console]::Error.WriteLine("[HARNESS] BLOCKED: 코드 변경 전에 plan이 필요합니다.")
[Console]::Error.WriteLine("")
[Console]::Error.WriteLine("대상 파일: $targetPath")
[Console]::Error.WriteLine("plan.md 또는 docs/plans/ 디렉터리가 없습니다.")
[Console]::Error.WriteLine("")
[Console]::Error.WriteLine("해결 방법:")
[Console]::Error.WriteLine("  1) plan-feature skill 호출:")
[Console]::Error.WriteLine("     사용자에게 '계획 작성해줘' 라고 요청하거나 /plan-feature <설명>")
[Console]::Error.WriteLine("")
[Console]::Error.WriteLine("  2) 긴급 1줄 수정 우회 (Claude Code 시작 전 PowerShell에서):")
[Console]::Error.WriteLine("     `$env:CLAUDE_HARNESS_QUICK = '1'")
[Console]::Error.WriteLine("")
[Console]::Error.WriteLine("  3) 다른 plan 경로를 쓰는 프로젝트:")
[Console]::Error.WriteLine("     docs/plans/ 디렉터리를 만들거나 prefer plan.md 사용")

exit 2
