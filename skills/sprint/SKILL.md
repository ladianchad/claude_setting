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

### 소규모 (10줄 미만)
바로 구현 → 빌드/테스트 통과 확인 후 완료.

### 중규모/대규모 (10줄 이상): `/coding` 호출

Skill tool로 `/coding`을 호출하여 구현을 위임한다.
- 전달: 확정 설계안 (변경 명세 + 구현 순서) + 빌드/테스트 명령.
- `/coding`이 내부에서 병렬 구현 + 통합 + 병렬 리뷰 검증 루프를 수행한다.
- `/coding` 완료 후 결과(modified_files, summary)를 수신하여 Phase 4로.

---

## Phase 4: 완료 보고

- 요구사항 대비 구현 결과 매핑 (요구사항 항목별 충족 여부).
- 변경된 파일 목록 + 핵심 변경 내용.
- 설계안 대비 달라진 점이 있으면 명시 및 사유.
- 미구현 항목이 있으면 사유 명시.
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
