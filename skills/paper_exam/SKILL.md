---
name: paper_exam
description: 논문 투고 전 최종 심사. PC Reviewer + 기술 전문가 + Area Chair 독립 심사 시뮬레이션.
argument-hint: [quick] [논문경로] [venue]
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Write, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# Paper Exam

완성된 논문의 투고 전 최종 심사 스킬. `/paper_exam`으로 호출.
실제 학회/저널 심사 프로세스를 모사하여 1회 심사 + 종합 판정. 수정하지 않는다.

## 스케일링
- **Quick** (`/paper_exam quick`): 사전 점검 + PC Reviewer 2명만 → 판정. 전문가 패널 생략.
- **Full** (기본): 아래 전체 프로세스 적용.

## 입력
1. **논문 파일 경로** (필수).
2. **타겟 venue** (선택): 미제공 시 자동 유추.

---

## Phase 0: 논문 분석 및 심사 설정

### 0-1. 논문 읽기
- 전체 논문을 읽고 다음을 추출:
  - 논문 유형: Empirical / Theoretical / System / Survey.
  - 도메인: 용어, 데이터셋, 방법론에서 판단.
  - 핵심 기여: 저자가 주장하는 contribution 목록.
  - 핵심 기술 영역: 교차 기술 분야 식별 (e.g. 농업 로보틱스 → AI + Vision + 농업).

### 0-2. Venue 확정
- 제공된 경우: 심사 기준, accept rate, 포맷 요구사항 파악.
- 미제공 시: 후보 1~3개 유추 → 사용자 확인.

### 0-3. 심사 패널 구성 계획
- 도메인과 핵심 기술 영역 기반으로 패널 구성 결정.
- 구성을 사용자에게 보고 후 Phase 1 진행.

---

## Phase 1: 형식 및 구조 사전 점검

메인 에이전트가 직접 수행. 결격 사유 확인.

### 1-1. 형식 점검
- venue 포맷 요구사항 충족 (페이지 수, 섹션 구성, 참고문헌 스타일).
- 용어/약어 일관성, 수식 표기법 일관성.
- Figure/Table 번호와 본문 참조 일치.
- 참고문헌과 본문 인용의 1:1 대응.

### 1-2. 구조 점검
- 각 섹션의 venue 관례 대비 존재 및 분량.
- Introduction의 질문이 Conclusion에서 답변되는가.
- 섹션 간 논리적 흐름.
- 모든 claim에 근거가 있는가.

### 1-3. 보고
- 결격 사유 있으면 사용자에게 보고, 진행 여부 확인.
- 없으면 Phase 2로.

---

## Phase 2: 독립 심사 (병렬 subagent)

모든 심사자를 독립 subagent로 병렬 생성. 서로의 존재와 리뷰를 알리지 않는다.

### 2-1. 패널 구성

#### PC Reviewer (3명)

**Reviewer 1 — Novelty & Contribution**:
- 기여의 명확성, novelty 수준, 분야 내 impact.
- 기존 연구 대비 차별성.
- Related work 커버리지.

**Reviewer 2 — Technical Soundness & Methodology**:
- 방법론 견고함, 가정의 타당성.
- 실험 설계: baseline 선정, ablation, 통계적 유의성.
- 재현 가능성.
- 수식/증명 정확성.

**Reviewer 3 — Clarity & Presentation**:
- 논증 흐름, 스토리텔링.
- Figure/Table 효과적 사용.
- venue 독자층 대비 접근성.
- 용어/표기법 일관성.

공통 (3명 모두):
- 섹션별 리뷰 + 전체 일관성.
- venue 수준 적합성.
- Verdict: Strong Accept / Accept / Weak Accept / Borderline / Weak Reject / Reject.
- 이슈: Critical / Major / Minor.
- Confidence: 1(low) ~ 5(expert).

#### 핵심 기술 전문가 (도메인에 따라 2~3개 하위 그룹, 각 2명)
- Phase 0에서 식별한 기술 영역별 구성.
- 자신의 기술 영역 관점에서 방법론 타당성, 기술적 정확성 평가.
- Verdict는 내리지 않는다. 기술적 이슈만 보고.

#### Figure/Table 전문가 (1명)
- 시각 자료 배치 적절성.
- 시각적 명확성 (축 라벨, 범례, 색상, 데이터 표현 방식).
- 캡션 품질: 자체 완결적인가.
- 누락된 시각 자료 제안.

#### Senior Area Chair (1명)
- Phase 2에서 독립적으로 논문을 읽고 초기 인상 형성:
  - venue 상위 몇 % 해당 여부.
  - 가장 큰 강점 1개, 가장 큰 약점 1개.
  - Accept 경향 / Reject 경향.
- Phase 3에서 모든 리뷰를 취합하여 meta-review 수행.

### 2-2. 공통 전달 사항
각 subagent에게 전달:
- 전체 논문 텍스트.
- 논문 유형 + 타겟 venue + 심사 기준.
- 자신의 역할과 평가 초점.
- `/paper_review 풀리뷰` 프레임워크 참조 지시.

전달 금지: 다른 심사자의 리뷰, 메인 에이전트의 해석/평가.

### 2-3. 심각도 기준 (공통)
- **Critical**: 논리적 오류, claim-evidence 불일치, 핵심 관련 연구 누락, 기술적 오류.
- **Major**: 흐름 단절, 실험 설명 불충분, 용어 혼용, 방법론 약점.
- **Minor**: 표현, 구조 미세 조정, 포매팅.

---

## Phase 3: 종합 판정

### 3-1. 이슈 통합
- 전체 이슈를 단일 리스트로 통합.
- 중복 병합 (동일 이슈 지적 횟수 표시).
- Critical → Major → Minor 순 정렬.

### 3-2. Area Chair Meta-Review
- Area Chair 초기 인상 + 전체 Reviewer 리뷰를 새 subagent에게 전달.
- Meta-Reviewer가 수행:
  1. Reviewer 간 의견 충돌 분석 → 어느 쪽이 타당한지 판단.
  2. 공통 지적 이슈의 심각성 재평가.
  3. Reviewer가 놓친 관점 보완.
  4. 최종 recommendation 제시.

### 3-3. 최종 판정

| 조건 | 판정 |
|------|------|
| PC 3명 모두 Accept 이상 + Critical 0 | **Strong Accept** |
| PC 과반 Accept 이상 + Critical 0 | **Accept** |
| PC 과반 Weak Accept 이상 + Critical 0 | **Weak Accept** |
| Verdict 혼재 또는 Critical 1~2개 | **Borderline** |
| PC 과반 Weak Reject 이하 | **Weak Reject** |
| PC 과반 Reject + Critical 다수 | **Reject** |

- Area Chair meta-review가 기계적 판정과 다를 경우, 양쪽 근거를 제시하고 Area Chair 판단을 우선 (근거 명시).

### 3-4. 합의 불가 처리
- PC Reviewer 판정이 3단계 이상 차이 (e.g. Accept vs Reject):
  - 새 subagent "Senior Meta-Reviewer" 생성.
  - 전달: 논문 + 양쪽 리뷰 (익명) + 기술 전문가 리뷰 요약.
  - Senior Meta-Reviewer가 최종 판정.
  - 이것도 불가 시 사용자에게 에스컬레이션.

---

## Phase 4: 최종 보고서

```
## 심사 결과 보고서

### 논문 정보
- 제목 / 타겟 venue / 논문 유형 / 도메인

### 최종 판정: [Strong Accept ~ Reject]
판정 근거 (2~3문장)

### PC Reviewer 판정 요약
| Reviewer | Verdict | Confidence | 핵심 근거 |
|----------|---------|------------|----------|
| R1 (Novelty) | ... | .../5 | ... |
| R2 (Technical) | ... | .../5 | ... |
| R3 (Clarity) | ... | .../5 | ... |

### 강점
1. [동의 N명] ...

### 약점 — Critical
1. [동의 N명] (Section) 설명 + 근거

### 약점 — Major
1. [동의 N명] (Section) 설명 + 근거

### 약점 — Minor
1. (Section) 설명

### 수정 권고 (우선순위 순)
| 우선순위 | 섹션 | 이슈 | 수정 방향 |
|---------|------|------|----------|
| 1 | ... | Critical | ... |
| 2 | ... | Major | ... |

### 전문가 패널 소견
- [기술영역]: 주요 소견 요약

### Figure/Table 전문가 소견
- ...

### Area Chair Meta-Review
(충돌 분석, 종합 판단 근거, recommendation)

### 투고 권고
- [ ] 즉시 투고 가능
- [ ] Minor revision 후 투고
- [ ] Major revision 필요
- [ ] 타겟 venue 재고 필요
```

---

## 매몰 방지
→ ~/.claude/rules/escalation.md 참조.

## 규칙
- **수정 금지**: 심사만 수행. 논문을 변경하지 않는다.
- **독립성 보장**: 각 심사 subagent는 서로의 리뷰를 전달받지 않는다.
- **근거 필수**: 모든 지적에 논문 내 위치 인용 (Section, Table, Figure).
- **객관/주관 구분**: `[객관]` `[주관]`으로 명시 구분.
- **날조 금지**: 논문에 없는 내용을 지어내지 않는다.
- **1회 심사**: 반복하지 않는다. 실제 학회처럼 1회 심사 후 판정.
- 한국어 보고서 시 학술 용어는 영어 병기.
