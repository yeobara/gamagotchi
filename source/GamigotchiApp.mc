import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class GamigotchiApp extends Application.AppBase {

    const FEED_COST = 1;
    const FEED_AMOUNT = 40.0;
    const PLAY_COST = 1;
    const PLAY_AMOUNT = 40.0;
    const MEDICINE_COST = 3;

    private var _transientMessage as String = "";
    private var _transientMessageUntil as Number = 0;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        if (Storage.getValue("initialized") == null) {
            _resetCharacter();
            Storage.setValue("initialized", true);
            // onStart() 시점엔 아직 화면이 만들어지기 전이라 WatchUi.requestUpdate()를
            // 호출하면 안 됨(크래시) → requestUpdate 없이 상태만 세팅, 첫 onUpdate()가
            // 알아서 그려줌
            _transientMessage = "take care of your egg!";
            _transientMessageUntil = Time.now().value() + 5;
        }
        GamigotchiStats.tick(); // 앱이 닫혀있던 동안 밀린 게이지 감소분 반영
        Background.registerForActivityCompletedEvent();

        // 30초 후 temporal event (테스트용 - 실제는 5분 간격으로 변경)
        try {
            var testTime = Time.now().add(new Time.Duration(30));
            Background.registerForTemporalEvent(testTime);
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
        if (earned instanceof Number) {
            var cur = Storage.getValue("tokens");
            var curVal = (cur instanceof Number) ? cur : 0;
            Storage.setValue("tokens", curVal + earned);
        }

        WatchUi.requestUpdate();
    }

    function feed() as Void {
        var tokens = getTokens();
        if (tokens < FEED_COST) {
            _setTransientMessage("no tokens...");
            return;
        }
        Storage.setValue("tokens", tokens - FEED_COST);
        GamigotchiStats.addGauge("hunger", FEED_AMOUNT);
        _setTransientMessage("yum yum!");
    }

    function play() as Void {
        var tokens = getTokens();
        if (tokens < PLAY_COST) {
            _setTransientMessage("no tokens...");
            return;
        }
        Storage.setValue("tokens", tokens - PLAY_COST);
        GamigotchiStats.addGauge("happiness", PLAY_AMOUNT);
        _setTransientMessage("wheee!");
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

    // 액션 결과 등 잠깐 보여줄 말풍선 메시지 (5초 후 자동으로 사라짐)
    private function _setTransientMessage(msg as String) as Void {
        _transientMessage = msg;
        _transientMessageUntil = Time.now().value() + 5;
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
        Storage.setValue("tokens", 0);
        Storage.setValue("growthStage", 0);
        Storage.setValue("healthStatus", 0);
        Storage.setValue("hunger", GamigotchiStats.GAUGE_MAX);
        Storage.setValue("happiness", GamigotchiStats.GAUGE_MAX);
        Storage.setValue("poopCount", 0);
        Storage.setValue("poopAccumSeconds", 0);
        Storage.setValue("healthyElapsedSeconds", 0);
        Storage.setValue("lastTickTime", Time.now().value());
        Storage.setValue("hungerNotified", false);
    }
}

function getApp() as GamigotchiApp {
    return Application.getApp() as GamigotchiApp;
}
