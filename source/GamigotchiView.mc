import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

class GamigotchiView extends WatchUi.View {

    private var _frame as Number = 1;
    private var _animTimer as Timer.Timer?;
    private var _showingEvolution as Boolean = false;
    private var _evolutionStage as Number = 0;
    private var _evolutionTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        // 손목 들었을 때(화면 켜질 때) 2프레임 애니메이션 시작
        _animTimer = new Timer.Timer();
        _animTimer.start(method(:_onAnimTick), 500, true);

        var pending = Storage.getValue("pendingEvolution");
        if (pending instanceof Boolean && pending) {
            Storage.setValue("pendingEvolution", false);
            _showingEvolution = true;
            _evolutionStage = getApp().getGrowthStage();
            _evolutionTimer = new Timer.Timer();
            _evolutionTimer.start(method(:_onEvolutionTimeout), 3500, false);
        }
    }

    function onHide() as Void {
        if (_animTimer != null) {
            _animTimer.stop();
            _animTimer = null;
        }
        if (_evolutionTimer != null) {
            _evolutionTimer.stop();
            _evolutionTimer = null;
        }
    }

    function _onEvolutionTimeout() as Void {
        _showingEvolution = false;
        WatchUi.requestUpdate();
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

        if (health == 2) {
            _drawDeathScreen(dc, cx, h);
            return;
        }

        if (_showingEvolution) {
            _drawEvolutionScreen(dc, cx, h);
            return;
        }

        // Hunger/Happy gauges (top) - 4 icons each, half-increments
        _drawIconGauge(dc, cx, 8, app.getHunger(), Rez.Drawables.HeartFull, Rez.Drawables.HeartHalf, Rez.Drawables.HeartEmpty);
        _drawIconGauge(dc, cx, 30, app.getHappiness(), Rez.Drawables.StarFull, Rez.Drawables.StarHalf, Rez.Drawables.StarEmpty);

        // Character
        var bitmap = WatchUi.loadResource(_getCharBitmapId(stage, health, _frame)) as WatchUi.BitmapResource;
        var charY = h / 2 - 10;
        dc.drawBitmap(cx - bitmap.getWidth() / 2, charY - bitmap.getHeight() / 2, bitmap);

        // Speech bubble
        var bubble = _getBubble(app, health);
        if (!bubble.equals("")) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 40, Graphics.FONT_TINY, bubble, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Tokens (coin icon + count)
        _drawTokenCount(dc, cx, h - 45, app.getTokens());
    }

    // 동전 아이콘 옆에 토큰 개수 표시
    private function _drawTokenCount(dc as Graphics.Dc, cx as Number, y as Number, tokens as Number) as Void {
        var coin = WatchUi.loadResource(Rez.Drawables.Coin) as WatchUi.BitmapResource;
        var text = tokens.format("%d");
        var textWidth = dc.getTextWidthInPixels(text, Graphics.FONT_SMALL);
        var gap = 6;
        var totalWidth = coin.getWidth() + gap + textWidth;
        var startX = cx - totalWidth / 2;

        dc.drawBitmap(startX, y - coin.getHeight() / 2, coin);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + coin.getWidth() + gap, y - Graphics.getFontHeight(Graphics.FONT_SMALL) / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // 배고픔/행복 게이지를 아이콘 4개(반칸 단위)로 표시 (value: 0~100)
    private function _drawIconGauge(dc as Graphics.Dc, cx as Number, y as Number, value as Float, fullId as ResourceId, halfId as ResourceId, emptyId as ResourceId) as Void {
        var pips = value / 100.0 * 4.0; // 0.0~4.0
        var full = WatchUi.loadResource(fullId) as WatchUi.BitmapResource;
        var iconW = full.getWidth();
        var spacing = 2;
        var totalW = iconW * 4 + spacing * 3;
        var x = cx - totalW / 2;

        for (var i = 0; i < 4; i += 1) {
            var id = emptyId;
            if (pips >= i + 1) {
                id = fullId;
            } else if (pips >= i + 0.5) {
                id = halfId;
            }
            var icon = WatchUi.loadResource(id) as WatchUi.BitmapResource;
            dc.drawBitmap(x, y, icon);
            x += iconW + spacing;
        }
    }

    // 진화 축하 연출: 방사형 광선(그래픽 도형만 사용, 별도 이미지 불필요) + 새 단계 스프라이트
    private function _drawEvolutionScreen(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cy = h / 2 - 10;
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        var rays = 12;
        for (var i = 0; i < rays; i += 1) {
            var angle = (Math.PI * 2 * i) / rays;
            var len = (i % 2 == 0) ? 115 : 90;
            var x2 = cx + (Math.sin(angle) * len).toNumber();
            var y2 = cy - (Math.cos(angle) * len).toNumber();
            dc.drawLine(cx, cy, x2, y2);
        }

        var bitmap = WatchUi.loadResource(_getCharBitmapId(_evolutionStage, 0, _frame)) as WatchUi.BitmapResource;
        dc.drawBitmap(cx - bitmap.getWidth() / 2, cy - bitmap.getHeight() / 2, bitmap);

        var stageName = (_evolutionStage == 1) ? "Baby" : "Adult";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 60, Graphics.FONT_SMALL, "Evolved into " + stageName + "!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _drawDeathScreen(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        var grave = WatchUi.loadResource(Rez.Drawables.Grave) as WatchUi.BitmapResource;
        var charY = h / 2 - 10;
        dc.drawBitmap(cx - grave.getWidth() / 2, charY - grave.getHeight() / 2, grave);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 40, Graphics.FONT_TINY, "Your pet has died.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 70, Graphics.FONT_XTINY, "SELECT: restart", Graphics.TEXT_JUSTIFY_CENTER);
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
        if (app.getHunger() <= 30.0 || app.getHappiness() <= 30.0) { return "hungry..."; }
        if (app.getPoopCount() > 0) { return "clean me up..."; }
        return "";
    }
}
