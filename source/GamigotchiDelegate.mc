import Toybox.Lang;
import Toybox.WatchUi;

class GamigotchiDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("Feed", null, :feed, {}));
        WatchUi.pushView(menu, new GamigotchiMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onMenu() as Boolean {
        return onSelect();
    }
}

class GamigotchiMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :feed) {
            getApp().feed();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
