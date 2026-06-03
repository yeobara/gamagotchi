import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// Activity.SPORT_RUNNING = 1
(:background)
class GamigotchiBackground extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onActivityCompleted(activity) as Void {
        if (activity == null) {
            Background.exit(null);
            return;
        }

        if (!(activity instanceof Dictionary)) { Background.exit(null); return; }
        var sport = (activity as Dictionary).get(:sport);
        if (!(sport instanceof Number) || sport != 1) {
            Background.exit(null);
            return;
        }

        var tokensEarned = 5;

        var stored = Storage.getValue("qualifyingRunCount");
        var count = (stored instanceof Number) ? stored : 0;
        count = count + 1;

        Background.exit({
            "tokens" => tokensEarned,
            "qualifyingRunCount" => count
        });
    }
}
