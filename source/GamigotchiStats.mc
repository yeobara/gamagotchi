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

    // 알 -> 아기: 3일, 아기 -> 어른: 추가 10일 (건강 유지 누적 시간 기준, 초 단위)
    const STAGE_THRESHOLDS_SEC = [3 * 86400, 10 * 86400];

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

        var isCriticallyLow = (hunger <= 0.0) || (happiness <= 0.0);
        if (isCriticallyLow) {
            _handleCriticalGauge(healthStatus, now);
        } else {
            if (healthStatus == 1) {
                Storage.setValue("healthStatus", 0);
            }
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
