import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Activity.SPORT_RUNNING = 1
(:background)
class GamigotchiBackground extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var info = Activity.getActivityInfo();
        if (info == null) {
            System.println("onTemporalEvent: no active activity");
            Background.exit(null);
            return;
        }
        var dist = info.elapsedDistance;
        System.println("onTemporalEvent: distance=" + dist);

        // 달리기 중이면 거리 저장 (최대값 갱신)
        var prev = Storage.getValue("lastRunDistance");
        var prevDist = (prev instanceof Float) ? prev : 0.0f;
        if (dist != null && dist > prevDist) {
            Storage.setValue("lastRunDistance", dist);
        }

        _checkHungerNotification();

        // 다음 5분 뒤 이벤트 재등록 (안 하면 최초 1회만 발화하고 끝남)
        try {
            Background.registerForTemporalEvent(Time.now().add(new Time.Duration(5 * 60)));
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            System.println("onTemporalEvent: reschedule too soon, skipping");
        }

        Background.exit(null);
    }

    // 마지막 급식 후 36시간 지점에 1회만 배고픔 알림 발송
    // (48시간 = 아픈 상태 되기 12시간 전 경고). feed() 시 hungerNotified 플래그 리셋됨
    //
    // Notifications.showNotification()은 배경(:background) 컨텍스트에서
    // "Unexpected Type Error - Failed invoking <symbol>"로 크래시남 (시뮬레이터 확인).
    // 이미 이 컨텍스트에서 정상 동작 중인 Background 모듈의 requestApplicationWake()로 대체.
    // requestApplicationWake() 호출 뒤 반드시 Background.exit()가 이어져야 확인 다이얼로그가 뜸.
    private function _checkHungerNotification() as Void {
        var lastFed = Storage.getValue("lastFedTime");
        if (!(lastFed instanceof Number)) { return; }

        var notified = Storage.getValue("hungerNotified");
        var alreadyNotified = (notified instanceof Boolean) ? notified : false;
        if (alreadyNotified) { return; }

        var elapsed = Time.now().value() - lastFed;
        if (elapsed >= 36 * 3600) {
            Background.requestApplicationWake("Your penguin is hungry!");
            Storage.setValue("hungerNotified", true);
        }
    }

    function onActivityCompleted(activity) as Void {
        Storage.setValue("bgDebug", "onActivityCompleted called: " + activity);
        var isRun = (activity instanceof Dictionary) &&
                    ((activity as Dictionary).get(:sport) instanceof Number) &&
                    ((activity as Dictionary).get(:sport) == 1);
        System.println("isRun=" + isRun);
        if (!isRun) {
            Background.exit(null);
            return;
        }

        // 저장된 달리기 거리 사용
        var stored = Storage.getValue("lastRunDistance");
        var distanceM = (stored instanceof Float) ? stored : 0.0f;
        var distanceKm = distanceM / 1000.0f;

        // 토큰: 1km당 1토큰 (최소 1)
        var tokensEarned = distanceKm.toNumber();
        if (tokensEarned < 1) { tokensEarned = 1; }

        // 5km 이상이면 성장 카운트
        var runCount = Storage.getValue("qualifyingRunCount");
        var count = (runCount instanceof Number) ? runCount : 0;
        if (distanceM >= 5000.0f) { count = count + 1; }

        System.println("onActivityCompleted: dist=" + distanceM + "m tokens=" + tokensEarned);

        // 거리 초기화
        Storage.setValue("lastRunDistance", 0.0f);

        Background.exit({
            "tokens" => tokensEarned,
            "qualifyingRunCount" => count
        });
    }
}
