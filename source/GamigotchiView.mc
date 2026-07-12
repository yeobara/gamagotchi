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
    private var _eggEasterEgg as Boolean = false;

    // 배회(걷기) 상태 머신 - 청년기에서만 사용
    private var _walkX as Number = 0;         // 중심 기준 현재 x 오프셋
    private var _walkTargetX as Number = 0;   // 걷는 중이면 목표 오프셋
    private var _isWalking as Boolean = false;
    private var _walkFrameIdx as Number = 0;  // 0~5, 걷기 프레임 순환
    private var _walkTicksLeft as Number = 0; // 현재 상태(서있기/걷기) 유지 틱 수

    const EGG_EASTER_EGG_CHANCE = 5; // 알 단계에서 이 확률(%)로 "이미 펭귄인 알" 등장
    const WALK_RANGE = 55;   // 중심에서 좌우 최대 이동 범위(px)
    const WALK_STEP = 4;     // 틱당 이동 픽셀
    const WALK_ANIM_FRAMES = 6;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        // 손목 들었을 때(화면 켜질 때) 2프레임 애니메이션 시작
        _animTimer = new Timer.Timer();
        _animTimer.start(method(:_onAnimTick), 500, true);

        // 알 단계일 때만 이스터에그 등장 여부를 세션당 한 번 굴림 (매 프레임 굴리면 깜빡거림)
        var roll = Math.rand() % 100;
        if (roll < 0) { roll = -roll; }
        _eggEasterEgg = (roll < EGG_EASTER_EGG_CHANCE);

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
        _updateWander();
        WatchUi.requestUpdate();
    }

    // 주기적이지 않게 "서있기 <-> 걷기"를 오가며 좌우로 불규칙하게 배회
    private function _updateWander() as Void {
        _walkTicksLeft -= 1;
        if (_isWalking) {
            _walkFrameIdx = (_walkFrameIdx + 1) % WALK_ANIM_FRAMES;
            if (_walkX < _walkTargetX) {
                _walkX += WALK_STEP;
                if (_walkX > _walkTargetX) { _walkX = _walkTargetX; }
            } else if (_walkX > _walkTargetX) {
                _walkX -= WALK_STEP;
                if (_walkX < _walkTargetX) { _walkX = _walkTargetX; }
            }
            if (_walkX == _walkTargetX || _walkTicksLeft <= 0) {
                _isWalking = false;
                _walkTicksLeft = 6 + (_randBelow(10)); // 3~8초 서있기 (500ms 틱 기준)
            }
        } else {
            if (_walkTicksLeft <= 0) {
                _isWalking = true;
                _walkTargetX = _randBelow(WALK_RANGE * 2 + 1) - WALK_RANGE;
                _walkTicksLeft = 20; // 최대 10초 안에 도착 못하면 그 자리에서 멈춤
            }
        }
    }

    private function _randBelow(n as Number) as Number {
        var r = Math.rand() % n;
        if (r < 0) { r = -r; }
        return r;
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

        // 청년기 + 정상 상태에서만 배경/배회 적용 (다른 단계는 아직 걷기 프레임이 없음)
        var canWander = (stage == 2 && health == 0);
        var charY = h / 2 - 10;

        if (canWander) {
            var ground = WatchUi.loadResource(Rez.Drawables.Ground) as WatchUi.BitmapResource;
            dc.drawBitmap(cx - ground.getWidth() / 2, charY + 52, ground);
        } else {
            _walkX = 0; // 배회 불가능한 단계면 중앙 고정
        }

        // Character
        var charStageX = cx + (canWander ? _walkX : 0);
        var bitmapId = (canWander && _isWalking) ? _getWalkBitmapId(_walkFrameIdx) : _getCharBitmapId(stage, health, _frame);
        var bitmap = WatchUi.loadResource(bitmapId) as WatchUi.BitmapResource;
        dc.drawBitmap(charStageX - bitmap.getWidth() / 2, charY - bitmap.getHeight() / 2, bitmap);

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

    private function _getWalkBitmapId(frameIdx as Number) as ResourceId {
        switch (frameIdx) {
            case 0: return Rez.Drawables.AdultWalk1;
            case 1: return Rez.Drawables.AdultWalk2;
            case 2: return Rez.Drawables.AdultWalk3;
            case 3: return Rez.Drawables.AdultWalk4;
            case 4: return Rez.Drawables.AdultWalk5;
            default: return Rez.Drawables.AdultWalk6;
        }
    }

    private function _getCharBitmapId(stage as Number, health as Number, frame as Number) as ResourceId {
        var sick = (health == 1);
        if (stage == 0) {
            if (sick) { return (frame == 1) ? Rez.Drawables.EggSick1 : Rez.Drawables.EggSick2; }
            if (_eggEasterEgg) { return Rez.Drawables.EggEaster; }
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
