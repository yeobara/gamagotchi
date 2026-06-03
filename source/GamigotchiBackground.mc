import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

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

        Background.exit(null);
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
