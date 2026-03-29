---
name: coding
description: 프로덕션 코딩. 병렬 구현 + 통합 + 다관점 병렬 리뷰 라운드 루프.
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# Production Coding

프로덕션 코딩 스킬. `/coding`으로 호출하여 코딩 모드 진입.

## 스케일링
- 모든 변경: ~/.claude/rules/principles.md 준수.
- 10줄 미만 단순 수정: 바로 실행 → 빌드/테스트 통과 확인 후 완료.
- 10줄 이상: 아래 검증 루프 적용.
- 100줄 이상 또는 구조 변경: /design (다중 에이전트 합의) 먼저 → 승인 후 구현.

## 검증 루프 (10줄 이상 변경 시 필수)

→ ~/.claude/rules/round-agent-protocol.md 적용.

메인 세션은 thin orchestrator로 동작한다. 매 라운드를 CodingRoundAgent subagent에 위임한다. 에러 0일 때만 완료 보고.

### 메인 세션 역할
- 매 라운드마다 CodingRoundAgent dispatch.
- 추적 상태: round_number, verdict, critical_issues, modification_approaches.
- verdict == PASS → 완료 보고.
- verdict == FAIL → 다음 라운드의 CodingRoundAgent dispatch.
- escalation → round-agent-protocol.md의 Cross-Round Escalation 적용.

### CodingRoundAgent (subagent)

메인으로부터 수신:
- 요구사항 / 구현 명세
- 대상 파일 경로
- review.md, principles.md 참조 지시

내부에서 수행:

#### Step 1: 병렬 구현
- 복수의 sub-subagent를 병렬 생성한다.
- 각 agent에게 동일한 요구사항 + 코드베이스 컨텍스트를 전달하되, 서로의 존재는 알리지 않는다.
- 각 sub-subagent는 독립적으로 구현한다.

#### Step 2: 구현 통합
- Round Agent가 구현체들을 비교한다:
  - 공통 접근: 높은 신뢰도로 채택.
  - 차이점: 코드 품질, 정확성, 설계 기준으로 우위를 판단하고 근거를 명시.
- 최선의 구현을 선택하거나, 각 구현의 강점을 통합하여 단일 구현을 확정한다.
- 확정된 구현을 실제 파일에 적용한다.

#### Step 3: 자기 검증
아래 항목을 순서대로 수행한다. 하나라도 실패하면 수정 후 Step 3을 처음부터 다시 수행 (내부 반복 허용). 모두 통과해야 Step 4로 진행한다.

**빌드 + 타입**:
- 빌드 실행하여 통과 확인.
- 타입체크 실행하여 에러 0 확인.

**테스트 + 커버리지**:
- 테스트 실행하여 전체 통과 확인. 테스트가 없으면 작성 후 실행.
- 변경된 코드의 테스트 커버리지가 85% 이상인지 확인한다. 프로젝트에 커버리지 도구가 설정되어 있으면 해당 도구를 사용하고, 없으면 설정 후 측정한다.
- 커버리지 미달 시 테스트를 추가하여 충족시킨다.

**실서비스 실행 검증**:
- 테스트 통과와 별개로, 실제 서비스를 기동하여 에러 없이 동작하는지 확인한다.
- 프레임워크/서비스 유형에 따라 적절한 방법을 선택: 서버면 기동 후 헬스체크/주요 엔드포인트 호출, CLI면 주요 커맨드 실행, 라이브러리면 import 및 주요 함수 호출.
- 기동 시 에러(crash, unhandled exception, 포트 충돌 등)가 발생하면 실패로 처리한다.

**기타**:
- 기존 코드와 스타일 일관성 확인.
- 새 의존성 추가 시 사용자에게 고지.

#### Step 4: 병렬 리뷰
복수의 리뷰 sub-subagent를 병렬 생성한다. 각 리뷰어에게 변경 파일 경로만 전달한다 (구현 의도/과정 미전달).

- **정확성 리뷰어**: 로직 버그, off-by-one, null/undefined, race condition, 엣지케이스. ~/.claude/rules/review.md 기준 적용.
- **설계 리뷰어**: **프로젝트 전체를 탐색**하여 아래 항목을 검출한다. ~/.claude/rules/principles.md 기준 적용.
  - DRY 위반: 변경된 코드와 동일/유사한 로직이 프로젝트 내 다른 곳에 이미 존재하는지 (재사용 가능한 유틸, 헬퍼, 베이스 클래스 등).
  - 기존 추상화 미활용: 프로젝트에 이미 있는 패턴/유틸을 새로 만들었는지.
  - SOLID 위반: 변경이 기존 구조의 SRP, OCP 등을 깨뜨리는지.
  - 일관성: 네이밍, 에러 처리, DI 방식이 기존 코드베이스와 일관되는지.

#### Step 5: 리뷰 통합 + 수정
- 양쪽 리뷰 결과를 통합한다.
- Critical 또는 Major가 없으면 → PASS verdict로 반환.
- 있으면:
  - 지적 사항을 수정한다.
  - Step 3(자기 검증)을 처음부터 다시 수행한다 (내부 반복).
  - **Step 4(병렬 리뷰)는 라운드당 1회만 수행한다. 재리뷰가 필요하면 FAIL verdict로 반환.**

메인에 반환 (round-agent-protocol.md 형식):
- verdict: PASS | FAIL (ESCALATE는 사용하지 않음 — 메인이 cross-round 비교로 escalation 판단)
- critical_issues, modification_approaches
- modified_files
- round_summary_path
- summary

## 원칙
- 프로젝트에 `.claude/rules/workflow.md`가 있으면 해당 Git 워크플로우를 따른다.

## 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md 참조.
