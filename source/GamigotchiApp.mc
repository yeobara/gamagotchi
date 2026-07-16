import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class GamigotchiApp extends Application.AppBase {

    const FEED_COST = 1;
    const FEED_AMOUNT = 40.0;
    const PLAY_AMOUNT = 40.0;
    const PLAY_HUNGER_COST = 5.0; // Play는 토큰 대신 배고픔을 소모 (2026-07-14: 10→5, 체감상 과하다는 피드백으로 완화)
    const MEDICINE_COST = 3;

    // 토큰 이중 상한 (2026-07-13 확정, 2026-07-15 구현)
    const DAILY_TOKEN_CAP = 10; // 하루 획득 한도 - 매일 리셋
    const WALLET_TOKEN_CAP = 30; // 지갑 보유 한도

    // 방향 B: 긍정적 가변 보상 (2026-07-15 구현) - 런 종료 보너스는 GamigotchiBackground.BONUS_TOKEN_CHANCE_PCT
    const SPECIAL_REACTION_CHANCE_PCT = 15; // Feed/Play 시 특별 리액션 확률

    const MESSAGE_DURATION_SEC = 5; // 일반 말풍선(Feed/Play 등) 표시 시간
    // 방향 E: 런 리액션 모션 표시 시간. 리액션과 함께 뜨는 말풍선도 이 길이에 맞춰 표시
    // (모션-메시지 연출 일관성). 8초→30초 (설계 감사 #5 - 앱을 늦게 열면 놓치기 쉬웠음)
    const REACTION_MOTION_DURATION_SEC = 30;

    private var _transientMessage as String = "";
    private var _transientMessageUntil as Number = 0;
    private var _reactionMotion as Number = GamigotchiStats.REACTION_NONE;
    private var _reactionMotionUntil as Number = 0;
    private var _heartEyesUntil as Number = 0; // 방향 D: 급식 직후 하트눈 표정 트랜지언트

    function initialize() {
        AppBase.initialize();
        Math.srand(Time.now().value());
    }

    function onStart(state as Dictionary?) as Void {
        if (Storage.getValue("initialized") == null) {
            _resetCharacter();
            Storage.setValue("initialized", true);
            // onStart() 시점엔 아직 화면이 만들어지기 전이라 WatchUi.requestUpdate()를
            // 호출하면 안 됨(크래시) → requestUpdate 없이 상태만 세팅, 첫 onUpdate()가
            // 알아서 그려줌
            _transientMessage = "take care of your egg!";
            _transientMessageUntil = Time.now().value() + MESSAGE_DURATION_SEC;
        }
        GamigotchiStats.tick(); // 앱이 닫혀있던 동안 밀린 게이지 감소분 반영
        Background.registerForActivityCompletedEvent();

        // 5분 후 temporal event (이후 GamigotchiBackground.onTemporalEvent()가 5분 간격으로 재등록)
        try {
            Background.registerForTemporalEvent(Time.now().add(new Time.Duration(5 * 60)));
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            System.println("temporal event: too soon, skipping");
        }
    }

    function onStop(state as Dictionary?) as Void {
    }

    (:background)
    function getServiceDelegate() as Array {
        return [new GamigotchiBackground()];
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new GamigotchiView(), new GamigotchiDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        if (!(data instanceof Dictionary)) { return; }
        var d = data as Dictionary;

        var earned = d.get("tokens");
        var earnedVal = (earned instanceof Number) ? earned : 0;
        var granted = 0;
        if (earned instanceof Number) {
            granted = _creditTokens(earned);
        }

        var bonus = d.get("bonus");
        var isBonus = (granted > 0 && bonus instanceof Boolean && bonus);

        // 방향 E: 리액션 모션은 말풍선과 별개 채널 - 태그가 있으면 항상 재생
        var reactionTag = d.get("reactionTag");
        var hasReaction = (reactionTag instanceof Number && reactionTag != GamigotchiStats.REACTION_NONE);
        if (hasReaction) {
            _reactionMotion = reactionTag;
            _reactionMotionUntil = Time.now().value() + REACTION_MOTION_DURATION_SEC;
        }

        // 말풍선은 한 번에 하나만 표시 가능 → bonus(2배 토큰, 더 신남)를 우선.
        // 리액션 모션이 도는 동안 뜨는 메시지는 모션과 같은 길이로 유지.
        if (isBonus) {
            _setTransientMessageFor("bonus tokens!! x2!", hasReaction ? REACTION_MOTION_DURATION_SEC : MESSAGE_DURATION_SEC);
        } else if (hasReaction) {
            _setTransientMessageFor(_reactionMessage(reactionTag), REACTION_MOTION_DURATION_SEC);
        } else if (earnedVal > 0 && granted == 0) {
            // 설계 감사 #16: 한도(일일/지갑)에 막혀 0 지급이면 이유를 알려줌 - 안 그러면 버그로 오인
            _setTransientMessage("daily goal reached!");
        }

        WatchUi.requestUpdate();
    }

    // 방향 E: 태그별 말풍선 문구 (Tier 1)
    private function _reactionMessage(tag as Number) as String {
        if (tag == GamigotchiStats.REACTION_FAST) { return "whew, that was FAST!"; }
        if (tag == GamigotchiStats.REACTION_TIRED) { return "so tired... but proud"; }
        if (tag == GamigotchiStats.REACTION_LONG) { return "what a long run!"; }
        return "";
    }

    // 방향 E: 뷰가 현재 활성 리액션 모션을 그릴지 판단할 때 사용 (만료되면 NONE으로 리셋)
    function getReactionMotion() as Number {
        if (_reactionMotion != GamigotchiStats.REACTION_NONE && Time.now().value() >= _reactionMotionUntil) {
            _reactionMotion = GamigotchiStats.REACTION_NONE;
        }
        return _reactionMotion;
    }

    // 방향 D: 현재 표정 상태 - 하트눈(급식 직후) 우선, 아니면 게이지로 계산
    function getExpression() as Number {
        if (Time.now().value() < _heartEyesUntil) {
            return GamigotchiStats.EXPR_HEART;
        }
        return GamigotchiStats.computeExpression(getHunger(), getHappiness());
    }

    // 하루 획득 한도(DAILY_TOKEN_CAP)와 지갑 보유 한도(WALLET_TOKEN_CAP)를 함께 적용해 토큰 지급.
    // 실제로 지갑에 들어간 양만 "오늘 획득량"으로 집계 - 지갑이 가득 차 막힌 만큼은
    // 하루 한도를 깎지 않아서, 나중에 토큰을 써서 지갑에 여유가 생기면 같은 날 안에도 다시 채울 수 있음
    private function _creditTokens(earned as Number) as Number {
        var todayKey = _currentDayKey();
        var storedDay = Storage.getValue("dailyTokenDay");
        var dailyEarned = 0;
        if (storedDay instanceof Number && storedDay == todayKey) {
            var de = Storage.getValue("dailyTokenEarned");
            dailyEarned = (de instanceof Number) ? de : 0;
        } else {
            Storage.setValue("dailyTokenDay", todayKey);
            // 날짜가 바뀌면 어제 획득량을 반드시 0으로 초기화 (감사 #9).
            // 이게 없으면 아래 grantable<=0 조기 반환(지갑 가득 등) 경로에서
            // 어제 값이 Storage에 남아 오늘 한도를 잠식함
            Storage.setValue("dailyTokenEarned", 0);
        }

        var dailyRemaining = DAILY_TOKEN_CAP - dailyEarned;
        if (dailyRemaining < 0) { dailyRemaining = 0; }

        var cur = getTokens();
        var walletRemaining = WALLET_TOKEN_CAP - cur;
        if (walletRemaining < 0) { walletRemaining = 0; }

        var grantable = earned;
        if (grantable > dailyRemaining) { grantable = dailyRemaining; }
        if (grantable > walletRemaining) { grantable = walletRemaining; }
        if (grantable <= 0) { return 0; }

        Storage.setValue("dailyTokenEarned", dailyEarned + grantable);
        Storage.setValue("tokens", cur + grantable);
        return grantable;
    }

    // 로컬 달력 날짜를 하나의 정수로 표현 (일일 한도 리셋 판정용)
    private function _currentDayKey() as Number {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return (info.year * 10000) + (info.month * 100) + info.day;
    }

    function feed() as Void {
        var tokens = getTokens();
        if (tokens < FEED_COST) {
            _setTransientMessage("no tokens...");
            return;
        }
        Storage.setValue("tokens", tokens - FEED_COST);
        GamigotchiStats.addGauge("hunger", FEED_AMOUNT);
        _heartEyesUntil = Time.now().value() + MESSAGE_DURATION_SEC; // 방향 D: 말풍선과 같은 길이로 하트눈
        _setTransientMessage(_maybeSpecial("yum yum!", "SO yummy!! best meal ever!"));
    }

    function play() as Void {
        // 설계 감사 #2: 배고픔이 PLAY_HUNGER_COST 이하면 놀아주는 게 배고픔을 0으로 만들어
        // 아픈 상태를 유발할 수 있었음 - "놀아줬더니 아파짐"은 감정 연결 원칙에 위배돼 거부로 변경
        if (getHunger() <= PLAY_HUNGER_COST) {
            _setTransientMessage("too hungry to play...");
            return;
        }
        GamigotchiStats.addGauge("happiness", PLAY_AMOUNT);
        GamigotchiStats.addGauge("hunger", -PLAY_HUNGER_COST);
        _setTransientMessage(_maybeSpecial("wheee!", "wheee!! best day ever!!"));
    }

    // 낮은 확률(SPECIAL_REACTION_CHANCE_PCT)로 평소보다 신난 리액션 문구를 대신 보여줌
    // (방향 B: 긍정적 가변 보상 - 부정적 랜덤은 절대 섞지 않음)
    private function _maybeSpecial(normal as String, special as String) as String {
        return ((Math.rand() % 100) < SPECIAL_REACTION_CHANCE_PCT) ? special : normal;
    }

    function clean() as Void {
        if (getPoopCount() < 1) {
            _setTransientMessage("all clean!");
            return;
        }
        Storage.setValue("poopCount", 0);
        _setTransientMessage("cleaned up!");
    }

    function giveMedicine() as Void {
        if (getHealthStatus() != 1) {
            _setTransientMessage("not sick");
            return;
        }
        var tokens = getTokens();
        if (tokens < MEDICINE_COST) {
            _setTransientMessage("no tokens...");
            return;
        }
        Storage.setValue("tokens", tokens - MEDICINE_COST);
        GamigotchiStats.addGauge("hunger", GamigotchiStats.HEALTHY_THRESHOLD);
        GamigotchiStats.addGauge("happiness", GamigotchiStats.HEALTHY_THRESHOLD);
        Storage.setValue("healthStatus", 0);
        _setTransientMessage("feeling better!");
    }

    // 액션 결과 등 잠깐 보여줄 말풍선 메시지 (기본 5초 후 자동으로 사라짐)
    private function _setTransientMessage(msg as String) as Void {
        _setTransientMessageFor(msg, MESSAGE_DURATION_SEC);
    }

    private function _setTransientMessageFor(msg as String, durationSec as Number) as Void {
        _transientMessage = msg;
        _transientMessageUntil = Time.now().value() + durationSec;
        WatchUi.requestUpdate();
    }

    function getTransientMessage() as String {
        if (!_transientMessage.equals("") && Time.now().value() >= _transientMessageUntil) {
            _transientMessage = "";
        }
        return _transientMessage;
    }

    function getTokens() as Number {
        var t = Storage.getValue("tokens");
        return (t instanceof Number) ? t : 0;
    }

    function getGrowthStage() as Number {
        var g = Storage.getValue("growthStage");
        return (g instanceof Number) ? g : 0;
    }

    function getHealthStatus() as Number {
        var h = Storage.getValue("healthStatus");
        return (h instanceof Number) ? h : 0;
    }

    function getHunger() as Float {
        return GamigotchiStats.getGauge("hunger");
    }

    function getHappiness() as Float {
        return GamigotchiStats.getGauge("happiness");
    }

    function getPoopCount() as Number {
        var c = Storage.getValue("poopCount");
        return (c instanceof Number) ? c : 0;
    }

    // 현재 단계에서 다음 진화까지 진행률 (0.0~1.0)
    function getGrowthProgress() as Float {
        var stage = getGrowthStage();
        if (stage >= GamigotchiStats.STAGE_THRESHOLDS_SEC.size()) {
            return 1.0;
        }
        var elapsed = Storage.getValue("healthyElapsedSeconds");
        var elapsedVal = (elapsed instanceof Number) ? elapsed : 0;
        var threshold = GamigotchiStats.STAGE_THRESHOLDS_SEC[stage];
        var progress = elapsedVal.toFloat() / threshold.toFloat();
        return (progress > 1.0) ? 1.0 : progress;
    }

    // 사망 확인 화면에서 사용자가 SELECT를 눌렀을 때 새 알로 리셋
    function reviveFromDeath() as Void {
        _resetCharacter();
        WatchUi.requestUpdate();
    }

    hidden function _resetCharacter() as Void {
        Storage.setValue("tokens", 30); // ⚠️ TEST ONLY (2026-07-15): 실기기 테스트용, 릴리즈 전 0으로 원복 필수
        Storage.setValue("growthStage", 0);
        Storage.setValue("healthStatus", 0);
        Storage.setValue("hunger", GamigotchiStats.GAUGE_MAX);
        Storage.setValue("happiness", GamigotchiStats.GAUGE_MAX);
        Storage.setValue("poopCount", 0);
        Storage.setValue("poopAccumSeconds", 0);
        Storage.setValue("healthyElapsedSeconds", 0);
        Storage.setValue("lastTickTime", Time.now().value());
        Storage.setValue("hungerNotified", false);
        Storage.setValue("pendingEvolution", false);
    }
}

function getApp() as GamigotchiApp {
    return Application.getApp() as GamigotchiApp;
}
