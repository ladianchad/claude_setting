# Code Review

## 스케일링
- 10줄 미만: 정확성 + 엣지케이스만 간략 확인.
- 10줄 이상: 아래 전체 프레임워크 적용.

## 분석 순서
1. 변경된 파일의 전체 컨텍스트를 Read로 확인 (diff만 보지 않는다).
2. 아키텍처 일관성: 기존 설계 의도 vs 변경사항. 의도 불명이면 git log로 확인.
3. 정확성: 로직 버그, off-by-one, null/undefined, race condition.
4. 보안: injection, 인증/인가 누락, 시크릿 노출.
5. **맥락적 정적 분석** (linter가 잡지 못하는 항목): non-exhaustive switch/match, 타입 narrowing 누수, 불필요한 cast/assertion, 도달 불가능하거나 죽은 분기, 변수/파라미터 shadowing, async/await 누락, Promise unhandled, nullable 체인 오용. 결정론적 도구(tsc/mypy/ruff/clippy/eslint)가 이미 잡는 항목은 Step 3(자기 검증)의 Static Analysis 블록이 담당하므로 여기서는 "도구가 놓치는 맥락적 문제"에 집중한다.
6. principles.md 기준으로 설계 품질 평가 (SOLID, LoD, 구현 규칙).
7. 잘된 점 언급.

## 심각도 기준
- **Critical**: 런타임 에러, 데이터 손실, 보안 취약점, 빌드/타입체크/린터 실패.
- **Major**: OOP 원칙 위반, 아키텍처 일관성 파괴, 테스트 누락, **principles.md 커버리지 기준(diff 90% AND 파일 90%) 미달 (화이트리스트 예외 사유 없음)**, 맥락적 정적 분석 문제(non-exhaustive, narrowing 누수, dead branch).
- **Minor**: 네이밍, 복잡도, 중복 코드, shadowing, 불필요한 cast.
- **Nitpick**: 포매팅, 주석 스타일.

## 출력 형식
- 결론 먼저 (Approve / Request Changes / Comment).
- 발견 사항: `[심각도] 파일:라인 — 원칙명: 설명 + 수정 제안`.
