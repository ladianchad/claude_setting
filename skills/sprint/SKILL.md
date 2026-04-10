---
name: sprint
description: 요구사항 파일 → 설계 → 구현 → 검증 원스톱 수행.
argument-hint: [요구사항파일경로]
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent, Skill
disable-model-invocation: false
---

# Sprint

요구사항 파일을 받아 설계 → 구현 → 검증까지 원스톱 수행. `/sprint <파일경로>`로 호출.

## 입력
- 요구사항 파일 경로 (.md 등)를 인자로 받는다.
- 파일을 읽고 기능/비기능 요구사항을 추출한다.
- **Design 연계**: 사용자가 design 상태 파일 경로를 명시적으로 전달한 경우에만 해당 설계안을 요구사항으로 사용하고, Phase 2(설계)를 건너뛰고 바로 Phase 3(구현)으로 진행한다. 경로 없이 "설계안 구현"이라고만 하면 경로를 질문한다. **자동으로 state 디렉토리를 탐색하지 않는다.**

## 스케일링 판단
요구사항을 분석하여 규모를 판단한다:
- **소규모** (단일 파일 수정, 10줄 미만 예상): 설계 생략 → 바로 구현.
- **중규모** (복수 파일 수정 또는 10줄 이상): 간소 설계 → 구현.
- **대규모** (구조 변경, 새 모듈 추가, 다중 파일 연쇄 변경): 전체 설계 → 구현.

판단 기준: 변경 파일 수, 새 클래스/모듈 생성 여부, 기존 인터페이스 변경 여부.

---

## Phase 1: 사전 분석 (모든 규모)

1. 요구사항 파일을 읽고 핵심 요구사항을 정리한다.
2. 디렉토리 트리 스캔 + 진입점 식별.
3. 대상 모듈의 의존 관계 추적.
4. 기존 패턴 추출: 네이밍, 에러 처리, DI 방식, 레이어 구조.
5. 기존 아키텍처의 제약 사항 명시.
6. **Pre-existing 이슈 사전 스캔**: 작업 대상 파일/모듈에 이미 존재하는 pre-existing error, legacy, dead code를 식별해 목록화한다. `/coding` 의 Step 3 Static Analysis 블록과 동일 범위로 baseline 스캔을 1회 실행하여 기록한다:
   - 빌드 / 파서 에러
   - 타입체크 (tsc, mypy, clippy 등)
   - 린터 (eslint, ruff, golangci-lint, shellcheck 등)
   - 포매터 (prettier, black, gofmt, rustfmt 등)
   - 복잡도 (프로젝트가 임계값을 설정해둔 경우)
   - 기존 테스트 커버리지 현황 (변경 대상 파일 기준)

   도구 탐색 원칙은 `/coding` 의 Step 3 Static Analysis와 동일: 프로젝트 기존 스크립트 우선 → 없으면 언어 표준 도구 도입. baseline 스캔 결과는 Phase 3 `/coding` 호출 시 "정적 분석 명령 + baseline 에러 목록" 형태로 함께 전달한다. 이 목록은 ~/.claude/rules/principles.md "Pre-existing 문제 처리" 절차에 따라 처리된다 (사용자 명시 제외 지시가 없는 한 수정 대상에 포함).

---

## Phase 2: 설계

→ ~/.claude/rules/round-agent-protocol.md 적용 (중규모/대규모). Thin Loop + 상태 파일 규약.

### 소규모: 생략
사전 분석 결과만으로 바로 Phase 3으로.

### 중규모: 간소 설계
- 상태 파일을 생성하고 DesignOrchestratorAgent 1개를 dispatch한다.
- OrchestratorAgent 내부: 단독 설계안 작성 + sub-subagent 1개로 검증. 상태 파일 갱신.
- 문제 없으면 PASS. 문제 있으면 수정 후 재검증 1회.
- FAIL로 반환 시 사용자에게 제시하고 판단 요청.

### 대규모: 전체 설계
- Skill tool로 `/design`을 직접 호출하여 전체 설계 프로세스를 실행한다.
- `/design`이 내부에서 DesignRoundAgent를 활용하여 독립 설계 + 합의 + 검증을 수행한다.
- 설계안 제출 결과(합의안 + decision_rationale + impact_analysis)를 수신한다.

### 설계안 제출 (중규모/대규모 공통)
- 변경 명세 (파일/클래스/함수 단위).
- 구현 순서 (의존성 순).
- 리스크 및 롤백 전략 (대규모만).
- 요구사항이 명확하고 설계안이 자명하면 Phase 3으로 자동 전환한다.
- 트레이드오프가 있거나 요구사항 해석이 갈리는 경우에만 사용자에게 핵심 결정 사항을 제시하고 승인을 받는다.

### Phase 2 → Phase 3 전환 시 정보 전달
- **전달**: 확정 설계안 (변경 명세 + 구현 순서 + 리스크) + 핵심 설계 결정 근거 (decision_rationale).
- **차단**: 대안으로 검토했다가 버린 설계안, 합의 과정의 논쟁, 개별 subagent 설계안.

---

## Phase 3: 구현

→ ~/.claude/rules/round-agent-protocol.md 적용 (중규모/대규모).

설계안의 구현 순서에 따라 순차 구현. 모든 변경은 ~/.claude/rules/principles.md를 준수.

### Pre-existing 이슈 처리 (모든 규모 공통)
Phase 1 단계 6에서 수집한 목록 + 구현 과정에서 추가로 발견된 항목을 ~/.claude/rules/principles.md "Pre-existing 문제 처리" 절차에 따라 분류한다:
- **강결합 소규모**: 현재 기능 커밋에 포함.
- **독립 중간 규모**: sub-task로 별도 커밋 (같은 sprint 세션 내). `/coding` 호출 시 "pre_existing_subtasks" 항목으로 요구사항에 함께 전달한다.
- **대규모**: 현재 sprint가 완료된 후, Phase 4 보고 직전에 Skill tool로 별도 `/sprint` 를 sequential 하게 호출하여 처리한다. 요구사항 파일은 즉석에서 작성 (원본 요구사항과 구분되는 별도 .md 임시 파일).
- **사용자가 제외 지시한 항목**: 수정 금지. Phase 4 보고에만 포함.

사용자가 "현재 작업 범위만 해달라" 고 **명시적으로** 말했다면 Phase 1의 목록을 보고만 하고 수정하지 않는다. 명시적 지시 없이 자의적으로 "범위 밖"을 판단하지 않는다.

### 소규모 (10줄 미만)
바로 구현 → 빌드/테스트 통과 확인 후 완료. Phase 1의 pre-existing 목록이 있으면 위 분류에 따라 함께 처리.

### 중규모/대규모 (10줄 이상): `/coding` 호출

Skill tool로 `/coding`을 호출하여 구현을 위임한다.
- 전달:
  - 확정 설계안 (변경 명세 + 구현 순서)
  - 빌드/테스트 명령
  - **정적 분석 명령 세트**: Phase 1 baseline 스캔에서 확인한 빌드/타입체크/린터/포매터/복잡도 도구 명령어. 프로젝트에 설정이 없어 `/coding` 측에서 도입해야 하는 경우 그 사실도 명시.
  - **Phase 1에서 수집한 pre-existing 이슈 목록 및 분류 (강결합/sub-task)**
- `/coding`이 내부에서 병렬 구현 + 통합 + 병렬 리뷰 검증 루프를 수행한다.
- `/coding` 완료 후 결과(modified_files, static_analysis_report, coverage_report, pre_existing_handled, summary)를 수신.
- 대규모로 분류된 pre-existing 이슈가 있으면 여기서 sequential `/sprint` 를 추가 호출한 뒤 Phase 4로.

---

## Phase 4: 완료 보고

- 요구사항 대비 구현 결과 매핑 (요구사항 항목별 충족 여부).
- 변경된 파일 목록 + 핵심 변경 내용.
- 설계안 대비 달라진 점이 있으면 명시 및 사유.
- 미구현 항목이 있으면 사유 명시.
- **Pre-existing 이슈 처리 결과**: Phase 1에서 발견한 항목별로 처리 방식 (같은 커밋 / sub-task 커밋 / sequential sprint / 사용자 제외 / 미처리). 미처리가 있으면 사유 명시.
- 커밋 여부를 사용자에게 확인. 자동 커밋하지 않는다.

---

## 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md 참조.
설계(Phase 2)와 구현(Phase 3) 각각 독립적으로 escalation을 추적한다.

## 원칙
- 모든 변경: ~/.claude/rules/principles.md 준수.
- 프로젝트에 `.claude/rules/workflow.md`가 있으면 해당 Git 워크플로우를 따른다.
- 기존 아키텍처를 최대한 존중. 새 패턴 도입 시 기존 패턴과의 공존 방안 명시.
- 과도 설계 금지. 현재 요구사항에 필요한 만큼만.
- Phase 간 전환 시 확정 산출물(설계안 텍스트 + decision_rationale)만 전달한다. 과정은 전달하지 않는다.

## Worktree CWD 준수

Claude Code의 sub-agent/Skill 호출은 프로세스 분리가 없어 부모의 working directory가 자동 전파되지 않는다. 호출자가 특정 worktree (예: `iteration` skill의 per-item agent) 내에서 sprint를 실행한 경우, 명시적으로 CWD를 다루지 않으면 Phase 2/3의 하위 sub-agent가 원 체크아웃 경로로 파일을 기록하여 **worktree 누수**가 발생한다.

절차:
1. Phase 1 시작 시 `git rev-parse --show-toplevel`로 현재 worktree 루트를 확정하고 `$WORKTREE_ROOT` 로 부른다.
2. Phase 2(/design) 및 Phase 3(/coding) 호출 시, 요구사항 전달 내용 최상단에 `worktree_root: {절대경로}` 를 명시한다. 하위 skill은 이 경로를 수신하여 모든 Edit/Write/Bash를 이 경로 기준 절대 경로로 수행해야 한다.
3. Phase 3 완료 직후, `git -C {원 체크아웃 경로} status --porcelain` 이 비어있는지 확인한다. 비어있지 않으면 호출자에게 누수 사실을 보고한다 (sprint 자신은 복구하지 않는다; 복구는 호출자의 책임).
4. 호출자가 worktree 개념 없이 main repo에서 직접 sprint를 실행한 경우에는 이 절차를 건너뛴다.
