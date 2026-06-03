# 개발 노트

## 백그라운드 서비스 구현 — 삽질 기록

### 뭐가 문제였나

가미고치의 핵심 기능 중 하나는 "달리기가 끝나면 토큰을 준다"는 것.
근데 Connect IQ 플랫폼 특성상 우리 앱이 꺼져 있을 때 달리기가 끝나면 어떻게 감지하느냐가 문제였다.

처음엔 단순히 `onActivityCompleted()` 콜백에서 거리를 읽으면 되겠다 싶었는데, 막상 API를 파보니 이 콜백은 **sport/subSport만 알려줄 뿐 거리는 없다**.

---

### 거리 가져오는 방법 탐색 과정

| 시도 | 결과 |
|------|------|
| `onActivityCompleted` 콜백 | ❌ sport/subSport만 있음, 거리 없음 |
| `ActivityMonitor.getInfo()` | ❌ 걸음수/칼로리만, 달리기 거리 없음 |
| `ActivityMonitor.getHistory()` | ❌ 일별 총계, 개별 런 거리 없음 |
| `SensorHistory` | ❌ 심박/기압/체온 등, 거리 없음 |
| `PersistedContent` | ❌ 코스/워크아웃만, 완주 기록 없음 |
| `Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE` | 🔶 존재하나 값 읽기 불확실 |
| `Activity.getActivityInfo().elapsedDistance` | ✅ **달리기 중에 백그라운드에서 읽기 가능** |

**결론**: 달리기 중 `registerForTemporalEvent`로 주기적으로 깨어나서 `Activity.getActivityInfo()`로 거리를 읽고 저장해두는 방식.

---

### 백그라운드 서비스 연결 삽질

백그라운드 서비스 클래스를 만들었는데 아무리 이벤트를 트리거해도 동작을 안 했다.
원인을 찾는 데 꽤 걸렸다.

**삽질 목록:**

1. **`Activity.Info.currentSportType`** — 존재하지 않는 필드. `sport`도 없음
2. **`Dictionary?` 파라미터 타입** — 부모 클래스 시그니처와 안 맞아서 빌드 에러. 타입 어노테이션 제거로 해결
3. **`getServiceDelegate()` 반환 타입** — 가장 핵심적인 버그. **단일 객체가 아니라 Array를 반환해야 함** (`getInitialView()`처럼)
4. **`(:background)` 어노테이션 누락** — `getServiceDelegate()` 메서드에도 붙여야 백그라운드 빌드에 포함됨
5. **시뮬레이터 Background Events** — 단순히 이벤트 타입 선택하는 게 아니라, `registerForActivityCompletedEvent()`가 먼저 등록되어 있어야 함
6. **`System.println` 백그라운드 미출력** — 백그라운드 프로세스의 println은 VS Code Debug Console에 안 나옴. Storage에 값을 써서 확인해야 함
7. **Temporal Event 5분 제한** — `Duration`이 아닌 `Moment`로 등록하면 최초 1회는 즉시 등록 가능. 단 이후 5분 제한 있음

---

### 최종 알고리즘

```
[달리기 중 — 5분마다]
백그라운드 Temporal Event 발화
  └→ Activity.getActivityInfo() 호출
       ├→ null이면 활동 없음 → 종료
       └→ elapsedDistance 읽기
            └→ 기존 저장값보다 크면 Storage["lastRunDistance"] 업데이트

[달리기 완주]
onActivityCompleted(activity) 발화
  └→ activity[:sport] == 1 (SPORT_RUNNING) 체크
       ├→ Running 아니면 → 종료
       └→ Storage["lastRunDistance"] 읽기
            ├→ 토큰 계산: km당 1토큰 (최소 1)
            ├→ 5km 이상이면 qualifyingRunCount++
            ├→ lastRunDistance 초기화
            └→ Background.exit({tokens, qualifyingRunCount})
                 └→ AppBase.onBackgroundData() 호출
                      └→ Storage 업데이트 → 화면 갱신
```

**정확도 한계**: Temporal Event 마지막 발화 시점 이후 거리는 누락됨 (최대 5분치).
평균 페이스 6분/km 기준 약 800m 오차. 게임 밸런스상 허용 범위.

---

### 미확인 사항

- `Activity.getActivityInfo()`가 실제 기기에서 백그라운드 컨텍스트로 네이티브 달리기 앱 세션을 읽어오는지 → **실기기 테스트 필요**
- Temporal Event 발화 주기를 5분보다 짧게 할 방법 없음 (플랫폼 제한)
