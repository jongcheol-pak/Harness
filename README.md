# pjc — Claude Code Harness Plugin (Windows / PowerShell)

종철님의 Claude Code 워크플로 plugin. 모든 skill·subagent·hook이
**`pjc:` namespace로 자동 prefix**되어 다른 plugin과 구분됩니다.

## 목차

- [개요](#개요)
- [사전 요구사항](#사전-요구사항)
- [설치](#설치-3단계)
- [확인](#확인)
- [Skill 상세](#skill-상세) — 6개
- [Subagent 상세](#subagent-상세) — 6개
- [Hook 동작 상세](#hook-동작-상세) — 4개
- [Permissions](#permissions)
- [첫 사용 Walkthrough](#첫-사용-walkthrough)
- [Plugin 구조](#plugin-구조)
- [업데이트 / 제거](#업데이트--제거)
- [트러블슈팅](#트러블슈팅)
- [Standalone 버전과의 차이](#standalone-버전과의-차이)

---

## 개요

`pjc`는 종철님의 Windows + PowerShell 환경에서 Claude Code의 작업 흐름을 강제·검증하는 plugin입니다.

### 아키텍처 패턴

이 plugin은 다음 두 가지 명시적 패턴 조합으로 동작합니다:

| 패턴 | 적용 |
|---|---|
| **Pipeline** | `plan-feature` → `implement-task` → Phase F → 최종 보고 (순차 처리) |
| **Producer-Reviewer** | `implement-task` (producer) → 5개 subagent (적대적 reviewer: plan-reviewer, spec-prefilter, spec-compliance, code-quality, plan-completion) |

다른 가능한 패턴 (Fan-out/Fan-in, Expert Pool, Supervisor, Hierarchical Delegation)은 종철님의 단일 사용자·sequential 작업 워크플로에 부적합하다고 판단되어 도입하지 않았습니다.

### 핵심 컴포넌트

| 컴포넌트 | 호출 형태 | 역할 |
|---|---|---|
| `pjc:plan-feature` | 자동 / `/pjc:plan-feature <설명>` | 계획 단계 — 모든 코드 변경 전 |
| `pjc:implement-task` | 자동 / `/pjc:implement-task <T번호>` | 구현 단계 (자율 루프) |
| `pjc:systematic-debugging` | 자동 / `/pjc:systematic-debugging <증상>` | 4-phase 근본 원인 디버깅 |
| `pjc:add-viewmodel` | `/pjc:add-viewmodel <화면명>` | WinUI 3 MVVM 보일러플레이트 (**Android 미지원**) |
| `pjc:add-domain-service` | `/pjc:add-domain-service <서비스명>` | DDD 서비스 추가 |
| `pjc:harness-toggle` | `/pjc:harness-toggle <hook> <action>` | hook 런타임 on/off |
| **6개 subagent** | 자동 호출 / `@<name>` | 적대적 검토, prefilter, 2단계 리뷰, 탐색, plan 완료 검증 |
| **5개 hook** | 자동 | 안전·검증·강제·영향 경고 |

### 설계 철학

| 영역 | 원칙 |
|---|---|
| 계획 | 팩트 기반, 근본 해결, 전수 확인, 결정 사전화, 적대적 자기 검증 |
| 구현 | 자율 루프, 2단계 리뷰 의무, Done = Proof, checkpoint 복구 |
| 코드 | DDD, YAGNI, Rule of Three, 한글 주석, 1500라인, UTF-8 |
| 안전 | permissions 3계층 + hooks 결정적 차단 |
| 디버깅 | Iron Law — 근본 원인 전에 수정 금지 |

---

## 사전 요구사항

- Windows 10/11
- Claude Code v2.0 이상 (plugin marketplace 지원)
- PowerShell 5.1+ (기본 탑재) 또는 7.x
- Git for Windows

---

## 설치

자동 스크립트(권장)와 수동 단계 두 방법을 제공합니다.

### 자동 설치 (권장 — 2단계)

```powershell
# 1. zip 풀기
Expand-Archive claude-harness-pjc.zip -DestinationPath C:\Tools\

# 2. 자동 설치 스크립트 실행
C:\Tools\claude-harness-pjc\install.ps1
```

`install.ps1`이 자동 수행:
- `claude` CLI 가용성 검증
- `claude plugin marketplace add <path>` 호출
- `claude plugin install pjc@pjc-harness --scope user` 호출
- 설치 확인 (`claude plugin list`)
- PowerShell 실행 정책 안내
- 다음 단계 안내 출력

#### 추가 옵션

```powershell
# 프로젝트별 설치 (현재 디렉터리의 .claude/settings.json에 추가)
.\install.ps1 -Scope project

# 제거
.\install.ps1 -Uninstall

# 검증 단계 생략 (빠른 설치)
.\install.ps1 -SkipVerification
```

> ⚠️ Claude Code REPL이 실행 중이면 설치 후 종료 후 다시 시작해야 변경이 반영됩니다.

### 수동 설치 (대안)

자동 스크립트가 동작하지 않거나 단계를 직접 확인하고 싶을 때:

```powershell
# 1. 압축 해제
Expand-Archive claude-harness-pjc.zip -DestinationPath C:\Tools\claude-harness-pjc

# 2-A. CLI에서 (비대화식)
claude plugin marketplace add C:\Tools\claude-harness-pjc
claude plugin install pjc@pjc-harness

# 2-B. 또는 Claude Code REPL에서
claude
# 안에서:
/plugin marketplace add C:\Tools\claude-harness-pjc
/plugin install pjc@pjc-harness
```

### 3. 각 프로젝트에 AGENTS.md 배치

```powershell
cd C:\Repos\<your-project>
Copy-Item C:\Tools\claude-harness-pjc\AGENTS.md.template .\AGENTS.md
notepad .\AGENTS.md   # <...> 플레이스홀더 채우기
```

---

## 확인

```
# Claude Code 안에서
/plugin list                   # pjc가 enabled로 표시되어야 함

# 사용 가능 명령
/                              # 자동완성에 pjc: 시작 명령들 표시
/pjc:plan-feature              # 직접 호출 테스트
```

### 정밀 검증 (선택)

설치 후 plugin이 정상 등록되었는지 자세히 확인하려면:

```powershell
# 패키지 디렉터리에서
C:\Tools\claude-harness-pjc\validate.ps1
```

검증 항목:
- plugin 디렉터리 구조 (cache + marketplace)
- JSON 파일 파싱 (plugin.json, hooks.json, settings.json, marketplace.json)
- skill 6개, agent 6개, hook 5개 모두 등록
- 모든 `.ps1` 파일의 UTF-8 BOM
- 토글 디렉터리 상태 (현재 비활성 hook 표시)

결과: PASS / FAIL / WARN 개수 표시. FAIL 시 재설치 권장.

---

## Skill 상세

각 skill은 `plugins/pjc/skills/<name>/SKILL.md` 에 정의되어 있으며,
Claude Code가 description의 키워드에 따라 자동으로 호출합니다.

---

### 1. `pjc:plan-feature` — 계획 단계

| 항목 | 내용 |
|---|---|
| **목적** | 코드 작성 전에 작업을 분해하고, 영향 범위를 전수 조사하고, 모든 결정 분기를 사전 해결 |
| **트리거 키워드** | "계획", "설계", "어떻게 구현", "feature 추가", "리팩토링", "수정", "추가", "변경", "구현", "plan", "design", "fix", "edit" |
| **호출 시점** | 모든 다단계 코드 변경 전 (자동 트리거) |
| **호출 subagent** | `explorer` (대규모 탐색), `plan-reviewer` (적대적 검토, 이슈 0까지 반복) |
| **산출물** | `plan.md` 또는 `docs/plans/<날짜>-<slug>.md` |

#### 워크플로 (10단계)

```
1. 컨텍스트 수집      → AGENTS.md, 관련 모듈 파악
2. 범위 명확화         → 모호하면 사용자에게 질문
3. 위험 식별           → 외부 의존, 동시성, 회귀, 미지영역
4. 영향 범위 전수 조사 → 심볼/호출그래프/테스트/외부계약 4축
5. 작업 분해           → 1–4시간 단위, acceptance 1줄
6. Decision Points 발굴 → 구현 중 물어야 할 분기를 미리 해결
7. plan.md 작성        → 정해진 템플릿
8. plan-reviewer 게이트 → BLOCKER/MAJOR 이슈 0까지 반복 (최대 3회)
9. Open Questions 해결  → 사용자에게 일괄 질문
10. 사용자 승인        → ExitPlanMode
```

#### 사용 예시

```
사용자: "사용자 설정 화면 추가해줘"
   ↓
[pjc:plan-feature 자동 트리거]
[AGENTS.md 읽기 → explorer subagent 코드베이스 탐색 → 위험 식별]
[Decision Points 발굴]:
  D1. 화면 종류: Page vs ContentDialog?
  D2. 설정 영속화: IConfiguration vs ApplicationData?
  D3. 즉시 적용 vs 재시작 필요?

Claude: "다음을 확인해 주세요:
        1. 화면 종류는 Page와 ContentDialog 중 어느 쪽?
        2. 설정 변경이 즉시 반영되어야 하나요?
        3. 영속화 위치는 ApplicationData.LocalSettings?"

사용자: "Page, 즉시 반영, ApplicationData OK"
   ↓
[plan.md 생성 → plan-reviewer 적대적 검토 → 이슈 0]
   ↓
Claude: "계획 작성 완료: plan.md. 승인하시면 진행합니다."
```

#### 통과 체크리스트 (구현 단계로 넘어가기 위한 조건)

- [ ] plan.md에 "아마도/보통" 0회
- [ ] Impact Analysis 4개 항목 모두 ✓
- [ ] plan-reviewer 이슈 0
- [ ] 각 task에 검증 가능한 acceptance
- [ ] Open Questions 모두 해결
- [ ] 코드 작성 중 사용자에게 물을 결정 분기 0

---

### 2. `pjc:implement-task` — 구현 단계

| 항목 | 내용 |
|---|---|
| **목적** | 승인된 plan.md의 **모든** 작업을 PIV 루프로 자율 실행. 빌드·테스트·2단계 리뷰 통과 후에만 완료 |
| **트리거 키워드** | "구현", "implement", "T<N> 진행", "이 작업 실행", "이대로 진행", "go", "진행해" |
| **호출 시점** | plan-feature 승인 후 자동, 또는 명시 호출 |
| **호출 subagent** | `spec-compliance-reviewer`, `code-quality-reviewer` (의무) |
| **산출물** | git 커밋 (task별 checkpoint + 완료 commit) |

#### 🚨 자율 루프의 핵심 원칙

**plan.md = 전체 task 위임장**.
implement-task가 시작되면 **모든 task(T1...Tn)를 사용자 개입 없이 처리**합니다.

| 동작 | 결과 |
|---|---|
| T1 완료 후 사용자에게 "T2 진행할까요?" 묻기 | ❌ **금지** |
| T1 완료 후 즉시 T2 시작 | ✅ **올바름** |
| MINOR follow-up 발견 시 사용자에게 의견 묻기 | ❌ 금지 (plan.md에 기록 후 계속) |
| Halt Condition (계획 결함, 파괴적 작업 등) 발동 | ✅ 정지 후 보고 |
| 모든 task 완료 | ✅ 최종 보고 |

**사용자 개입 지점은 단 2개**:
1. plan-feature 단계의 plan.md 승인 (1회)
2. Halt Condition 또는 모든 task 완료 시 보고

#### PIV 루프

```
loop over plan.md tasks:
  Phase P  → 변경 전략 확정 (1–3줄)
  Phase I  → 최소 변경 구현 (checkpoint commit 후)
  Phase V  → 빌드 / 테스트 / 린트 + 자동 hook + 2단계 리뷰 subagent
  
  통과     → Phase D (commit) → 다음 task
  사소한 실패 → Phase I로 1회 자체 수정
  Halt Condition → 사용자 보고 후 정지
```

#### Phase V Fast-Path (Task Type별 적용)

plan.md의 task Type에 따라 다른 단계 적용:

| Type | 적용 단계 |
|---|---|
| **A** (Doc/Config) | V-1(빌드 적용 시) + V-8 |
| **B** (Trivial Code) | V-1 + V-2 + V-5(**prefilter Haiku → 의심 시 compliance Sonnet**) + V-8 |
| **C** (Normal Code) | V-1 + V-2 + V-3 + V-5(compliance Sonnet) + V-7 + V-8 (V-6 선택) |
| **D** (Complex/Cross-cutting) | V-1 ~ V-8 **전체** |

각 단계 상세:

```
V-1. 빌드           AGENTS.md의 build 명령 실행
V-2. 테스트         AGENTS.md의 test 명령 실행
V-3. 린트           프로젝트 표준 도구
V-4. PostToolUse hook 자동 (UTF-8/1500라인/한글주석)  ← 모든 Type 자동 실행
V-5. spec-compliance-reviewer subagent → BLOCKER 0까지
       (acceptance + 범위 + Decisions + 환각 + 우회 +
        Cross-File Caller Impact + Evidence Honesty)
V-6. code-quality-reviewer subagent → BLOCKER 0까지
       (DDD + 환각 + 안전 우회 + 위생 + 규율 + 보안 + 동시성)
V-7. Caller Re-verification — 변경된 심볼의 호출자 grep
       a 수정 → b, c 누락을 마지막으로 잡는 관문
V-8. Self-Honesty Check — Phase D 진입 전 자기 정직성 검증
       "빌드만 통과한 채 '동작 확인됨' 보고" 자기기만 차단
```

**Task Type 미명시** → D로 간주 (안전 우선).

#### Halt Conditions (자동 중단 → 사용자 보고)

| 카테고리 | 조건 |
|---|---|
| 계획 결함 | plan.md에 없는 결정 분기 발견 |
| 계획 결함 | plan.md의 가정이 실측과 불일치 |
| 루프 실패 | checkpoint 복구 2회 |
| 루프 실패 | Review subagent 동일 이슈 3회 |
| 루프 실패 | 빌드/테스트 5회 연속 실패 |
| 범위 초과 | plan에 없는 모듈로 번짐 |
| 파괴적 작업 | force push, history rewrite, 데이터 삭제 |
| 외부 의존 | 새 라이브러리 도입 필요 |
| 환경 의존 | 실제 디바이스 접근 필요 |

#### 사용 예시

```
사용자: "OK 진행"
   ↓
[pjc:implement-task 자율 루프 시작]

✅ T1 완료 (1/5 tasks)
   Build: dotnet build → OK
   Tests: 12/12 passed
   Review: spec OK, quality OK

✅ T2 완료 (2/5 tasks)
   ...

⛔ T3 작업 중단
   Reason: 계획 결함
   Details: plan.md에 명시되지 않은 INavigationService 의존 발견
   Options:
     A) plan.md에 task 추가하여 progress
     B) 다른 접근으로 재계획
     C) plan-feature 재실행
```

#### 금지 (안티패턴)

- "구현이 맞아 보입니다"로 완료 선언 → 증거 첨부 의무
- Review subagent 생략 → 절대 금지
- 무관한 리팩토링 끼워넣기 → plan에 새 task 등록
- 영문 주석 자동 생성 → 한글 주석 강제
- 환각 메서드 호출 → 문서 확인 또는 Halt

---

### 3. `pjc:systematic-debugging` — 4-phase 디버깅

| 항목 | 내용 |
|---|---|
| **목적** | 증상 추측이 아닌 근본 원인 조사를 강제. 4-phase 절차로 수정 전 진단 의무화 |
| **트리거 키워드** | "버그", "에러", "안 됨", "이상해", "왜 이래", "테스트 실패", "fix", "debug", "error" |
| **호출 시점** | 모든 버그/실패 발생 시 (자동) |
| **호출 subagent** | 필요 시 `explorer` (코드 탐색) |
| **산출물** | `debug-<날짜>.md` 또는 기존 plan.md에 조사 로그 추가 |

#### Iron Law

> **근본 원인을 찾기 전에는 어떤 수정도 시도하지 않는다.**  
> 증상 수정은 실패다.  
> 95%의 "근본 원인 없음" 사례는 불충분한 조사의 결과다.

#### 4 Phase 절차

```
Phase 1 — Root Cause Investigation (필수)
  1-A. 에러 메시지·스택트레이스 정독
  1-B. 신뢰성 있는 재현 절차 확보
  1-C. 최근 변경 검사 (git log, 의존성)
  1-D. 컴포넌트 경계 증거 수집 (어느 레이어가 실패하나)

Phase 2 — Pattern Analysis
  2-A. 유사 사례 검색
  2-B. 가설 후보 ≥2개 작성

Phase 3 — Hypothesis Testing
  3-A. 진단 코드 (로그, 테스트)
  3-B. 가설 ✅/❌/⚠️ 결정
  3-C. 임시 진단 코드 정리

Phase 4 — Implementation
  4-A. 회귀 테스트 먼저 (RED)
  4-B. 최소 수정 (GREEN)
  4-C. Defense in Depth (선택)
  4-D. 검증

Phase 4.5 — Architectural Doubt
  3회 이상 수정 실패 → 아키텍처 의심, 사용자 보고
```

#### 즉시 Phase 1 복귀 조건

- "아마 ~ 때문일 거야"로 수정 진입
- 에러 메시지 첫 줄만 보고 결론
- 재현 절차 미확정 채 수정
- 가설이 1개뿐
- try-catch로 에러 가리기
- 테스트 없이 "이제 될 거다"

#### 사용 예시

```
사용자: "이상해 사용자 설정이 저장이 안 돼"
   ↓
[pjc:systematic-debugging 자동 트리거]

Phase 1 시작:
  - 에러 메시지: 없음 (조용히 실패)
  - 재현: 설정 변경 후 앱 재시작 → 기본값으로 돌아감
  - 최근 변경: git log → 이번 주 ApplicationData 관련 커밋 3건
  - 레이어 분석:
    [VM] Save() 호출 ✓
    [Service] ApplicationData.Current.LocalSettings.Values["key"] = value ✓
    [재시작 후]
    [Service] ApplicationData.Current.LocalSettings.Values["key"] → null ✗
  → LocalSettings 영속화 단계가 실패

Phase 2 가설:
  H1: Unpackaged 모드에서 ApplicationData 사용 불가? 검증: WinUI Package 모드 확인
  H2: 동시성 문제로 저장 직후 덮어쓰기?    검증: 단일 저장만으로 재현 시도
  H3: 키 이름 충돌?                          검증: 다른 키 이름으로 시도

Phase 3:
  H1 ✅ 확정 — Unpackaged WinUI 3에서 LocalSettings 동작 안 함

Phase 4:
  - 회귀 테스트 작성 (LocalSettings 저장/로드 시나리오)
  - 수정: Microsoft.Windows.Storage.ApplicationData (Windows App SDK 1.5+) 또는
          ConfigurationManager + JSON 파일로 변경
  - 검증: 재시작 후 설정 유지 확인
```

---

### 4. `pjc:add-viewmodel` — WinUI 3 MVVM

| 항목 | 내용 |
|---|---|
| **목적** | WinUI 3 / WPF / MAUI 프로젝트에 ViewModel + View + DI 등록 + 테스트 스캐폴드 일괄 생성 |
| **트리거 키워드** | "ViewModel 추가", "새 화면", "다이얼로그 추가", "페이지 만들기" |
| **호출 시점** | 보통 implement-task의 한 task로 호출 |
| **호출 subagent** | (직접 호출 없음, code-quality-reviewer가 검증) |
| **산출물** | ViewModel.cs, View.xaml, View.xaml.cs, DI 등록, 단위 테스트 |

#### 사전 조건 (plan-feature에서 결정되어야 함)

- 화면 이름 (예: `Settings`)
- 화면 종류: Page / Window / UserControl / ContentDialog
- 위치 (어느 모듈/프로젝트)
- 상위 네비게이션과의 연결 방식
- 필요한 의존성 서비스

#### 변형 (Variants)

| 종류 | 사용 케이스 |
|---|---|
| Page | 네비게이션 진입 화면 |
| ContentDialog | 모달 입력/확인 |
| UserControl | 재사용 부품 (외부에서 DataContext 주입) |
| Settings (Singleton) | 영속화 필요 ViewModel |

#### 생성되는 코드 (Page 케이스)

```csharp
// SettingsViewModel.cs - 자동 생성
public sealed partial class SettingsViewModel : ObservableObject
{
    [ObservableProperty] private string _title = "설정";
    [ObservableProperty] private bool _isBusy;
    
    [RelayCommand]
    private async Task LoadAsync() { ... }
}
```

```xml
<!-- SettingsPage.xaml - 자동 생성 -->
<Page x:Class="...SettingsPage">
  <Grid Padding="16">
    <TextBlock Text="{x:Bind ViewModel.Title, Mode=OneWay}"/>
  </Grid>
</Page>
```

```csharp
// App.xaml.cs - DI 등록 자동 추가
services.AddTransient<SettingsViewModel>();
services.AddTransient<SettingsPage>();
```

#### 안티패턴 (자동 거부)

- `INotifyPropertyChanged` 수동 구현 → `[ObservableProperty]` 사용
- ViewModel에서 `MessageBox` 직접 호출 → `IDialogService` 추상화
- 코드비하인드에 비즈니스 로직 → ViewModel로 이동
- 영문 XML doc 주석 → 한글 강제

---

### 5. `pjc:add-domain-service` — DDD 서비스

| 항목 | 내용 |
|---|---|
| **목적** | DDD 프로젝트에 Domain Service 또는 Application Service 추가. 비즈니스 로직은 Domain에, 오케스트레이션은 Application에 |
| **트리거 키워드** | "서비스 추가", "도메인 로직", "비즈니스 로직", "use case 추가" |
| **호출 시점** | implement-task의 한 task로 호출 |
| **호출 subagent** | code-quality-reviewer (csproj 의존 방향 검증) |
| **산출물** | Interface (Domain), Implementation, DI 등록, 단위 테스트 |

#### Domain vs Application 판별

| 케이스 | 위치 |
|---|---|
| 순수 비즈니스 규칙 (가격 계산, 정책 판정) | Domain Service |
| 여러 Aggregate에 걸친 규칙 | Domain Service |
| 외부 시스템 호출, DB 트랜잭션, 메시징 | Application Service (UseCase) |
| 단순 CRUD + UI 호출 | Application Service |
| 단일 Aggregate 내부 로직 | Aggregate에 메서드 추가 (서비스 X) |

#### 자동 검증

생성 후 다음을 자동 확인:

```xml
<!-- Domain.csproj에 다음이 없어야 함 -->
<PackageReference Include="Microsoft.EntityFrameworkCore..." />
<PackageReference Include="Microsoft.AspNetCore..." />
<PackageReference Include="System.Net.Http..." />
<ProjectReference Include="...Infrastructure..." />
<ProjectReference Include="...UI..." />
```

위반 발견 시 즉시 Halt → 사용자 보고.

#### 생성되는 코드

```csharp
// Domain/Services/IPriceCalculator.cs
public interface IPriceCalculator { Money Calculate(Order order); }

// Domain/Services/PriceCalculator.cs
public sealed class PriceCalculator : IPriceCalculator
{
    private readonly IDiscountPolicy _discount;
    public Money Calculate(Order order) { /* 규칙 */ }
}

// Application/UseCases/CalculatePrice/CalculatePriceHandler.cs
public sealed class CalculatePriceHandler
{
    // Domain Service 호출 + 영속화 오케스트레이션
}
```

#### 안티패턴 (자동 거부)

- Domain에서 `DbContext` 직접 사용 → IRepository 추상화
- Domain에서 `DateTime.Now` → IClock/TimeProvider 추상화
- Anemic Domain (서비스가 모든 로직, Entity는 데이터만)
- Service명에 Manager/Helper/Util → 책임 기반 명사
- Result type과 예외 혼용 → 컨벤션 통일

---

### 6. `pjc:harness-toggle` — Hook 런타임 On/Off

| 항목 | 내용 |
|---|---|
| **목적** | 개별 hook을 Claude Code 재시작 없이 즉시 on/off |
| **트리거 키워드** | "harness 끄기", "harness 켜기", "plan 강제 꺼", "hook 상태", "harness status", "harness 토글" |
| **호출 시점** | 사용자가 hook 동작을 조정하고 싶을 때 |
| **호출 subagent** | 없음 |
| **산출물** | `~/.claude/.disabled/<hookname>` 마커 파일 |

#### 동작 원리

각 hook 스크립트는 시작 시 `~/.claude/.disabled/<hookname>` 파일을 확인:
- 파일 있음 → 즉시 exit 0 (검사 안 함)
- 파일 없음 → 정상 검사

#### 토글 가능 / 불가능

| Hook | 토글 |
|---|---|
| `require-plan-for-write` | ✅ |
| `require-evidence` | ✅ |
| `check-utf8-and-lines` | ✅ |
| `block-destructive` | ❌ (안전상) |

#### 명령 매핑

| 사용자 요청 | 동작 |
|---|---|
| "harness 상태" | 4개 hook의 ON/OFF 표시 |
| "plan 강제 꺼" | require-plan-for-write 비활성화 |
| "plan 강제 켜" | require-plan-for-write 활성화 |
| "evidence 꺼" | require-evidence 비활성화 |
| "utf8 검사 꺼" | check-utf8-and-lines 비활성화 |
| "(hook) 토글" | on ↔ off 전환 |

#### 사용 예시

```
사용자: "harness 상태"
Claude:
  [ON]  require-plan-for-write
  [ON]  require-evidence
  [ON]  check-utf8-and-lines
  [ON]  block-destructive (안전상 토글 불가)

사용자: "plan 강제 잠깐 꺼줘"
Claude: [OFF] require-plan-for-write
        즉시 반영됩니다. 작업 끝나면 'plan 강제 켜'로 다시 활성화하세요.
```

---

## Subagent 상세

각 subagent는 **독립된 컨텍스트**에서 동작하므로 메인 대화를 오염시키지 않습니다.

### 1. `plan-reviewer`

| 항목 | 내용 |
|---|---|
| **역할** | plan.md의 적대적 검토 |
| **모델** | Opus (정밀도 우선) |
| **도구** | Read, Grep, Glob (읽기 전용) |
| **호출 시점** | plan-feature 의 Step 8 (이슈 0까지 반복) |
| **출력** | BLOCKER / MAJOR / MINOR 이슈 목록 |

#### 검토 항목

1. 추측·가정이 사실로 진술된 곳
2. 우회로 보이는 해결책
3. 영향 범위 누락 (DI, 이벤트, 직렬화, 마이그레이션, 권한, 캐싱, 동시성, 로깅)
4. **Breaking Change Propagation 누락** — a 수정 시 b, c가 plan의 Files/task에 빠져 있지 않은가
5. 검증 불가능한 acceptance
6. Decision Points 미해결
7. 모호한 요구사항 (구현 중 질문 필요)
8. 부분 확인 (전수 조사 아님)
9. 과대 범위 (out of scope 누락)

### 2. `spec-prefilter` 🆕

| 항목 | 내용 |
|---|---|
| **역할** | Type B (Trivial Code) task의 V-5 빠른 1차 필터 |
| **모델** | Haiku (저렴·빠름) |
| **도구** | Read, Grep, Glob, Bash |
| **호출 시점** | implement-task V-5 — **Type B에서만** |
| **출력** | PASS / ESCALATE (1줄) |

#### 동작

```
Type B task의 V-5
  ├─ spec-prefilter (Haiku) 먼저 호출
  ├─ PASS → V-5 종료 (Sonnet 호출 없음, 토큰 절감)
  └─ ESCALATE → spec-compliance-reviewer (Sonnet) 호출
```

#### 빠른 체크 항목 (3분 이내)

- Acceptance 충족 여부 (diff에 키워드 일치)
- 명백한 환각 패턴 (import 누락, 미상 네임스페이스)
- 명백한 우회 패턴 (빈 catch, `Assert.True(true)`, TODO 그대로)
- 명백한 cross-file 누락 (Type B는 단일 파일 전제, 2개 이상이면 ESCALATE)
- Files 범위 일치

확신 없으면 ESCALATE — Sonnet에 위임.

### 3. `spec-compliance-reviewer`

| 항목 | 내용 |
|---|---|
| **역할** | 구현 diff가 plan.md acceptance에 부합하는지 검증 |
| **모델** | Sonnet (속도 우선) |
| **도구** | Read, Grep, Glob, Bash |
| **호출 시점** | implement-task Phase V-5 (의무) |
| **출력** | BLOCKER / MAJOR / MINOR + Acceptance 체크리스트 |

#### 검토 항목

- Acceptance 충족 (각 조건마다 diff에서 증거 확인)
- 범위 일치 (Files 목록 외 수정 여부)
- Decisions 준수 (Chosen option대로 구현되었나)
- 환각 검출 (외부 API/라이브러리 실재 여부, grep으로 직접 확인)
- 우회 흔적 (빈 catch, 임시 조건문, 테스트 비활성화)
- plan에 없는 신규 의존성
- **Cross-File Caller Impact** — 변경된 심볼의 모든 호출자/구현체가 함께 갱신되었나
- **Evidence Honesty** — 빌드/테스트 실제 실행 흔적, 새 코드에 대응 테스트 추가 여부, "확인됨" 주장의 근거

### 4. `code-quality-reviewer`

| 항목 | 내용 |
|---|---|
| **역할** | 코드 품질·아키텍처·컨벤션 검증 |
| **모델** | Sonnet |
| **도구** | Read, Grep, Glob, Bash |
| **호출 시점** | implement-task Phase V-6 (의무) |
| **출력** | BLOCKER / MAJOR / MINOR |

#### 검토 항목

- 아키텍처 위반 (DDD, 레이어 의존 역전)
- 환각 코드 (존재하지 않는 API)
- 안전 우회 (빈 catch, 테스트 skip, 하드코딩 검증 우회)
- 코드 위생 (죽은 코드, 미사용 import, TODO 미완)
- 프로젝트 규율 (영문 주석, 1500라인 초과, UTF-8 BOM)
- 보안 (비밀 정보 하드코딩, injection 패턴, 권한 누락)
- 동시성 (락 없는 공유 상태, async/await 누락)

### 5. `explorer`

| 항목 | 내용 |
|---|---|
| **역할** | 코드베이스 빠른 탐색 (메인 컨텍스트 오염 방지) |
| **모델** | Haiku (비용 절감) |
| **도구** | Read, Grep, Glob, Bash |
| **호출 시점** | plan-feature 의 컨텍스트 수집 단계 |
| **출력** | 파일 위치 + 한 줄 설명 형식의 간결한 요약 |

#### 호출 예시

```
plan-feature: explorer subagent에 위임
  Query: "이 프로젝트의 DI 등록 진입점은 어디?"

[explorer Haiku로 빠른 탐색]

Result:
- `src/App.xaml.cs:42` — ConfigureServices에서 DI 컨테이너 빌드
- `src/Modules/*/ModuleRegistration.cs` — 모듈별 등록 진입점

[메인 컨텍스트로 요약만 반환 — 파일 내용 전체는 explorer 컨텍스트에서 소비]
```

### 6. `plan-completion-reviewer`

| 항목 | 내용 |
|---|---|
| **역할** | 모든 task 완료 후 plan 전체 통합 검증 (적대적) |
| **모델** | Opus (전체 plan 적대적 검토 — 정밀도 우선) |
| **도구** | Read, Grep, Glob, Bash |
| **호출 시점** | implement-task Phase F-7 (모든 task 완료 후, 의무) |
| **출력** | BLOCKER / MAJOR / MINOR + Goal Assessment + Build/Test 재실행 결과 |

#### 검토 항목

- **Goal 충족** — plan의 Goal 한 문장이 실제 구현으로 달성되었는가
- **Acceptance 전수 충족** — 모든 task의 acceptance가 충족되었는가
- **Impact Analysis 실제 처리** — plan이 명시한 영향 영역이 모두 처리되었는가
- **Cross-Task Caller Consistency** — task별 V-7이 누락한 cross-task 영향이 없는가
- **회귀 가능성** — 전체 빌드/테스트 재실행, 회귀 영역 테스트 존재 여부
- **Risks & Unknowns 실현 검토** — 위험이 실현됐는지, 완화책이 작동했는지
- **Edge Cases 처리** — plan에 명시된 Edge Cases가 diff에 반영되었는지
- **Follow-ups 완전성** — 발견된 follow-up이 plan에 기록되었는지
- **자기기만 패턴** — acceptance가 도중에 약화됐는지, 빌드/테스트 증거 신뢰성

#### V-5 (spec-compliance-reviewer)와의 차이

| 항목 | spec-compliance-reviewer | plan-completion-reviewer |
|---|---|---|
| 호출 시점 | 각 task의 V-5 | 모든 task 완료 후 (F-7) |
| 검증 단위 | 단일 task의 acceptance | plan 전체의 Goal + 통합 |
| 회귀 검증 | 거의 없음 | 전체 테스트 재실행 |
| 모델 | Sonnet | Opus |

이 5번째 subagent가 자율 루프의 마지막 안전망입니다.

---

## Hook 동작 상세

### 1. `block-destructive.ps1` — 파괴적 명령 차단

| 항목 | 내용 |
|---|---|
| **이벤트** | PreToolUse |
| **Matcher** | `Bash` |
| **동작** | 위험 패턴 매칭 시 exit 2로 차단 |
| **토글** | ❌ (안전상 불가) |
| **우회** | 사용자가 직접 PowerShell에서 실행 |

#### 차단 패턴

```
rm -rf / | rm -rf ~ | rm -rf $HOME | rm -rf *
git push --force | git push -f | git push --force-with-lease
git filter-branch | git filter-repo | git reflog expire
sudo (전체)
DROP TABLE | DROP DATABASE | TRUNCATE TABLE
mkfs.* | dd if=*of=/dev/*
Remove-Item -Recurse -Force C:\... (Windows)
Format-Volume | Clear-RecycleBin -Force
fork bomb 패턴
```

조합 우회 대응: `;`, `&&`, `||`, `|`로 분리된 각 subcommand 모두 검사.

### 2. `require-plan-for-write.ps1` — Plan 강제

| 항목 | 내용 |
|---|---|
| **이벤트** | PreToolUse |
| **Matcher** | `Write\|Edit` |
| **동작** | plan.md 또는 docs/plans/ 없으면 코드 파일 Write 차단 |
| **토글** | ✅ |
| **우회** | `$env:CLAUDE_HARNESS_QUICK = '1'` 또는 harness-toggle |

#### 차단 / 허용 매트릭스

| 파일 / 상황 | 결과 |
|---|---|
| `.cs`, `.ts`, `.py`, `.java` 등 코드 + plan 없음 | ⛔ 차단 |
| 코드 + plan 있음 | ✅ 허용 |
| `.md`, `.json`, `.yml`, `.csproj`, `.gitignore` | ✅ 항상 허용 |
| `.git/`, `.vs/`, `bin/`, `obj/`, `node_modules/`, `dist/`, `build/` | ✅ 허용 |
| `docs/`, `plans/`, `.claude/` 경로 | ✅ 허용 |
| `CLAUDE_HARNESS_QUICK=1` 설정됨 | ✅ 우회 |

#### 차단 시 안내 메시지

```
[HARNESS] BLOCKED: 코드 변경 전에 plan이 필요합니다.

대상 파일: src/MyApp/Foo.cs
plan.md 또는 docs/plans/ 디렉터리가 없습니다.

해결 방법:
  1) plan-feature skill 호출
  2) 긴급 1줄 수정 우회: $env:CLAUDE_HARNESS_QUICK = '1'
  3) docs/plans/ 디렉터리 생성
```

### 3. `check-utf8-and-lines.ps1` — 파일 검증

| 항목 | 내용 |
|---|---|
| **이벤트** | PostToolUse |
| **Matcher** | `Write\|Edit` |
| **동작** | 저장된 파일 검사 후 stderr 경고 (차단 X) |
| **토글** | ✅ |

#### 검사 항목

| 항목 | 경고 조건 |
|---|---|
| BOM | UTF-8 BOM 발견 |
| 인코딩 | 비-UTF8 |
| 라인 수 | 1500 초과 |
| 영문 주석 | 코드 파일에서 영문 주석이 절반 초과 |

대상 확장자: `.cs`, `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.java`, `.go`, `.rs`, `.cpp`, `.c`, `.h`, `.hpp`, `.fs`, `.kt`, `.swift`

### 4. `require-evidence.ps1` — Stop 증거 검사

| 항목 | 내용 |
|---|---|
| **이벤트** | Stop |
| **Matcher** | (모두) |
| **동작** | 마지막 git 커밋에 증거 없으면 stderr 경고 |
| **토글** | ✅ |

#### 경고 조건

- 마지막 커밋 메시지가 `checkpoint:` 로 시작 (task 미완)
- 마지막 커밋이 `T<N>:` 형식인데 Build/Tests/Review 흔적 없음

### 5. `impact-warn.ps1` — Public 심볼 변경 시 caller 경고 🆕

| 항목 | 내용 |
|---|---|
| **이벤트** | PostToolUse |
| **Matcher** | `Write\|Edit` |
| **동작** | 변경 파일의 public/internal/export 심볼 검출 → grep으로 caller 검색 → stderr 경고 (차단 X) |
| **토글** | ✅ |
| **언어 지원** | C#, TypeScript, JavaScript, Python, Java, Kotlin, Go, Rust 등 |

#### 검출 패턴

| 언어 | 선언 패턴 |
|---|---|
| C# | `public/internal/protected` + 메서드/클래스 |
| TS/JS | `export function/class/const/interface/type/enum` |
| Python | `def/class` (underscore prefix 제외) |
| Kotlin | `fun/class/interface` 등 |
| Go | 대문자 시작 함수 |
| Rust | `pub fn/struct/enum/trait` |

#### 경고 예시

```
[IMPACT WARNING] src/PriceService.cs 의 public/internal 심볼이 변경되었습니다.
심볼 'CalculatePrice' 참조 발견 (caller가 함께 갱신되었는지 확인):
  - src/CheckoutService.cs:42
  - src/OrderHistoryView.cs:128
  - tests/PriceServiceTests.cs:7

위 caller 파일들의 동작이 변경되었을 수 있습니다.
각 파일을 Read로 열어 영향을 검증하고, 필요 시 함께 수정하세요.
이 경고는 차단이 아닙니다. 끄려면: harness-toggle impact-warn off
```

Claude는 이 경고를 받으면 자동으로 caller 파일을 열어 영향을 검증.
**모든 Type에서 작동** (Type A 제외, 코드 파일이 아니므로 미발동).

---

## 자기기만·누락 차단 메커니즘

다음 3가지 흔한 문제에 대한 다층 방어:

### 문제 1 — 연관 파일 누락 (a 수정 → b, c 미수정)

| 단계 | 어떻게 잡는가 |
|---|---|
| plan-feature Step 4 (Impact Analysis) | 변경 대상 심볼의 호출자/구현체/참조를 파일별로 명시 |
| plan-reviewer 항목 3-B | "Breaking Change Propagation 누락" 검출 |
| implement-task Phase P-3 | Phase I 전에 caller 전수 grep, 누락 시 Halt |
| **PostToolUse impact-warn hook 🆕** | **모든 Write/Edit 후 자동 caller 경고 (1.8.0)** |
| implement-task Phase V-5 | spec-compliance-reviewer의 G "Cross-File Caller Impact" |
| implement-task Phase V-7 | Caller Re-verification — 변경 후 grep으로 마지막 검증 (Type B/C/D 의무) |

### 문제 2 — 예측 기반 작성 (팩트 아님)

| 단계 | 어떻게 잡는가 |
|---|---|
| plan-feature 절대 규칙 #2 | "팩트 기반" 명시, "아마도/보통" 금지 |
| plan-reviewer 항목 1 | "추측·가정 검출" |
| implement-task Phase P-2 | 파일 직접 Read, 가정 금지 |
| implement-task Phase P-4 | 외부 식별자를 grep/Read로 정의 위치까지 확인 |
| code-quality-reviewer 항목 B | 환각 검출 — "검증 불가 = BLOCKER" |
| implement-task Phase V-8 | Self-Honesty Check — "추측 코드 0개" 자기 확인 |

### 문제 3 — 수정 후 별도 에이전트 검증

| 단계 | 누가 검증 |
|---|---|
| Phase V-5 | `spec-compliance-reviewer` (의무) — acceptance + cross-file + 동작 증거 |
| Phase V-6 | `code-quality-reviewer` (의무) — 환각 + 안전 우회 + 규율 |
| Phase V-7 | Caller Re-verification — 마지막 grep 관문 |
| Phase V-8 | Self-Honesty Check — "동작 확인됨"의 근거 자기 검증 |

각 단계는 BLOCKER 발견 시 Phase I로 복귀 후 재시도. 동일 BLOCKER 3회 연속 시 자동 Halt → 사용자 보고.

### 문제 4 — 자율 실행 도중 멈춤 (사용자 개입 불가)

implement-task는 사용자 개입 없이 모든 task를 처리하므로 plan에 결함이 있으면 멈추거나 추측으로 진행. plan 단계에서 미리 차단:

| 단계 | 어떻게 잡는가 |
|---|---|
| plan-feature 절대 규칙 #9 | "자율 실행 전제" — "다른 사람이 plan만 보고 끝낼 수 있는가?" |
| plan-feature Step 6 (Decision Points) | 11개 카테고리의 결정을 사전 해결 |
| plan-feature Step 6.5-A (Edge Cases) | 10개 카테고리 경계 시나리오 명시 |
| plan-feature Step 6.5-B (Halt Forecast) | 멈출 가능성 + plan 내 해결책 지목 |
| plan-feature Step 6.5-C | 자율 실행 준비도 3개 자문 |
| plan-reviewer 항목 11 | Autonomous Readiness — 모호한 지시 검출 |
| plan-reviewer 항목 12 | Edge Case 커버리지 검사 |
| plan-reviewer 항목 13 | Halt Forecast 부재 검사 |
| implement-task 자율 루프 절대 규칙 (1.4.3) | task 사이 사용자 확인 금지 |

자율 실행 적합성 자문 (plan 작성자가 답해야 함):

- 이 task의 모든 결정이 plan에 적혀 있는가?
- 이 task 구현 중 발생 가능한 에러 케이스가 모두 정의되었는가?
- **다른 사람이 추가 질문 없이 이 task를 끝낼 수 있는가?**

하나라도 "아니오"면 plan 미완.

### Self-Honesty Check (Phase V-8) 질문

Phase D 진입 전 다음에 모두 "예"라고 답할 수 있어야 한다:

- [ ] 빌드 명령을 실제로 실행했고 exit 0을 봤는가?
- [ ] 테스트 명령을 실제로 실행했고 통과 수를 봤는가?
- [ ] acceptance 각 항목에 대해 diff 어디서 충족되는지 지목할 수 있는가?
- [ ] 변경한 심볼의 caller가 모두 함께 갱신되었는가?
- [ ] "동작 확인됨" 주장의 근거가 빌드 통과 외에 있는가?
- [ ] 이 task에서 추측으로 작성한 코드가 하나도 없는가?

하나라도 "아니오/모름"이면 Phase I 복귀.

---

## Permissions

Plugin enable 시 다음 권한이 자동 적용됩니다 (`plugins/pjc/settings.json`).

### Allow (자동 실행 가능)

```
Read, Glob, Grep
Bash(git status / diff:* / log:* / add:* / commit:* / checkout:* / branch:* / stash:* / rev-parse:* / reset --soft:* / reset --hard:*)
Bash(dotnet build:* / test:* / restore:* / format:* / run:* / pack:* / publish:* / tool:*)
Bash(powershell*harness-toggle.ps1*)
```

### Ask (사용자 확인 후 실행)

```
Bash(git push:* / merge:*)
Bash(dotnet add package:* / remove package:* / nuget:*)
Write, Edit
```

### Deny (절대 차단)

```
Read(./.env, ./.env.*, ./secrets/**, ./**/*.pem, ./**/*.key)
Read(./**/appsettings.Production.json)
Bash(git push --force:* / -f:* / --force-with-lease:* / filter-branch:* / filter-repo:* / reflog expire:*)
```

---

## 첫 사용 Walkthrough

### 시나리오: 빈 프로젝트에서 첫 기능 추가

```powershell
# 1. 프로젝트 디렉터리로 이동
cd C:\Repos\MyNewApp

# 2. AGENTS.md 배치
Copy-Item C:\Tools\claude-harness-pjc\AGENTS.md.template .\AGENTS.md
notepad .\AGENTS.md   # Build/Test 명령 등 채우기

# 3. Claude Code 시작
claude
```

#### 대화 흐름

```
사용자: 사용자 로그인 화면 추가해줘

[pjc:plan-feature 자동 트리거]

Claude: AGENTS.md를 읽고 코드베이스를 탐색했습니다. 
        다음을 확인해 주세요:
        1. 로그인 방식은? (a) Local credentials  (b) OAuth  (c) Windows Hello
        2. 자격증명 영속화 위치는? (a) ApplicationData  (b) DPAPI 암호화 파일
        3. 다중 사용자 지원 필요한가요?

사용자: a, b, 아니오

Claude: [plan.md 작성 중...]
        [plan-reviewer subagent 호출 - 적대적 검토]
        [BLOCKER 2개 발견 → 수정]
        [재검토 → 이슈 0]

        ## Plan: Login Screen
        
        Tasks (4개):
        - [ ] T1. ICredentialStore (Domain) 인터페이스 정의
        - [ ] T2. DpapiCredentialStore (Infrastructure) 구현
        - [ ] T3. LoginViewModel + LoginPage
        - [ ] T4. App 시작 시 로그인 페이지 진입 분기
        
        Decisions: 3개 (모두 해결)
        Impact: ICredentialStore 등록 / App.xaml.cs 진입 변경 / 1개 통합 테스트
        
        승인하시겠습니까?

사용자: OK 진행

[pjc:implement-task 자율 루프 시작]

✅ T1 완료 (1/4)
   Build: OK / Tests: 0 added (인터페이스만)
   Review: spec OK, quality OK

✅ T2 완료 (2/4)
   Build: OK / Tests: 4/4 passed
   Review: spec OK, quality OK

# Phase I 시작 - T3 LoginViewModel
[pjc:add-viewmodel skill 자동 호출]
[ViewModel.cs + Page.xaml + Page.xaml.cs + DI 등록 + 테스트 생성]

✅ T3 완료 (3/4)
   Build: OK / Tests: 12/12 passed
   Review: spec OK, quality OK

✅ T4 완료 (4/4)
   ...

🎉 모든 task 완료. plan.md 모든 acceptance 만족.
```

### 시나리오: 버그 발생

```
사용자: 로그인 후 메인 화면에 사용자 이름이 안 보여

[pjc:systematic-debugging 자동 트리거]

Claude: Phase 1 — 근본 원인 조사를 시작합니다. 코드는 수정하지 않습니다.
        
        재현 절차를 확정합니다:
        1. 로그인 화면에서 valid credentials 입력
        2. 메인 화면으로 이동
        3. 사용자 이름 binding이 빈 문자열로 표시됨 (실제 입력값 무시)
        
        ...
```

### 시나리오: hook 일시 비활성화

```
사용자: 1줄만 빠르게 수정하고 싶어, plan 강제 잠깐 꺼

Claude: [pjc:harness-toggle 자동 호출]
        [OFF] require-plan-for-write 비활성화됨
        즉시 반영됩니다. 작업 끝나면 'plan 강제 켜'로 다시 활성화하세요.

사용자: src/Foo.cs 32번째 줄 typo 수정 "calcualte" → "calculate"

[Write 도구 호출됨 → hook 통과 (비활성)]

Claude: 수정 완료. 'plan 강제 켜'로 다시 활성화하시는 것을 권장합니다.

사용자: 플랜 강제 다시 켜

Claude: [pjc:harness-toggle]
        [ON]  require-plan-for-write 활성화됨
```

---

## Plugin 구조

```
C:\Tools\claude-harness-pjc\
├── .claude-plugin\
│   └── marketplace.json              ← marketplace 정의
├── plugins\
│   └── pjc\                          ← plugin root
│       ├── .claude-plugin\
│       │   └── plugin.json           ← plugin 메타데이터
│       ├── skills\                   → /pjc:<폴더명>
│       │   ├── plan-feature\SKILL.md
│       │   ├── implement-task\SKILL.md
│       │   ├── systematic-debugging\SKILL.md
│       │   ├── add-viewmodel\SKILL.md
│       │   ├── add-domain-service\SKILL.md
│       │   └── harness-toggle\SKILL.md
│       ├── agents\
│       │   ├── plan-reviewer.md
│       │   ├── spec-compliance-reviewer.md
│       │   ├── code-quality-reviewer.md
│       │   └── explorer.md
│       ├── hooks\
│       │   └── hooks.json            ← hook 정의 (CLAUDE_PLUGIN_ROOT 사용)
│       ├── scripts\                  ← PowerShell hook 스크립트
│       │   ├── block-destructive.ps1
│       │   ├── check-utf8-and-lines.ps1
│       │   ├── require-evidence.ps1
│       │   ├── require-plan-for-write.ps1
│       │   ├── impact-warn.ps1
│       │   └── harness-toggle.ps1
│       └── settings.json             ← plugin enable 시 추가될 permissions
├── AGENTS.md.template                ← 각 프로젝트 루트에 복사용
├── install.ps1                       ← 자동 설치 스크립트
└── README.md
```

설치 후 사용자 영역:

```
%USERPROFILE%\.claude\
├── .disabled\                        ← hook 토글 상태 (plugin이 아닌 사용자 데이터)
└── settings.json                     ← plugin에서 추가된 permissions 병합
```

---

## 비용 최적화 (모델 라우팅)

| 컴포넌트 | 모델 | 사유 |
|---|---|---|
| plan-feature (메인) | Opus (기본) | 깊은 분석 |
| plan-reviewer | Opus | 적대적 검토 정밀도 |
| **plan-completion-reviewer** | **Opus** | **plan 전체 적대적 검토 (Phase F-7)** |
| implement-task | Sonnet | 작업 실행 |
| spec-compliance-reviewer | Sonnet | 빠른 리뷰 |
| code-quality-reviewer | Sonnet | 빠른 리뷰 |
| **spec-prefilter** 🆕 | **Haiku** | **Type B의 V-5 1차 빠른 필터 (Sonnet 호출 회피)** |
| explorer | Haiku | 단순 검색/읽기 |

---

## 업데이트 / 제거

### 업데이트

```powershell
# CLI 직접
claude plugin update pjc

# 또는 marketplace 갱신 후 업데이트
claude plugin marketplace update pjc-harness
claude plugin update pjc
```

### 제거

```powershell
# 자동 스크립트
C:\Tools\claude-harness-pjc\install.ps1 -Uninstall

# 또는 CLI 직접
claude plugin uninstall pjc
claude plugin marketplace remove pjc-harness
```

사용자 토글 데이터(`~/.claude/.disabled/`)는 plugin 제거 후에도 남음. 필요 시 수동 삭제:

```powershell
Remove-Item -Recurse "$env:USERPROFILE\.claude\.disabled"
```

---

## 트러블슈팅

### 설치 관련

| 증상 | 원인 | 해결 |
|---|---|---|
| `/plugin marketplace add` 에서 경로 인식 안 됨 | 백슬래시 처리 | `\` 대신 `/` 사용 시도 또는 따옴표로 감싸기 |
| `/plugin install pjc@pjc-harness` 실패 | marketplace 미등록 | `/plugin marketplace list`로 확인 |
| `/plugin list`에 pjc가 보이지 않음 | plugin 비활성 | `/plugin enable pjc` |
| Claude Code 버전 호환성 | v2.0 미만 | `npm update -g @anthropic-ai/claude-code` |

### Skill 동작 관련

| 증상 | 원인 | 해결 |
|---|---|---|
| `/pjc:` 명령이 자동완성에 안 보임 | plugin 인식 실패 | Claude Code 재시작 |
| Skill prefix가 안 붙음 (`/plan-feature`로 나옴) | SKILL.md에 `name:` 잔존 | `grep '^name:' plugins/pjc/skills/*/SKILL.md`로 확인 (이미 제거됨) |
| Skill 자동 트리거 안 됨 | description 키워드 미매칭 | `/pjc:<name>`으로 명시 호출 |
| Skill이 너무 자주 트리거됨 | description이 너무 광범위 | 슬래시 명령으로 명시 호출만 사용 |

### Hook 관련

| 증상 | 원인 | 해결 |
|---|---|---|
| Hook이 동작 안 함 | 실행 정책 | `Get-ExecutionPolicy -Scope CurrentUser` → `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Hook 스크립트 차단됨 | 다운로드 차단 마크 | `Get-ChildItem "$env:USERPROFILE\.claude\plugins\pjc\scripts" -Recurse \| Unblock-File` |
| plan 차단이 너무 빡빡함 | 의도된 동작 | `pjc:harness-toggle`로 끄거나 `$env:CLAUDE_HARNESS_QUICK = '1'` |
| Hook 안에서 한글 깨짐 | PowerShell 출력 인코딩 | `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` |
| `${CLAUDE_PLUGIN_ROOT}` 인식 안 됨 | Claude Code 버전 영향 | hooks.json 경로를 절대 경로로 변경 후 보고 |

### Subagent 관련

| 증상 | 원인 | 해결 |
|---|---|---|
| Subagent가 호출 안 됨 | description 매칭 실패 | `@plan-reviewer` 등 명시 호출 |
| Review subagent 무한 반복 | BLOCKER 동일 이슈 지속 | 3회 재시도 후 자동 Halt — 사용자에게 보고됨 |
| Subagent 토큰 비용 과다 | 모델 설정 잘못 | `~/.claude/plugins/pjc/agents/*.md`의 `model:` 필드 확인 |

### Permissions 관련

| 증상 | 원인 | 해결 |
|---|---|---|
| `dotnet build` 가 매번 확인 요청 | allow에 없음 | 본 plugin 설치 시 자동 추가. 누락이면 plugin 재설치 |
| `.env` 파일이 읽힘 | deny 누락 | 본 plugin 설치 시 자동 추가됨. 누락이면 마이그레이션 확인 |
| `git push --force` 실수 실행됨 | hook 비활성? | block-destructive는 토글 불가. 발생 시 issue 보고 |

---

## Standalone 버전과의 차이

이 plugin은 이전에 제공된 standalone 글로벌 버전(`%USERPROFILE%\.claude\skills\` 직접 설치)을 plugin 형식으로 재패키징한 것입니다.

| 항목 | Standalone | Plugin (이 패키지) |
|---|---|---|
| Skill 이름 | `plan-feature` | `pjc:plan-feature` |
| 설치 | `install.ps1` (파일 복사) | `/plugin install` |
| 업데이트 | 재설치 | `/plugin update` |
| 비활성화 | settings 수정 | `/plugin disable pjc` |
| Hook 경로 | `%USERPROFILE%\.claude\scripts\...` | `${CLAUDE_PLUGIN_ROOT}\scripts\...` |
| 다른 plugin과 namespace 충돌 | ⚠️ 위험 | ✅ 자동 회피 |
| 토글 데이터 위치 | `~/.claude/.disabled/` | `~/.claude/.disabled/` (동일) |

### ⚠️ 두 버전 동시 설치 금지

동일한 description의 skill 두 개가 충돌하여 자동 트리거가 불안정해집니다.
이미 standalone 버전을 설치했다면 plugin 설치 전에 제거 권장:

```powershell
# Standalone 제거 (백업 후)
$d = "$env:USERPROFILE\.claude"
$bak = "$d.standalone.bak"
Move-Item $d $bak
# Plugin 설치 후 ~/.claude/는 자동 재생성
```

---

## 라이선스

MIT — 자유롭게 수정·재배포 가능.
