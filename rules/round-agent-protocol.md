# Round Agent Protocol

라운드 기반 workflow에서 메인 세션과 Round Agent의 역할을 규정한다.
직접 참조하는 skill: design, coding, sprint, refactor, paper, paper_submit.
(paper_exam은 자체적으로 라운드 기반이 아니나, paper_submit 내에서 Round Agent로 감싸여 실행된다.)

## 상태 파일 규약

라운드 상태는 메인 세션의 context가 아닌 **디스크 상태 파일**로 관리한다. 이를 통해 메인 세션의 context 누적 → compaction → 상태 유실 문제를 아키텍처로 방지한다.

### 위치
- 프로젝트 skill (coding, design, sprint, refactor): `{project_root}/.claude/state/{skill}-{YYYYMMDD-HHmmss}.json`
- 글로벌 skill (paper, paper_submit): `~/.claude/state/{skill}-{YYYYMMDD-HHmmss}.json`
- 디렉토리가 없으면 생성한다.

### 공통 스키마
```json
{
  "skill": "coding",
  "created_at": "2026-03-29T12:00:00",
  "requirements": "요구사항 요약 (1회 기록, 이후 불변)",
  "round_number": 2,
  "current_verdict": "FAIL",
  "critical_issues": ["[Section]:[Category]:[keyword]"],
  "rounds": [
    {
      "round": 1,
      "verdict": "FAIL",
      "critical_issues": ["..."],
      "modification_approaches": [{ "issue": "...", "approach": "..." }],
      "round_summary_path": "/path/to/round-001-summary.md"
    }
  ],
  "artifact_paths": {}
}
```

### skill별 artifact_paths
- design: `consensus`, `decision_rationale`, `impact_analysis`
- coding: `modified_files`
- paper: `paper_file_path`, `outline_file_path`
- paper_submit: `paper_file_path`, `exam_report_path`

## 메인 세션 (Thin Loop)

메인 세션은 **thin loop**로 동작한다. 라운드 작업을 직접 수행하지 않고, 매 라운드마다 fresh Agent를 생성하여 위임한다. 이를 통해 메인 context에 라운드 상세가 쌓이지 않는다.

### Thin Loop 절차

```
1. 상태 파일 생성 (최초 1회 — requirements + artifact_paths 초기값 기록)
2. loop:
   a. 상태 파일을 Read로 읽는다. **자신의 메모리가 아닌 파일 내용만을 신뢰한다.**
   b. current_verdict == PASS → 완료 보고 후 종료.
   c. Cross-Round Escalation 체크 (아래 섹션 참조).
   d. fresh OrchestratorAgent를 Agent tool로 생성한다.
      - 전달: 상태 파일 경로 + skill별 추가 지시.
      - OrchestratorAgent가 내부에서 작업 수행 → 상태 파일 갱신 → 반환.
   e. goto 2.
```

### 메인이 하는 것
- 상태 파일 읽기/쓰기 (최초 생성 + verdict 확인)
- Escalation 체크 (상태 파일의 rounds 배열 비교)
- OrchestratorAgent dispatch
- 사용자에게 라운드 번호, verdict, Critical issue 제목 보고

### 메인이 하지 않는 것
- 분석, 수정, 리뷰, 설계 — 모두 OrchestratorAgent에 위임
- 라운드 상세를 context에 보유

## OrchestratorAgent

메인이 매 라운드마다 생성하는 **fresh Agent**. 상태 파일을 읽고, 작업을 수행하고, 상태 파일을 갱신한다.

### 절차
1. 상태 파일을 Read로 읽어 현재 상태를 파악한다.
2. skill별 작업을 수행한다 (내부에서 sub-subagent 생성 가능).
3. 상태 파일을 갱신한다: `round_number` 증가, 새 라운드를 `rounds` 배열에 추가, `current_verdict`/`critical_issues`/`artifact_paths` 업데이트.
4. 라운드 상세를 별도 파일(`round_summary_path`)에 기록한다.
5. 메인에 verdict + summary를 반환한다.

### 수신
- 상태 파일 경로
- skill별 추가 지시 (review.md, principles.md 참조 등)

### 제약
- 이전 라운드의 리뷰/수정/분석 컨텍스트를 수신하지 않는다. 상태 파일의 `rounds` 배열만 참조.
- 내부에서 sub-subagent를 생성할 수 있다 (최대 nesting depth 1 — main → OrchestratorAgent → sub-subagent까지).

### 상태 파일 갱신 형식
라운드 완료 시 아래 필드를 `rounds` 배열에 추가:
```json
{
  "round": N,
  "verdict": "PASS | FAIL | ESCALATE",
  "critical_issues": ["[Section]:[Category]:[keyword]"],
  "modification_approaches": [{ "issue": "...", "approach": "..." }],
  "round_summary_path": "/path/to/round-N-summary.md"
}
```
skill별 추가 필드를 `artifact_paths`에 갱신한다 (예: design의 `consensus`, coding의 `modified_files`).

## 라운드 모델

### 단일 OrchestratorAgent 모델
하나의 fresh OrchestratorAgent가 분석/수정을 모두 수행하고 상태 파일을 갱신한다.
적용: design, coding, sprint, refactor.

### Review + Revision 분리 모델
한 라운드 안에서 ReviewOrchestratorAgent(리뷰 전담)와 RevisionOrchestratorAgent(수정 전담)를 순차 dispatch한다. 각각 fresh Agent.
- ReviewOrchestratorAgent: 상태 파일에 verdict, critical_issues, review_report_path 기록.
- RevisionOrchestratorAgent: 상태 파일에 modification_approaches, 수정된 artifact_paths 기록.
- 메인은 상태 파일을 Read하여 라운드 상태를 확인한다.
적용: paper (Phase 3), paper_submit (Round 2+).

## Cross-Round Escalation

메인이 **상태 파일의 `rounds` 배열**에서 마지막 2개 라운드의 `modification_approaches`를 비교한다:
1. 동일 `issue` + 동일/유사 `approach`가 2 consecutive rounds → escalation.md 적용.
2. 동일 `issue` + 다른 `approach` → 아직 다른 접근이므로 계속 진행.
3. escalation 발동 시 메인은 issue title + artifact 파일 경로 + 이전 approach 요약(사실만)을 전달한다.
