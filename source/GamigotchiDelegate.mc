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
    // (시뮬레이터에서 확인됨) → 대신 Up/Down 버튼에 배치.
    // fr255에서 Up/Down 물리 버튼은 onKey()가 아니라 onPreviousPage()/onNextPage()로
    // 들어옴(제스처 처리가 onKey보다 우선) → Up=onPreviousPage, Down=onNextPage로 배정.
    // (⚠️ TEST ONLY 2026-07-17: Down=디버그 로그 화면, 확인 후 제거)
    function onPreviousPage() as Boolean {
        _openStatusView();
        return true;
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new GamigotchiDebugLogView(), new GamigotchiDebugLogDelegate(), WatchUi.SLIDE_UP);
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
