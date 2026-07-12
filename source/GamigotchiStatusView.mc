import Toybox.Graphics;
import Toybox.Lang;
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
        dc.drawText(cx, h / 2 - 55, Graphics.FONT_SMALL, "Tokens: " + tokens.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        var hunger = app.getHunger().toNumber();
        var happiness = app.getHappiness().toNumber();
        dc.drawText(cx, h / 2 - 20, Graphics.FONT_SMALL, "Hunger: " + hunger.format("%d") + "  Happy: " + happiness.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        var stage = app.getGrowthStage();
        var stageName = (stage == 0) ? "Egg" : ((stage == 1) ? "Baby" : "Adult");
        var progressPct = (app.getGrowthProgress() * 100).toNumber();
        dc.drawText(cx, h / 2 + 15, Graphics.FONT_SMALL, "Growth: " + stageName + " (" + progressPct.format("%d") + "%)", Graphics.TEXT_JUSTIFY_CENTER);

        var poop = app.getPoopCount();
        dc.drawText(cx, h / 2 + 50, Graphics.FONT_SMALL, "Poop: " + poop.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

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
