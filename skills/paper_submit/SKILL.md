---
name: paper_submit
description: 논문 작성→심사→수정→재심사를 Accept까지 반복. /paper + /paper_exam 자동 체이닝.
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Write, Glob, Grep, Bash, Agent, Skill
disable-model-invocation: true
---

# Paper Submit

논문 작성 → 심사 → 수정 → 재심사를 Accept까지 반복하는 오케스트레이션 스킬.
`/paper_submit`으로 호출. `/paper` + `/paper_exam`을 자동 체이닝한다.

→ ~/.claude/rules/round-agent-protocol.md 적용.

## 입력
`/paper`와 동일. 핵심 기여, 소스 자료, 타겟 venue 등.

## 오케스트레이션 원칙

메인 세션은 thin orchestrator로 동작한다.
- 라운드 간 보유 상태: round_number, verdict, paper_file_path, critical_issues (현재 + 이전), modification_approaches (현재 + 이전).
- 각 라운드는 독립 Round Agent가 내부에서 완결한다.
- 분석 context는 라운드 간 전달되지 않는다.

## 프로세스

### Round 1: 초고 작성
- Skill tool로 `/paper`를 직접 호출하여 전체 프로세스(Phase 0~4)를 실행한다.
- Phase 3(작성 중 검증)을 통과한 논문이 산출물.
- paper_file_path를 수신하고 Round 2로.

### Round 2+: 심사 → 수정 루프

매 라운드마다 독립적으로 수행한다. 이전 라운드의 심사 결과, 수정 내역, 컨텍스트를 일절 전달하지 않는다.

#### Step 1: 심사
- Skill tool로 `/paper_exam`을 직접 호출한다 (paper_file_path + 타겟 venue 전달).
- `/paper_exam` Phase 4 보고서를 수신한 후, 프로토콜 형식으로 변환한다:
  - 최종 판정 → `verdict` (Accept 이상 = PASS, Borderline 이하 = FAIL)
  - 약점 Critical/Major → `critical_issues` (`[Section]:[Category]:[keyword]` 형식)
  - Phase 4 보고서 전문 → `exam_report_path` (디스크 파일)
  - 요약 → `round_summary_path`

#### Step 2: 판정 확인 (메인이 수행)
- **Accept 이상** (Strong Accept / Accept): 종료 → 최종 보고로.
- **Weak Accept + Critical 0**: Accept를 목표로 Step 3으로 자동 진행한다. 단, 직전 라운드도 Weak Accept + Critical 0이었으면 개선 여지가 낮으므로 사용자에게 투고/계속 여부를 확인한다.
- **Borderline 이하**: Step 3으로.

#### Step 3: 수정
- RevisionRoundAgent subagent를 생성한다.
- 전달: paper_file_path + exam_report_path (디스크 파일).
- RevisionRoundAgent 내부: exam 보고서 기반 수정 + `/paper`의 Phase 3 Step 1(자기 검증) 적용.
- Critical → Major → Minor 순으로 수정.
- 수신: modified_file_path + modification_approaches + round_summary_path.
- 수정 완료 후 Step 1로 (새 라운드).

### 라운드 독립성
- 라운드 횟수 제한 없음. Accept까지 계속한다.
- 각 라운드는 독립적으로 실행된다 (Skill 호출 또는 Round Agent).
- 메인 세션은 verdict와 critical_issues, modification_approaches만 보유한다.
- Round Agent 내부의 심사 보고서, 수정 과정은 메인에 반환되지 않는다.
- 라운드별 상세는 round_summary_path 파일로 디스크에 기록된다.

### 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md 참조.
- 메인이 critical_issues + modification_approaches를 라운드 간 비교한다.
- 동일 issue + 동일/유사 approach가 2 consecutive rounds → escalation.md 적용.
- 매몰 방지 에스컬레이션 시 사용자에게 선택지 제시:
  1. 새 subagent에게 해당 이슈 위임
  2. 타겟 venue 변경
  3. 핵심 기여 재정의 후 대폭 수정
  4. 현재 상태로 투고
  5. 중단

---

## 최종 보고

Accept 도달 시 아래를 제출:
- **최종 논문 파일 경로**.
- **라운드별 심사 이력**: 각 round_summary_path 파일을 수집. 메인은 verdict 목록만 직접 보유.
- **최종 심사 보고서**: 마지막 ExamRoundAgent의 exam_report_path.
- **투고 체크리스트**:
  - [ ] venue 포맷/페이지 제한 준수
  - [ ] 참고문헌 완결성
  - [ ] Figure/Table 해상도
  - [ ] 저자 정보, acknowledgment
  - [ ] supplementary material (코드, 데이터)
- 커밋/제출 여부는 사용자가 결정.

## 규칙
- 각 라운드 시작/종료 시 사용자에게 진행 상황 보고.
- 라운드 간 사용자 승인 없이 자동 진행한다 (Accept까지). 단, 매몰 방지 에스컬레이션은 멈추고 사용자 판단을 기다린다.
- `/paper`와 `/paper_exam`의 규칙을 각각 해당 Phase에서 준수한다.
