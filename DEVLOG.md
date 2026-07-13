# 개발 노트

## 심리학적 설계 기반 도입 (2026-07-13)

- **다마고치 심리 분석 자료(`다마고치_심리학적_분석.docx`)를 가미고치 설계에 반영** — 6대 몰입 기제(가변적 보상/손실 회피/의인화·애착/매몰비용/자기결정성)를 현재 기획에 매핑. 결과는 REQUIREMENTS.md "심리학적 설계 기반" 섹션에 정리
- **핵심 전략 = 문서 8번과 동일**: 긍정 기제(SDT·긍정적 서프라이즈)를 메인 엔진, 부정 기제(손실 회피)는 순화. **달리기 동기부여 앱에서 과한 페널티는 "더 달리기"가 아니라 "앱 삭제"로 이어진다**는 게 판단의 축
- **도출된 4개 방향** (우선순위순): B 긍정적 가변 보상(저비용·즉효) → D 얼굴/표정 강조 → C 개체 이름(개별화) → A 사망→"완주 서사" 재설계(세대교체, 설계 큼)
- **묶임 구조 발견**: 방향 A(세대교체)가 허브 — 세대마다 이름(C)+살짝 다른 개체가 붙으면 이름·다양성·손실 순화·매몰비용이 한 번에 엮임. "캐릭터 다양성이 있어야 이름을 붙인다"가 아니라, 이름은 지금도 개별화 효과가 있고 다양성은 A로 공짜에 가깝게 따라옴
- 이번 커밋은 **문서화만**. 구현은 B부터 순차 진행 예정

---

## UI 아이콘화 + 실제 아트 반영 시작 (2026-07-12 밤 ~ 07-13)

- **메인 화면 UI를 아이콘 기반으로 전면 교체**
  - 배고픔/행복 막대 그래프 → 하트/별 아이콘 4개(반칸 단위) — 값이 12.5% 떨어질 때마다 반칸씩 깎이는 방식
  - "N tokens" 텍스트 → 마리오 코인 스타일 아이콘(세로 슬롯 바) + 숫자, 숫자는 동전 옆에 배치(겹치면 안 예쁨)
  - 이모지(❤🪙)는 한글처럼 시스템 폰트에서 렌더링 안 됨 확인(하트는 미출력, 코인은 물음표 tofu) → 전부 직접 픽셀아트로 제작, PixelLab 크레딧 안 씀
- **PixelLab `create_character`가 "알(egg)"을 잘 못 그림** — description에 "egg"를 넣어도 계속 펭귄 몸체(팔다리 있는 humanoid)로 그려짐, "penguin"이라는 단어에 강하게 편향되는 듯. `create_map_object`(오브젝트 전용 도구)로 바꾸니 제대로 된 알 형태가 나옴. **캐릭터가 아닌 소품/오브젝트는 create_character 대신 create_map_object를 먼저 시도할 것**
- **이스터에그 추가**: 알을 만들다 실수로 나온 "이미 펭귄인 알" 이미지가 귀여워서 버리지 않고 재활용 — 알 단계에서 앱 열 때마다(`onShow()`) 5% 확률로 정상 알 대신 이 이미지가 뜸. 세션당 한 번만 굴려서 보는 동안 안 깜빡이게 함. 순전히 표시용이라 게임 데이터엔 영향 없음
- **남은 캐릭터 아트**: 청년기 정상 ✅ / 알 정상 ✅ 완료. 아직 남음 — 청년기 아픈 상태, 유년기(정상+아픈), 노년기(정상+아픈), 알 아픈 상태, 묘비 실제 아트
- **보류 중이던 것 중 결정**: 배경(땅)+포포 걷기 모션은 ✅ 계속 진행. 인스타 프사 포트레이트 재시도, 인스타툰 컨셉은 ❌ 폐기(2026-07-13) — 진행 안 하기로 함
- **배경+걷기 모션 완료** — 얼음 바닥(`create_map_object`) + 청년기 걷기 6프레임(`animate_character`, walk 템플릿) + "서있기 3~8초 ↔ 걷기" 상태 머신으로 불규칙 배회 구현. 청년기+정상 상태에서만 적용
- **⚠️ `create_character_state` 비용이 예상보다 훨씬 큼** — 청년기 벨리에 노란 별무늬 추가해보려고 시도했는데(사용자 요청으로 결국 폐기), 이 호출 하나로 크레딧이 30 넘게 깎임(처리 시간도 7분+ 걸림, create_character/animate_character의 1세대·2~3분과는 확연히 다름). API 설명엔 비용이 명시 안 되어 있어서 몰랐음 — **이후로는 create_character_state 쓰기 전에 반드시 get_balance로 전후 비교해서 실제 비용 확인할 것**. 이번 소모로 남은 크레딧이 12개까지 줄어서, 애초 계획했던 "무료 잔량으로 전체 캐릭터 아트 커버" 시나리오가 깨짐 — 유료 결제 없이는 유년기/노년기/아픈 상태 전부를 못 끝낼 가능성 높음

---

## 캐릭터/마케팅 결정 사항 (2026-07-12, 오후)

- **캐릭터 이름 "포포" 확정** — 가미고치(세계관/앱) vs 포포(캐릭터) 분리 구조. REQUIREMENTS.md/INSTAGRAM.md 반영 완료
- **캐릭터 디자인 브리프 갱신** — "특색 없다" 피드백 → 아기 도식(큰 눈, 목 생략, 동글동글) 전 단계 적용 + 노란 스카프 시그니처 + 노란색 메인 테마. PixelLab으로 청년기 재생성 완료, 훨씬 귀여워짐 확인
- **실기기 배포 방법 확정** — MTP 기기에 PowerShell Shell.Application COM으로 자동 복사(CopyHere) 시도했으나 신뢰 안 됨(파일이 실제로 안 들어가는 경우 발생, 크래시 로그도 이전 세션 것이 재생되어 헷갈림 유발). **탐색기로 직접 드래그앤드롭이 유일하게 확실히 작동하는 방법**으로 결론
- **인스타툰 컨셉은 보류** — "그림으로 만들면 더 좋을 것 같다"는 방향에는 공감했으나(현재 스크린샷+텍스트박스 방식이 딱딱하다는 피드백), 구체 컨셉/스타일은 사용자가 더 고민 중. PixelLab은 픽셀아트 전용이라 부드러운 일러스트 톤엔 안 맞음 — 그림체 결정되면 별도 AI 도구 필요
- **PixelLab 포트레이트 생성 1건 실패/방치** — `character_to_portrait` 변환이 진행률 62%에서 멈추고 ETA가 계속 늘어나는 이상 동작. 취소 API가 없어서 그냥 방치하기로 함 (크레딧 25개 손실 가능성, 완료/실패 시점에 정산되는 것으로 추정)

---

## 오늘 작업 요약 (2026-07-12)

1. **배고픔 알림 구현** — 36시간 미급식 시 1회 알림 (이후 게이지 시스템으로 트리거 조건 교체됨)
2. **픽셀 아트 기획 정리** — PixelLab.ai MCP 연동 방법 조사, 4단계(알/유년/청년/노년) 캐릭터 컨셉 검토, 실루엣 우선 원칙 확인
3. **코어 시스템 재설계 결정** — 런 횟수 기반 성장 → 배고픔/행복 게이지 + 시간 기반 성장으로 전환, Feed/Play/Clean/Medicine 4액션 확정
4. **코드 마이그레이션 완료** — `GamigotchiStats.mc` 신설, 관련 파일 전부 갱신, 시뮬레이터로 성장/아픔/사망 전 구간 자동 검증

**남은 것**: Feed/Play/Clean/Medicine 버튼 액션과 사망 리셋은 사람이 직접 눌러서 확인 필요 (자동화 한계). 픽셀 아트 실제 에셋 제작.

---

## 게이지 기반 코어 시스템 마이그레이션 (2026-07-12)

런 횟수 기반 성장 → 배고픔/행복 게이지 + 시간 기반 성장으로 전면 교체. 새 파일 `GamigotchiStats.mc`(모듈)에 tick/decay/성장 타이머 로직을 몰아넣고, `GamigotchiApp.mc`/`GamigotchiBackground.mc`/`GamigotchiDelegate.mc`/`GamigotchiStatusView.mc`가 이걸 갖다 씀. 상세 설계는 REQUIREMENTS.md 참고.

**가장 큰 삽질 — 모듈 함수는 `public` 없으면 크로스 파일 호출이 런타임에 죽는다.**

`GamigotchiStats` 모듈에 함수를 만들고 아무 접근제어자 없이 그대로 뒀더니, `GamigotchiApp.onStart()`에서 `GamigotchiStats.tick()`을 부르는 순간 컴파일은 멀쩡히 되는데 실행하면 크래시:

```
Error: Illegal Access (Out of Bounds)
Details: Failed invoking <symbol>
Stack: - onStart() at GamigotchiApp.mc:33
```

같은 파일 안에서 부르는 게 아니라 **다른 파일에서 모듈 함수를 부를 때는 `public function`으로 명시해야** 함. `private`/`hidden` 키워드는 모듈 레벨에서 아예 문법 에러(`extraneous input`)— 모듈 함수는 기본이 `public`도 `hidden`도 아닌 애매한 상태였다가, 명시적으로 `public`을 붙이니 해결됨. 오늘 벌써 세 번째로 겪는 "컴파일은 되는데 런타임에 Failed invoking symbol로 죽는" 패턴 — Monkey C는 이 클래스의 링크 문제를 컴파일 타임에 못 잡아준다는 걸 체감함.

부수적으로: `module` 블록 안에서는 `Toybox.System` 같은 것도 클래스와 달리 암묵적으로 안 열려 있어서, `System.println` 쓰려면 `import Toybox.System`을 명시해야 했음 (클래스에서는 왜인지 import 없이도 됐었는데, 모듈은 다름).

**모니터링 중 헷갈렸던 것**: `monkeydo`로 재실행할 때마다 이전 실행에서 났던 크래시 로그가 디버그 콘솔에 다시 찍혀서 나옴 (연결이 새로 붙을 때 버퍼된 이전 로그를 재생하는 듯). 실제로는 크래시 안 났는데 로그만 보면 크래시난 것처럼 보여서 헷갈림 — 스크린샷으로 실제 화면 상태를 같이 봐야 진짜 크래시인지 판단 가능.

**시뮬레이터 자동 입력**: 물리 버튼 클릭은 반응 없음(터치스크린 없는 기기라 마우스 클릭이 안 먹히는 듯). `SendKeys`로 키보드 입력은 성공했는데(Alt 탭 트릭으로 포그라운드 잠금 우회), 실제 SELECT 버튼에 대응하는 키를 못 찾음 — `{ENTER}`는 예상과 다르게 Up 버튼(상태 화면 열기)에 매핑됨. Feed/Play/Clean/Medicine처럼 메뉴 선택이 필요한 액션은 결국 사람이 눌러야 검증 가능. 성장/아픔/사망처럼 자동으로(버튼 없이) 진행되는 로직은 시뮬레이터 재실행만으로 전부 자동 검증함 (임시로 감소 속도/임계값을 극단적으로 낮춰서 알→아기→어른, 정상→아픔→사망 전 구간 스크린샷으로 확인).

시뮬레이터 persisted storage 파일 위치도 확인함: `%LOCALAPPDATA%\Temp\com.garmin.connectiq\GARMIN\APPS\DATA\{앱이름}.DAT/.IDX/.IMT` — 이 파일들 지우면 다음 실행이 완전 첫 실행(재설치)처럼 됨. 실기기 리셋 없이 "새 알" 상태로 빠르게 되돌릴 때 유용.

---

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
