---
name: coding
description: 프로덕션 코딩. 병렬 구현 + 통합 + 다관점 병렬 리뷰 라운드 루프.
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
disable-model-invocation: false
---

# Production Coding

프로덕션 코딩 스킬. `/coding`으로 호출하여 코딩 모드 진입.

## Design 연계
사용자가 "설계안 구현" 등으로 호출하며 **design 상태 파일 경로를 명시적으로 전달한 경우에만** 해당 파일을 읽어 구현 명세로 사용한다.
- 경로가 없으면 사용자에게 질문한다. **자동으로 state 디렉토리를 탐색하지 않는다.**
- `/design` 완료 시 보고된 상태 파일 경로를 사용자가 그대로 전달하는 것을 기대한다.

## 스케일링
- 모든 변경: ~/.claude/rules/principles.md 준수.
- 10줄 미만 단순 수정: 바로 실행 → 빌드/테스트 통과 확인 후 완료.
- 10줄 이상: 아래 검증 루프 적용.
- 100줄 이상 또는 구조 변경: /design (다중 에이전트 합의) 먼저 → 승인 후 구현.

## Pre-existing 이슈 취급 (모든 규모 공통)

작업 중 발견한 pre-existing error / legacy / dead code는 ~/.claude/rules/principles.md "Pre-existing 문제 처리" 에 따라 **사용자 명시 제외 지시가 없는 한 수정 대상에 포함**한다.

- 구현 시작 전: 대상 파일/모듈에 baseline 스캔 (빌드, 타입체크, 린터) 1회 실행해 기존 에러 목록을 확보한다. 신규 도입 에러와 구분하기 위함.
- sprint가 상위에서 호출한 경우: 상위에서 전달된 pre-existing 이슈 목록 + 분류 (강결합/sub-task) 를 그대로 사용.
- 분류 처리:
  - **강결합 소규모**: 현재 구현 커밋에 포함.
  - **독립 중간 규모**: sub-task 커밋으로 분리. 같은 `/coding` 세션 안에서 완료. 커밋 메시지 prefix `chore:` 또는 `fix:`.
  - **대규모**: `/coding` 자체적으로 처리하지 않는다. 요구사항에 "대규모 pre-existing" 항목이 포함된 경우, 최종 리턴 시 "sequential sprint 필요" 플래그로 보고하고 호출자(sprint)에게 위임한다.
- 최종 반환 시 modified_files와는 별도로 **pre_existing_handled** 필드에 처리 결과를 명시한다.

## 검증 루프 (10줄 이상 변경 시 필수)

→ ~/.claude/rules/round-agent-protocol.md 적용 (Thin Loop + 상태 파일 규약).

### 메인 세션 (Thin Loop)
1. 상태 파일 생성: requirements에 구현 명세 + 대상 파일 경로 기록.
2. loop:
   a. 상태 파일 Read → `current_verdict` 확인.
   b. PASS → 완료 보고.
   c. Cross-Round Escalation 체크 (상태 파일의 `rounds` 배열 비교).
   d. fresh CodingOrchestratorAgent dispatch (상태 파일 경로 + review.md, principles.md 참조 지시).
   e. goto 2.

### CodingOrchestratorAgent (fresh Agent)

상태 파일에서 수신:
- requirements (구현 명세 + 대상 파일 경로)
- 최신 라운드의 critical_issues (수정/리뷰 과정은 미수신)

내부에서 수행:

#### Step 1: 병렬 구현
- 복수의 sub-subagent를 병렬 생성한다.
- 각 agent에게 동일한 요구사항 + 코드베이스 컨텍스트를 전달하되, 서로의 존재는 알리지 않는다.
- 각 sub-subagent는 독립적으로 구현한다.
- **WORKDIR 준수**: 요구사항 또는 상태 파일에 `worktree_root: {절대경로}` 가 명시되어 있으면, 모든 sub-subagent에게 "모든 Edit/Write/Bash 대상 경로는 `{worktree_root}` 기준 **절대 경로**로 작성하고, Bash 명령은 `{worktree_root}` 에서 실행한다" 는 지침을 함께 전달한다. Claude Code의 sub-agent는 기본 CWD가 원 체크아웃이므로, 명시적 전달이 없으면 병렬 구현체가 원 repo에 기록될 수 있다 (worktree 누수).
- WORKDIR 지정이 없으면 프로젝트 루트 기준으로 동작한다.

#### Step 2: 구현 통합
- Round Agent가 구현체들을 비교한다:
  - 공통 접근: 높은 신뢰도로 채택.
  - 차이점: 코드 품질, 정확성, 설계 기준으로 우위를 판단하고 근거를 명시.
- 최선의 구현을 선택하거나, 각 구현의 강점을 통합하여 단일 구현을 확정한다.
- 확정된 구현을 실제 파일에 적용한다.

#### Step 3: 자기 검증
아래 블록들을 순서대로 수행한다. 하나라도 실패하면 수정 후 Step 3을 처음부터 다시 수행 (내부 반복 허용). 모두 통과해야 Step 4로 진행한다.

**Static Analysis (전담 sub-subagent)**:
Step 3 시작 시 **StaticAnalysisAgent**라는 전담 sub-subagent 1개를 생성하여 결정론적 정적 분석을 수행한다. 이 agent는 기계적으로 CLI 도구를 실행하고 보고만 담당한다 (판단/해석/수정 금지 — 수정은 Orchestrator가 담당).

StaticAnalysisAgent의 절차:
1. **도구 탐색** (1차): 프로젝트에 이미 설정된 정적 분석 스크립트를 탐색한다.
   - `package.json`의 `scripts` (lint, typecheck, format, check 등)
   - `pyproject.toml` / `setup.cfg` / `tox.ini` (ruff, mypy, pyright, black, flake8)
   - `Cargo.toml` + `clippy` / `rustfmt`
   - `Makefile` / `justfile` / `mise.toml`의 check 타겟
   - `.pre-commit-config.yaml`의 hooks
   - Go: `go vet`, `golangci-lint`, `gofmt`
   - Shell: `shellcheck`
   - 기타 언어: 해당 언어 표준 도구
2. **도구 도입** (2차 fallback): 프로젝트에 설정이 전혀 없으면 언어에 맞는 기본 도구를 프로젝트의 dependency manager 관례에 따라 도입한다 (e.g. `uv add --dev ruff mypy`, `pnpm add -D eslint prettier`, `cargo install`은 프로젝트 의존성에 포함되지 않으므로 rustup component 등 선호). 도입 사실은 최종 보고에 반드시 명시한다.
3. **검사 항목 실행** (아래 순서, 각 항목 실패는 Critical로 처리하여 차단):
   - (a) **빌드 / 파서 에러**: 컴파일 가능 언어는 빌드 실행. 스크립트 언어는 syntax 파싱(e.g. `python -m py_compile`, `node --check`).
   - (b) **타입체크**: `tsc --noEmit`, `mypy`, `pyright`, `clippy`, `javac`, `go vet` 등. 에러 0 확인.
   - (c) **린터**: `eslint`, `ruff check`, `golangci-lint run`, `clippy`, `shellcheck` 등. 경고/에러 0 확인.
   - (d) **포매터**: `prettier --check`, `black --check`, `gofmt -l`, `rustfmt --check` 등. 위반이 있으면 **자동 수정이 가능한 경우** 즉시 적용하고 재검사. 자동 수정 불가(예: whitespace-sensitive 언어의 일부 케이스)하면 실패 처리.
   - (e) **복잡도**: 프로젝트가 이미 임계값을 설정해둔 경우(`radon`, `eslint-plugin-complexity`, `lizard`, `clippy::cognitive_complexity` 등)에만 실행. 설정이 없으면 skip하되, 이번 변경에서 신규 함수 중 명백한 과복잡 함수(cyclomatic > 15 또는 함수 길이 > 100 line 등)가 있으면 보고.
4. **보고**: 각 항목의 명령어, 종료 코드, 요약 결과를 상태 파일 `artifact_paths.static_analysis_report` 경로에 기록하고 Orchestrator에 반환.
5. **범위 제외 항목**: 보안 정적 분석(SAST)은 이 단계에서 다루지 않는다.

StaticAnalysisAgent가 실패를 보고하면 Orchestrator는 직접 수정 후 StaticAnalysisAgent를 재실행한다. 내부 반복은 escalation.md 기준(같은 접근 2회 반복 시)에 도달하면 상태 파일 FAIL 반환.

**테스트 + 커버리지**:
- 테스트 실행하여 전체 통과 확인. 테스트가 없으면 작성 후 실행.
- **커버리지 기준**: ~/.claude/rules/principles.md "테스트 커버리지" 섹션을 적용한다. 즉,
  - **Diff coverage ≥ 90%** (변경/추가한 라인의 90%가 테스트로 실행)
  - AND **변경된 파일 전체 coverage ≥ 90%**
- 프로젝트에 커버리지 도구가 설정되어 있으면 해당 도구를 사용하고, 없으면 언어 표준 도구를 도입(도입 사실 보고 필수) 후 측정한다.
- 미달 시 테스트를 추가하여 충족시킨다.
- **예외 적용**: principles.md "테스트 커버리지 → 예외 사유" 화이트리스트 (thin wrapper / 자동 생성 코드 / 사용자 명시 면제) 에 해당하는 파일/심볼은 기준에서 제외한다. 제외 적용 시 각 항목의 경로 + 사유를 상태 파일 `artifact_paths.coverage_report`에 기록한다.
- 커버리지 수치와 예외 목록은 `artifact_paths.coverage_report` 에 기록.

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
- **맥락적 정적 분석 리뷰어** (ContextualStaticReviewer): 결정론적 도구(Step 3 Static Analysis)가 놓치는 맥락적 문제를 검출한다. Step 3의 StaticAnalysisAgent와 직교하며, linter 설정으로는 잡을 수 없는 항목에 집중한다. ~/.claude/rules/review.md "분석 순서 → 맥락적 정적 분석" 항목 적용.
  - Non-exhaustive switch/match (타입이 union/enum인데 일부 케이스만 처리).
  - 타입 narrowing 누수 (`if`로 좁힌 타입이 콜백/클로저를 지나며 원래 타입으로 되돌아감).
  - 불필요한 cast / assertion (`as T`, `! non-null`, `cast()`).
  - Dead branch (도달 불가능한 분기, 항상 동일한 결과를 반환하는 조건).
  - 변수/파라미터 shadowing.
  - async/await 누락, unhandled Promise, `await` 없는 async 호출.
  - Nullable 체인의 오용 (optional chain 뒤에 non-null assertion 등).

#### Step 5: 리뷰 통합 + 수정
- 세 리뷰어(정확성 / 설계 / 맥락적 정적 분석)의 결과를 통합한다.
- Critical 또는 Major가 없으면 → PASS verdict로 반환.
- 있으면:
  - 지적 사항을 수정한다.
  - Step 3(자기 검증)을 처음부터 다시 수행한다 (내부 반복).
  - **Step 4(병렬 리뷰)는 라운드당 1회만 수행한다. 재리뷰가 필요하면 FAIL verdict로 반환.**

상태 파일 갱신 (round-agent-protocol.md 형식):
- `rounds` 배열에 새 라운드 추가 (verdict, critical_issues, modification_approaches, round_summary_path).
- `artifact_paths.modified_files` 갱신.
- `artifact_paths.pre_existing_handled` 갱신 (처리 항목 목록 + 각 항목의 처리 방식).
- `artifact_paths.static_analysis_report` 갱신 (StaticAnalysisAgent의 각 검사 항목 명령어/종료 코드/요약).
- `artifact_paths.coverage_report` 갱신 (diff coverage %, 파일별 coverage %, 화이트리스트 예외 목록).
- `current_verdict`, `critical_issues` 최신화.
- ESCALATE는 사용하지 않음 — 메인이 cross-round 비교로 escalation 판단.

메인에 반환: verdict + summary + pre_existing_handled + static_analysis_report 경로 + coverage_report 경로 (sequential sprint 필요 항목이 있으면 명시).

## 원칙
- 프로젝트에 `.claude/rules/workflow.md`가 있으면 해당 Git 워크플로우를 따른다.

## 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md 참조.
