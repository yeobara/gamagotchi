import Toybox.Lang;
import Toybox.WatchUi;

class GamigotchiDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        if (getApp().getHealthStatus() == 2) {
            getApp().reviveFromDeath();
            return true;
        }
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("Feed", null, :feed, {}));
        menu.addItem(new WatchUi.MenuItem("Play", null, :play, {}));
        menu.addItem(new WatchUi.MenuItem("Clean", null, :clean, {}));
        menu.addItem(new WatchUi.MenuItem("Medicine", null, :medicine, {}));
        WatchUi.pushView(menu, new GamigotchiMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onMenu() as Boolean {
        return onSelect();
    }

    // 왼쪽 상단(LIGHT)은 백라이트용으로 시스템이 예약해 앱까지 이벤트가 전달되지 않음
    // (시뮬레이터에서 확인됨) → 대신 Up 버튼(왼쪽 중단)에 배치.
    // Up이 onNextPage/onPreviousPage 중 어디로 오는지 기기마다 다를 수 있어 둘 다 처리
    function onNextPage() as Boolean {
        _openStatusView();
        return true;
    }

    function onPreviousPage() as Boolean {
        _openStatusView();
        return true;
    }

    private function _openStatusView() as Void {
        WatchUi.pushView(new GamigotchiStatusView(), new GamigotchiStatusDelegate(), WatchUi.SLIDE_UP);
    }
}

class GamigotchiMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :feed) {
            getApp().feed();
        } else if (id == :play) {
            getApp().play();
        } else if (id == :clean) {
            getApp().clean();
        } else if (id == :medicine) {
            getApp().giveMedicine();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
