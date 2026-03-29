---
name: evaluate
description: 프로젝트 품질 평가. 다관점 병렬 분석 → 통합 → 진단 보고서 생성. 수정하지 않는다.
argument-hint: [스코프|파일경로]
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Glob, Grep, Bash, Agent
disable-model-invocation: false
---

# Project Evaluation

프로젝트(또는 지정 스코프)의 품질 상태를 진단하는 스킬. `/evaluate`로 호출.
코드를 **수정하지 않는다**. 현재 상태를 평가하고 보고서만 생산한다.

## 입력
- **스코프 미지정**: 프로젝트 전체를 평가.
- **스코프 지정**: 해당 범위만 집중 평가. 파일/디렉토리/모듈명 모두 가능.
- 사용자가 특정 관점을 명시한 경우 (e.g. "보안만 봐줘") 해당 관점에 가중치를 두되, 다른 관점도 최소한으로 점검.

---

## Phase 1: 구조 파악

1. 디렉토리 트리 스캔 + 진입점(main, index, app) 식별.
2. 빌드/테스트 설정 파일 확인 (package.json, pyproject.toml, Makefile, build.gradle 등).
3. 주요 의존성 목록 + 버전 확인.
4. 레이어 구조 파악: presentation → application → domain → infrastructure.
5. 의존 관계 추적 (import/DI 흐름). 순환 의존성 1차 탐지.
6. 테스트 구조 파악: 테스트 파일 존재 여부, 테스트 프레임워크, 커버리지 설정.
7. 기존 디자인 패턴 식별 (Repository, Factory, Strategy, Observer 등).
8. 기존 코드 관습 추출: 네이밍, 에러 처리, DI 방식, 파일 구조.

---

## Phase 2: 다관점 병렬 분석

복수의 분석 subagent를 병렬 생성한다. 각 agent는 서로의 존재를 알지 못한다.
모든 agent는 Phase 1의 구조 파악 결과를 공통으로 수신한다.

### Agent A: 설계 품질 분석
~/.claude/rules/principles.md 기준으로 평가.

**SOLID 위반 탐지**:
- SRP: 변경 이유가 둘 이상인 클래스/모듈. 파일 크기, 메서드 수, import 다양성으로 1차 필터링 → 내용 확인.
- OCP: 조건 분기(if/switch)로 확장하는 패턴.
- LSP: 상속 구조에서 부모 계약 위반.
- ISP: 인터페이스 구현체가 빈 메서드/throw로 구현하는 패턴.
- DIP: 구체 클래스에 직접 의존하는 상위 레이어.
- LoD: 3단계 이상 체이닝.

**구현 규칙 위반 탐지**:
- 구현체가 하나뿐인 인터페이스.
- 에러를 삼키는 catch 블록 (빈 catch, console.log만 있는 catch).
- any 타입 사용.
- Dead code: 미사용 import, 호출되지 않는 함수/클래스. test, plugin, config 등 전체 탐색.
- 중복 코드: 유사한 로직이 복수 위치에 존재.

**구조적 문제 탐지**:
- 순환 의존성.
- God class / God module.
- Feature envy.
- 레이어 위반 (하위 레이어가 상위 레이어를 import).
- 일관성 파괴 (동일 계층 모듈이 서로 다른 패턴 사용).

### Agent B: 아키텍처 일관성 분석

**패턴 일관성**:
- 동일 계층에서 서로 다른 패턴을 사용하는 모듈 식별.
- 네이밍 규칙 이탈 (e.g. 일부만 camelCase, 일부만 snake_case).
- 에러 처리 방식의 불일치.
- DI 방식의 불일치.

**의존성 건강성**:
- 순환 의존성 상세 경로.
- 레이어 위반 경로.
- 불필요한 의존성 (import하지만 실제로 사용하지 않는 모듈).
- 의존성 방향의 역전 (domain이 infrastructure를 직접 import 등).

**모듈 응집도/결합도**:
- 응집도 낮은 모듈: 내부 멤버 간 상호 참조가 적은 모듈.
- 결합도 높은 모듈 쌍: 상호 참조가 과도한 모듈 쌍.

### Agent C: 운영 품질 분석

**테스트 현황**:
- 테스트 파일 존재 비율 (소스 파일 대비).
- 테스트되지 않는 핵심 모듈 식별.
- 테스트 품질: 단순 smoke test vs 의미 있는 assertion.
- 테스트 구조: 단위/통합/E2E 비율.

**빌드/설정 상태**:
- 빌드 정상 통과 여부 (실행 가능 시).
- Lint/타입체크 설정 존재 및 적절성.
- CI/CD 설정 존재 여부.

**의존성 관리**:
- 주요 의존성의 최신 버전 대비 격차.
- deprecated 의존성 사용 여부.
- 보안 취약점이 알려진 버전 사용 여부 (npm audit, pip-audit 등 실행 가능 시).
- lock 파일 존재 여부.

**보안 기본 점검**:
- 시크릿 하드코딩 (API key, password, token 패턴 탐색).
- .gitignore에 .env, 시크릿 파일 포함 여부.
- SQL injection / XSS 취약 패턴 (해당 기술 스택인 경우).

---

## Phase 3: 통합 및 보고서 생성

메인 agent가 모든 분석 결과를 통합한다.

### 3-1. 중복 제거 및 교차 검증
- 복수 agent가 동일 이슈를 지적한 경우 병합. 신뢰도 상승으로 표기.
- Agent 간 모순되는 판단이 있으면 근거를 비교하여 판정.

### 3-2. 심각도 분류
각 발견 사항에 심각도를 부여한다:
- **Critical**: 런타임 에러 유발 가능, 보안 취약점, 데이터 손실 위험, 순환 의존성.
- **Major**: SOLID 위반, God class, 레이어 위반, 테스트 부재(핵심 모듈), 일관성 파괴.
- **Minor**: 네이밍 불일치, dead code, 미사용 인터페이스, 중복 코드(소규모).

### 3-3. 종합 점수
5개 영역에 대해 각 A~D 등급을 부여한다:
- **설계 품질** (SOLID, 패턴, 책임 분리)
- **아키텍처 일관성** (패턴 일관성, 의존성 건강성, 응집/결합)
- **테스트 충실도** (커버리지, 테스트 품질, 구조)
- **운영 성숙도** (빌드, lint, CI/CD, 의존성 관리)
- **보안 기본** (시크릿, 취약 패턴, 의존성 보안)

등급 기준:
- A: 해당 영역에 Critical/Major 이슈 없음.
- B: Major 1~2건, Critical 없음.
- C: Major 3건 이상, 또는 Critical 1건.
- D: Critical 2건 이상.

### 3-4. 리팩토링 권고
- Critical + Major 항목을 우선순위로 정렬.
- 각 항목에 대해 1줄 리팩토링 방향 제안.
- `/refactor`로 연계 시 참조할 수 있도록 구조화.

---

## Phase 4: 상태 파일 저장 및 보고

### 4-1. 상태 파일
평가 결과를 상태 파일로 저장한다: `{project_root}/.claude/state/evaluate-{YYYYMMDD-HHmmss}.json`

스키마:
```json
{
  "skill": "evaluate",
  "created_at": "...",
  "scope": "전체 | 지정 스코프",
  "project_context": {
    "tech_stack": ["..."],
    "entry_points": ["..."],
    "layer_structure": "...",
    "test_framework": "..."
  },
  "scores": {
    "design_quality": "A~D",
    "architecture_consistency": "A~D",
    "test_coverage": "A~D",
    "operational_maturity": "A~D",
    "security_basics": "A~D"
  },
  "findings": [
    {
      "severity": "Critical | Major | Minor",
      "category": "SOLID | Architecture | Test | Operations | Security",
      "location": "파일:라인 또는 모듈명",
      "description": "...",
      "refactor_direction": "1줄 방향 제안",
      "confidence": "high | medium",
      "detected_by": ["A", "B"]
    }
  ],
  "summary": "종합 평가 요약"
}
```

### 4-2. 사용자 보고
- 종합 점수 (5개 영역 등급).
- Critical → Major 순으로 발견 사항 보고. 위치 + 설명 + 리팩토링 방향.
- Minor는 건수만 요약.
- **상태 파일 경로를 사용자에게 명시적으로 보고한다.** (예: `평가 상태 파일: {path}`)
- 보고하고 종료한다. 수정하지 않는다.

### 4-3. 후속 연계
- 사용자가 `/refactor`를 호출할 때 상태 파일 경로를 전달하면, `/refactor`는 Phase 1(분석)을 간소화하고 평가 결과를 직접 활용한다.
- 예: `/refactor {evaluate_state_file_path}`

---

## 원칙
- **읽기 전용**: 코드를 수정하지 않는다. 평가/진단만 수행.
- 존재하지 않는 문제를 날조하지 않는다. 코드에서 직접 확인한 것만 보고.
- 프로젝트가 작으면 (파일 20개 미만) 병렬 agent 없이 순차 분석으로 간소화.
- 분석 불가능한 영역 (e.g. 빌드 명령 없음, 테스트 프레임워크 미설정)은 "평가 불가"로 명시. 추측하지 않는다.
- 과도한 이슈 나열 금지. Critical + Major에 집중하고, Minor는 개수만 요약.

## 매몰 방지
→ ~/.claude/rules/escalation.md 참조.
