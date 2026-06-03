import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class GamigotchiView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();

        var app = getApp();
        var stage = app.getGrowthStage();
        var health = app.getHealthStatus();

        // Time
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 30, Graphics.FONT_MEDIUM, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Character
        var charStr = _getCharStr(stage, health);
        var charColor = (health == 1) ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE;
        dc.setColor(charColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 20, Graphics.FONT_LARGE, charStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Speech bubble
        var bubble = _getBubble(app, health);
        if (!bubble.equals("")) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 40, Graphics.FONT_TINY, bubble, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Tokens
        var tokens = app.getTokens();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 35, Graphics.FONT_SMALL, tokens.format("%d") + " tokens", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onHide() as Void {
    }

    private function _getCharStr(stage as Number, health as Number) as String {
        if (health == 1) {
            if (stage == 0) { return "( x_x )"; }
            if (stage == 1) { return "(>_<)v"; }
            return "(X_X)/";
        }
        if (stage == 0) { return "( o )"; }
        if (stage == 1) { return "(^.^)v"; }
        return "(^v^)/";
    }

    private function _getBubble(app as GamigotchiApp, health as Number) as String {
        if (health == 1) { return "so hungry..."; }
        var elapsed = Time.now().value() - app.getLastFedTime();
        if (elapsed >= 36 * 3600) { return "hungry..."; }
        return "";
    }
}
