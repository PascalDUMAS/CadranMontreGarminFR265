// Fichier : forunner265_01App.mc

using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Lang as Lang; 
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg;

class forunner265_01App extends App.AppBase {
    var tideDisplayString as Lang.String = "Chargement..."; 
    var dateDisplayString as Lang.String = "";

    function initialize() {
        AppBase.initialize();
    }

    function formatCurrentDate() as Void {
        var now = Time.now();
        var info = Greg.info(now, Time.FORMAT_LONG);
        var dayOfWeekString = "";
        switch (info.day_of_week) {
            case "Sun":  dayOfWeekString = "Dim"; break;
            case "Mon":  dayOfWeekString = "Lun"; break;
            case "Tue":  dayOfWeekString = "Mar"; break;
            case "wed":  dayOfWeekString = "Mer"; break;
            case "Thu":  dayOfWeekString = "Jeu"; break;
            case "Fri":  dayOfWeekString = "Ven"; break;
            case "Sat":  dayOfWeekString = "Sam"; break;
        }

        var monthString = info.month;
        
        dateDisplayString = Lang.format("$1$ $2$ $3$", [
            dayOfWeekString, 
            info.day, 
            monthString
        ]);
    }
    
    function getDateData() as Lang.String {
        return dateDisplayString;
    }

    function getTideInfo() as Void {
        System.println("DEBUG:  getTideInfo()  appelée....");

        var apiKey = "VOTRE_CLÉ_SHOM_PERSONNELLE"; 
        var portId = "110";
        var dateNow = Time.Gregorian.info(Time.now(), Toybox.Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$-$2$-$3$", [dateNow.year, dateNow.month.format("%02d"), dateNow.day.format("%02d")]);

        var url = Lang.format("https://data.shom.fr/api/marvea/maree?apikey=$1$&id=$2$&date=$3$&format=json", 
            [apiKey, portId, dateString]
        );
        
        var options = {
            :method => Comm.HTTP_REQUEST_METHOD_GET,
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        
        Comm.makeWebRequest(url, null, options, method(:onReceiveTideInfo));
    }

    function onReceiveTideInfo(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String) as Void {
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            if (data.hasKey("previsions")) {
                var previsions = data["previsions"] as Lang.Array;
                var nowMoment = Time.now();
                var dateInfo = Time.Gregorian.info(nowMoment, Time.FORMAT_MEDIUM);
                
                for (var i = 0; i < previsions.size(); i++) {
                    var prevision = previsions[i];
                    var type = prevision["type"] as Lang.String;
                    var time = prevision["heure"] as Lang.String;
                    
                    var tideMoment = Time.Gregorian.moment({
                        :year => dateInfo.year,
                        :month => dateInfo.month,
                        :day => dateInfo.day,
                        :hour => time.substring(0, 2).toNumber(),
                        :minute => time.substring(3, 5).toNumber()
                    });
                    if (tideMoment.greaterThan(Time.now())) {
                        var typeString = (type.equals("PM")) ? "Pleine Mer" : "Basse Mer";
                        tideDisplayString = Lang.format("$1$ à $2$", [typeString, time]);
                        break;
                    }
                }
            } else {
                tideDisplayString = "Erreur format SHOM";
            }
        } else {
            tideDisplayString = "Erreur API: " + responseCode;
        }
        
        Ui.requestUpdate(); 
    }
    
    function getTideData() as Lang.String {
        return tideDisplayString;
    }

    function getInitialView() {
        System.println("DEBUG: getInitialView appelée. Création de la vue...");
        return [ new MonCadranDeMontreView() ];
    }
}