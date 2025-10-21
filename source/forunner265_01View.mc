// Fichier : source/MonCadranDeMontreView.mc

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


    // ✅ CORRECTION APPLIQUÉE ICI : 
    // Initialisation de la classe enfant et appel de la méthode du parent.
    function initialize() {
        // Appelle la méthode d'initialisation de la classe WatchFace
        Ui.WatchFace.initialize(); 
        
        // Ou, de manière plus générique, vous pouvez utiliser :
        // Super.initialize(); 
    }

    //! Charger vos ressources ici
    function onLayout(dc as Gfx.Dc) as Void {
        //System.println("DEBUG: onLayout appelée.");
        // Charge la ressource en utilisant l'ID défini dans le XML (Rez.Fonts.ID_DE_VOTRE_POLICE)

        timeFont = Ui.loadResource(Rez.Fonts.BebasNeueRegular) ;
        var timefontHeight = Gfx.getFontHeight(timeFont);

        Green_color = Gfx.createColor(255,160,209,177);
        Orange_color = Gfx.createColor(255,230,146,215);
        Blue_color = Gfx.createColor(255,96,164,226);
        lightgray_color = Gfx.createColor(255,129,133,135);
      
        //Orange_color = Gfx.COLOR_RGB(160,209,177);
        //Green_color = Gfx.COLOR_RGB(160,209,177);
        

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
        background = Ui.loadResource(Rez.Drawables.Background);
        heartIcon = Ui.loadResource(Rez.Drawables.HeartIcon);
        batteryIcon = Ui.loadResource(Rez.Drawables.BatteryIcon);
        altitudeIcon = Ui.loadResource(Rez.Drawables.AltitudeIcon);
        temperatureIcon = Ui.loadResource(Rez.Drawables.TemperatureIcon);
        soleilIcon = Ui.loadResource(Rez.Drawables.SoleilIcon);
        
    }
    

    
     function drawTemperatureGraph2(dc as Gfx.Dc, temps,precipitations,posX,posY ) as Void {
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Définir la zone où le graphique sera dessiné (Ex: bas de l'écran)
        var graphHeight = height / 3; // Graphique de 1/5e de la hauteur de l'écran
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
        dc.setColor(lightgray_color, Gfx.COLOR_TRANSPARENT);
        var lastClockTimeX = graphXStart + graphWidth / 2;
        var lastClockTimeY = (graphYStart + graphHeight / 2) + 40;
        var lastClockTimeXString = Lang.format("$1$:$2$", [lastClockTime.hour.format("%02d"), lastClockTime.min.format("%02d")]);
        
        dc.drawText(
            lastClockTimeX,
            lastClockTimeY,
            Gfx.FONT_XTINY,
            lastClockTimeXString,
            Gfx.TEXT_JUSTIFY_CENTER
        );
    }
    /*function drawTemperatureGraph(dc as Gfx.Dc, temps ) as Void {
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Définir la zone où le graphique sera dessiné (Ex: bas de l'écran)
        var graphHeight = height / 3; // Graphique de 1/5e de la hauteur de l'écran
        var graphYStart = height - graphHeight - 50; // Commencer juste au-dessus du "GARMIN"
        var graphXStart = width/6; 
        var graphXEnd = width - width/6;
        var graphWidth = graphXEnd - graphXStart;
       // Sys.println("DEBUG: "+width+"x"+height+" "+graphXStart+","+graphYStart+" "+graphWidth+"-"+graphHeight);
        //dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);// couleur rectangle
        //dc.drawRectangle(graphXStart, graphYStart, graphWidth, graphHeight);
        if (temps.size() == 0) {
            return; // Rien à dessiner
        }
        
        // 1. Déterminer les valeurs Min/Max pour l'échelle Y
        var minTemp = temps[0];
        var maxTemp = temps[0];
        for (var i = 1; i < temps.size(); i++) {
            if (temps[i] < minTemp) { minTemp = temps[i]; }
            if (temps[i] > maxTemp) { maxTemp = temps[i]; }
        }
        //Sys.println("DEBUG: "+"minTemp:"+ minTemp + "maxTemp:"+maxTemp);
        // Ajouter une marge pour que la courbe ne touche pas les bords
        minTemp -= 2; 
        maxTemp += 2;
        var tempRange = maxTemp - minTemp;
        if (tempRange == 0) { tempRange = 1; } // Éviter la division par zéro
        
        // 2. Dessiner la courbe
        dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
        var prevX = -1;
        var prevY = -1;
        
        for (var i = 0; i < temps.size(); i++) {
            // Calculer la position X (répartition des 24 points sur la largeur du graphique)
            var currentX = graphXStart + (i * graphWidth) / (temps.size() - 1);
            
            // Calculer la position Y (mise à l'échelle de la température sur la hauteur du graphique)
            // L'axe Y est inversé (Y=0 est en haut)
            var tempNormalized = (temps[i] - minTemp) / tempRange;
            var currentY = graphYStart + graphHeight - (tempNormalized * graphHeight);
            
            // Dessiner la ligne entre les points
            if (prevX != -1) {
                //dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
                dc.setColor(Green_color,Gfx.COLOR_TRANSPARENT);
                dc.drawLine(prevX.toNumber(), prevY.toNumber(), currentX.toNumber(), currentY.toNumber());

                dc.fillCircle(prevX,prevY,2);
                dc.setColor(Gfx.COLOR_DK_BLUE, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(prevX,graphYStart,prevX,graphYStart+graphHeight);
                
            }
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            var maxTempFormat = Lang.format("$1$", [maxTemp.format("%d")]);
            var minTempFormat = Lang.format("$1$", [minTemp.format("%d")]);
            
            dc.drawText(
                    graphXStart-25,
                    graphYStart+60,
                    Gfx.FONT_XTINY,
                    minTempFormat,
                    Gfx.TEXT_JUSTIFY_CENTER
                );
            dc.drawText(
                   graphXStart-25,
                    graphYStart-10,
                    Gfx.FONT_XTINY,
                    maxTempFormat,
                    Gfx.TEXT_JUSTIFY_CENTER
                );
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            var lastClockTimeX = graphXStart+graphWidth/2;
            var lastClockTimeY = (graphYStart+graphHeight/2)+40;
            var lastClockTimeXString = Lang.format("$1$:$2$", [lastClockTime.hour.format("%2d"), lastClockTime.min.format("%2d")]);
            //var lastClockTimeXString = lastClockTime.hour+":"+lastClockTime.min;
            dc.drawText(
                   lastClockTimeX,
                    lastClockTimeY,
                    Gfx.FONT_XTINY,
                    lastClockTimeXString,
                    Gfx.TEXT_JUSTIFY_CENTER
                );
            
            prevX = currentX;
            prevY = currentY;
        }
        
        // 3. (Optionnel) Dessiner un marqueur de temps (ex: l'heure actuelle au début)
        var tempMaxNormalized = maxTemp;
        var posYtempMax = graphYStart + graphHeight - (tempMaxNormalized * graphHeight);//ici
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(
            graphXStart, 
            graphYStart + graphHeight + 5, 
            Gfx.FONT_XTINY, 
            maxTemp ,
            Gfx.TEXT_JUSTIFY_LEFT
        );
    }*/
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
        Sys.println(textFunction);
        Sys.println("DEBUG: "+optionCoucherSoleil[:hour] +" " +lastOptionCoucherSoleil[:hour]);
        //if (optionCoucherSoleil[:hour]!= lastOptionCoucherSoleil[:hour]){
            Sys.println("DEBUG on passe dansle If pour affichier leheure de coucher de soleil ");
            lastOptionCoucherSoleil = optionCoucherSoleil;
            var todayMoment = Gregorian.moment(optionCoucherSoleil);
            var HeureCoucheSoleil = Weather.getSunset(positionSoleil.position,todayMoment);

            Sys.println("DEBUG: HeureCoucheSoleil:"+HeureCoucheSoleil+"positionSoleil.position:"+positionSoleil.position+" todayMoment:"+todayMoment);
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
                Sys.println("DEBUG: coucherSoleil:"+coucherSoleilString);
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
        var textFunction ="DEBUG: showPas(dc, "+posX+","+posY+")";
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
        var altPosX = posX;
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
         // --- 📉 COURBE DES TEMPÉRATURES PRÉVUES (24h) --------------------------
        //si check il ya  plus d'une heure d'une heure 
        var newClock  = Sys.getClockTime();
        var newValueClock =0;
        var lastValueClock = (lastClockTime.hour*60)+lastClockTime.min;

        //Sys.println("DEBUG: "+newValueClock+"-"+lastValueClock+"="+(newValueClock-lastValueClock));

        if((newValueClock-lastValueClock>60) ||(newValueClock-lastValueClock<0) ){
            newValueClock = (newClock.hour*60)+newClock.min;
            var hourlyForecast = Toybox.Weather.getHourlyForecast();
            //Sys.println("DEBUG: "+newValueClock+"-"+lastValueClock+"="+(newValueClock-lastValueClock));
            if (hourlyForecast != null && hourlyForecast.size() > 0) {
                
                
                var temperatures = [];
                var precipitation = [];
                var maxPoints = 24; // Nous ne voulons que les 24 prochaines heures
                
                // 1. Collecter les 24 points de données de température
                for (var i = 0; i < hourlyForecast.size() && i < maxPoints; i++) {
                    var forecast = hourlyForecast[i];
                    
                    // La température est généralement fournie en degrés Celsius ou selon les paramètres utilisateur
                    var temp = forecast.temperature; 
                    var prec = forecast.precipitationChance;
                    
                    // Si la température est en Celsius (unité par défaut de l'API), la convertir si l'utilisateur est en STATUTE (Fahrenheit)
                   /* if (Sys.getDeviceSettings().temperatureUnits == Sys.UNIT_STATUTE) {
                        // Conversion Celsius vers Fahrenheit: (C * 9/5) + 32
                        temp = (temp * 9 / 5) + 32;
                    }
                    */
                    temperatures.add(temp);
                    precipitation.add(prec);

                }
                
                // 2. Dessiner la courbe à partir du tableau 'temperatures'
                drawTemperatureGraph2(dc, temperatures,precipitation,posX,posY); 

               
                lastValueClock = newValueClock;
            }
        }
        //--- fin weather ------------------------------------------
    }
    function test(dc as Gfx.Dc) as Void{
        var textfunction="DEBUG function test(dc as Gfx.Dc)";
        Sys.println(textfunction);
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(200,200,50);
      
    }
    function onUpdate(dc as Gfx.Dc) as Void {
        //System.println("DEBUG: onUpdate appelée. Début du dessin...");//
         // 0. Appel parent (bonne pratique pour les WatchFace)
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
        var graphHeight = height / 3; // Graphique de 1/5e de la hauteur de l'écran
        var graphYStart = height - graphHeight - 65; // Commencer juste au-dessus du "GARMIN"
        var graphXStart = width/6; 
        //var graphXEnd = width - width/6;
        //var graphWidth = graphXEnd - graphXStart;
        showTemperatureGraph(dc,graphXStart,graphYStart);
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
        // Si la police 'timeFont' n'est pas déjà définie, utilisons une grande police sûre.
        var now = Sys.getClockTime();
        var hours = now.hour;
        var min = now.min;
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