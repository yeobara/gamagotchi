import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// 배고픔/행복 게이지, 응아, 성장 타이머 계산 로직.
// foreground(GamigotchiApp)와 background(GamigotchiBackground) 양쪽에서 호출됨 -
// WatchUi 등 foreground 전용 API는 쓰지 않음.
//
// (:background) 필수: 백그라운드 서비스(GamigotchiBackground)가 tick()/getGauge()/
// computeRunReaction()을 호출하는데, 이 어노테이션이 없으면 백그라운드 이미지에
// 포함되지 않아 실기기에서 "Failed invoking symbol"로 서비스가 죽음(시뮬레이터는
// 분리를 강제 안 해서 정상 동작 → 실기기에서만 재현됨). 2026-07-17 확인.
(:background)
module GamigotchiStats {
    const GAUGE_MAX = 100.0;
    const HEALTHY_THRESHOLD = 50.0; // 이 이상이어야 "건강 유지"로 쳐서 성장 타이머가 감

    // 48시간 방치하면 게이지가 0에 도달하는 속도 (기존 "48h=아픈 상태" 감각 유지)
    const DECAY_PER_HOUR = GAUGE_MAX / 48.0;
    const POOP_PENALTY_MULT = 1.5; // 응아 방치 시 감소 속도 배율
    const POOP_INTERVAL_HOURS = 8.0; // 8시간마다 응아 1개 발생
    const SICK_TO_DEAD_HOURS = 24.0; // 아픈 상태 24시간 지속 시 사망 (기존 72h 총합과 일치)

    // 알 -> 아기: 2시간(짧은 기대감 비트, 2026-07-15 문서 결정 반영 - 기존 3일은 문서-코드 불일치였음),
    // 아기 -> 어른: 추가 10일 (건강 유지 누적 시간 기준, 초 단위). 단계별 배율(아래 STAGE_*_DECAY_MULT)
    // 적용 후에도 알 단계는 ×0.4라 100->50에 약 60시간 걸려 2시간 부화엔 케어 불필요. 튜닝값
    const STAGE_THRESHOLDS_SEC = [2 * 3600, 10 * 86400];

    // 단계별 케어 차등 (2026-07-13 확정, 2026-07-16 구현 - 설계 감사 #11).
    // 인덱스: 0=알, 1=유아기, 2=청년기. 기준 감소(DECAY_PER_HOUR)에 곱해서 적용
    const STAGE_HUNGER_DECAY_MULT = [0.4, 1.6, 0.8];    // 유아기는 자주 먹여야
    const STAGE_HAPPINESS_DECAY_MULT = [0.4, 0.7, 1.6]; // 청년기는 잘 놀아줘야

    // 방향 E: 런 데이터 리액션 - 페이스/거리 기반 태그 (Tier 1, 2026-07-15)
    // 날씨 기반 태그(더움/추움/비)는 Toybox.Weather 검증 후 4~6번대로 추가 예정
    const REACTION_NONE = 0;
    const REACTION_FAST = 1;  // 빠른 페이스 - 통통 튐
    const REACTION_TIRED = 2; // LSD(느림+장거리) - 축 처짐
    const REACTION_LONG = 3;  // 장거리(페이스 무관) - 다리 후들거림

    const LONG_DISTANCE_KM = 8.0;     // 이 이상이면 "장거리" 태그 (가안, 튜닝 필요)
    const SLOW_PACE_MIN_PER_KM = 7.5; // 이 이상 느리면 "슬로우" 태그 (가안)
    const FAST_PACE_MIN_PER_KM = 5.5; // 이 이하로 빠르면 "패스트" 태그 (가안)
    const MIN_REACTION_DISTANCE_KM = 1.0; // 이 미만은 리액션 없음 (설계 감사 #12 - 진짜 러닝에만 반응)

    // 방향 D: 얼굴/표정 (2026-07-15) - 게이지 파생 표정. 알 단계는 얼굴 없어서 미적용,
    // 아픈 상태는 별도 스프라이트 계열이라 미적용 (정상 상태에서만 표정 분기)
    const EXPR_NORMAL = 0;
    const EXPR_SULKY = 1;     // 둘 중 하나라도 낮음 - 시무룩
    const EXPR_DELIGHTED = 2; // 둘 다 높음 - 활짝
    const EXPR_HEART = 3;     // 방금 급식 (트랜지언트 - GamigotchiApp에서 타이머로 관리)

    const EXPR_LOW_THRESHOLD = 30.0;  // ALERT_THRESHOLD와 동일 감각 - 이 이하면 시무룩
    const EXPR_HIGH_THRESHOLD = 70.0; // 이 이상이면 활짝 (가안, 튜닝 필요)

    // 케어 품질 등급 (2026-08-23 확정, 2026-08-29 트리거 변경) - 진화 체크포인트에서 그 단계
    // 동안의 케어를 평가해 다음 외형(성장 결과)을 가른다. 성장 "속도"(healthyElapsedSeconds)와는
    // 별개 트랙 - 이 점수는 결과(등급)만 결정하고 성장 타이머엔 영향 없음
    //
    // Neglected(뚱뚱) 트리거를 "케어 점수가 낮음"에서 "과식(불필요할 때도 계속 Feed)"으로 변경 -
    // 원작 다마고치의 "많이 먹이면 살찐다" 감각 계승. 케어 점수가 낮은데 과식도 안 했으면
    // (그냥 방치) Normal로 떨어짐 - "못 키운 것"은 뚱뚱해지는 게 아니라 그냥 평범해짐
    const CARE_TIER_NEGLECTED = 0; // 과식(과다 급식)으로 뚱뚱해진 결과
    const CARE_TIER_NORMAL = 1;    // 케어 점수 낮음(방치) - 기본 외형
    const CARE_TIER_WELL = 2;      // 케어 점수 높음 - 러너 체형

    const CARE_HIGH_CUTOFF = 75.0;  // 이상 - Well-cared
    const CARE_SICK_PENALTY = 5.0;  // 그 단계에서 아픈 상태(healthStatus 0->1) 진입할 때마다 감점

    const OVEREAT_COUNT_THRESHOLD = 5;     // 한 단계 동안 과식이 이 횟수 이상이면 Neglected(뚱뚱) 확정 (가안, 튜닝 필요)

    // 배고픔/행복 게이지로 표정 계산 (하트눈은 여기 포함 안 됨 - 호출부에서 트랜지언트로 덧씌움)
    public function computeExpression(hunger as Float, happiness as Float) as Number {
        if (hunger <= EXPR_LOW_THRESHOLD || happiness <= EXPR_LOW_THRESHOLD) {
            return EXPR_SULKY;
        }
        if (hunger >= EXPR_HIGH_THRESHOLD && happiness >= EXPR_HIGH_THRESHOLD) {
            return EXPR_DELIGHTED;
        }
        return EXPR_NORMAL;
    }

    // 런 하나의 거리(km)·소요시간(ms)으로 리액션 태그 계산.
    // 우선순위: 빠름(신남) > LSD(지침) > 장거리(단순 후들거림) > 없음
    public function computeRunReaction(distanceKm as Float, elapsedMs as Number) as Number {
        if (distanceKm < MIN_REACTION_DISTANCE_KM || elapsedMs <= 0) {
            return REACTION_NONE;
        }
        var paceMinPerKm = (elapsedMs / 60000.0) / distanceKm;
        var isLong = distanceKm >= LONG_DISTANCE_KM;
        var isSlow = paceMinPerKm >= SLOW_PACE_MIN_PER_KM;
        var isFast = paceMinPerKm <= FAST_PACE_MIN_PER_KM;

        if (isFast) { return REACTION_FAST; }
        if (isLong && isSlow) { return REACTION_TIRED; }
        if (isLong) { return REACTION_LONG; }
        return REACTION_NONE;
    }

    public function tick() as Void {
        var now = Time.now().value();
        var last = Storage.getValue("lastTickTime");
        if (!(last instanceof Number)) {
            Storage.setValue("lastTickTime", now);
            return;
        }

        var elapsedSec = now - last;
        if (elapsedSec <= 0) {
            return;
        }
        Storage.setValue("lastTickTime", now);

        var healthStatus = _getNumber("healthStatus", 0);
        if (healthStatus == 2) {
            return; // 이미 사망, SELECT로 리셋 대기 중
        }

        var poopCount = _getNumber("poopCount", 0);
        var penalty = (poopCount > 0) ? POOP_PENALTY_MULT : 1.0;
        var elapsedHours = elapsedSec / 3600.0;

        // 단계별 케어 차등 (설계 감사 #11) - growthStage가 배열 범위를 벗어날 일은 없으나 방어적으로 clamp
        var growthStage = _getNumber("growthStage", 0);
        var stageIdx = growthStage;
        if (stageIdx >= STAGE_HUNGER_DECAY_MULT.size()) { stageIdx = STAGE_HUNGER_DECAY_MULT.size() - 1; }
        var hungerMult = STAGE_HUNGER_DECAY_MULT[stageIdx];
        var happinessMult = STAGE_HAPPINESS_DECAY_MULT[stageIdx];

        var hunger = _clamp(_getFloat("hunger") - DECAY_PER_HOUR * penalty * hungerMult * elapsedHours);
        var happiness = _clamp(_getFloat("happiness") - DECAY_PER_HOUR * penalty * happinessMult * elapsedHours);
        Storage.setValue("hunger", hunger);
        Storage.setValue("happiness", happiness);

        _accumulateCareScore(hunger, happiness, elapsedSec);
        _accumulatePoop(elapsedSec);

        // 아픔/사망은 배고픔 단독 트리거 (행복 0은 소프트 실패 - 성장만 멈추고 안 죽음).
        // 회복은 Medicine 전용(GamigotchiApp.giveMedicine)으로만 - 설계 감사 #1: 예전엔
        // 배고픔이 0 넘기만 해도(=Feed 한 번으로) 자동으로 나아서 Medicine이 무의미했음
        if (hunger <= 0.0) {
            _handleCriticalGauge(healthStatus, now);
        }

        if (hunger >= HEALTHY_THRESHOLD && happiness >= HEALTHY_THRESHOLD) {
            _accumulateGrowth(elapsedSec);
        }
    }

    function _handleCriticalGauge(healthStatus as Number, now as Number) as Void {
        if (healthStatus == 0) {
            Storage.setValue("healthStatus", 1);
            Storage.setValue("sickSinceTime", now);
            Storage.setValue("careSickEpisodes", _getNumber("careSickEpisodes", 0) + 1);
            return;
        }
        // 이미 아픈 상태 - 얼마나 지속됐는지 확인
        var sickSince = _getNumber("sickSinceTime", now);
        if (now - sickSince >= SICK_TO_DEAD_HOURS * 3600) {
            Storage.setValue("healthStatus", 2);
        }
    }

    function _accumulatePoop(elapsedSec as Number) as Void {
        var accum = _getNumber("poopAccumSeconds", 0) + elapsedSec;
        var intervalSec = (POOP_INTERVAL_HOURS * 3600).toNumber();
        var poopCount = _getNumber("poopCount", 0);
        while (accum >= intervalSec) {
            poopCount += 1;
            accum -= intervalSec;
        }
        Storage.setValue("poopAccumSeconds", accum);
        Storage.setValue("poopCount", poopCount);
    }

    function _accumulateGrowth(elapsedSec as Number) as Void {
        var growthStage = _getNumber("growthStage", 0);
        if (growthStage >= STAGE_THRESHOLDS_SEC.size()) {
            return; // 이미 최종 단계
        }

        var healthyElapsed = _getNumber("healthyElapsedSeconds", 0) + elapsedSec;
        var threshold = STAGE_THRESHOLDS_SEC[growthStage];
        if (healthyElapsed >= threshold) {
            var tier = _finalizeCareTier();
            if (growthStage == 0) {
                Storage.setValue("careTierBaby", tier); // 알 단계 케어 -> 아기 외형
            } else if (growthStage == 1) {
                Storage.setValue("careTierAdult", tier); // 아기 단계 케어 -> 어른 외형
            }

            growthStage += 1;
            healthyElapsed = 0;
            Storage.setValue("growthStage", growthStage);
            Storage.setValue("pendingEvolution", true); // 다음에 앱 열 때 축하 연출 표시용
        }
        Storage.setValue("healthyElapsedSeconds", healthyElapsed);
    }

    // 방금 끝난 단계의 케어 점수(시간 가중 평균 게이지 - 아픈 상태 진입 감점)를 등급으로 확정하고
    // 다음 단계를 위해 누적값 리셋
    function _finalizeCareTier() as Number {
        var sum = Storage.getValue("careScoreSum");
        var sumVal = (sum instanceof Float) ? sum : ((sum instanceof Number) ? sum.toFloat() : 0.0);
        var elapsed = _getNumber("careScoreElapsedSec", 0);
        var sickEpisodes = _getNumber("careSickEpisodes", 0);
        var overeatCount = _getNumber("overeatCount", 0);

        var avgScore = (elapsed > 0) ? (sumVal / elapsed.toFloat()) : GAUGE_MAX;
        var finalScore = avgScore - sickEpisodes * CARE_SICK_PENALTY;
        if (finalScore < 0.0) { finalScore = 0.0; }

        Storage.setValue("careScoreSum", 0.0);
        Storage.setValue("careScoreElapsedSec", 0);
        Storage.setValue("careSickEpisodes", 0);
        Storage.setValue("overeatCount", 0);

        // 과식이 최우선 판정 - 케어 점수가 아무리 높아도 과식했으면 뚱뚱해짐 (원작 다마고치 "많이
        // 먹이면 살찐다" 감각). 과식 안 했는데 점수도 낮으면(그냥 방치) Normal - 뚱뚱해지는 게
        // 아니라 그냥 평범하게 못 큼
        if (overeatCount >= OVEREAT_COUNT_THRESHOLD) { return CARE_TIER_NEGLECTED; }
        if (finalScore >= CARE_HIGH_CUTOFF) { return CARE_TIER_WELL; }
        return CARE_TIER_NORMAL;
    }

    // Feed 시점에 호출 - 배고픔이 이미 꽉 찬(GAUGE_MAX) 상태인데도 먹이면 "과식"으로 집계
    // (GamigotchiApp.feed()에서 사용)
    public function recordFeed(hungerBeforeFeed as Float) as Void {
        if (hungerBeforeFeed >= GAUGE_MAX) {
            Storage.setValue("overeatCount", _getNumber("overeatCount", 0) + 1);
        }
    }

    // 단계 진행 중 매 tick마다 (hunger+happiness)/2를 경과시간 가중해 누적 - 진화 체크포인트에서
    // 평균을 내 케어 등급을 매김. 성장 여부(healthy threshold)와 무관하게 항상 누적
    function _accumulateCareScore(hunger as Float, happiness as Float, elapsedSec as Number) as Void {
        var sum = Storage.getValue("careScoreSum");
        var sumVal = (sum instanceof Float) ? sum : ((sum instanceof Number) ? sum.toFloat() : 0.0);
        sumVal += (hunger + happiness) / 2.0 * elapsedSec;
        Storage.setValue("careScoreSum", sumVal);
        Storage.setValue("careScoreElapsedSec", _getNumber("careScoreElapsedSec", 0) + elapsedSec);
    }

    // 뷰/앱에서 등급 조회용
    public function getCareTierBaby() as Number {
        return _getNumber("careTierBaby", CARE_TIER_NORMAL);
    }

    public function getCareTierAdult() as Number {
        return _getNumber("careTierAdult", CARE_TIER_NORMAL);
    }

    // 게이지를 amount만큼 올리고 결과값 반환 (Feed/Play/Medicine에서 사용)
    public function addGauge(key as String, amount as Float) as Float {
        var v = _clamp(_getFloat(key) + amount);
        Storage.setValue(key, v);
        return v;
    }

    public function getGauge(key as String) as Float {
        return _getFloat(key);
    }

    function _getFloat(key as String) as Float {
        var v = Storage.getValue(key);
        if (v instanceof Float) { return v; }
        if (v instanceof Number) { return v.toFloat(); }
        return GAUGE_MAX;
    }

    function _getNumber(key as String, fallback as Number) as Number {
        var v = Storage.getValue(key);
        return (v instanceof Number) ? v : fallback;
    }

    function _clamp(v as Float) as Float {
        if (v < 0.0) { return 0.0; }
        if (v > GAUGE_MAX) { return GAUGE_MAX; }
        return v;
    }
}
