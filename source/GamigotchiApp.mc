import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GamigotchiApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new GamigotchiView(), new GamigotchiDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
    }
}

function getApp() as GamigotchiApp {
    return Application.getApp() as GamigotchiApp;
}
