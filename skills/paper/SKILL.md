---
name: paper
description: 학술 논문 작성. 아웃라인 합의 → 섹션별 병렬 작성 → 전문가 패널 리뷰 루프.
argument-hint: [short]
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Write, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# Paper Writing

학술 논문 작성 스킬. `/paper`로 호출. `/paper short`로 짧은 글 모드.

## 스케일링
- **Short** (abstract, 포스터, extended abstract): Phase 1 → Phase 3 단축. 다중 에이전트 생략, 단일 초안 → 자기 검증 → 리뷰 1회.
- **Full** (풀 페이퍼): 아래 전체 프로세스 적용.
- 명시 없으면 분량으로 자동 판단. 불확실하면 질문.

## Phase 0: 입력 확인 및 도메인 유추

### 0-1. 사용자 입력 수집
1. **핵심 기여**: 이 논문이 기존 대비 무엇을 새로 보여주는가.
2. **소스 자료**: 실험 결과, 데이터, 코드, 기존 초안, 관련 논문 경로.
3. **논문 유형**: Empirical / Theoretical / System / Survey.
4. **저자 스타일 선호**: 톤, 용어 규칙이 있으면 확인.

### 0-2. 자동 유추 (소스 자료 + 주제 기반)
소스 자료와 핵심 기여를 분석하여 다음을 유추한다:
1. **도메인**: 필드 로보틱스, NLP, CV, 강화학습 등 — 소스 자료의 용어, 데이터셋, 방법론에서 판단.
2. **venue 유형**: 저널 / 학회 / 워크샵 — 기여 규모와 논문 유형에서 판단.
3. **타겟 venue**: 도메인 + venue 유형 조합으로 후보 venue 1~3개 제시.
4. **핵심 기술 영역**: 논문이 교차하는 기술 분야 식별 (e.g. 농업 로보틱스 → AI + Vision + 농업).

유추 결과를 사용자에게 제시하고 확인/수정을 받는다. 불확실한 항목은 추측하지 않고 질문한다.

### 0-3. 확정 항목
- 타겟 venue 확정 후 페이지 제한, 포맷 요구사항, 심사 기준을 파악.
- 도메인과 핵심 기술 영역 확정 → Phase 3 전문가 패널 구성에 사용.

---

## Phase 1: 아웃라인 설계 (다중 에이전트 합의)

### 1-1. 사전 분석
- 소스 자료 전수 읽기.
- 핵심 기여를 1~3개로 정제.
- 타겟 venue의 관례적 구조 파악 (섹션 수, 분량 배분).
- 경쟁 논문 대비 차별화 포인트 정리.

### 1-2. 독립 아웃라인 (병렬 subagent)
- 2~3개 subagent를 병렬 생성. 서로의 존재를 알리지 않는다.
- 각 subagent에게 전달: 사전 분석 결과 + 소스 자료.
- 각 subagent는 독립적으로 아웃라인을 제시:
  - 섹션 구성 + 각 섹션의 핵심 주장 1줄.
  - 논증 흐름 (어떤 순서로 독자를 설득하는가).
  - Figure/Table 배치 계획.

### 1-3. 합의안 도출
- 공통 구조: 높은 신뢰도로 채택.
- 차이점: 논증 흐름의 설득력 기준으로 우위 판단, 근거 명시.
- 합의 불가 시: trade-off 정리하여 사용자에게 선택 요청.

### 1-4. 사용자 승인
- 합의된 아웃라인을 제출. **승인 후** Phase 2 진행.

---

## Phase 2: 섹션별 작성 (다중 에이전트)

### 2-1. 의존성 기반 그룹 분할
- **Group A** (독립 작성): Related Work, Method, Experiments — 아웃라인만으로 병렬 작성 가능.
- **Group B** (Group A 의존): Introduction, Discussion — Group A 결과 참조 필요.
- **Group C** (전체 의존): Abstract, Conclusion — 전체 초안 완성 후 작성.
- 실제 분할은 논문 구조에 따라 조정. 원칙: 의존성 없으면 병렬, 있으면 순차.

### 2-2. Group A 병렬 작성
- 각 섹션마다 subagent를 생성.
- 전달: 전체 아웃라인 + 해당 섹션 상세 아웃라인 + 소스 자료 + 용어집 + 아래 "작성 기준".
- 각 subagent는 독립 작성.

### 2-3. Group A 통합 및 일관성 검토
- 메인 에이전트가 통합 후 점검:
  - 용어 일관성: 동일 개념에 다른 이름 사용 시 통일.
  - 표기법 일관성: notation, 약어 정의, 수식 번호.
  - 중복 제거: 섹션 간 겹치는 설명 정리.
  - 흐름 연결: 섹션 전환부의 자연스러운 연결.
- 문제 시 국소 수정. 전면 재작성 불필요.

### 2-4. Group B 순차 작성
- Group A 통합 결과를 입력으로 작성. subagent 위임 가능.

### 2-5. Group C 작성
- 전체 초안 완성 후 Abstract, Conclusion 작성.
- Abstract은 venue의 word limit 내에서 작성.

---

## Phase 3: 검증 루프 (전문가 패널 리뷰)

→ ~/.claude/rules/round-agent-protocol.md 적용 (Thin Loop + 상태 파일 규약).

### 개요
Critical/Major 이슈가 0이 될 때까지 라운드를 반복한다. 최대 횟수 제한 없음.

### 메인 세션 (Thin Loop)
1. 상태 파일 생성: `artifact_paths`에 `paper_file_path`, `outline_file_path` 기록. `requirements`에 venue 정보, 도메인, 핵심 기술 영역, 논문 유형, 패널 구성 정보 기록.
2. loop:
   a. 상태 파일 Read → `current_verdict` 확인.
   b. PASS → Phase 4.
   c. Cross-Round Escalation 체크 (상태 파일의 `rounds` 배열 비교).
   d. fresh ReviewOrchestratorAgent dispatch (상태 파일 경로만 전달).
   e. 상태 파일 Read → verdict 확인.
   f. PASS → Phase 4.
   g. FAIL → fresh RevisionOrchestratorAgent dispatch (상태 파일 경로만 전달).
   h. goto 2.

### ReviewOrchestratorAgent (fresh Agent)

상태 파일에서 수신:
- `artifact_paths`: paper_file_path, outline_file_path
- `requirements`: venue 정보, 도메인, 핵심 기술 영역, 논문 유형, 패널 구성 정보

이전 라운드의 리뷰 결과, 수정 내역, 컨텍스트를 수신하지 않는다. 매번 논문을 처음 보는 것처럼 판단한다.

내부에서 수행:

#### Step 1: 자기 검증

아래 항목을 순서대로 점검. 하나라도 실패하면 수정 후 Step 1을 처음부터.

**구조 검증**:
- 각 섹션이 아웃라인의 목적/핵심 메시지를 충족하는가.
- 섹션 간 논리적 흐름: S_n의 결론 → S_{n+1}의 전제.
- Introduction의 질문이 Conclusion에서 답변되는가.

**내용 검증**:
- 모든 claim에 근거(실험, 수식, 인용)가 있는가.
- 근거 없는 주장에 `[NEEDS CITATION]` 또는 `[NEEDS EVIDENCE]` 태그.
- 실험 수치와 본문 서술 일치 (표/그림 참조 정확성).
- Related Work에서 주요 baseline 인용 누락 없는가.

**형식 검증**:
- 용어/약어: 첫 등장 시 풀네임(약어), 이후 약어만.
- 수식 표기법 일관성.
- 그림/표 번호 참조 정확성.
- venue 포맷 요구사항 충족.

#### Step 2: 전문가 패널 리뷰 (병렬 sub-subagent)

Phase 0에서 확정한 도메인과 핵심 기술 영역에 맞춰 전문가 패널을 동적으로 구성한다.

##### 2-A. 패널 구성

**분야 연구자 그룹** (2명):
- 해당 도메인의 박사급 연구자 역할.
- 논문의 학술적 정확성, novelty, contribution을 평가.
- 분야 내 positioning과 관련 연구 커버리지를 점검.

**시니어 어드바이저 그룹** (3명):
- 지도교수/시니어 연구자 역할. 각각 다른 관점을 담당:
  - **Advisor 1 — Contribution & Novelty**: 기여의 명확성, novelty 수준, 분야 내 impact.
  - **Advisor 2 — Methodology & Rigor**: 방법론의 견고함, 실험 설계, 통계적 타당성.
  - **Advisor 3 — Presentation & Readability**: 논증 흐름, 스토리텔링, 독자 친화성.
- 공통: Introduction-Method-Experiment-Conclusion의 논리적 일관성, venue 수준 적합성.

**핵심 기술 전문가 그룹** (도메인에 따라 2~3개 하위 그룹, 각 2명):
- Phase 0에서 식별한 핵심 기술 영역별로 전문가 그룹을 구성.
- 예시:
  - 농업 로보틱스 논문 → AI 전문가 2명 + Vision 전문가 2명 + 농업 전문가 2명
  - NLP 논문 → 언어학 전문가 2명 + ML 전문가 2명
  - 의료 AI 논문 → 의료 도메인 전문가 2명 + ML 전문가 2명 + 통계 전문가 2명
- 각 하위 그룹은 자신의 기술 영역 관점에서 방법론의 타당성, 실험 설계, 기술적 정확성을 평가.

##### 2-B. 리뷰 실행

모든 전문가를 **병렬 sub-subagent**로 생성한다. 각 sub-subagent에게 전달:
- 전체 논문 텍스트
- 논문 유형 (Empirical / Theoretical / System / Survey)
- 타겟 venue 이름 및 심사 기준
- 자신의 역할 (전문 분야, 시니어리티)
- `/paper_review 풀리뷰` 프레임워크 참조 지시

각 전문가는 다음을 수행:
1. **섹션별 리뷰**: 각 섹션을 자신의 전문 관점에서 점검.
2. **전체 리뷰**: 논문 전체의 일관성, 논증 흐름, contribution 평가.
3. **심각도 분류**:
   - **Critical**: 논리적 오류, claim-evidence 불일치, 핵심 관련 연구 누락, 기술적 오류.
   - **Major**: 흐름 단절, 실험 설명 불충분, 용어 혼용, 방법론 약점.
   - **Minor**: 표현, 구조 미세 조정.

#### Step 3: Figure 전문가 리뷰 (별도 sub-subagent)

Step 2와 병렬로 Figure 전문가 sub-subagent를 생성한다. 전달: 전체 논문 텍스트 + Figure/Table 목록.

점검 항목:
- 각 섹션에 적합한 Figure/Table이 배치되어 있는가.
- 누락된 시각 자료 제안 (e.g. 아키텍처 다이어그램, 정성적 결과, ablation 차트).
- 기존 Figure/Table의 시각적 명확성 평가:
  - 축 라벨, 범례, 색상 대비, 해상도.
  - 데이터 표현 방식의 적절성 (bar vs line, table vs figure).
- 캡션 품질: 자체 완결적인가, Figure만 보고 핵심을 파악할 수 있는가.
- Figure 번호와 본문 참조의 일치.
- 심각도 분류: Critical / Major / Minor (Step 2와 동일 기준).

#### Step 4: 학회/저널 심사위원 리뷰 (별도 sub-subagent)

Step 2, 3과 병렬로 심사위원 sub-subagent **2명**을 생성한다. 각 심사위원은 독립적으로 판단한다.

전달 (각 심사위원에게 동일):
- 전체 논문 텍스트
- 타겟 venue 이름, 심사 기준, accept rate (알려진 경우)
- 논문 유형

심사 항목:
1. **Contribution 충분성**: 이 venue에 실을 만한 수준의 기여인가.
2. **Novelty**: 기존 대비 충분한 차별성이 있는가.
3. **Technical Soundness**: 방법론과 실험이 견고한가.
4. **Clarity**: 해당 venue 독자층이 이해할 수 있는가.
5. **Reproducibility**: 재현에 필요한 정보가 충분한가.
6. **섹션별 심사**: 각 섹션이 venue 관례에 맞는 깊이와 분량을 갖추었는가.
7. **전체 일관성**: 논문 전체가 하나의 coherent story를 전달하는가.

각 심사위원의 출력:
- Accept / Weak Accept / Borderline / Weak Reject / Reject 판정.
- 판정 근거 + 섹션별 코멘트.
- Critical / Major / Minor 분류.
- 두 심사위원의 verdict가 다를 경우, 양쪽 근거를 모두 수정 시 참고.

#### Step 5: 리뷰 통합

Round Agent가 모든 리뷰 결과를 통합한다.

##### 5-1. 이슈 수집 및 분류
- 모든 전문가/심사위원의 피드백을 단일 리스트로 통합.
- 중복 이슈를 병합 (같은 문제를 여러 전문가가 지적한 경우).
- Critical → Major → Minor 순으로 정렬.

##### 5-2. 판정
- **Critical 또는 Major가 1개 이상**: verdict = FAIL.
- **Minor만 남음 또는 이슈 없음**: verdict = PASS.

##### 5-3. 디스크 기록
- 리뷰 통합 결과를 review_report 파일로 디스크에 기록한다.
- 라운드 요약을 round_summary 파일로 기록한다.

상태 파일 갱신:
- `rounds` 배열에 리뷰 라운드 추가 (verdict, critical_issues, round_summary_path).
- `artifact_paths.review_report_path` 갱신.
- `current_verdict`, `critical_issues` 최신화.

메인에 반환: verdict + summary.

### RevisionOrchestratorAgent (fresh Agent)

상태 파일에서 수신:
- `artifact_paths`: paper_file_path, review_report_path

이전 라운드의 수정 내역, 과거 리뷰는 수신하지 않는다.

내부에서 수행:
- review_report를 읽고 Critical → Major → Minor 순으로 수정한다.
- 수정 시 새로운 문제를 만들지 않도록 주변 맥락을 함께 점검.
- Step 1(자기 검증)을 수행하여 구조/내용/형식 검증.

상태 파일 갱신:
- `rounds` 배열에 수정 라운드 추가 (modification_approaches, round_summary_path).
- `artifact_paths.paper_file_path` 갱신 (수정된 논문 경로).

메인에 반환: summary.

---

## Phase 4: 최종 제출

1. **Title 후보**: 2~3개 + 각각의 의도. 사용자 선택.
2. **최종 체크리스트**:
   - [ ] 모든 Figure/Table이 본문에서 참조되는가.
   - [ ] 참고문헌이 본문 인용과 1:1 대응하는가.
   - [ ] venue 페이지/형식 제한 준수.
   - [ ] 저자 정보, acknowledgment, 부록 포함 여부.
3. **함께 제출**:
   - 전체 라운드별 round_summary_path 파일 수집.
   - 잔여 이슈 (추가 실험 필요 등).
   - 자기 평가 (paper_review Verdict 기준).
   - Figure 전문가의 최종 시각 자료 권고 사항.
4. 사용자 피드백 시 해당 섹션 수정 → Phase 3 재진입.

---

## 작성 기준

모든 섹션 작성 시 준수.

### 논리적 글쓰기
- 단락 구조: 주제문(첫 문장) → 근거/설명 → 연결문(마지막 문장).
- 주장(claim) → 근거(evidence) → 해석(interpretation) 3단 구조.

### 인용
- 모든 사실 주장에 인용 첨부. 자명한 사실(상식 수준)은 예외.
- 인용은 실재하는 논문만. 불확실한 인용은 `[TODO: cite]`로 표시.
- 자기 인용 과다 주의.

### 학술 어투
- 불필요한 수식어 제거 ("very", "extremely", "obviously").
- 기여 서술 시 과장 금지: "first-ever" → 구체적 차별점 서술.
- 한국어 논문 시 학술 용어는 영어 병기: 주의 메커니즘(attention mechanism).

---

## 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md 참조.

## 규칙
- 사용자가 제공하지 않은 실험 결과를 날조하지 않는다. 데이터가 부족하면 필요한 실험을 제안한다.
- 수식/용어는 분야 관례를 따른다. 새 notation 도입 시 정의를 먼저 쓴다.
- 각 Phase 완료 시 사용자에게 진행 상황을 간결하게 보고.
- Phase 간 전환 시 사용자 승인 (Phase 1→2, Phase 3→4).
