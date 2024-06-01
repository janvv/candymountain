import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
var waiting = "";
var watchDog = false;
class sugarView extends WatchUi.SimpleDataField {

    // Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();
        //SimpleDataField.backgroundColor
        label = "candymountain";
    }

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        watchDog = !watchDog;

        // See Activity.Info in the documentation for available information.
        var string = "???";

        var now = Time.now().value();
        if ((glucoseTimestamp == null) || ((now - glucoseTimestamp) > 10*60)) {
            waiting = waiting + ".";
            if (waiting.length() > 3) {
                waiting = "";
            }
            string = waiting;
        } 
        //glucose data available
        else { 
            var trendArrow = "?";
            if (glucoseTrend != null) {
                if (glucoseTrend > 3) {
                    trendArrow = "\u219F";
                } else if (glucoseTrend > 2) {
                    trendArrow = "\u2191"; 
                } else if (glucoseTrend > 1) {
                    trendArrow = "\u2197"; 
                } else if (glucoseTrend >= -1) {
                    trendArrow = "\u2192"; 
                } else if (glucoseTrend < -1){
                    trendArrow = "\u2198"; 
                } else if (glucoseTrend < -2) {
                    trendArrow = "\u2193"; 
                } else {
                    trendArrow = "\u21A1"; 
                }
            }
            string = glucoseValue.format("%.0f");
        }
        return string;
    }

}