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

        _checkPendingEvolution();

        // 연출 도중 메뉴 등으로 화면을 벗어나면 onHide가 타이머만 멈추고
        // _showingEvolution은 남아 연출 화면에 영구 고착됨 → 복귀 시 타이머 재가동 (감사 #10b)
        if (_showingEvolution && _evolutionTimer == null) {
            _evolutionTimer = new Timer.Timer();
            _evolutionTimer.start(method(:_onEvolutionTimeout), 3500, false);
        }
    }

    // pendingEvolution 플래그를 소비해 진화 축하 연출 시작.
    // onShow뿐 아니라 애니 틱에서도 확인 - 화면을 보고 있는 중에 진화가 일어나면
    // onShow만으론 다음 화면 진입 때까지 스프라이트만 조용히 바뀌고 연출이 지연됨 (감사 #10a)
    private function _checkPendingEvolution() as Void {
        if (_showingEvolution) { return; }
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
        _checkPendingEvolution(); // 화면 표시 중에 진화해도 즉시 연출 (감사 #10a)
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

        // 청년기 + 정상 상태에서만 배회 적용 (다른 단계는 아직 걷기 프레임이 없음)
        var canWander = (stage == 2 && health == 0);
        var charY = h / 2 - 10;

        if (!canWander) {
            _walkX = 0; // 배회 불가능한 단계면 중앙 고정
        }

        // 방향 E: 런 리액션 모션 (Tier 1) - 새 아트 없이 기존 2프레임 토글로 오프셋만 적용
        var reaction = app.getReactionMotion();
        var reactionX = 0;
        var reactionY = 0;
        if (reaction == GamigotchiStats.REACTION_FAST) {
            reactionY = (_frame == 1) ? -4 : 4; // 통통 튐
        } else if (reaction == GamigotchiStats.REACTION_TIRED) {
            reactionY = 6; // 축 처짐(스쿼시)
        } else if (reaction == GamigotchiStats.REACTION_LONG) {
            reactionX = (_frame == 1) ? -2 : 2; // 다리 후들거림
        }

        // Character
        var expression = app.getExpression();
        var charStageX = cx + (canWander ? _walkX : 0) + reactionX;
        var bitmapId = (canWander && _isWalking) ? _getWalkBitmapId(_walkFrameIdx) : _getCharBitmapId(stage, health, _frame, expression);
        var bitmap = WatchUi.loadResource(bitmapId) as WatchUi.BitmapResource;
        var charDrawY = charY + reactionY;
        dc.drawBitmap(charStageX - bitmap.getWidth() / 2, charDrawY - bitmap.getHeight() / 2, bitmap);

        // Speech bubble - 원작처럼 게이지/응아 상세 수치는 상태 화면(Up 버튼)으로 미루고
        // 메인 화면은 심플하게. 예전에 하트/별 게이지가 있던 자리로 이동(2026-08-29) - 화면
        // 맨 위(y=8 근처)는 원형이라 폭이 좁아 긴 문구가 테두리에 잘릴 수 있어 그보다 살짝
        // 아래(원이 넓어지는 지점)에 배치
        var bubble = _getBubble(app, health);
        if (!bubble.equals("")) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 45, Graphics.FONT_TINY, bubble, Graphics.TEXT_JUSTIFY_CENTER);
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

        // 진화 연출은 기분 상태와 무관하게 항상 기본 표정으로 표시
        var bitmap = WatchUi.loadResource(_getCharBitmapId(_evolutionStage, 0, _frame, GamigotchiStats.EXPR_NORMAL)) as WatchUi.BitmapResource;
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

    // 설계 감사 #6: *Sick*.png이 전부 단색 placeholder 확인됨(2026-07-15) - 실제 아픈 아트가
    // 나오기 전까진 normal로 폴백. "귀여움 최우선" 원칙상 아무 표시 없는 것보다 흉한 단색
    // 사각형이 뜨는 게 더 나쁘다고 판단, "so hungry..." 말풍선이 상태를 대신 알려줌.
    // 아트 완성되면 아래 주석 해제
    private function _getCharBitmapId(stage as Number, health as Number, frame as Number, expression as Number) as ResourceId {
        // var sick = (health == 1);
        if (stage == 0) {
            // if (sick) { return (frame == 1) ? Rez.Drawables.EggSick1 : Rez.Drawables.EggSick2; }
            if (_eggEasterEgg) { return Rez.Drawables.EggEaster; }
            return (frame == 1) ? Rez.Drawables.EggNormal1 : Rez.Drawables.EggNormal2;
        }
        if (stage == 1) {
            // if (sick) { return (frame == 1) ? Rez.Drawables.BabySick1 : Rez.Drawables.BabySick2; }
            return _getBabyExpressionBitmapId(expression, frame);
        }
        // if (sick) { return (frame == 1) ? Rez.Drawables.AdultSick1 : Rez.Drawables.AdultSick2; }
        return _getAdultExpressionBitmapId(expression, frame, getApp().getCareTierAdult());
    }

    // 방향 D: 아기 단계 표정별 스프라이트 (2026-08-29 아트 연결 완료)
    //
    // 케어 등급 없음(2026-08-29 결정): 알->아기 전환이 2시간짜리라 케어할 기회가 거의 없어서
    // 등급을 안 나누고 항상 Normal 고정으로 감. 이미 만들어둔 BabyNeglected/BabyWellCared
    // 아트는 v2에서 성장 단계가 늘어나면 재검토
    private function _getBabyExpressionBitmapId(expression as Number, frame as Number) as ResourceId {
        if (expression == GamigotchiStats.EXPR_SULKY) { return (frame == 1) ? Rez.Drawables.BabySulky1 : Rez.Drawables.BabySulky2; }
        if (expression == GamigotchiStats.EXPR_DELIGHTED) { return (frame == 1) ? Rez.Drawables.BabyDelighted1 : Rez.Drawables.BabyDelighted2; }
        if (expression == GamigotchiStats.EXPR_HEART) { return (frame == 1) ? Rez.Drawables.BabyHeart1 : Rez.Drawables.BabyHeart2; }
        return (frame == 1) ? Rez.Drawables.BabyNormal1 : Rez.Drawables.BabyNormal2;
    }

    // 방향 D: 어른 단계 표정별 스프라이트 (2026-08-29 아트 연결 완료).
    // 케어 등급이 표정보다 우선 - Neglected/Well-cared는 그 등급 고유의 몸 상태를 계속
    // 유지해야 정체성이 안정적으로 보임(등급3×표정3 조합 폭발 방지). 표정은 Normal 등급에서만 반영
    private function _getAdultExpressionBitmapId(expression as Number, frame as Number, careTier as Number) as ResourceId {
        if (careTier == GamigotchiStats.CARE_TIER_NEGLECTED) { return (frame == 1) ? Rez.Drawables.AdultNeglected1 : Rez.Drawables.AdultNeglected2; }
        if (careTier == GamigotchiStats.CARE_TIER_WELL) { return (frame == 1) ? Rez.Drawables.AdultWellCared1 : Rez.Drawables.AdultWellCared2; }
        if (expression == GamigotchiStats.EXPR_SULKY) { return (frame == 1) ? Rez.Drawables.AdultSulky1 : Rez.Drawables.AdultSulky2; }
        if (expression == GamigotchiStats.EXPR_DELIGHTED) { return (frame == 1) ? Rez.Drawables.AdultDelighted1 : Rez.Drawables.AdultDelighted2; }
        if (expression == GamigotchiStats.EXPR_HEART) { return (frame == 1) ? Rez.Drawables.AdultHeart1 : Rez.Drawables.AdultHeart2; }
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
