---
name: debug
description: 체계적 디버깅. 가설 수립 → 검증 → 이분 탐색 → 근본 원인 수정.
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
disable-model-invocation: false
---

# Systematic Debugging

체계적 디버깅 스킬. `/debug`로 호출.

## 프로세스

### 1. 증상 정리
- 에러 메시지 / 스택 트레이스 전문 확인.
- 재현 조건 정리: 입력값, 환경, 빈도(항상/간헐).
- 예상 동작 vs 실제 동작 명확히 구분.

### 2. 가설 수립
- 스택 트레이스 기반으로 의심 지점 3개 이내 선정.
- 각 가설에 검증 방법 명시.
- 가설 없이 코드를 수정하지 않는다.

### 3. 검증
- 가설당 최소한의 검증 수행 (로그, breakpoint, 단위 테스트).
- 검증 결과를 기록: 확인됨 / 기각됨 / 불확실.
- 불확실하면 범위를 좁혀 추가 검증. 추측으로 수정하지 않는다.

### 4. 이분 탐색 (원인 불명 시)
- git bisect 활용: 정상 커밋과 비정상 커밋 사이에서 탐색.
- 또는 코드 블록 단위로 비활성화하며 범위 축소.

### 5. 수정
- 근본 원인(root cause)을 수정. 증상만 가리는 workaround 금지.
- 수정 후 원래 재현 조건으로 검증.
- 회귀 방지 테스트 추가.

## 수정 후 검증
- 빌드/타입체크 실행하여 통과 확인.
- 테스트 실행하여 전체 통과 확인.
- 원래 재현 조건으로 실제 실행하여 수정 확인.
- 하나라도 실패하면 수정 철회 후 가설 수립으로 돌아간다.

## 매몰 방지
→ ~/.claude/rules/escalation.md 참조.

## 규칙
- 고치기 전에 재현부터.
- 한 번에 하나만 변경. 동시에 여러 곳 수정하면 원인 특정 불가.
- 디버깅 코드(console.log, print)는 수정 완료 후 반드시 제거.
- 프로젝트에 `.claude/rules/workflow.md`가 있으면 해당 Git 워크플로우를 따른다.
