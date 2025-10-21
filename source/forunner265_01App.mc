// Fichier : source/forunner265_01App.mc

using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Lang as Lang; 
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg; // ajout date mois jour

class forunner265_01App extends App.AppBase {
    // ✅ Ajout de la variable de membre pour stocker l'info à afficher
    var tideDisplayString as Lang.String = "Chargement..."; 
    var dateDisplayString as Lang.String = "";
    function initialize() {
        AppBase.initialize();
    }
    function formatCurrentDate() as Void {
        var now = Time.now();
        var info = Greg.info(now, Time.FORMAT_LONG); // FORMAT_LONG donne toutes les informations nécessaires
        //Sys.println("DEBUG info: "+info.day_of_week+" "+info.month+" "+info.day+" Greg.DAY_SUNDAY "+Greg.DAY_SUNDAY);
        // 1. Déterminer le jour de la semaine (Ex: "Dim")
        // Les jours de la semaine (Day of Week) sont des entiers (1=Dimanche, 7=Samedi)
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

        // 2. Déterminer le mois (Ex: "Octobre")
        // Les mois (Month) sont aussi des entiers (1=Janvier, 12=Décembre)
        var monthString = info.month;
        
        //Sys.println("DEBUG: "+dayOfWeekString+"_"+monthString+"_"+info.day);
        // 3. Mettre tout ensemble (Ex: "Lun 28 Octobre")
        dateDisplayString = Lang.format("$1$ $2$ $3$", [
            dayOfWeekString, 
            info.day, 
            monthString
        ]);
    }
    
    // ✅ Fonction pour donner la date à la vue
    function getDateData() as Lang.String {
        return dateDisplayString;
    }
// Fonction pour récupérer les marées
    function getTideInfo() as Void {
        System.println("DEBUG:  getTideInfo()  appelée....");

        // ⚠️ REMPLACER PAR VOTRE VRAIE CLÉ ET IDENTIFIANT SHOM ⚠️
        var apiKey = "VOTRE_CLÉ_SHOM_PERSONNELLE"; 
        var portId = "110"; // Identifiant commun pour Ploumanac'h/Perros-Guirec
        
        // Date du jour au format ISO (YYYY-MM-DD)

        var dateNow = Time.Gregorian.info(Time.now(), Toybox.Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$-$2$-$3$", [dateNow.year, dateNow.month.format("%02d"), dateNow.day.format("%02d")]);

        var url = Lang.format("https://data.shom.fr/api/marvea/maree?apikey=$1$&id=$2$&date=$3$&format=json", 
            [apiKey, portId, dateString]
        );
        
        var options = {
            :method => Comm.HTTP_REQUEST_METHOD_GET,
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        
        // Envoyer la requête
        Comm.makeWebRequest(url, null, options, method(:onReceiveTideInfo));
    }

    // Callback après réception de la réponse
    function onReceiveTideInfo(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String) as Void {
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            
            // Analyse des données JSON du SHOM (Structure hypothétique)
            if (data.hasKey("previsions")) {
                var previsions = data["previsions"] as Lang.Array;
                var nowMoment = Time.now(); // Moment actuel pour la comparaison
                var dateInfo = Time.Gregorian.info(nowMoment, Time.FORMAT_MEDIUM);
                
                // Chercher la prochaine marée (PM = Pleine Mer, BM = Basse Mer)
                for (var i = 0; i < previsions.size(); i++) {
                    var prevision = previsions[i];
                    var type = prevision["type"] as Lang.String;
                    var time = prevision["heure"] as Lang.String; // Ex: "14:30"
                    var height = prevision["hauteur"] as Lang.String; // Ex: "5.2"
                    
                    // On cherche la prochaine marée qui n'est pas passée
                    //var tideTime = Sys.Gregorian.buildFromFormat(dateString + " " + time, "yyyy-MM-dd HH:mm");
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
                        break; // On a trouvé la prochaine
                    }
                }
            } else {
                tideDisplayString = "Erreur format SHOM";
            }
            
        } else {
            // Le code 403 (Interdit) est fréquent sans bonne clé d'API
            tideDisplayString = "Erreur API: " + responseCode;
        }
        
        // Demande de rafraîchissement de la vue
        Ui.requestUpdate(); 
    }
    
    // Fonction pour fournir les données à la vue
    function getTideData() as Lang.String {
        return tideDisplayString;
    }
    // ✅ CORRECTION DÉFINITIVE APPLIQUÉE ICI : 
    // Suppression de l'annotation de type de retour complète ('as Array<?>') 
    // pour satisfaire l'override strict de AppBase.
    function getInitialView() {
        
        // Nous retournons simplement le tableau avec un casting minimal si nécessaire.
        // L'absence de la signature de type de retour résout l'erreur d'override.
        System.println("DEBUG: getInitialView appelée. Création de la vue...");
        return [ new MonCadranDeMontreView() ];
    }
}