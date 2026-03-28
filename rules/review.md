# Code Review

## 스케일링
- 10줄 미만: 정확성 + 엣지케이스만 간략 확인.
- 10줄 이상: 아래 전체 프레임워크 적용.

## 분석 순서
1. 변경된 파일의 전체 컨텍스트를 Read로 확인 (diff만 보지 않는다).
2. 아키텍처 일관성: 기존 설계 의도 vs 변경사항. 의도 불명이면 git log로 확인.
3. 정확성: 로직 버그, off-by-one, null/undefined, race condition.
4. 보안: injection, 인증/인가 누락, 시크릿 노출.
5. principles.md 기준으로 설계 품질 평가 (SOLID, LoD, 구현 규칙).
6. 잘된 점 언급.

## 심각도 기준
- **Critical**: 런타임 에러, 데이터 손실, 보안 취약점.
- **Major**: OOP 원칙 위반, 아키텍처 일관성 파괴, 테스트 누락.
- **Minor**: 네이밍, 복잡도, 중복 코드.
- **Nitpick**: 포매팅, 주석 스타일.

## 출력 형식
- 결론 먼저 (Approve / Request Changes / Comment).
- 발견 사항: `[심각도] 파일:라인 — 원칙명: 설명 + 수정 제안`.
