import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class GamigotchiApp extends Application.AppBase {

    private var _transientMessage as String = "";
    private var _transientMessageUntil as Number = 0;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        if (Storage.getValue("initialized") == null) {
            Storage.setValue("tokens", 0);
            Storage.setValue("lastFedTime", Time.now().value());
            Storage.setValue("growthStage", 0);
            Storage.setValue("qualifyingRunCount", 0);
            Storage.setValue("healthStatus", 0);
            Storage.setValue("initialized", true);
            // onStart() 시점엔 아직 화면이 만들어지기 전이라 WatchUi.requestUpdate()를
            // 호출하면 안 됨(크래시) → requestUpdate 없이 상태만 세팅, 첫 onUpdate()가
            // 알아서 그려줌
            _transientMessage = "take care of your egg!";
            _transientMessageUntil = Time.now().value() + 5;
        }
        _checkHealth();
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

        var newCount = d.get("qualifyingRunCount");
        if (newCount instanceof Number) {
            Storage.setValue("qualifyingRunCount", newCount);
            _updateGrowth();
        }

        WatchUi.requestUpdate();
    }

    // 사망 확인 화면에서 사용자가 SELECT를 눌렀을 때 새 알로 리셋
    function reviveFromDeath() as Void {
        _resetCharacter();
        WatchUi.requestUpdate();
    }

    function feed() as Void {
        var t = Storage.getValue("tokens");
        var tokens = (t instanceof Number) ? t : 0;
        if (tokens < 1) {
            _setTransientMessage("no tokens...");
            return;
        }
        Storage.setValue("tokens", tokens - 1);
        Storage.setValue("lastFedTime", Time.now().value());
        Storage.setValue("healthStatus", 0);
        _setTransientMessage("yum yum!");
    }

    // 밥주기 결과 등 잠깐 보여줄 말풍선 메시지 (3초 후 자동으로 사라짐)
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

    function getLastFedTime() as Number {
        var t = Storage.getValue("lastFedTime");
        return (t instanceof Number) ? t : Time.now().value();
    }

    function getQualifyingRunCount() as Number {
        var c = Storage.getValue("qualifyingRunCount");
        return (c instanceof Number) ? c : 0;
    }

    hidden function _checkHealth() as Void {
        // 이미 사망 확인 화면 대기 중이면 사용자가 리셋할 때까지 상태 유지
        if (getHealthStatus() == 2) { return; }

        var lastFed = Storage.getValue("lastFedTime");
        if (!(lastFed instanceof Number)) { return; }
        var elapsed = Time.now().value() - lastFed;
        if (elapsed >= 72 * 3600) {
            Storage.setValue("healthStatus", 2);
        } else if (elapsed >= 48 * 3600) {
            Storage.setValue("healthStatus", 1);
        } else {
            Storage.setValue("healthStatus", 0);
        }
    }

    hidden function _resetCharacter() as Void {
        Storage.setValue("tokens", 0);
        Storage.setValue("lastFedTime", Time.now().value());
        Storage.setValue("growthStage", 0);
        Storage.setValue("qualifyingRunCount", 0);
        Storage.setValue("healthStatus", 0);
    }

    hidden function _updateGrowth() as Void {
        var c = Storage.getValue("qualifyingRunCount");
        var count = (c instanceof Number) ? c : 0;
        var stage = (count >= 13) ? 2 : ((count >= 3) ? 1 : 0);
        Storage.setValue("growthStage", stage);
    }
}

function getApp() as GamigotchiApp {
    return Application.getApp() as GamigotchiApp;
}
