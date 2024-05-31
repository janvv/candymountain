using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.System;
using Toybox.Time;

var phoneMethod;
var glucoseValue;
var glucoseTrend;
var glucoseDatetime;

class sugarApp extends Application.AppBase {

    function initialize() {
        Application.AppBase.initialize();
        glucoseValue = -1;
        glucoseTrend = -1;
        glucoseDatetime = -1;
        
        phoneMethod = method(:onPhone);
        if(Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(phoneMethod);
        } else {
            var hasDirectMessagingSupport = false;
        }
    }

    function onPhone(msg) {
        System.println("Received phone message");
        var now = Time.now().value();
        System.println("Received phone message: "+ msg.data.toString() +" at: "+ now);
        
        //parse data
        if (msg.data instanceof Toybox.Lang.Dictionary) {
            System.println("Received a dictionary: Parsing ...");
            glucoseValue = msg.data.get("glucose");
            glucoseTrend = msg.data.get("trend");
            glucoseDatetime = msg.data.get("datetime");
        } else {
            System.println("Received something else: Stop.");
        }
        System.println("Parsed glucose:" + glucoseValue + ", trend: " + glucoseTrend + ", datetime: " + glucoseDatetime);
        System.println("Age : "+ (now - glucoseDatetime));
        WatchUi.requestUpdate();
    }
    // onStart() is called on application start up
    function onStart(state) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() {
        return [ new sugarView() ];
    }

}

function getApp() as sugarApp {
    return Application.getApp() as sugarApp;
}