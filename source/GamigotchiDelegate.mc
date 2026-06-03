import Toybox.Lang;
import Toybox.WatchUi;

class GamigotchiDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        return true;
    }
}
