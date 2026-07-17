import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// ⚠️ TEST ONLY (2026-07-17): 토큰-러닝 연동 디버깅용 전용 화면 (Down 버튼). 확인 후 제거.
class GamigotchiDebugLogView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 26, Graphics.FONT_MEDIUM, "Debug Log", Graphics.TEXT_JUSTIFY_CENTER);

        var acCalled = Storage.getValue("debugActivityCompletedCalled");
        var acCalledVal = (acCalled instanceof Boolean && acCalled) ? "Y" : "N";
        var sportRaw = Storage.getValue("debugSportRaw");
        var sportStr = (sportRaw instanceof String) ? sportRaw : "?";

        var lastTemporal = Storage.getValue("debugLastTemporalEventTime");
        var lastTemporalVal = (lastTemporal instanceof Number) ? lastTemporal : -1;
        var agoStr = (lastTemporalVal < 0) ? "never" : ((Time.now().value() - lastTemporalVal).format("%d") + "s ago");

        var dailyEarned = Storage.getValue("dailyTokenEarned");
        var dailyEarnedVal = (dailyEarned instanceof Number) ? dailyEarned : -1;

        var tickCrash = Storage.getValue("debugTickCrashMsg");
        var tickCrashStr = (tickCrash instanceof String) ? tickCrash : "none";
        var regAcCrash = Storage.getValue("debugRegisterACCrashMsg");
        var regAcStr = (regAcCrash instanceof String) ? regAcCrash : "?";

        // 지금 이 순간 실제로 활동(러닝 등)이 기록 중인지 직접 조회 - 백그라운드 이벤트를
        // 거치지 않는 실시간 확인용. 러닝 중에 Down 버튼 눌러서 바로 확인 가능.
        var liveInfo = Activity.getActivityInfo();
        var liveStr = "none";
        if (liveInfo != null) {
            var d = liveInfo.elapsedDistance;
            liveStr = (d != null) ? (d / 1000.0).format("%.2f") + "km" : "active,no dist";
        }

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 75, Graphics.FONT_SMALL, "AC: " + acCalledVal, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 - 48, Graphics.FONT_SMALL, "Sport: " + sportStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 - 21, Graphics.FONT_SMALL, "TE: " + agoStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 6, Graphics.FONT_SMALL, "Ea: " + dailyEarnedVal, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 30, Graphics.FONT_XTINY, "Live: " + liveStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 44, Graphics.FONT_XTINY, "Reg:" + regAcStr + " Tick:" + tickCrashStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 28, Graphics.FONT_XTINY, "Back: bottom-right", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class GamigotchiDebugLogDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
