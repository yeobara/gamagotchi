import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class GamigotchiView extends WatchUi.View {

    private var _frame as Number = 1;
    private var _animTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        // 손목 들었을 때(화면 켜질 때) 2프레임 애니메이션 시작
        _animTimer = new Timer.Timer();
        _animTimer.start(method(:_onAnimTick), 500, true);
    }

    function onHide() as Void {
        if (_animTimer != null) {
            _animTimer.stop();
            _animTimer = null;
        }
    }

    function _onAnimTick() as Void {
        _frame = (_frame == 1) ? 2 : 1;
        WatchUi.requestUpdate();
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
        var bitmap = WatchUi.loadResource(_getCharBitmapId(stage, health, _frame)) as WatchUi.BitmapResource;
        var charY = h / 2 - 20;
        dc.drawBitmap(cx - bitmap.getWidth() / 2, charY - bitmap.getHeight() / 2, bitmap);

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

    private function _getCharBitmapId(stage as Number, health as Number, frame as Number) as ResourceId {
        var sick = (health == 1);
        if (stage == 0) {
            if (sick) { return (frame == 1) ? Rez.Drawables.EggSick1 : Rez.Drawables.EggSick2; }
            return (frame == 1) ? Rez.Drawables.EggNormal1 : Rez.Drawables.EggNormal2;
        }
        if (stage == 1) {
            if (sick) { return (frame == 1) ? Rez.Drawables.BabySick1 : Rez.Drawables.BabySick2; }
            return (frame == 1) ? Rez.Drawables.BabyNormal1 : Rez.Drawables.BabyNormal2;
        }
        if (sick) { return (frame == 1) ? Rez.Drawables.AdultSick1 : Rez.Drawables.AdultSick2; }
        return (frame == 1) ? Rez.Drawables.AdultNormal1 : Rez.Drawables.AdultNormal2;
    }

    private function _getBubble(app as GamigotchiApp, health as Number) as String {
        var transient = app.getTransientMessage();
        if (!transient.equals("")) { return transient; }
        if (health == 1) { return "so hungry..."; }
        var elapsed = Time.now().value() - app.getLastFedTime();
        if (elapsed >= 36 * 3600) { return "hungry..."; }
        return "";
    }
}
