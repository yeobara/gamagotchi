import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class GamigotchiStatusView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var app = getApp();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 30, Graphics.FONT_MEDIUM, "Status", Graphics.TEXT_JUSTIFY_CENTER);

        var tokens = app.getTokens();
        dc.drawText(cx, h / 2 - 50, Graphics.FONT_SMALL, "Tokens: " + tokens.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        var fedInfo = Gregorian.info(new Time.Moment(app.getLastFedTime()), Time.FORMAT_SHORT);
        var fedStr = fedInfo.month.format("%02d") + "/" + fedInfo.day.format("%02d") + " " +
                     fedInfo.hour.format("%02d") + ":" + fedInfo.min.format("%02d");
        dc.drawText(cx, h / 2 - 10, Graphics.FONT_SMALL, "Last fed: " + fedStr, Graphics.TEXT_JUSTIFY_CENTER);

        var count = app.getQualifyingRunCount();
        var stage = app.getGrowthStage();
        var stageName = (stage == 0) ? "Egg" : ((stage == 1) ? "Baby" : "Adult");
        dc.drawText(cx, h / 2 + 30, Graphics.FONT_SMALL, "Growth: " + stageName + " (" + count.format("%d") + "/13)", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 30, Graphics.FONT_XTINY, "Back: bottom-right", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class GamigotchiStatusDelegate extends WatchUi.BehaviorDelegate {

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
