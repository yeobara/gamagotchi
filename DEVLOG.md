# 개발 노트

## 배고픔 알림 구현 (2026-07-12)

36시간 미급식 시 알림을 보내는 기능. 문서상 `Toybox.Notifications.showNotification()`이 "배경에서 사용자에게 알리는" 용도로 명시되어 있어서(API 5.1.0) 이걸로 구현했으나, `(:background)` 컨텍스트(`GamigotchiBackground.onTemporalEvent()` 안)에서 호출하면 시뮬레이터에서 바로 크래시:

```
Error: Unexpected Type Error
Details: Failed invoking <symbol>
Stack: - _checkHungerNotification() at GamigotchiBackground.mc:58
```

Garmin 포럼 검색 결과 비슷한 "Failed invoking symbol" 사례들이 background 컨텍스트에서 모듈/심볼이 제대로 로드 안 되는 문제로 보고되어 있음 — 공식 문서가 background 사용을 권장한다고 해서 실제로 background 심볼 테이블에 포함되어 있다는 보장은 없다는 교훈.

**해결**: 이미 이 컨텍스트에서 문제없이 쓰던 `Toybox.Background` 모듈의 `requestApplicationWake(message)`로 교체. "앱 실행 확인 다이얼로그" 방식이라 UX는 다르지만(수동 알림 배너가 아니라 확인창), 크래시 없이 동작 확인. `Notifications` uses-permission도 더 이상 필요 없어 manifest.xml에서 제거.

**시뮬레이터 한계**: 확인 다이얼로그가 뜬 뒤 자동으로 상호작용되는 것처럼 보여(사람이 응답 안 해도 다음 스크린샷에서 앱 메뉴 화면으로 넘어가 있음) 실제 다이얼로그 문구/외형은 시뮬레이터로 완전히 재현 안 됨 → 실기기 확인 필요.

---

## 오늘 작업 요약 (2026-07-11)

1. **백그라운드 재등록 버그 수정 + 실기기 검증** — Temporal Event 최초 1회만 발화하던 버그 수정, Forerunner 255 실기기에서 백그라운드→토큰→Feed 전체 파이프라인 확인 (→ [실기기 검증](#실기기-검증-2026-07-11-forerunner-255))
2. **상태 확인 화면 추가** — 토큰/마지막 급식/성장 진행도 표시 (→ [캐릭터 스프라이트 + 화면 인터랙션](#캐릭터-스프라이트--화면-인터랙션-구현--삽질-기록-2026-07-11))
3. **캐릭터 스프라이트 렌더링 배선** — placeholder 이미지로 이미지 로딩/애니메이션 파이프라인 검증, 실제 픽셀 아트는 추후 같은 파일명으로 교체 예정
4. **시뮬레이터 자동 테스트 루프 구축** — WSL에서 `cmd.exe`로 monkeyc 빌드, 시뮬레이터 실행/스크린샷까지 자동화해서 반복 검증
5. **버그 3개 발견 및 수정**: LIGHT 버튼 불통(→Up 버튼 재배치), 한글 폰트 미지원(→영어 전환), `onStart()`에서 `WatchUi.requestUpdate()` 호출 시 크래시
6. **사망 플로우 확정 및 구현** — 사망 확인 화면 + SELECT로 리셋 방식, 첫 실행 인트로 메시지 (→ [사망 플로우 구현](#사망-플로우-구현-2026-07-11))

**남은 것**: 픽셀 아트 실제 에셋, 알림 기능, 밸런스 수치(밥주기 소모 토큰, 알림 타이밍) 확정

---

## 캐릭터 스프라이트 + 화면 인터랙션 구현 — 삽질 기록 (2026-07-11)

PIL/ImageMagick이 개발 환경에 없어서 순수 Python(`zlib`+`struct`)으로 최소 PNG 인코더를 짜서 placeholder 스프라이트 12장 생성. `resources/drawables.xml`에 비트맵 리소스로 등록하고 `WatchUi.loadResource()` + `dc.drawBitmap()`으로 연결, `Toybox.Timer`로 500ms마다 프레임 토글.

로컬에 Connect IQ SDK가 있어서(`monkeyc.bat`) WSL에서 `cmd.exe`로 직접 빌드 가능. 시뮬레이터(`simulator.exe`)도 같은 방식으로 띄우고 `monkeydo.bat`으로 앱 푸시. 시뮬레이터 창을 `PrintWindow`(PW_RENDERFULLCONTENT) API로 캡처해서 렌더링 결과를 직접 확인하는 루프를 돌림 — `CopyFromScreen` + `SetForegroundWindow` 조합은 포그라운드 잠금 때문에 실패(다른 창이 찍힘), `PrintWindow`가 백그라운드 상태에서도 안정적으로 동작.

**시뮬레이터 테스트에서 발견한 것들:**

1. **LIGHT 버튼(왼쪽 상단)은 앱에 이벤트가 안 옴** — 백라이트 전용으로 시스템이 예약. `onKey(KEY_LIGHT)`로 가로채려 했으나 시뮬레이터에서도 반응 없음. 상태 확인 화면을 Up 버튼으로 재배치 (`onNextPage`/`onPreviousPage` 둘 다 처리 — 기기별로 Up이 어느 쪽에 매핑되는지 달라서 둘 다 구현)
2. **한글 텍스트가 시스템 폰트에 없어 물음표 다이아몬드로 깨짐** — `dc.drawText`에 한글을 넣으면 tofu 글리프로 렌더링됨. 모든 화면 텍스트를 영어로 전환 (REQUIREMENTS.md의 말풍선 문구 기획은 한글이지만 실제 구현은 영어)
3. **`WatchUi.loadResource()`의 반환 타입은 `WatchUi.BitmapResource`** — `Graphics.BitmapResource`로 캐스팅하면 `getWidth`/`getHeight`를 못 찾는 컴파일 에러 발생

**결론**: 상태 확인 화면(Up 버튼), Feed 메뉴, 토큰 부족 피드백("no tokens...") 모두 시뮬레이터에서 실제 동작 확인 완료.

---

## 사망 플로우 구현 (2026-07-11)

미확정이던 사망 플로우를 "사망 확인 화면 + SELECT로 리셋" 방식으로 확정하고 구현. `healthStatus=2` 상태를 추가해 `_checkHealth()`가 72시간 경과 시 자동 리셋 대신 이 상태로만 전환하고, 실제 리셋(`_resetCharacter()`)은 `GamigotchiDelegate.onSelect()`에서 사망 상태일 때 `reviveFromDeath()`를 호출해야 일어나도록 분리.

**크래시 삽질**: `onStart()`의 최초 실행 분기에서 인트로 말풍선을 띄우려고 `_setTransientMessage()`(내부에서 `WatchUi.requestUpdate()` 호출)를 불렀더니 `Error: Permission Required — Permission for module 'Toybox.WatchUi' required`로 크래시. `onStart()`는 `getInitialView()`가 뷰를 만들기 *전* 단계라 아직 WatchUi 컨텍스트가 없어서 `requestUpdate()`를 호출할 수 없음. → `onStart()`에서는 `requestUpdate()` 없이 상태(`_transientMessage`/`_transientMessageUntil`)만 세팅해두면, 뷰가 처음 만들어지며 자동으로 호출되는 `onUpdate()`가 알아서 그 상태를 그려줌.

이 크래시가 앞서 "Up 버튼 눌렀더니 크래시남" 사건의 원인이었을 가능성이 높음 — 그 시점이 마침 첫 실행(스토리지 초기화) 타이밍과 겹쳤던 것으로 추정.

---

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

- Temporal Event 발화 주기를 5분보다 짧게 할 방법 없음 (플랫폼 제한)

---

### 실기기 검증 (2026-07-11, Forerunner 255)

Temporal Event가 최초 1회만 발화하고 끝나는 문제를 발견 — `onTemporalEvent()` 안에서 `registerForTemporalEvent()`를 재호출하지 않으면 다음 이벤트가 안 잡힘. 재등록 로직 추가 후 실기기 테스트 진행.

**확인 방법**: 워치가 USB(MTP) 연결 상태라 드라이브 문자가 안 잡혀서, PowerShell `Shell.Application` COM으로 MTP 네임스페이스를 직접 순회해 `GARMIN/APPS/LOGS/CIQ_LOG`, `GARMIN/APPS/DATA` 를 확인.

- `CIQ_LOG` 폴더 비어있음 → 백그라운드 실행 중 예외 없음
- `gamigotchi.DAT` (Storage 파일) 수정 시각이 정확히 5분 뒤로 찍힘 → Temporal Event 재등록이 실제로 동작 확인
  - 단, 파일 자체는 Garmin이 암호화해서 내용은 못 읽음 (바이너리 엔트로피 확인만 가능)
- 워치에서 앱 직접 실행해 확인 → 토큰 1개 생성됨, 메뉴 → Feed 실행 후 0으로 정상 차감

**결론**: `Activity.getActivityInfo()` → `onActivityCompleted` → `Background.exit(data)` → `onBackgroundData` → `Storage` → 화면 갱신까지 실기기 전체 파이프라인 검증 완료. 이전 "미확인 사항"이었던 실기기 백그라운드 동작 항목 해소.
