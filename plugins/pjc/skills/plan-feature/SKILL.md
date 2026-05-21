---
description: Use when the user requests code change beyond trivial single-line edits. Triggers on phrases like "계획", "설계", "어떻게 구현", "feature 추가", "리팩토링", "구현", "plan", "design", "implement". TRIVIAL BYPASS - Do NOT trigger for the following obvious single-shot edits where Claude can directly apply the change without a plan - UI text/label changes ("버튼 라벨", "메시지 문구" 등), icon/image file swaps, color/size token tweaks (1-2 values), README/문서 typo fixes, comment additions, single-line config edits (.editorconfig, .gitignore), or single-line resource changes (strings.xml, Resources.resx). For those, Claude proceeds directly with Write/Edit and lets the PostToolUse impact-warn hook validate. Use plan-feature ONLY when the change involves multiple files, logic flow, signature changes, or has unclear impact. When in doubt, prefer plan-feature.
argument-hint: "<요청 설명>"
---

# Plan Feature

코드 작성 전에 작업을 분해하고, 모든 결정 분기를 사전 해결하고, 검증 가능한 수용 기준을 정의한다.

## Trivial Bypass — 이 skill을 건너뛰는 경우

다음 케이스는 **plan-feature를 호출하지 않고** Claude가 직접 Write/Edit으로 처리한다:

| 카테고리 | 예시 |
|---|---|
| UI 문구·라벨 | "확인 버튼 라벨을 'OK'로", "메시지 문구 변경" |
| 아이콘·이미지 교체 | "이 아이콘을 SVG 파일로 교체", "PNG 새 파일로 변경" |
| 색상·치수 토큰 1-2개 | "Primary 색상을 #336699로", "padding을 16px로" |
| 문서·README 오타 | "README 오타 수정", "줄바꿈 추가" |
| 주석 추가 | "이 메서드에 한글 주석 추가" |
| 단일 라인 설정 | ".editorconfig에 한 줄 추가", "gitignore에 폴더 추가" |
| 단일 라인 리소스 | "strings.xml의 키 한 개 값 변경" |

**Trivial 판정 기준** (모두 만족):
1. 변경 대상이 **단일 파일·단일 위치**
2. **로직 흐름·시그니처·구조** 변경 없음
3. **영향 범위가 명확히 0** (다른 파일 caller 없음, 또는 caller가 영향 안 받음)
4. 사용자 요청이 **명백하고 단순** (의도 모호함 없음)

**불확실하면 → plan-feature 사용.** 안전 우선.

**Trivial 작업의 안전망**: `impact-warn.ps1` PostToolUse hook이 자동 caller 영향 검출.

## 자율성 모드: USER-INTERACTIVE

> **이 skill 안에서는 사용자에게 물어도 된다.** 모호한 요구사항은 명확화 질문 권장.
>
> 그러나 **`implement-task` 단계로 넘어가기 전에 모든 질문이 해결**되어야 한다.
> implement-task는 FULLY AUTONOMOUS이므로 그 안에서는 사용자에게 묻지 않는다.

```
plan-feature (이 skill)         | implement-task
USER-INTERACTIVE                | FULLY AUTONOMOUS
                                |
질문 OK (Open Questions에 모음) | 질문 금지 (Halt만 가능)
사용자 승인 1회 (게이트)         | plan = 전체 위임장
                                |
↓ 모든 질문 해결 후 ──────────→ ↓
```

## 절대 규칙 (Hard Rules)

1. **이 Skill은 코드를 작성하지 않는다.** 산출물은 `plan.md` 하나.

2. **팩트 기반 — 예측 금지, 전수 확인.**
   - 모르는 것은 "확인 필요"로 표시. "아마도", "보통은", "일반적으로" 같은 가정은 금지.
   - 모든 주장은 Read 또는 grep으로 직접 확인한 결과여야 한다.
   - 사용처는 grep으로 **전수 조사**. "샘플 몇 개 확인 후 전체가 그럴 것"이라 결론짓지 않는다.
   - 확인 방법은 Investigation Log에 기록.

3. **근본 해결.** 증상 우회는 plan의 해결책이 될 수 없다.

4. **결정 사전화 — 자율 실행 전제.**
   `implement-task`는 plan.md를 받으면 **사용자 개입 없이 모든 task를 끝까지 실행**한다.
   - 모호한 요구사항은 사용자에게 미리 묻는다 (한 번에 최대 3개, 선택지 제시).
   - 구현 도중 결정해야 할 분기가 **하나도 남아 있지 않아야** 한다.
   - 자기 검증: **"이 plan을 다른 사람에게 넘겨도 추가 질문 없이 끝낼 수 있는가?"**

5. **연관 파일 의무 명시 (Cross-File Awareness).**
   - 변경 대상의 모든 호출자/구현체/직렬화/테스트를 task의 Files 목록에 **모두** 명시.
   - 누락 시 plan-reviewer 또는 spec-compliance-reviewer가 차단한다.

6. **요청 범위 밖 작업 금지.** "참고 김에 정리"는 plan에 새 task로 등록 후 사용자 확인.

7. **모든 task에 검증 가능한 acceptance.** "잘 동작한다" 같은 모호한 기준 금지.

## 실행 단계

### Step 1. 컨텍스트 수집
- `AGENTS.md` (또는 `CLAUDE.md`) 읽기
  - **없으면**: `pjc:bootstrap-agents-md` skill 자동 호출 → 사용자 승인 후 plan-feature 계속
  - 사용자가 bootstrap을 거부하면 추측 모드로 진행 (build/test 명령 모름 → 작업 중 Halt 빈번)
- 관련 모듈/파일 식별
- 기존 컨벤션, 테스트 위치, 빌드 명령 확인
- **대규모 탐색이 필요하면** `explorer` subagent에 위임 (메인 컨텍스트 보호)

### Step 2. 범위 명확화

다음을 답할 수 없으면 사용자에게 질문:
- 영향을 주는 사용자 시나리오는?
- 명시적으로 out of scope는?
- 성공을 어떻게 측정하는가?

### Step 3. 위험 식별

- 외부 의존성 (API, OS, 드라이버, 권한)
- 동시성·상태 (멀티스레드, 비동기, 라이프사이클)
- 회귀 가능성 (기존 기능 영향)
- 알려지지 않은 영역 (가설로 명시)

### Step 4. 영향 범위 전수 조사 (Impact Analysis)

변경 대상의 모든 사용처를 **실제로 식별하고 읽어** 분석.

#### 4-A. 심볼/타입 추적
- [ ] 심볼 참조 grep — **결과를 모두 Read로 열어 확인** (요약만으로 끝내기 금지)
- [ ] 인터페이스 변경 시 — 모든 **구현체 파일** 식별
- [ ] 메서드 시그니처 변경 시 — 모든 **호출자 파일** 식별
- [ ] 타입/필드 변경 시 — 모든 **참조 위치** 식별
- [ ] DI 등록·이벤트 핸들러·옵저버 — 등록부와 사용처 모두

#### 4-B. 계약·직렬화 변경
- 시그니처, 이벤트 페이로드, 직렬화 형식 변경 → 호환성 확인
- 마이그레이션 필요 시 별도 task

#### 4-C. 영향 받는 테스트
- 변경 대상을 직접 호출하는 테스트
- 변경 대상에 간접 의존하는 통합 테스트
- 테스트가 없으면 추가 필요성 검토 (plan에 task로)

#### Halt 조건
- 사용처 추적이 단순 grep 카운트만으로 끝남 (실제 파일 Read 안 함)
- "기타 영향 있을 수 있음" 같은 모호한 표현
- 변경 대상이 인터페이스인데 구현체 식별이 누락됨

### Step 5. 작업 분해

- 각 작업은 1–4시간 단위, 독립 검증 가능
- 각 작업마다 acceptance criterion 1줄 명시
- 의존 관계 표시
- **각 task에 Type 분류 명시 (의무)** — implement-task가 fast-path 결정에 사용

#### Task Type 분류 (필수)

| Type | 정의 | 적용 Phase V 단계 |
|---|---|---|
| **A** (Doc/Config) | `.md`, `.json`, `.yml`, `.csproj`, `.editorconfig` 등 코드 외 파일만 | V-1(빌드만, 적용 시) + V-8 |
| **B** (Trivial Code) | 단일 코드 파일, 단일 메서드/필드, **호출자 변경 없음** (typo, 주석) | V-1 + V-2 + V-5(prefilter) + V-7 + V-8 |
| **C** (Normal Code) | 단일 또는 2-3개 파일, caller 갱신 있음 | V-1 ~ V-3 + V-5 + V-7 + V-8 |
| **D** (Complex/Cross-cutting) | 다중 파일, 인터페이스 변경, 시그니처 변경, 직렬화 변경, DDD/아키텍처 영향 | V-1 ~ V-8 **전체 의무** |

확실하지 않으면 **한 단계 더 무거운 쪽 선택** (안전 우선).

#### 긴 plan 분할 권고 (컨텍스트 관리)

task가 **8개를 초과**하면 사용자에게 분할을 제안한다:

```
이 plan은 <N>개 task로 큽니다. implement-task의 자율 실행 중
컨텍스트가 누적되어 후반 task의 품질이 저하될 수 있습니다.

A) 그대로 진행 (Progress Log로 일부 완화됨)
B) 2개 plan으로 분할 (T1-<M>, T<M+1>-<N>)
   → 첫 plan 완료 후 두 번째 plan 별도 실행
```

분할 시 각 plan은 독립 실행 가능하도록 task 의존성을 고려해 경계를 정한다.
사용자가 A를 택하면 그대로 진행하되, implement-task가 Progress Log를 적극 활용.

### Step 6. Decision Points 발굴

각 task에 대해 결정 분기를 사전 해결.

**Type별 적용 범위**:
- Type A: skip
- Type B: 1-2개 (해당하는 것만)
- Type C: 5-6개
- Type D: 11개 전체

**상세 카테고리 11개 + 기록 형식은 `reference/decision-points.md` 참조.**

### Step 6.5. Edge Case & Halt Forecast (자율 실행 대비)

`implement-task`가 사용자 개입 없이 끝까지 가야 하므로, 구현 중 발생 가능한 멈춤 지점을 사전 예측.

**Type별 적용 범위**:
- Type A: skip
- Type B: 빈/null 입력 + 경계값만
- Type C: 5-6개
- Type D: 10개 전체

**상세 카테고리 + Halt Forecast + 자율 실행 준비도 자문은 `reference/edge-cases.md` 참조.**

### Step 7. plan.md 작성

**위치 결정** (AGENTS.md의 `Plan Location` 항목 우선):

| 프로젝트 규모 | 권장 위치 |
|---|---|
| 작은 프로젝트, 단일 작업 | `<repo>/plan.md` (덮어쓰기) |
| 큰 프로젝트, 여러 plan 누적 | `<repo>/docs/plans/<YYYY-MM-DD>-<slug>.md` |

**상세 plan.md 템플릿은 `reference/plan-template.md` 참조.**

### Step 8. 리뷰 게이트 (subagent 필수)

**`plan-reviewer` subagent 호출.** 자체 검토 금지.
- 결과가 BLOCKER 또는 MAJOR면 plan 수정 후 재호출 (최대 3회).
- 통과 후에만 다음 단계.

### Step 9. Open Questions 해결

질문이 있으면 **여기서** 사용자에게 일괄 질문. 답변을 plan.md에 반영.

### Step 10. 사용자 승인 게이트

ExitPlanMode로 plan.md 제시. 승인 시 `implement-task` 호출.

## 통과 체크리스트

다음을 모두 만족해야 implement-task로 넘어갈 수 있다:

- [ ] "아마도/보통" 0회
- [ ] Impact Analysis 4개 항목 모두 ✓
- [ ] plan-reviewer 이슈 0 (또는 MINOR만 follow-up으로 등록)
- [ ] 각 task에 검증 가능한 acceptance 1개 이상
- [ ] Open Questions 모두 해결됨
- [ ] 코드 작성 중 사용자에게 물을 결정 분기 0
- [ ] 각 task에 Type(A/B/C/D) 분류 명시
- [ ] 각 task에 Edge Cases 명시 (해당하는 모든 카테고리)
- [ ] 각 task에 Halt Forecast 명시
- [ ] 자율 실행 준비도 자문 3개 질문 모두 "예"

## 참조 문서

- Decision Points 상세: `reference/decision-points.md`
- Edge Cases + Halt Forecast: `reference/edge-cases.md`
- plan.md 템플릿: `reference/plan-template.md`
