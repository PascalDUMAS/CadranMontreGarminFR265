// Fichier : source/MonCadranDeMontreView.mc
// test0203r
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Position as Position; // ajout pour l'altitude et le couche du soleil
using Toybox.ActivityMonitor as AM; // ajout des pas
using Toybox.Activity as Activity; 
using Toybox.Time.Gregorian ;
using Toybox.Time;
using Toybox.Weather as Weather; // couche de soleil 
using Toybox.SensorHistory as SensorHistory; //ajout de la frequence cardiaque
//using Toybox.WatchUi.FontResource; // pour la font a utiliser


// La classe qui dessine le cadran de montre
class MonCadranDeMontreView extends Ui.WatchFace {

    var timeFont = null;
    private var heartIcon as Ui.BitmapResource or Null; 
    private var batteryIcon as Ui.BitmapResource or Null; 
    private var altitudeIcon as Ui.BitmapResource or Null; 
    private var temperatureIcon as Ui.BitmapResource or Null; 
    private var background as Ui.BitmapResource or Null;
    private var soleilIcon as Ui.BitmapResource or Null;
    private var lastClockTime = Sys.getClockTime();
    private var lastSync ;
    private var lastOptionCoucherSoleil  = {
            :year   => 0,
            :month  => 0,
            :day    => 0,
            :hour   => 0 , 
            :minute => 0
        };
   
    private var dateLabel as Ui.Text or Null; // Déclaration
    private var Orange_color ;
    private var Green_color;
    private var Blue_color;
    private var lightgray_color;
    private var backupBuffer = null; // Pour stocker la zone sauvegardée
    private var backupBufferX;
    private var backupBufferY;
    private var backupBufferDimX;
    private var backupBufferDimY;

    private var temperatures = [];
    private var precipitation = [];
    
    // ✅ CORRECTION APPLIQUÉE ICI : 
    // Initialisation de la classe enfant et appel de la méthode du parent.
    function initialize() {
        // Appelle la méthode d'initialisation de la classe WatchFace
        Ui.WatchFace.initialize(); 
        Green_color = Gfx.createColor(255,160,209,177);
        Orange_color = Gfx.createColor(255,247,168,19);
        Blue_color = Gfx.createColor(255,96,164,226);
        lightgray_color = Gfx.createColor(255,129,133,135);

        timeFont = Ui.loadResource(Rez.Fonts.BebasNeueRegular) ;
        
        background = Ui.loadResource(Rez.Drawables.Background);
        heartIcon = Ui.loadResource(Rez.Drawables.HeartIcon);
        batteryIcon = Ui.loadResource(Rez.Drawables.BatteryIcon);
        altitudeIcon = Ui.loadResource(Rez.Drawables.AltitudeIcon);
        temperatureIcon = Ui.loadResource(Rez.Drawables.TemperatureIcon);
        soleilIcon = Ui.loadResource(Rez.Drawables.SoleilIcon);

        // Ou, de manière plus générique, vous pouvez utiliser :
        // Super.initialize(); 
    }

    //! Charger vos ressources ici
    function onLayout(dc as Gfx.Dc) as Void {
        //System.println("DEBUG: onLayout appelée.");
        // Charge la ressource en utilisant l'ID défini dans le XML (Rez.Fonts.ID_DE_VOTRE_POLICE)
  
        var timefontHeight = Gfx.getFontHeight(timeFont);


        //Sys.println("timeFont: timefontHeight:"+timefontHeight);
        //timeFont = Gfx.FONT_LARGE;
        // ✅ Initialisation du champ de texte pour la date
        dateLabel = new Ui.Text({
            :locX => Ui.LAYOUT_HALIGN_CENTER, // Centré horizontalement
            :locY => (dc.getHeight() / 2) + 40, // Placez-le sous l'heure, par exemple
            :justification => Gfx.TEXT_JUSTIFY_CENTER,
            :font => Gfx.FONT_XTINY, // Une petite police est souvent suffisante
            :color => Gfx.COLOR_WHITE
        });
        
        
    }
    

    
    function drawTemperatureGraph2(dc as Gfx.Dc, temps,precipitations,posX,posY ) as Void {
        var fonctioName="drawTemperatureGraph2(dc as Gfx.Dc, temps,precipitations,posX,posY ) ";
        var width = dc.getWidth();
        var height = dc.getHeight();
        Sys.println("DEBUG::"+fonctioName+" \ntemps:"+temps+" \nprecipitations:"+precipitations);
        // Définir la zone où le graphique sera dessiné (Ex: bas de l'écran)
        var graphHeight = height / 3; // Graphique de 1/3e de la hauteur de l'écran
        var graphYStart = height - graphHeight - 65; // Commencer juste au-dessus du "GARMIN"
        var graphXStart = width/6; 
        var graphXEnd = width - width/6;
        var graphWidth = graphXEnd - graphXStart;
       // Sys.println("DEBUG: "+width+"x"+height+" "+graphXStart+","+graphYStart+" "+graphWidth+"-"+graphHeight);
        //dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);// couleur rectangle
        //dc.drawRectangle(graphXStart, graphYStart, graphWidth, graphHeight);
        if (temps == null || temps.size() == 0) {
            return;
        }
        
        // 1. Déterminer les valeurs Min/Max pour l'échelle Y (Température)
        var minTemp = temps[0];
        var maxTemp = temps[0];
        for (var i = 1; i < temps.size(); i++) {
            if (temps[i] < minTemp) { minTemp = temps[i]; }
            if (temps[i] > maxTemp) { maxTemp = temps[i]; }
        }
        
        // NOUVEAU: Déterminer l'échelle pour la précipitation (échelle de 0 à 10 mm/hr)
        var maxPrecip = 0.0;
        if (precipitations != null) {
            for (var i = 0; i < precipitations.size(); i++) {
                if (precipitations[i] != null && precipitations[i] > maxPrecip) { maxPrecip = precipitations[i]; }
            }
        }
        var precipRange = 10.0; // Échelle fixe: 0 à 10 mm/hr pour la normalisation
        if (maxPrecip > 10.0) {
            precipRange = maxPrecip * 1.1; // Échelle dynamique si le max est très haut
        }
        var minPrecip = 0.0; // Toujours 0 pour la précipitation

        // Ajouter une marge pour que la courbe ne touche pas les bords (TEMPÉRATURE)
        minTemp -= 2;
        maxTemp += 2;
        var tempRange = maxTemp - minTemp;
        if (tempRange == 0) { tempRange = 1; }
        
        // 2. Dessiner les courbes
        var prevX = -1;
        var prevYTemp = -1; 
        var prevYPrecip = -1; // AJOUTÉ
        
        for (var i = 0; i < temps.size(); i++) {
            // Utiliser 1.0 pour forcer la division flottante
            var currentX = graphXStart + (i * graphWidth) / (temps.size() - 1.0); 
            
            // Calculer la position Y pour la TEMPÉRATURE
            var tempNormalized = (temps[i] - minTemp) / tempRange;
            var currentYTemp = graphYStart + graphHeight - (tempNormalized * graphHeight);
            
            // NOUVEAU : Calculer la position Y pour la PRÉCIPITATION
            var currentYPrecip = -1;
            if (precipitations != null && precipitations.size() > i && precipitations[i] != null) {
                var precipNormalized = (precipitations[i] - minPrecip) / precipRange;
                currentYPrecip = graphYStart + graphHeight - (precipNormalized * graphHeight);
            }

            if (prevX != -1) {
                // Dessiner la ligne de TEMPÉRATURE (Vert)
                dc.setColor(Green_color, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(prevX.toNumber(), prevYTemp.toNumber(), currentX.toNumber(), currentYTemp.toNumber());
                
                // Dessiner la ligne de PRÉCIPITATION (Bleu Foncé)
                if (prevYPrecip != -1 && currentYPrecip != -1) {
                    dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
                    dc.drawLine(prevX.toNumber(), prevYPrecip.toNumber(), currentX.toNumber(), currentYPrecip.toNumber());
                }
            }
            
            // Dessiner les points (Température)
            dc.setColor(Green_color, Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(currentX, currentYTemp, 2);
            
            // Dessiner les points (Précipitation)
            if (currentYPrecip != -1) {
                dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(currentX, currentYPrecip, 2);
            }

            // Dessiner les lignes verticales
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(currentX, graphYStart, currentX, graphYStart + graphHeight);
            
            // Mise à jour des variables précédentes
            prevX = currentX;
            prevYTemp = currentYTemp;
            prevYPrecip = currentYPrecip; 
        }

        // 3. Dessiner les étiquettes Min/Max de Température (côté gauche)
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        var maxTempFormat = Lang.format("$1$", [maxTemp.format("%d")]);
        var minTempFormat = Lang.format("$1$", [minTemp.format("%d")]);
        
        // Étiquette Min Temp (en bas à gauche)
        dc.drawText(
            graphXStart - 5,
            graphYStart + graphHeight - Gfx.getFontHeight(Gfx.FONT_XTINY),
            Gfx.FONT_XTINY,
            minTempFormat,
            Gfx.TEXT_JUSTIFY_RIGHT
        );
        // Étiquette Max Temp (en haut à gauche)
        dc.drawText(
            graphXStart - 5,
            graphYStart - 10,
            Gfx.FONT_XTINY,
            maxTempFormat,
            Gfx.TEXT_JUSTIFY_RIGHT
        );

        // NOUVEAU : Étiquette Max Précipitation (côté droit)
        dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
        var maxPrecipFormat = Lang.format("$1$", [precipRange.format("%d")]);
        var minPrecipFormat = "0";
        
        dc.drawText(
            graphXEnd + 5, // Côté droit
            graphYStart - 10,
            Gfx.FONT_XTINY,
            maxPrecipFormat ,
            Gfx.TEXT_JUSTIFY_LEFT
        );
        
         dc.drawText(
            graphXEnd + 5, // Côté droit
            graphYStart + graphHeight,
            Gfx.FONT_XTINY,
            minPrecipFormat ,
            Gfx.TEXT_JUSTIFY_LEFT
        );
        // Étiquette Heure Actuelle
        //ici
        Sys.println("DEBUG::"+fonctioName+"Dessin heure lastSync");
        dc.setColor(lightgray_color, Gfx.COLOR_TRANSPARENT);
        var lastClockTimeX = graphXStart + graphWidth / 2;
        var lastClockTimeY = (graphYStart + graphHeight / 2) + 40;
        var lastClockTimeXString = Lang.format("$1$:$2$", [lastSync.hour.format("%02d"), lastSync.min.format("%02d")]);
        
        //var lastClockTimeXString = Lang.format("$1$:$2$ $3$/$4$/$5$", [lastSync.hour.format("%02d"),lastSync.min.format("%02d"),lastSync.day.format("%02d"),lastSync.month.format("%02d"),lastSync.year.format("%02d")]);
        
        dc.drawText(
            lastClockTimeX,
            lastClockTimeY,
            Gfx.FONT_XTINY,
            lastClockTimeXString,
            Gfx.TEXT_JUSTIFY_CENTER
        );
    }
    function showTemperature(dc as Gfx.Dc, posX, posY) as Void{
        var textFunction = "function showTemperature(dc as Gfx.Dc, posY:"+posX+", posY:"+posY+")";
        // --- 🌡️ AFFICHAGE TEMPÉRATURE ------------------------------------------

        var tempString = "--°C"; // Valeur par défaut
        var tempFont = Gfx.FONT_XTINY;
        
        // 1. Récupérer les données de température via l'historique du capteur
        var tempIterator = SensorHistory.getTemperatureHistory({});
        
        if (tempIterator != null) {
            // Récupérer l'élément le plus récent (le "sample")
            var tempSample = tempIterator.next();
            
            if (tempSample != null && tempSample.data != null) {
                // La valeur est déjà en degrés Celsius (Float)
                var tempC = tempSample.data; 
                
                // 2. Formater et afficher en Celsius (°C)
                // On ignore Sys.getDeviceSettings().temperatureUnits pour forcer le Celsius.
                tempString = Lang.format("$1$°C", [tempC.format("%02d")]); 
            }
        }

       
        // var tempXPos =  dc.getTextWidthInPixels(tempString, tempFont);; // Utilise la même colonne que l'Altitude/FC
        //var tempXPos = dateXpos - dc.getTextWidthInPixels(tempString, tempFont)- 115;
        var tempXPos = posX + dc.getTextWidthInPixels(tempString, tempFont)- 115;
        var tempYPos = posY ; // Sous l'Altitude
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        //Sys.println("DEBUG: "+tempXPos+" "+tempYPos+" "+tempFont+" "+tempString);
        dc.drawText(
            tempXPos,
            tempYPos,
            tempFont,
            tempString,
            Gfx.TEXT_JUSTIFY_CENTER|Gfx.TEXT_JUSTIFY_RIGHT
        );
        
        if (temperatureIcon != null) {
            //var iconWidth = heartIcon.getWidth();
            var tempIconHeight = temperatureIcon.getHeight();
            var tempIconWidth = temperatureIcon.getWidth();
            // Calculer où dessiner l'icône pour qu'elle soit à GAUCHE du texte "XX bpm" :
            // 1. Mesurer la largeur du texte "XX bpm" (à centrer)
            var tempTextWidth = dc.getTextWidthInPixels(tempString, tempFont);
            
            // 2. Déterminer le point de départ X de l'icône
            // (Centre de l'écran) - (Moitié de la largeur du texte) - (Largeur de l'icône) - (Petite marge)
        
            var tempIconXPos = tempXPos - tempIconWidth/2;
            
            // 3. Déterminer le point Y (centré sur la ligne de texte "XX bpm")
            var tempIconYPos = tempYPos - (Gfx.getFontHeight(tempFont))+5;
            
            dc.drawBitmap(tempIconXPos, tempIconYPos, temperatureIcon);
        }  

    }//showTemperature
    function showCoucheSoleil (dc as Gfx.Dc, posX, posY) as Void{
        var textFunction ="showCoucheSoleil (dc as Gfx.Dc, "+posX+", "+posY+") as Void{";
        var positionSoleil = Position.getInfo(); 
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        
        var optionCoucherSoleil = {
            :year   => today.year,
            :month  => today.month,
            :day    => today.day,
            :hour   => today.hour , 
            :minute => today.min 
        };
        //Sys.println(textFunction);
        //Sys.println("DEBUG: "+optionCoucherSoleil[:hour] +" " +lastOptionCoucherSoleil[:hour]);
        //if (optionCoucherSoleil[:hour]!= lastOptionCoucherSoleil[:hour]){
            //Sys.println("DEBUG on passe dansle If pour affichier leheure de coucher de soleil ");
            lastOptionCoucherSoleil = optionCoucherSoleil;
            var todayMoment = Gregorian.moment(optionCoucherSoleil);
            var HeureCoucheSoleil = Weather.getSunset(positionSoleil.position,todayMoment);

            //Sys.println("DEBUG: HeureCoucheSoleil:"+HeureCoucheSoleil+"positionSoleil.position:"+positionSoleil.position+" todayMoment:"+todayMoment);
            //getSunrise(location as Position.Location, date as Time.Moment) as Time.Moment or Null
            //Get sunrise time for the provided location and date.
              
            // 2. Formatage de l'heure si un moment est trouvé
            var timeInfoCoucheSoleil ;
            if (HeureCoucheSoleil != null) {
                timeInfoCoucheSoleil = Gregorian.info(
                    HeureCoucheSoleil, 
                    Time.FORMAT_MEDIUM 
                );
                var coucherSoleilString = Lang.format(
                    "$1$:$2$",[timeInfoCoucheSoleil.hour.format("%02d"), 
                        timeInfoCoucheSoleil.min.format("%02d")]
                );
                var soleilFont = Gfx.FONT_XTINY;
                var soleilXpos = posX;
                var soleilYpos = posY;
                //Sys.println("DEBUG: coucherSoleil:"+coucherSoleilString);
                dc.setColor(Gfx.COLOR_BLUE,Gfx.COLOR_TRANSPARENT);
                dc.setColor(Green_color, Gfx.COLOR_TRANSPARENT); // Texte gris clair pour les pas

                dc.drawText(
                    soleilXpos,
                    soleilYpos,
                    soleilFont,
                    coucherSoleilString,
                    Gfx.TEXT_JUSTIFY_LEFT
                );
                if (soleilIcon != null) {
                    //var iconWidth = heartIcon.getWidth();
                    var soleilIconHeight = soleilIcon.getHeight();
                    var soleilIconWidth = soleilIcon.getWidth();
                    // Calculer où dessiner l'icône pour qu'elle soit à GAUCHE du texte "XX bpm" :
                    // 1. Mesurer la largeur du texte "XX bpm" (à centrer)
                    var soleilTextWidth = dc.getTextWidthInPixels(coucherSoleilString, soleilFont);
                    
                    // 2. Déterminer le point de départ X de l'icône
                    // (Centre de l'écran) - (Moitié de la largeur du texte) - (Largeur de l'icône) - (Petite marge)
                
                    var soleilIconXPos = soleilXpos + soleilIconWidth/2 -15;
                    
                    // 3. Déterminer le point Y (centré sur la ligne de texte "XX bpm")
                    var soleilIconYPos = soleilYpos - (Gfx.getFontHeight(Gfx.FONT_XTINY))+5;
                    
                    dc.drawBitmap(soleilIconXPos, soleilIconYPos, soleilIcon);
                }   
        

            }
        //}  
    } // fin --- ☀️ COUCHER DU SOLEIL (Méthode Météo GARANTIE) ---   
    function showPas(dc, posX,posY)as Void{
        //var textFunction ="DEBUG: showPas(dc, "+posX+","+posY+")";
        // --- 👣 AFFICHAGE DES PAS  ------------------------------------------
        // 1. Définir le FOND en NOIR et le premier plan en BLANC pour le CLEAR

        // 1. Récupérer les informations de l'activité
        var info = AM.getInfo();
        var steps = info.steps;
        var stepGoal = info.stepGoal;
        
        // 2. Formater la chaîne des pas (ex: "1 254 Pas")
        var stepString = Lang.format("$1$/$2$", [steps.format("%d"), stepGoal.format("%d")]);
        
        // 3. Calculer la position Y : Sous l'heure, avec un petit espacement
        // L'heure est déjà centrée. On ajoute la moitié de la hauteur de l'heure
        // plus une petite marge de 5 pixels et la moitié de la hauteur de la police des pas.
        var stepFont = Gfx.FONT_XTINY;
        var fontHeight = Gfx.getFontHeight(stepFont);
        //var stepFontHeight = Gfx.getFontHeight(stepFont);
       
        // Pour placer le texte des pas sous le texte de l'heure
        var stepsYPos = posY + (fontHeight / 2) - 25 ; 

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT); // Texte gris clair pour les pas

        dc.drawText(
            posX,
            stepsYPos,
            stepFont,
            stepString,
            Gfx.TEXT_JUSTIFY_CENTER
        );
    } 
    function showHR(dc,posX,posY)as Void{
    
        // --- ❤️ AFFICHAGE FRÉQUENCE CARDIAQUE  ------------------------------------------
        var hrString = "--"; // Valeur par défaut si aucune donnée n'est trouvée
        var heartRate = 0;
        
        // Tentative de récupérer l'historique de FC la plus récente
        var hrIterator = SensorHistory.getHeartRateHistory({});

        // Récupérer la valeur la plus récente
        var hrSample = hrIterator.next();
        if (hrSample != null && hrSample.data != null) {
            heartRate = hrSample.data;
            hrString = Lang.format("$1$", [heartRate]);
        }

        // Position Y de la FC : Sous les pas, en utilisant la hauteur de la police secondaire
        var hrYPos = posY; // Ajout d'une marge de 5 pixels
        var hrXPos = posX;
        var hrFont = Gfx.FONT_XTINY;
        // Définir la couleur pour la FC (Blanc ou Rouge si très élevé)
        var hrColor = (heartRate > 150) ? Gfx.COLOR_RED : Gfx.COLOR_WHITE;
        dc.setColor(hrColor, Gfx.COLOR_TRANSPARENT);
        
        // Dessiner la FC
        dc.drawText(
            hrXPos,
            hrYPos,
            hrFont,
            hrString,
            Gfx.TEXT_JUSTIFY_RIGHT
        ); 
        if (heartIcon != null) {
            //var iconWidth = heartIcon.getWidth();
            var iconHrHeight = heartIcon.getHeight();
            var iconHrWidth = heartIcon.getWidth();
            // Calculer où dessiner l'icône pour qu'elle soit à GAUCHE du texte "XX bpm" :
            // 1. Mesurer la largeur du texte "XX bpm" (à centrer)
            var hrTextWidth = dc.getTextWidthInPixels(hrString, hrFont);
            
            // 2. Déterminer le point de départ X de l'icône
            // (Centre de l'écran) - (Moitié de la largeur du texte) - (Largeur de l'icône) - (Petite marge)
        
            //var iconXPos = hrXPos +hrTextWidth+ iconHrWidth/2;
            var iconXPos = hrXPos + iconHrWidth/2;
            
            // 3. Déterminer le point Y (centré sur la ligne de texte "XX bpm")
            var iconYPos = hrYPos + (Gfx.getFontHeight(hrFont) / 2) - (iconHrHeight / 2);
            
            dc.drawBitmap(iconXPos, iconYPos, heartIcon);
        } 
    }
    function showBattery(dc,posX,posY)as Void{
        // Obtenir le niveau de batterie (valeur de 0.0 à 100.0)
        var batteryLevel = Sys.getSystemStats().battery;
        var batteryFont= Gfx.FONT_XTINY;
        
        
        // Créer la chaîne de la batterie (ex: "85%")
        var batteryString = Lang.format(
            "$1$%",
            [batteryLevel.format("%d")]
        );
        // Calcul de la position : Centre Y moins une hauteur de police (pour le mettre au-dessus de l'heure)
        var batteryXPos = posX;
        var batteryYPos = posY - batteryFont - 80; 
        
        
        //Sys.println("DEBUG:batterie position : X "+batteryXPos+" Y "
        //    +batteryYPos+" H:"+batteryIcon.getHeight()+"W:"+batteryIcon.getWidth()
        //    +"Fontheight:"+dc.getFontHeight( batteryFont)+" fontWidth:"+dc.getTextWidthInPixels(batteryString, batteryFont));
        // Définir la couleur (Vert si la batterie est bonne, Rouge si faible)
        var batteryColor = (batteryLevel > 20) ? Gfx.COLOR_WHITE : Gfx.COLOR_RED;
       
        dc.setColor(batteryColor, Gfx.COLOR_TRANSPARENT);
        // Dessiner le pourcentage de batterie
       
        dc.drawText(
            batteryXPos, 
            batteryYPos,      
            batteryFont, // Utilisez une police plus petite pour la batterie
            batteryString,
            Gfx.TEXT_JUSTIFY_CENTER
        );
        if (batteryIcon != null) {
            //var batIconWidth = batteryIcon.getWidth();
            //var batIconHeight = batteryIcon.getHeight();
            
            // Calculer où dessiner l'icône pour qu'elle soit à GAUCHE du texte "XX bpm" :
            // 1. Mesurer la largeur du texte "XX bpm" (à centrer)
            var batTextWidth = dc.getTextWidthInPixels(batteryString, batteryFont);
            
            // 2. Déterminer le point de départ X de l'icône
            // (Centre de l'écran) - (Moitié de la largeur du texte) - (Largeur de l'icône) - (Petite marge)
        
            var batIconXPos = batteryXPos - batTextWidth/2 -2;
            
            // 3. Déterminer le point Y (centré sur la ligne de texte "XX bpm")
            //var batIconYPos = batteryYPos  + (batIconHeight / 2);
            var batIconYPos = batteryYPos+2;
            
            dc.drawBitmap(batIconXPos, batIconYPos, batteryIcon);
        
        } 

    }
    function showAltitude(dc,posX,posY)as Void{
        // --- ⛰️ AFFICHAGE ALTITUDE (SOUS LA FC) ------------------------------------------
        var altString = "-- m";
        
        // Tente de récupérer l'altitude la plus récente
        var positionInfo = Position.getInfo(); 
        var altFont = Gfx.FONT_XTINY;
        var altPosX = posX+15;
        var altPosY = posY;
        
        //var hrYPos = height/2 - height/4+20 ; // Ajout d'une marge de 5 pixels
        //var hrXPos = width/2 +width/4+40 ;
        if (positionInfo != null && positionInfo.altitude != null) {
            // L'altitude est donnée en mètres
            var altitude = positionInfo.altitude.toFloat();
            
            // Afficher l'altitude sans décimales, avec "m"
            altString = Lang.format("$1$", [altitude.format("%d")]);
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT); // Couleur blanche pour l'altitude
        
        dc.drawText(
            altPosX,
            altPosY,
            altFont,
            altString,
            Gfx.TEXT_JUSTIFY_RIGHT);

        if (altitudeIcon != null) {
            var altitudeiconWidth = altitudeIcon.getWidth();
            //var altitudeiconHeight = altitudeIcon.getHeight();
            
            // Calculer où dessiner l'icône pour qu'elle soit à GAUCHE du texte "XX bpm" :
            // 1. Mesurer la largeur du texte "XX bpm" (à centrer)
            var altTextWidth = dc.getTextWidthInPixels(altString, altFont);
            
            // 2. Déterminer le point de départ X de l'icône
            // (Centre de l'écran) - (Moitié de la largeur du texte) - (Largeur de l'icône) - (Petite marge)
        
            var altIconXPos = altPosX + altitudeiconWidth/2;
        
            
            // 3. Déterminer le point Y (centré sur la ligne de texte "XX bpm")
            //var altIconYPos = altPosY - (altitudeiconHeight );
            var altIconYPos = altPosY -5;
            
            dc.drawBitmap(altIconXPos, altIconYPos, altitudeIcon);
        
            }
    }
    function showDate(dc,posX,posY)as Void{
        var clockTime = Sys.getClockTime();
        var hours = clockTime.hour;
        var app = App.getApp();

        var dateFont =  Gfx.FONT_XTINY;
        var dateYpos =  posY;
        var dateString = app.getDateData();


        

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        var optionCoucherSoleil = {
                    :year   => today.year,
                    :month  => today.month,
                    :day    => today.day,
                    :hour   => today.hour , 
                    :minute => today.min ,
                    :dayOfWeek => today.day_of_week
                };
        switch (optionCoucherSoleil [:dayOfWeek] ){
            case "Mon":
                optionCoucherSoleil [:dayOfWeek] = "Lun";
            case "Tue":
                optionCoucherSoleil [:dayOfWeek] = "Mar";
            case "Wed": 
                optionCoucherSoleil [:dayOfWeek] = "Mer";
            case "Thu": 
                optionCoucherSoleil [:dayOfWeek] = "Jeu";
            case "Fri":
                optionCoucherSoleil [:dayOfWeek] = "Ven";
            case "Sat":
                optionCoucherSoleil [:dayOfWeek] = "Sam";
            case "Sun":
                optionCoucherSoleil [:dayOfWeek] = "Dim";
            }
     /*           var now = Time.now();
        var info = Calendar.info(now, Time.FORMAT_LONG);
        var dateStr;

        dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);
        */
        var dateWidth = dc.getTextWidthInPixels(dateString,dateFont);
        var dateXpos = posX;
        if (dateLabel != null) {
        // 🚨 IMPORTANT : Appeler la fonction de formatage AVANT d'obtenir les données.
            app.formatCurrentDate();
            
           
            //dateLabel.setText(dateString);
            //Sys.println("DEBUG: dateString:"+dateString);
            
            dc.drawText(
            posX,
             posY,
            dateFont, // Utilisez une police plus petite pour la batterie
            dateString,
            Gfx.TEXT_JUSTIFY_RIGHT);
            dateLabel.draw(dc);
            
        }
        Sys.println("DEBUG: dateString:"+dateString);
            
    }
    function showTemperatureGraph(dc,posX,posY) as Void{
         // --- 📉 COURBE DES TEMPÉRATURES PRÉVUES (24h) et precipitation -------------------------
        //si check il ya  plus d'une heure d'une heure 
        var fonctionName = "showTemperatureGraph(dc,posX,posY)";
        var newClock  = Sys.getClockTime();
        var newValueClock = 0;
        var lastValueClock = (lastClockTime.hour*60)+lastClockTime.min;
       
        
       
        var differenceHour = newClock.hour  - lastClockTime.hour;
        var hourlyForecast = null;
        //differenceHour = 3;// test synchro
        Sys.println("DEBUG: "+fonctionName+" differenceHour:"+differenceHour+" lastSync:"+lastSync);
        Sys.println("DEBUG: "+fonctionName+" temperatures:"+temperatures+" precipitation:"+precipitation);
        if(differenceHour>2||lastSync == null){ // ou premiere lancement le graph ne s'affiche pas au demarrage 
            // fais un synchro seuleemnt toute les 2 heures
        
            newValueClock = (newClock.hour*60)+newClock.min;
            hourlyForecast = Toybox.Weather.getHourlyForecast();
            Sys.println("DEBUG: "+fonctionName+" la synchro doit etre faite ");
            //Sys.println("DEBUG: "+newValueClock+"-"+lastValueClock+"="+(newValueClock-lastValueClock));
        }
        Sys.println("DEBUG: "+fonctionName+" precipitation.size():"+precipitation.size());
        // test sur les tailles des tableau precipitaion et temperature

        
        if (hourlyForecast != null && hourlyForecast.size() > 0) {
            
            var maxPoints = 24; // Nous ne voulons que les 24 prochaines heures
            
            // 1. Collecter les 24 points de données de température
            for (var i = 0; i < hourlyForecast.size() && i < maxPoints; i++) {
                var forecast = hourlyForecast[i];
                var forecastTime = forecast.forecastTime;
                var info = Time.Gregorian.info(forecastTime, Time.FORMAT_SHORT);
                
                // La température est généralement fournie en degrés Celsius ou selon les paramètres utilisateur
                var temp = forecast.temperature; 
                var prec = forecast.precipitationChance;
                lastSync = info;
                //Sys.println("DEBUG::"+fonctionName+"\ntemperatures[]:"+temperatures+"\nprecipitation[]:"+precipitation+" \ninfo:"+info.hour+":"+info.min);
                
                // Si la température est en Celsius (unité par défaut de l'API), la convertir si l'utilisateur est en STATUTE (Fahrenheit)
                /* if (Sys.getDeviceSettings().temperatureUnits == Sys.UNIT_STATUTE) {
                    // Conversion Celsius vers Fahrenheit: (C * 9/5) + 32
                    temp = (temp * 9 / 5) + 32;
                }
                */
                temperatures.add(temp);
                precipitation.add(prec);

            }
        }
        if(precipitation.size()>1){
            // 2. Dessiner la courbe à partir du tableau 'temperatures'
            Sys.println("DEBUG: "+fonctionName+" avant drawTemperatureGraph2 ");
            drawTemperatureGraph2(dc, temperatures,precipitation,posX,posY); 

            
            lastValueClock = newValueClock;
        }
        
        //--- fin weather ------------------------------------------
    }
    function test02(dc as Gfx.Dc) as Void{
        var textfunction="DEBUG function test02(dc as Gfx.Dc)";
        //Sys.println(textfunction);
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        
        var textTest02Y = 300;
        var textTest02X = 200;
        var textTest02Font = Gfx.FONT_XTINY;
        dc.drawCircle(textTest02X,textTest02Y,50);
        dc.drawText(
                    textTest02X,
                    textTest02Y,
                    textTest02Font,
                    "Choix 1",
                    Gfx.TEXT_JUSTIFY_LEFT
                );
       
    }
    function test(dc as Gfx.Dc) as Void{
        var textfunction="DEBUG function test(dc as Gfx.Dc)";
        //Sys.println(textfunction);
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(200,200,50);
      
    }
    function alternanceDisplay(value){
        //  retourne une valeur entre 0 et 1 suivant les valeur de seconde 
        //  5 pour toutes les 5 sec 
        //  2 pour le nombre de vue 
        
        var textfunction="DEBUG: alternanceDisplay("+value+")";
        var result  = (value / 5) % 2;
        //var result = value / 10;
        
        Sys.println(textfunction+"\nresult: "+result);
        switch(result){
            case 0:
                    return 0;
            case 1: 
                    return 1;
            default: 
                    return 2;
                    
        }
        
    }
    function backupBackground(dc as Gfx.Dc,X as Lang.Number,Y as Lang.Number,dimX as Lang.Number ,dimY as Lang.Number){
        //cette methode doit sauvegarder une zone rectangulaire definie par les parametres
        //X et Y plus une dimension en dimX et dimY
        var textfunction  = "function backupBackground(dc as Gfx.Dc,X as Lang.Number,Y as Lang.Number,dimX as Lang.Number ,dimY as Lang.Number)";
        
       
        if (Graphics has :createBufferedBitmap) {
        backupBuffer = Graphics.createBufferedBitmap({
            :width => dimX, 
            :height => dimY
        }).get();
       
        }

        
        if (backupBuffer != null) {
            // 1. On mémorise les paramètres pour la restauration future
            backupBufferX = X;
            backupBufferY = Y;
            backupBufferDimX = dimX;
            backupBufferDimY = dimY;

            // 2. On récupère le contexte graphique du buffer pour écrire dedans

            var bufferDc = backupBuffer.getDc();

            // 3. ON CAPTURE : on dessine l'écran dans le buffer avec le décalage négatif
            // Cela aligne le point (x,y) de l'écran sur le point (0,0) du buffer
            Sys.println("DEBUG:"+textfunction+"\n\t\tbackupBuffer[X,Y]: ["+backupBufferX+","+backupBufferY+"]");
            Sys.println("DEBUG:\t\tbackupBufferDimX: ["+backupBufferDimX+"x"+backupBufferDimY+"]");
            bufferDc.drawBitmap(-backupBufferX, -backupBufferY, background);
        }
    }
    function restoreBackgroundAt(dc as Gfx.Dc,X as Lang.Number, Y as Lang.Number) as Void {
        // restaorer le buffer image sauvegrar à un endroit precis X ,Y
        var textfunction = "function restoreBackgroundAt(dc as Gfx.Dc,X as Lang.Number, Y as Lang.Number)";
         if (backupBuffer != null) {
            // On définit une zone de découpe (Clip) pour ne pas déborder 
            // si le buffer est plus grand que la zone sauvegardée

            //rectangle bleu de visualisation des modifs
            //dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
            //dc.fillRectangle(0,backupBufferY-5,backupBufferDimX+150,backupBufferDimY+20);

            //dc.setClip(backupBufferX, backupBufferY, backupBufferDimX, backupBufferDimY);
            Sys.println("DEBUG:"+textfunction+"\nDEBUG:\tdc.fillCircle(backupBufferX+50,backupBufferY+50,12);");
            
            dc.setColor(Green_color,Gfx.COLOR_TRANSPARENT);
           
            // On redessine le buffer aux coordonnées mémorisées
            dc.drawBitmap(X, Y, backupBuffer);
            //dc.fillCircle(X+50,Y+50,12);
            //dc.drawRectangle(X+49,Y+49,backupBufferDimX+2,backupBufferDimY+2);
            
            // On réinitialise la zone de découpe à l'écran entier
            dc.clearClip();
        }
    }
    function restoreBackground(dc as Gfx.Dc) as Void {
        var textfunction  ="function restoreBackground(dc as Gfx.Dc) as Void";
        //Sys.println("DEBUG:"+textfunction+"\nBefore:  if (backupBuffer != null)  ");
        //Sys.println("DEBUG: "+"backupBuffer:"+backupBuffer);
        if (backupBuffer != null) {
            // On définit une zone de découpe (Clip) pour ne pas déborder 
            // si le buffer est plus grand que la zone sauvegardée

            //rectangle bleu de visualisation des modifs
            //dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
            //dc.fillRectangle(0,backupBufferY-5,backupBufferDimX+150,backupBufferDimY+20);

            //dc.setClip(backupBufferX, backupBufferY, backupBufferDimX, backupBufferDimY);
            Sys.println("DEBUG:"+textfunction+"\nDEBUG:\tdc.fillCircle(backupBufferX+50,backupBufferY+50,12);");
            
            dc.setColor(Green_color,Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(backupBufferX+50,backupBufferY+50,12);
            // On redessine le buffer aux coordonnées mémorisées
            dc.drawBitmap(backupBufferX, backupBufferY, backupBuffer);
            
            // On réinitialise la zone de découpe à l'écran entier
            dc.clearClip();
        }
}
    function onUpdate(dc as Gfx.Dc) as Void {
        var textfunction  ="function onUpdate(dc as Gfx.Dc) as Void";
        //System.println("DEBUG: onUpdate appelée. Début du dessin...");//
         // 0. Appel parent (bonne pratique pour les WatchFace)
        Sys.println("DEBUG:"+textfunction);
        Ui.WatchFace.onUpdate(dc); 
        var app = App.getApp();
       
        // --- 🖼️ DESSIN DE L'IMAGE DE FOND (EN PREMIER) ---
        if (background != null) {
            //Sys.println("DEBUG: background not null "+background);
            // Dessiner l'image à la position (0, 0) pour qu'elle couvre tout l'écran
            dc.drawBitmap(0, 0, background); 
        }
        // fin dessine image background ------------------------
        
        // --- LOGIQUE GÉNÉRALE ---
        var width = dc.getWidth();
        var height = dc.getHeight();
        var currentFont = (timeFont != null) ? timeFont : Gfx.FONT_SMALL;
        currentFont = timeFont;
        var fontHeight = Gfx.getFontHeight(currentFont);
        var timeYpos = (height / 2)-45 ;
        // --- 📉 COURBE DES TEMPÉRATURES PRÉVUES (24h) weather --------------------------
        var graphHeight = height / 3; // Graphique de 1/3e de la hauteur de l'écran
        var graphYStart = height - graphHeight - 65; // Commencer juste au-dessus du "GARMIN"
        var graphXStart = width/6; 
        var graphWidth = (width - width/6) - graphXStart;
       
        
        dc.setColor(Orange_color, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(graphXStart,graphYStart,graphWidth,graphHeight);
                /* -- A VERIFIER ------
                drawRectangle(x as Lang.Numeric, y as Lang.Numeric, width as Lang.Numeric, height as Lang.Numeric)
                   
                */
        // ----- TIME
        var now = Sys.getClockTime();
        var hours = now.hour;
        var min = now.min;
        var sec= now.sec;
        //Sys.println(hours+":"+min+":"+sec);
        // antichevauchement 


        
        
        //dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        //dc.fillRectangle(0, 180, width, 120);
        
        //system d'alternance 
        var displayMode = alternanceDisplay(sec);
        Sys.println("displaymode: "+displayMode);
        //var displayMode = 1 ;
        var tailley= graphHeight ;
        var taillex= graphWidth;
        
        Sys.println("DEBUG: [taillex x tailley]: ["+tailley+" x "+taillex+"]");
        restoreBackgroundAt(dc,20,20);
        restoreBackground(dc);
        backupBackground(dc,graphXStart-20,graphYStart,taillex+20,tailley);
        showTemperatureGraph(dc,graphXStart,graphYStart);
        /*
        switch( displayMode){
            case 0:
               
                dc.setColor(Blue_color,Gfx.COLOR_TRANSPARENT);
                dc.fillRectangle(graphXStart+50,graphYStart+10,40,40);
                
                //showTemperatureGraph(dc,graphXStart,graphYStart);
            case 1:
                dc.setColor(Orange_color,Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(graphXStart+80,graphYStart+80,12);
                test02(dc);
           
           

        }
        */
        // fin 📉 COURBE DES TEMPÉRATURES PRÉVUES (24h) weather --------------------------
        // --- 👣 AFFICHAGE DES PAS  ------------------------------------------
        var timefontHeight = Gfx.getFontHeight(timeFont); 
        showPas(dc,(width/2),(timeYpos + (Gfx.getFontHeight(Gfx.FONT_NUMBER_HOT) / 2)-10 ) );
        // fin 👣 AFFICHAGE DES PAS  ------------------------------------------
        // --- ❤️ AFFICHAGE FRÉQUENCE CARDIAQUE  ------------------------------------------
        showHR(dc, width/2 +width/4+40, height/2 - height/4+20);
        // fin ❤️ AFFICHAGE FRÉQUENCE CARDIAQUE  ------------------------------------------
        // --- 🔋 AFFICHAGE BATTERIE ------------------------------------------
        showBattery(dc,width / 2, (height / 4));
        // fin 🔋 AFFICHAGE BATTERIE ------------------------------------------
        
        showDate(dc,width / 2 +70, (height/5)-30 );
        // --- ⛰️ AFFICHAGE ALTITUDE (SOUS LA FC) --------------------------------
        showAltitude(dc,(width/2)+width/4+35,height/2 - (height/4)+30 + Gfx.getFontHeight(Gfx.FONT_XTINY));
        // fin ⛰️ AFFICHAGE ALTITUDE (SOUS LA FC) --------------------------------
        // --- 🌡️ AFFICHAGE TEMPÉRATURE ------------------------------------------
        showTemperature(dc ,(width/2) - 50,60);
        // fin 🌡️ AFFICHAGE TEMPÉRATURE ------------------------------------------
        // --- ☀️ COUCHER DU SOLEIL (Méthode Météo GARANTIE) ----------------------
        showCoucheSoleil(dc ,(width/2 + 75),60);
        // fin ☀️ COUCHER DU SOLEIL (Méthode Météo GARANTIE) ----------------------
        
    
        // --- TIME  ------------------------------------------

        
        if (timeFont == null) {
            timeFont = Gfx.FONT_NUMBER_HOT;
        }

        // GESTION DU FORMAT 12 HEURES (décommenter si vous utilisez le 12h)
        /*
        if (Sys.getDeviceSettings().is24Hour == false) {
            if (hours > 12) {
                hours = hours - 12;
            } else if (hours == 0) {
                hours = 12;
            }
        }
        */
        
        // 2. Créer la chaîne de caractères de l'heure (Ex: "1:27" ou "13:27")
        var timeString = Lang.format(
            "$1$:$2$",
            [
                hours.format("%d"),        // Affiche l'heure sans zéro devant (ex: 1 au lieu de 01)
                min.format("%02d") // Affiche les minutes avec un zéro devant (ex: 07 au lieu de 7)
            ]
        );
        timeFont = Gfx.FONT_NUMBER_HOT;
        
        var timeXpos = width/2+105;
        // Définir la couleur pour le texte (Blanc sur fond transparent)
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        
        
        //Sys.println("DEBUG: "+timeString+" x"+timeXpos+"y:"+timeXpos);
       /* dc.drawText(
           timeXpos, 
            timeYpos,      
            timeFont,
            timeString,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);       
        */
        dc.drawText(
           timeXpos, 
            timeYpos,      
            timeFont,
            timeString,
            Gfx.TEXT_JUSTIFY_RIGHT|  Gfx.TEXT_JUSTIFY_VCENTER);       


    }//OnUpdate

    //! Les autres fonctions (onShow, onHide, etc.) peuvent rester inchangées si elles existent.
}