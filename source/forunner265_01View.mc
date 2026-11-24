// Fichier : MonCadranDeMontreView.mc

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Position as Position;
using Toybox.ActivityMonitor as AM;
using Toybox.Activity as Activity; 
using Toybox.Time.Gregorian;
using Toybox.Time;
using Toybox.Weather as Weather;
using Toybox.SensorHistory as SensorHistory;

class MonCadranDeMontreView extends Ui.WatchFace {

    var timeFont = null;
    private var heartIcon as Ui.BitmapResource or Null; 
    private var batteryIcon as Ui.BitmapResource or Null; 
    private var altitudeIcon as Ui.BitmapResource or Null; 
    private var temperatureIcon as Ui.BitmapResource or Null; 
    private var background as Ui.BitmapResource or Null;
    private var soleilIcon as Ui.BitmapResource or Null;
    private var lastClockTime = Sys.getClockTime();
    private var lastSync = null;        // ✅ Initialisé
    private var lastClockSync = null;   // ✅ Initialisé
    private var lastOptionCoucherSoleil = {
        :year   => 0,
        :month  => 0,
        :day    => 0,
        :hour   => 0, 
        :minute => 0
    };
   
    private var dateLabel as Ui.Text or Null;
    private var Orange_color;
    private var Green_color;
    private var Blue_color;
    private var Red_color;
    private var lightgray_color;
    private var backupBuffer = null;
    private var backupBufferX = 0;
    private var backupBufferY = 0;
    private var backupBufferDimX = 0;
    private var backupBufferDimY = 0;

    private var temperatures = [];
    private var precipitation = [];

    private var testheuresynchro = null; // ✅ Initialisé
    
    function initialize() {
        Ui.WatchFace.initialize(); 
        Green_color = Gfx.createColor(255, 160, 209, 177);
        Orange_color = Gfx.createColor(255, 247, 168, 19);
        Blue_color = Gfx.createColor(255, 96, 164, 226);
        Red_color = Gfx.createColor(255, 255, 0, 0);
        lightgray_color = Gfx.createColor(255, 129, 133, 135);

        timeFont = Ui.loadResource(Rez.Fonts.BebasNeueRegular);
        
        background = Ui.loadResource(Rez.Drawables.Background);
        heartIcon = Ui.loadResource(Rez.Drawables.HeartIcon);
        batteryIcon = Ui.loadResource(Rez.Drawables.BatteryIcon);
        altitudeIcon = Ui.loadResource(Rez.Drawables.AltitudeIcon);
        temperatureIcon = Ui.loadResource(Rez.Drawables.TemperatureIcon);
        soleilIcon = Ui.loadResource(Rez.Drawables.SoleilIcon);
    }

    function onLayout(dc as Gfx.Dc) as Void {
        dateLabel = new Ui.Text({
            :locX => Ui.LAYOUT_HALIGN_CENTER,
            :locY => (dc.getHeight() / 2) + 40,
            :justification => Gfx.TEXT_JUSTIFY_CENTER,
            :font => Gfx.FONT_XTINY,
            :color => Gfx.COLOR_WHITE
        });
    }
    
    function drawTemperatureGraph2(dc as Gfx.Dc, temps, precipitations, posX, posY) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var graphHeight = height / 3; 
        var graphYStart = height - graphHeight - 65; 
        var graphXStart = width / 6; 
        var graphXEnd = width - width / 6;
        var graphWidth = graphXEnd - graphXStart;

        if (temps == null || temps.size() == 0) {
            return;
        }
        
        var minTemp = temps[0];
        var maxTemp = temps[0];
        for (var i = 1; i < temps.size(); i++) {
            if (temps[i] < minTemp) { minTemp = temps[i]; }
            if (temps[i] > maxTemp) { maxTemp = temps[i]; }
        }
        
        var maxPrecip = 0.0;
        if (precipitations != null) {
            for (var i = 0; i < precipitations.size(); i++) {
                if (precipitations[i] != null && precipitations[i] > maxPrecip) { maxPrecip = precipitations[i]; }
            }
        }
        var precipRange = 10.0; 
        if (maxPrecip > 10.0) {
            precipRange = maxPrecip * 1.1; 
        }
        var minPrecip = 0.0; 

        minTemp -= 2;
        maxTemp += 2;
        var tempRange = maxTemp - minTemp;
        if (tempRange == 0) { tempRange = 1; }
        
        var prevX = -1;
        var prevYTemp = -1; 
        var prevYPrecip = -1; 
        
        for (var i = 0; i < temps.size(); i++) {
            var currentX = graphXStart + (i * graphWidth) / (temps.size() - 1.0); 
            var tempNormalized = (temps[i] - minTemp) / tempRange;
            var currentYTemp = graphYStart + graphHeight - (tempNormalized * graphHeight);
            
            var currentYPrecip = -1;
            if (precipitations != null && precipitations.size() > i && precipitations[i] != null) {
                var precipNormalized = (precipitations[i] - minPrecip) / precipRange;
                currentYPrecip = graphYStart + graphHeight - (precipNormalized * graphHeight);
            }

            if (prevX != -1) {
                dc.setColor(Green_color, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(prevX.toNumber(), prevYTemp.toNumber(), currentX.toNumber(), currentYTemp.toNumber());
                
                if (prevYPrecip != -1 && currentYPrecip != -1) {
                    dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
                    dc.drawLine(prevX.toNumber(), prevYPrecip.toNumber(), currentX.toNumber(), currentYPrecip.toNumber());
                }
            }
            
            dc.setColor(Green_color, Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(currentX, currentYTemp, 2);
            
            if (currentYPrecip != -1) {
                dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(currentX, currentYPrecip, 2);
            }

            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(currentX, graphYStart, currentX, graphYStart + graphHeight);
            
            prevX = currentX;
            prevYTemp = currentYTemp;
            prevYPrecip = currentYPrecip; 
        }

        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        var maxTempFormat = Lang.format("$1$", [maxTemp.format("%d")]);
        var minTempFormat = Lang.format("$1$", [minTemp.format("%d")]);
        
        dc.drawText(graphXStart - 5, graphYStart + graphHeight - Gfx.getFontHeight(Gfx.FONT_XTINY) - 15, Gfx.FONT_XTINY, minTempFormat, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(graphXStart - 5, graphYStart - 10, Gfx.FONT_XTINY, maxTempFormat, Gfx.TEXT_JUSTIFY_RIGHT);

        dc.setColor(Blue_color, Gfx.COLOR_TRANSPARENT);
        var maxPrecipFormat = Lang.format("$1$", [precipRange.format("%d")]);
        var minPrecipFormat = "0";
        
        dc.drawText(graphXEnd + 5, graphYStart - 10, Gfx.FONT_XTINY, maxPrecipFormat, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(graphXEnd + 5, graphYStart + graphHeight - Gfx.getFontHeight(Gfx.FONT_XTINY) - 15, Gfx.FONT_XTINY, minPrecipFormat, Gfx.TEXT_JUSTIFY_LEFT);

        showTemperatureGraphDrawNowLine2(dc, posX, posY);

        if (lastSync != null) {
            dc.setColor(lightgray_color, Gfx.COLOR_TRANSPARENT);
            var lastClockTimeX = graphXStart + graphWidth / 2;
            var lastClockTimeY = (graphYStart + graphHeight / 2) + 40;
            
            var lastClockTimeXString = Lang.format("$1$:$2$ $3$/$4$/$5$", [
                lastSync.hour.format("%02d"),
                lastSync.min.format("%02d"),
                lastSync.day.format("%02d"),
                lastSync.month.format("%02d"),
                lastSync.year.format("%02d").substring(2, 4)
            ]);
            
            dc.drawText(lastClockTimeX, lastClockTimeY + 30, Gfx.FONT_XTINY, lastClockTimeXString, Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    function showTemperature(dc as Gfx.Dc, posX, posY) as Void {
        var tempString = "--°C"; 
        var tempFont = Gfx.FONT_XTINY;
        
        var tempIterator = SensorHistory.getTemperatureHistory({});
        if (tempIterator != null) {
            var tempSample = tempIterator.next();
            if (tempSample != null && tempSample.data != null) {
                var tempC = tempSample.data; 
                tempString = Lang.format("$1$°C", [tempC.format("%02d")]); 
            }
        }

        var tempXPos = posX + dc.getTextWidthInPixels(tempString, tempFont) - 115;
        var tempYPos = posY; 
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tempXPos, tempYPos, tempFont, tempString, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_RIGHT);
        
        if (temperatureIcon != null) {
            var tempIconWidth = temperatureIcon.getWidth();
            var tempIconXPos = tempXPos - tempIconWidth / 2;
            var tempIconYPos = tempYPos - Gfx.getFontHeight(tempFont) + 5;
            dc.drawBitmap(tempIconXPos, tempIconYPos, temperatureIcon);
        }  
    }

    function showCoucheSoleil(dc as Gfx.Dc, posX, posY) as Void {
        var positionSoleil = Position.getInfo(); 
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        
        var optionCoucherSoleil = {
            :year   => today.year,
            :month  => today.month,
            :day    => today.day,
            :hour   => today.hour, 
            :minute => today.min 
        };
        if (positionSoleil != null) {
            lastOptionCoucherSoleil = optionCoucherSoleil;
            var todayMoment = Gregorian.moment(optionCoucherSoleil);
            var HeureCoucheSoleil = Weather.getSunset(positionSoleil.position, todayMoment);

            var timeInfoCoucheSoleil;
            if (HeureCoucheSoleil != null) {
                timeInfoCoucheSoleil = Gregorian.info(HeureCoucheSoleil, Time.FORMAT_MEDIUM);
                var coucherSoleilString = Lang.format("$1$:$2$", [
                    timeInfoCoucheSoleil.hour.format("%02d"), 
                    timeInfoCoucheSoleil.min.format("%02d")
                ]);
                var soleilFont = Gfx.FONT_XTINY;
                var soleilXpos = posX;
                var soleilYpos = posY;
                
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT); 
                dc.drawText(soleilXpos, soleilYpos, soleilFont, coucherSoleilString, Gfx.TEXT_JUSTIFY_LEFT);
                
                if (soleilIcon != null) {
                    var soleilIconWidth = soleilIcon.getWidth();
                    var soleilIconXPos = soleilXpos + soleilIconWidth / 2 - 15;
                    var soleilIconYPos = soleilYpos - Gfx.getFontHeight(Gfx.FONT_XTINY) + 5;
                    dc.drawBitmap(soleilIconXPos, soleilIconYPos, soleilIcon);
                }   
            }
        }  
    } 

    function showPourtour(dc, posX, posY, rayon) {
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(posX, posY, rayon);
    }

    function drawPercentTicksStep(dc as Gfx.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;
        var radius = width / 2;
        
        var info = AM.getInfo();
        var steps = info.steps;
        var stepGoal = info.stepGoal;
        var percentage = (steps * 100) / stepGoal;

        var minorTickLength = 3;  
        var mediumTickLength = 6; 
        var majorTickLength = 10; 
        var outerRadius = radius - 5; 
        
        for (var i = 0; i < percentage; i++) {
            var angle = i * 3.6; 
            var angleRadians = Math.toRadians(angle);
            var innerRadius;
            var tickLength;
            var thickness; 
            
            if (i % 10 == 0) {
                tickLength = majorTickLength;
                thickness = 3;
                if (i < 100) {
                    dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
                } else if (i > 100 && i <= 200) {
                    dc.setColor(Orange_color, Gfx.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Red_color, Gfx.COLOR_TRANSPARENT);
                }
            } else if (i % 5 == 0) {
                tickLength = mediumTickLength;
                thickness = 2;
                if (i < 100) {
                    dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
                } else if (i > 100 && i <= 200) {
                    dc.setColor(Orange_color, Gfx.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Red_color, Gfx.COLOR_TRANSPARENT);
                }
            } else {
                tickLength = minorTickLength;
                thickness = 1; 
                if (i < 100) {
                    dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Orange_color, Gfx.COLOR_TRANSPARENT);
                }
            }
            
            innerRadius = outerRadius - tickLength;
            var x1 = centerX + outerRadius * Math.sin(angleRadians);
            var y1 = centerY - outerRadius * Math.cos(angleRadians); 
            var x2 = centerX + innerRadius * Math.sin(angleRadians);
            var y2 = centerY - innerRadius * Math.cos(angleRadians);
            
            dc.setPenWidth(thickness);
            dc.drawLine(x1.toNumber(), y1.toNumber(), x2.toNumber(), y2.toNumber());
        }
    }   

    function showPas(dc, posX, posY) as Void {
        var info = AM.getInfo();
        var steps = info.steps;
        var stepGoal = info.stepGoal;
        
        var stepString = Lang.format("$1$/$2$", [steps.format("%d"), stepGoal.format("%d")]);
        var stepFont = Gfx.FONT_XTINY;
        var fontHeight = Gfx.getFontHeight(stepFont);
        var stepsYPos = posY + (fontHeight / 2) - 25; 

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(posX, stepsYPos, stepFont, stepString, Gfx.TEXT_JUSTIFY_CENTER);
    } 

    function showHR(dc, posX, posY) as Void {
        var hrString = "--"; 
        var heartRate = 0;
        
        var hrIterator = SensorHistory.getHeartRateHistory({});
        if (hrIterator != null) {
            var hrSample = hrIterator.next();
            if (hrSample != null && hrSample.data != null) {
                heartRate = hrSample.data;
                hrString = Lang.format("$1$", [heartRate]);
            }
        }

        var hrYPos = posY; 
        var hrXPos = posX;
        var hrFont = Gfx.FONT_XTINY;
        var hrColor = (heartRate > 150) ? Gfx.COLOR_RED : Gfx.COLOR_WHITE;
        dc.setColor(hrColor, Gfx.COLOR_TRANSPARENT);
        
        dc.drawText(hrXPos, hrYPos, hrFont, hrString, Gfx.TEXT_JUSTIFY_RIGHT); 
        
        if (heartIcon != null) {
            var iconHrHeight = heartIcon.getHeight();
            var iconHrWidth = heartIcon.getWidth();
            var iconXPos = hrXPos + iconHrWidth / 2;
            var iconYPos = hrYPos + (Gfx.getFontHeight(hrFont) / 2) - (iconHrHeight / 2);
            dc.drawBitmap(iconXPos, iconYPos, heartIcon);
        } 
    }

    function showBattery(dc, posX, posY) as Void {
        var batteryLevel = Sys.getSystemStats().battery;
        var batteryFont = Gfx.FONT_XTINY;
        var batteryString = Lang.format("$1$%", [batteryLevel.format("%d")]);
        var batteryXPos = posX;
        var batteryYPos = posY - batteryFont - 80; 
        var batteryColor = (batteryLevel > 20) ? Gfx.COLOR_WHITE : Gfx.COLOR_RED;
       
        dc.setColor(batteryColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(batteryXPos, batteryYPos, batteryFont, batteryString, Gfx.TEXT_JUSTIFY_CENTER);
        
        if (batteryIcon != null) {
            var batTextWidth = dc.getTextWidthInPixels(batteryString, batteryFont);
            var batIconXPos = batteryXPos - batTextWidth / 2 - 2;
            var batIconYPos = batteryYPos + 2;
            dc.drawBitmap(batIconXPos, batIconYPos, batteryIcon);
        } 
    }

    function showAltitude(dc, posX, posY) as Void {
        var altString = "-- m";
        var positionInfo = Position.getInfo(); 
        var altFont = Gfx.FONT_XTINY;
        var altPosX = posX + 15;
        var altPosY = posY;
        var altitude = 0;
        
        if (positionInfo != null && positionInfo.altitude != null) {
            altitude = positionInfo.altitude.toFloat();
            if (altitude > 10000) {
                altitude = -500;
            }
            altString = Lang.format("$1$", [altitude.format("%d")]);
        }
        
        if (altitudeIcon != null && altitude > 1) {
            var altitudeiconWidth = altitudeIcon.getWidth();
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(altPosX, altPosY, altFont, altString, Gfx.TEXT_JUSTIFY_RIGHT);
            
            var altIconXPos = altPosX + altitudeiconWidth / 2;
            var altIconYPos = altPosY - 5;
            dc.drawBitmap(altIconXPos, altIconYPos, altitudeIcon);
        }
    }

    function showDate(dc, posX, posY) as Void {
        //var app = App.getApp() as App.AppBase; as forunner265_01App;
        var app = App.getApp() as forunner265_01App;

        var dateFont = Gfx.FONT_XTINY;
        var dateString = "";

        if (app != null && app has :getDateData) {
            app.formatCurrentDate();
            dateString = (app as forunner265_01App).getDateData();
        }

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var optionCoucherSoleil = {
            :year   => today.year,
            :month  => today.month,
            :day    => today.day,
            :hour   => today.hour, 
            :minute => today.min,
            :dayOfWeek => today.day_of_week
        };

        switch (optionCoucherSoleil[:dayOfWeek]) {
            case "Mon": optionCoucherSoleil[:dayOfWeek] = "Lun"; break;
            case "Tue": optionCoucherSoleil[:dayOfWeek] = "Mar"; break;
            case "Wed": optionCoucherSoleil[:dayOfWeek] = "Mer"; break;
            case "Thu": optionCoucherSoleil[:dayOfWeek] = "Jeu"; break;
            case "Fri": optionCoucherSoleil[:dayOfWeek] = "Ven"; break;
            case "Sat": optionCoucherSoleil[:dayOfWeek] = "Sam"; break;
            case "Sun": optionCoucherSoleil[:dayOfWeek] = "Dim"; break;
        }

        dateString = optionCoucherSoleil[:dayOfWeek] + " " + dateString;
        
        if (dateLabel != null) {
            dc.setColor(Green_color, Gfx.COLOR_TRANSPARENT); 
            dc.drawText(posX, posY, dateFont, dateString, Gfx.TEXT_JUSTIFY_RIGHT);
            dateLabel.draw(dc);
        }
    }

    function showVilleSynchro(dc, x, y, ville) as Void {
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, y, Gfx.FONT_XTINY, ville, Gfx.TEXT_JUSTIFY_RIGHT);
        if (dateLabel != null) {
            dateLabel.draw(dc);
        }
    }

    function recupVilleGPS() {
        var positionInfo = Position.getInfo();
        if (positionInfo != null && positionInfo.position != null) {
            var lat = positionInfo.position.toDegrees()[0];
            var lon = positionInfo.position.toDegrees()[1];
            requestCityName(lat, lon);
        }
    }

    function requestCityName(lat, lon) {
        var url = "https://nominatim.openstreetmap.org/reverse";
        var params = {
            "format" => "jsonv2",
            "lat" => lat.toString(),
            "lon" => lon.toString(),
            "zoom" => 10,
            "accept-language" => "fr"
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        Communications.makeWebRequest(url, params, options, method(:onReceiveCity));
    }

    function onReceiveCity(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        if (responseCode == 200 && data != null && data instanceof Lang.Dictionary) {
            var address = data.get("address") as Lang.Dictionary;
            if (address != null) {
                var cityName = address.get("town") as Lang.String;
                if (cityName == null) { cityName = address.get("municipality") as Lang.String; }
                if (cityName == null) { cityName = address.get("village") as Lang.String; }
                
                if (cityName != null) {
                    Toybox.Application.Storage.setValue("savedCity", cityName);
                }
            }
        }
    }

    function showTemperatureGraphDrawNowLine2(dc, x, y) {
        var width = dc.getWidth();
        var xStart = 69;
        var xEnd = width - 40;
        var graphWidth = xEnd - xStart - 29;

        if (lastSync == null) { return; }

        var options = {
            :year   => lastSync.year,
            :month  => lastSync.month,
            :day    => lastSync.day,
            :hour   => lastSync.hour,
            :minute => lastSync.min
        };
        var lastSyncMoment = Gregorian.moment(options);
        if (lastSyncMoment != null) {
            var now = Time.now();
            var secondsSinceSync = now.value() - lastSyncMoment.value();
            var totalGraphSeconds = 86400; 
            
            if (secondsSinceSync >= 0 && secondsSinceSync <= totalGraphSeconds) {
                var decalage = (secondsSinceSync.toFloat() / totalGraphSeconds * graphWidth);
                var xNow = xStart + decalage;
                
                dc.setPenWidth(2); 
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                for (var tempY = y + 32; tempY < y + 140; tempY += 10) {
                    dc.drawLine(xNow, tempY, xNow, tempY + 4);
                }
                dc.setPenWidth(1); 
            }
        }
    } 

    function showTemperatureGraph(dc, posX, posY) as Void {
        var newClock = Sys.getClockTime();
        var newValueClock = 0;
        var differenceHour = 0;
        var hourlyForecast = null;
        
        if (lastClockSync != null) {
            differenceHour = newClock.hour - lastClockSync.hour;
            if (differenceHour < 0) {
                lastClockSync = newClock;
            }
        }
        
        differenceHour = 9; 
        if (differenceHour > 7 || lastSync == null) { 
            newValueClock = (newClock.hour * 60) + newClock.min;
            hourlyForecast = Toybox.Weather.getHourlyForecast();
            
            var currentConditions = Toybox.Weather.getCurrentConditions();
            var nomVille = (currentConditions != null) ? currentConditions.observationLocationName : null;
            
            lastClockSync = newClock;
            if (hourlyForecast != null && hourlyForecast.size() > 0) {
                testheuresynchro = hourlyForecast[0];
            }
            
            if (nomVille == null) {
                nomVille = "null";
            }
            showVilleSynchro(dc, 220, 380, nomVille);
        }

        if (testheuresynchro != null) {
            var forcastTimesynch = testheuresynchro.forecastTime;
            var synch = Time.Gregorian.info(forcastTimesynch, Time.FORMAT_SHORT);
            lastSync = synch;
        }

        if (hourlyForecast != null && hourlyForecast.size() > 0) {
            var maxPoints = 24; 
            
            if (temperatures.size() > 7) { 
                temperatures = [];
                precipitation = [];
            }
            
            for (var i = 0; i < hourlyForecast.size() && i < maxPoints; i++) {
                var forecast = hourlyForecast[i];
                var temp = forecast.temperature; 
                var prec = forecast.precipitationChance;
                
                temperatures.add(temp);
                precipitation.add(prec);
            }
        }
        
        if (precipitation.size() > 1) {
            drawTemperatureGraph2(dc, temperatures, precipitation, posX, posY); 
        }
    }

    function onUpdate(dc as Gfx.Dc) as Void {
        Ui.WatchFace.onUpdate(dc); 
        
        if (background != null) {
            dc.drawBitmap(0, 0, background); 
        }
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        var timeYpos = (height / 2) - 45;
        
        var graphHeight = height / 3; 
        var graphYStart = height - graphHeight - 65; 
        var graphXStart = width / 6; 
        
        var now = Sys.getClockTime();
        var hours = now.hour;
        var min = now.min;
        var sec = now.sec;
        
        showTemperatureGraph(dc, graphXStart, graphYStart);
        showPas(dc, (width / 2), (timeYpos + (Gfx.getFontHeight(Gfx.FONT_NUMBER_HOT) / 2) - 10));
        drawPercentTicksStep(dc);
        showHR(dc, width / 2 + width / 4 + 40, height / 2 - height / 4 + 20);
        showBattery(dc, width / 2, (height / 4));
        showAltitude(dc, (width / 2) + width / 4 + 35, height / 2 - (height / 4) + 30 + Gfx.getFontHeight(Gfx.FONT_XTINY));
        showTemperature(dc, (width / 2) - 50, 80);
        showCoucheSoleil(dc, (width / 2 + 75), 80);
        showDate(dc, width / 2 + 70, (height / 5) - 30);
        
        if (timeFont == null) {
            timeFont = Gfx.FONT_NUMBER_HOT;
        }

        var timeString = Lang.format(
            "$1$:$2$",
            [
                hours.format("%d"),
                min.format("%02d")
            ]
        );
        timeFont = Gfx.FONT_NUMBER_HOT;
        
        var timeXpos = width / 2 + 105;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        dc.drawText(
            timeXpos, 
            timeYpos,      
            timeFont,
            timeString,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER
        );       
    }
}