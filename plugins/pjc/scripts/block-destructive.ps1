# PreToolUse hook - PowerShell 버전
# Bash 도구 호출 시 파괴적 명령 차단.
# exit 2 = block (Claude에게 차단 사유 전달).

$ErrorActionPreference = 'Stop'

# stdin으로 JSON 입력 수신
$inputJson = [Console]::In.ReadToEnd()

# JSON 파싱
try {
    $data = $inputJson | ConvertFrom-Json
    $cmd = $data.tool_input.command
} catch {
    # 파싱 실패 시 통과 (차단 실패가 더 위험)
    exit 0
}

if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

# 차단 패턴 (POSIX + Windows 둘 다 대응)
$patterns = @(
    'rm\s+-rf\s+/(\s|$)',                               # rm -rf /
    'rm\s+-rf\s+~',                                     # rm -rf ~
    'rm\s+-rf\s+\$HOME',                                # rm -rf $HOME
    'rm\s+-rf\s+\*(\s|$)',                              # rm -rf *
    'git\s+push\s+.*(--force|--force-with-lease)',      # git push --force
    'git\s+push\s+-f(\s|$)',                            # git push -f
    'git\s+filter-branch',                              # 히스토리 재작성
    'git\s+filter-repo',
    'git\s+reflog\s+expire',
    '(^|\s)sudo(\s|$)',                                 # sudo
    'DROP\s+TABLE',                                     # SQL
    'DROP\s+DATABASE',
    'TRUNCATE\s+TABLE',
    'mkfs\.',                                           # 포맷
    'dd\s+if=.*of=/dev/',                               # dd to device
    # Windows 특화 위험 명령
    'Remove-Item.*-Recurse.*-Force\s+[A-Z]:\\',         # PowerShell 드라이브 루트 강제 삭제
    'Remove-Item.*-Recurse.*-Force\s+\$env:',           # 환경 변수 경로 강제 삭제
    'rmdir\s+/s\s+/q\s+[A-Z]:\\',                       # cmd 드라이브 루트 강제 삭제
    'Format-Volume',                                    # 볼륨 포맷
    'Clear-RecycleBin\s+.*-Force'                       # 휴지통 강제 비우기
)

# &&, ||, ;, |로 분리 (PowerShell의 ;도 포함)
$subs = $cmd -split '[;|&]'

foreach ($sub in $subs) {
    $sub = $sub.Trim()
    if ([string]::IsNullOrWhiteSpace($sub)) { continue }

    foreach ($pattern in $patterns) {
        if ($sub -match $pattern) {
            [Console]::Error.WriteLine("BLOCKED: 파괴적 명령 패턴 감지: '$pattern'")
            [Console]::Error.WriteLine("Command: $sub")
            [Console]::Error.WriteLine("필요하다면 사용자에게 명시적 확인을 받은 뒤 직접 실행하도록 보고하세요.")
            exit 2
        }
    }
}

exit 0
