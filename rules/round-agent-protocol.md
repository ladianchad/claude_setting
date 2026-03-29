# Round Agent Protocol

라운드 기반 workflow에서 메인 세션과 Round Agent의 역할을 규정한다.
직접 참조하는 skill: design, coding, sprint, refactor, paper, paper_submit.
(paper_exam은 자체적으로 라운드 기반이 아니나, paper_submit 내에서 Round Agent로 감싸여 실행된다.)

## 메인 세션 (Orchestrator)

1. Round Agent에게 substantive work를 위임한다. 메인은 직접 분석/수정/리뷰하지 않는다.
2. 메인이 추적하는 상태:
   - `round_number`
   - `verdict`: PASS | FAIL | ESCALATE
   - `critical_issues`: `["[Section]:[Category]:[keyword]", ...]`
   - `modification_approaches`: `[{ issue, approach }]`
   - 주요 산출물 경로 (skill별: coding → `modified_files`, paper → `paper_file_path`, design → `consensus` 텍스트 등)
   - `round_summary_path`
3. 메인이 추적하지 않는 것:
   - 리뷰 세부사항, 수정 과정, 내부 subagent 분석, 개별 설계안
4. 사용자에게 보고하는 것:
   - 라운드 번호, verdict, Critical issue 제목, 진행 요약

## Round Agent

1. 수신: artifact 파일 경로 + 원본 요구사항 + task config.
2. 이전 라운드의 리뷰/수정/분석 컨텍스트를 수신하지 않는다.
3. 내부에서 sub-subagent를 생성할 수 있다 (최대 nesting depth 1 — main → Round Agent → sub-subagent까지).
4. 라운드 상세를 디스크 파일로 기록한다 (`round_summary_path`).
5. 기본 반환 필드:
   - `verdict`: PASS | FAIL | ESCALATE
   - `critical_issues`: `["[Section]:[Category]:[keyword]", ...]`
   - `modification_approaches`: `[{ issue: "[Section]:[Category]:[keyword]", approach: "1줄 요약" }]`
   - `modified_files`: string[]
   - `round_summary_path`: string
   - `summary`: string
6. skill별 추가 반환 필드를 허용한다. 각 SKILL.md에서 정의한다 (예: design의 `consensus`, `decision_rationale`, `impact_analysis`).

## 라운드 모델

### 단일 Round Agent 모델
하나의 Round Agent가 분석/수정을 모두 수행하고 반환한다.
적용: design, coding, sprint, refactor.

### Review + Revision 분리 모델
한 라운드 안에서 ReviewRoundAgent(리뷰 전담)와 RevisionRoundAgent(수정 전담)를 순차 dispatch한다.
- ReviewRoundAgent 반환: `verdict`, `critical_issues`, `review_report_path`, `round_summary_path`, `summary`. (`modification_approaches`는 리뷰 단계에서 생성하지 않는다.)
- RevisionRoundAgent 반환: `modified_files`, `modification_approaches`, `round_summary_path`, `summary`.
- 메인은 양쪽 반환을 조합하여 라운드 상태를 갱신한다.
적용: paper (Phase 3), paper_submit (Round 2+).

## Cross-Round Escalation

메인이 `modification_approaches`를 라운드 간 비교한다:
1. 동일 `issue` + 동일/유사 `approach`가 2 consecutive rounds → escalation.md 적용.
2. 동일 `issue` + 다른 `approach` → 아직 다른 접근이므로 계속 진행.
3. escalation 발동 시 메인은 issue title + artifact 파일 경로 + 이전 approach 요약(사실만)을 전달한다.
