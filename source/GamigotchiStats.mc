import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// 배고픔/행복 게이지, 응아, 성장 타이머 계산 로직.
// foreground(GamigotchiApp)와 background(GamigotchiBackground) 양쪽에서 호출됨 -
// WatchUi 등 foreground 전용 API는 쓰지 않음.
module GamigotchiStats {
    const GAUGE_MAX = 100.0;
    const HEALTHY_THRESHOLD = 50.0; // 이 이상이어야 "건강 유지"로 쳐서 성장 타이머가 감

    // 48시간 방치하면 게이지가 0에 도달하는 속도 (기존 "48h=아픈 상태" 감각 유지)
    const DECAY_PER_HOUR = GAUGE_MAX / 48.0;
    const POOP_PENALTY_MULT = 1.5; // 응아 방치 시 감소 속도 배율
    const POOP_INTERVAL_HOURS = 8.0; // 8시간마다 응아 1개 발생
    const SICK_TO_DEAD_HOURS = 24.0; // 아픈 상태 24시간 지속 시 사망 (기존 72h 총합과 일치)

    // 알 -> 아기: 2시간(짧은 기대감 비트, 2026-07-15 문서 결정 반영 - 기존 3일은 문서-코드 불일치였음),
    // 아기 -> 어른: 추가 10일 (건강 유지 누적 시간 기준, 초 단위). 현행 단일 감소율(약 2.08/시간)로도
    // 게이지 100->50에 약 24시간이 걸리므로 2시간 부화엔 별도 케어 불필요. 튜닝값, 실기기 반응 보고 조정
    // ⚠️ 문서의 단계별 감소 배율(알 ×0.4, 유아 배고픔 ×1.6, 청년 행복 ×1.6)은 아직 미구현 (설계 감사 #11)
    const STAGE_THRESHOLDS_SEC = [2 * 3600, 10 * 86400];

    // 방향 E: 런 데이터 리액션 - 페이스/거리 기반 태그 (Tier 1, 2026-07-15)
    // 날씨 기반 태그(더움/추움/비)는 Toybox.Weather 검증 후 4~6번대로 추가 예정
    const REACTION_NONE = 0;
    const REACTION_FAST = 1;  // 빠른 페이스 - 통통 튐
    const REACTION_TIRED = 2; // LSD(느림+장거리) - 축 처짐
    const REACTION_LONG = 3;  // 장거리(페이스 무관) - 다리 후들거림

    const LONG_DISTANCE_KM = 8.0;     // 이 이상이면 "장거리" 태그 (가안, 튜닝 필요)
    const SLOW_PACE_MIN_PER_KM = 7.5; // 이 이상 느리면 "슬로우" 태그 (가안)
    const FAST_PACE_MIN_PER_KM = 5.5; // 이 이하로 빠르면 "패스트" 태그 (가안)

    // 방향 D: 얼굴/표정 (2026-07-15) - 게이지 파생 표정. 알 단계는 얼굴 없어서 미적용,
    // 아픈 상태는 별도 스프라이트 계열이라 미적용 (정상 상태에서만 표정 분기)
    const EXPR_NORMAL = 0;
    const EXPR_SULKY = 1;     // 둘 중 하나라도 낮음 - 시무룩
    const EXPR_DELIGHTED = 2; // 둘 다 높음 - 활짝
    const EXPR_HEART = 3;     // 방금 급식 (트랜지언트 - GamigotchiApp에서 타이머로 관리)

    const EXPR_LOW_THRESHOLD = 30.0;  // ALERT_THRESHOLD와 동일 감각 - 이 이하면 시무룩
    const EXPR_HIGH_THRESHOLD = 70.0; // 이 이상이면 활짝 (가안, 튜닝 필요)

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
        if (distanceKm <= 0.0 || elapsedMs <= 0) {
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

        var hunger = _clamp(_getFloat("hunger") - DECAY_PER_HOUR * penalty * elapsedHours);
        var happiness = _clamp(_getFloat("happiness") - DECAY_PER_HOUR * penalty * elapsedHours);
        Storage.setValue("hunger", hunger);
        Storage.setValue("happiness", happiness);

        _accumulatePoop(elapsedSec);

        // 아픔/사망은 배고픔 단독 트리거 (행복 0은 소프트 실패 - 성장만 멈추고 안 죽음)
        if (hunger <= 0.0) {
            _handleCriticalGauge(healthStatus, now);
        } else if (healthStatus == 1) {
            Storage.setValue("healthStatus", 0);
        }

        if (hunger >= HEALTHY_THRESHOLD && happiness >= HEALTHY_THRESHOLD) {
            _accumulateGrowth(elapsedSec);
        }
    }

    function _handleCriticalGauge(healthStatus as Number, now as Number) as Void {
        if (healthStatus == 0) {
            Storage.setValue("healthStatus", 1);
            Storage.setValue("sickSinceTime", now);
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
            growthStage += 1;
            healthyElapsed = 0;
            Storage.setValue("growthStage", growthStage);
            Storage.setValue("pendingEvolution", true); // 다음에 앱 열 때 축하 연출 표시용
        }
        Storage.setValue("healthyElapsedSeconds", healthyElapsed);
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
