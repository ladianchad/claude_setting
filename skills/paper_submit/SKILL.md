# Paper Submit

논문 작성 → 심사 → 수정 → 재심사를 Accept까지 반복하는 오케스트레이션 스킬.
`/paper_submit`으로 호출. `/paper` + `/paper_exam`을 자동 체이닝한다.

## 입력
`/paper`와 동일. 핵심 기여, 소스 자료, 타겟 venue 등.

## 프로세스

### Round 1: 초고 작성
- `/paper` skill의 전체 프로세스를 수행한다 (Phase 0~4).
- Phase 3(작성 중 검증)을 통과한 논문이 산출물.
- 산출물 파일 경로를 확보하고 Round 2로.

### Round 2+: 심사 → 수정 루프

#### Step 1: 심사
- `/paper_exam` skill의 Full 프로세스를 수행한다.
- 현재 논문 파일 + 타겟 venue를 전달.
- **매 라운드 완전 독립**: 심사 패널은 매번 새 subagent. 이전 라운드의 심사 결과, 수정 내역, 컨텍스트를 일절 전달하지 않는다. 논문 파일만 전달한다.

#### Step 2: 판정 확인
- **Accept 이상** (Strong Accept / Accept): 종료 → 최종 보고로.
- **Weak Accept + Critical 0**: 사용자에게 투고 여부 확인. 투고 시 종료, 수정 시 Step 3으로.
- **Borderline 이하**: Step 3으로.

#### Step 3: 수정
- `/paper_exam` 보고서의 수정 권고를 기반으로 논문을 수정한다.
- 수정 시 `/paper`의 Phase 3 Step 1(자기 검증)만 적용한다. 전문가 심사는 Step 1의 `/paper_exam`이 담당한다.
- Critical → Major → Minor 순으로 수정.
- 수정 완료 후 Step 1로 (새 라운드).

### 라운드 독립성
- 라운드 횟수 제한 없음. Accept까지 계속한다.
- 각 라운드의 심사/수정은 완전히 독립적인 세션이다:
  - 심사: 새 subagent, 이전 라운드 결과 미전달.
  - 수정: 현재 논문 + 현재 라운드의 심사 보고서만 참조. 과거 라운드 수정 이력 미참조.

### 매몰 방지
- 동일 이슈가 2라운드 연속 Critical/Major로 지적되면:
  → ~/.claude/rules/escalation.md 적용 (subagent 위임 → 에스컬레이션).
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
- **라운드별 심사 이력**: 각 라운드의 verdict + 주요 이슈 + 수정 내역.
- **최종 심사 보고서**: 마지막 `/paper_exam` 출력.
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
