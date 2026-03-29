---
name: coding
description: 프로덕션 코딩. 구현 + 빌드/테스트 검증 + 독립 리뷰 라운드 루프.
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

메인 세션은 thin orchestrator로 동작한다. 구현 완료 후 검증 루프의 각 라운드를 CodingRoundAgent subagent에 위임한다. 에러 0일 때만 완료 보고.

### 메인 세션 역할
- 최초 구현을 수행한다.
- 매 라운드마다 CodingRoundAgent dispatch.
- 추적 상태: round_number, verdict, critical_issues, modification_approaches.
- verdict == PASS → 완료 보고.
- verdict == FAIL → 다음 라운드의 CodingRoundAgent dispatch.
- escalation → round-agent-protocol.md의 Cross-Round Escalation 적용.

### CodingRoundAgent (subagent)

메인으로부터 수신:
- 변경된 파일 경로
- 요구사항 / 구현 명세
- review.md, principles.md 참조 지시

내부에서 수행:

#### Step 1: 자기 검증
- 빌드 실행하여 통과 확인. 실패 시 Step 2로 넘어가지 않는다.
- 타입체크 실행하여 에러 0 확인.
- 테스트 실행하여 전체 통과 확인. 테스트가 없으면 작성 후 실행.
- 실제 실행하여 의도한 동작이 되는지 확인 (API면 호출, UI면 렌더링, CLI면 실행).
- 기존 코드와 스타일 일관성 확인.
- 새 의존성 추가 시 사용자에게 고지.
- 위 항목 중 하나라도 실패하면 수정 후 Step 1을 처음부터 다시 수행 (내부 반복 허용).

#### Step 2: 독립 리뷰 (sub-subagent)
- 리뷰 전용 sub-subagent를 생성한다.
- sub-subagent에게 변경된 파일 경로만 전달한다. 구현 의도/과정은 전달하지 않는다.
- sub-subagent에게 ~/.claude/rules/review.md와 ~/.claude/rules/principles.md를 읽고 기준으로 삼으라고 지시한다.
- sub-subagent는 코드만 보고 판단한다.
- Critical 또는 Major가 없으면 → PASS verdict로 반환.
- 있으면 → Step 3으로.

#### Step 3: 수정 후 재검증
- Critical/Major 지적 사항을 수정한다.
- Step 1을 처음부터 다시 수행한다 (내부 반복).
- **Step 2(독립 리뷰)는 라운드당 1회만 수행한다. 2nd 리뷰가 필요하면 FAIL verdict로 반환.**

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
