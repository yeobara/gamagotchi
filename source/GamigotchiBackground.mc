import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Activity.SPORT_RUNNING = 1
(:background)
class GamigotchiBackground extends System.ServiceDelegate {

    const ALERT_THRESHOLD = 30.0; // 게이지가 이 이하로 떨어지면 알림

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var info = Activity.getActivityInfo();
        if (info != null) {
            var dist = info.elapsedDistance;
            System.println("onTemporalEvent: distance=" + dist);

            // 달리기 중이면 거리 저장 (최대값 갱신)
            var prev = Storage.getValue("lastRunDistance");
            var prevDist = (prev instanceof Float) ? prev : 0.0f;
            if (dist != null && dist > prevDist) {
                Storage.setValue("lastRunDistance", dist);
            }
        } else {
            System.println("onTemporalEvent: no active activity");
        }

        GamigotchiStats.tick();
        _checkGaugeAlert();

        // 다음 5분 뒤 이벤트 재등록 (안 하면 최초 1회만 발화하고 끝남)
        try {
            Background.registerForTemporalEvent(Time.now().add(new Time.Duration(5 * 60)));
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            System.println("onTemporalEvent: reschedule too soon, skipping");
        }

        Background.exit(null);
    }

    // 배고픔/행복 게이지가 경고 수준 이하로 떨어지면 1회만 알림
    // (게이지가 다시 오르면 GamigotchiApp.feed()/play()가 아니라 여기서 매 tick마다
    //  재확인하므로, 회복되면 자동으로 다음 위기 때 다시 알림 가능하도록 플래그를 풂)
    //
    // Notifications.showNotification()은 배경(:background) 컨텍스트에서
    // "Unexpected Type Error - Failed invoking <symbol>"로 크래시남 (시뮬레이터 확인).
    // 이미 이 컨텍스트에서 정상 동작 중인 Background 모듈의 requestApplicationWake()로 대체.
    // requestApplicationWake() 호출 뒤 반드시 Background.exit()가 이어져야 확인 다이얼로그가 뜸.
    private function _checkGaugeAlert() as Void {
        var hunger = GamigotchiStats.getGauge("hunger");
        var happiness = GamigotchiStats.getGauge("happiness");
        var isLow = (hunger <= ALERT_THRESHOLD) || (happiness <= ALERT_THRESHOLD);

        var notified = Storage.getValue("hungerNotified");
        var alreadyNotified = (notified instanceof Boolean) ? notified : false;

        if (isLow && !alreadyNotified) {
            Background.requestApplicationWake("Your penguin needs you!");
            Storage.setValue("hungerNotified", true);
        } else if (!isLow && alreadyNotified) {
            Storage.setValue("hungerNotified", false);
        }
    }

    function onActivityCompleted(activity) as Void {
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

        System.println("onActivityCompleted: dist=" + distanceM + "m tokens=" + tokensEarned);

        // 거리 초기화
        Storage.setValue("lastRunDistance", 0.0f);

        Background.exit({
            "tokens" => tokensEarned
        });
    }
}
