---
name: design
description: 아키텍처 설계. 다중 에이전트 독립 설계 → 합의 → 검증 → 영향도 분석.
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# Architecture Design

아키텍처 설계 스킬. 큰 기능 추가나 구조 변경 전 `/design`으로 호출.

## 1. 사전 분석
1. 디렉토리 트리 전체 스캔 + 진입점(main, index, app) 식별.
2. 대상 모듈의 의존 관계 추적 (import/DI 흐름).
3. 레이어 구조 파악: presentation → application → domain → infrastructure.
4. 기존 디자인 패턴 식별 (Repository, Factory, Strategy, Observer 등).
5. 기존 패턴 추출: 네이밍, 에러 처리, DI 방식.
6. 기능/비기능 요구사항 정리. 기존 아키텍처의 제약 사항 명시.

## 2. 설계 루프

→ ~/.claude/rules/round-agent-protocol.md 적용.

메인 세션은 thin orchestrator로 동작한다. 매 iteration마다 DesignRoundAgent subagent를 생성하여 설계 작업을 위임한다.

### 메인 세션 역할
- Phase 1(사전 분석) 수행 (1회성).
- 매 iteration마다 DesignRoundAgent dispatch.
- 추적 상태: round_number, verdict, critical_issues, modification_approaches.
- verdict == PASS → 설계안 제출로.
- verdict == FAIL → 다음 iteration의 DesignRoundAgent dispatch.
- 2회 반복 후에도 FAIL → 현재까지의 합의안 + 미해결 쟁점을 사용자에게 제시하고 판단 요청.
- escalation → round-agent-protocol.md의 Cross-Round Escalation 적용.

### DesignRoundAgent (subagent)

메인으로부터 수신:
- 요구사항 + 사전 분석 결과
- iteration 2+: 이전 합의안 텍스트 + 이전 critical issue 제목 (도출 과정/개별 설계안은 미전달)

내부에서 수행:

#### Design Step 1: 독립 설계
- 복수의 sub-subagent를 병렬 생성한다.
- 각 agent에게 동일한 요구사항 + 사전 분석 결과를 전달하되, 서로의 존재는 알리지 않는다.
- 각 sub-subagent는 독립적으로 설계안을 제시한다.

#### Design Step 2: 합의안 도출
- Round Agent가 설계안들을 비교하여 합의안을 도출한다:
  - 공통점: 높은 신뢰도로 채택.
  - 차이점: 각 근거를 비교하여 우위를 판단하고, 판단 근거를 명시.
  - 모두 다르면: 각 안의 trade-off를 정리하여 ESCALATE verdict로 반환.

#### Design Step 3: 합의안 검증
- 합의안을 새 sub-subagent에게 전달하여 독립 검증한다 (도출 과정은 전달하지 않는다).
- 검증 관점: ~/.claude/rules/principles.md의 SOLID/구현 규칙 위반, 기존 아키텍처와 충돌, 구현 불가능한 부분, 누락된 엣지케이스.
- 검증 결과:
  - 문제 없음 → Design Step 4로.
  - 문제 있음 → FAIL verdict로 반환. critical_issues + modification_approaches 포함.

#### Design Step 4: 변경 영향도 분석
- 직접 수정 파일 목록.
- 간접 영향 파일 (import하는 곳).
- 테스트 수정/추가 필요 범위.
- 마이그레이션 필요 여부.

메인에 반환:
- verdict: PASS | FAIL | ESCALATE
- critical_issues, modification_approaches (round-agent-protocol.md 형식)
- consensus: 합의안 텍스트
- decision_rationale: 핵심 설계 결정 근거 (1~2문장씩)
- impact_analysis: 변경 영향도 (PASS인 경우)
- round_summary_path: 디스크에 기록한 라운드 상세
- summary: 요약

## 3. 설계안 제출
- 선택한 대안 + 선택 근거.
- 파일/클래스 단위 변경 명세.
- 구현 순서 (의존성 순).
- 리스크 및 롤백 전략.
- 설계안을 보고하고 종료한다. 구현하지 않는다. 구현은 사용자가 `/coding` 또는 `/sprint`로 별도 진행한다.

## 원칙
- 기존 아키텍처를 최대한 존중. 새 패턴 도입 시 기존 패턴과의 공존 방안 명시.
- 과도 설계 금지. 현재 요구사항에 필요한 만큼만.

## 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md 참조.
