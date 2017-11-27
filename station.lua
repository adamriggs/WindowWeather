-- *****
-- TEMPURATURE FUNCTIONS
-- *****

function getTemp()
    -- get the temperature data from the sensor
    local pin = 3
    local status, temp, humi, temp_dec, humi_dec = dht.read(pin)
    local o = {}

    o["status"] = status
    o["c"] = temp
    o["f"] = ( temp * 9 / 5 ) + 32
    o["h"] = humi
    o["heatIndex_f"] = calcHeatIndex(o.f, o.h)
    o["heatIndex_c"] = ( o.heatIndex_f - 32 ) / ( 9 / 5 )
    
    return o
end

function calcHeatIndex(Temperature, RelativeHumidity)
    
    local t = Temperature --farenheight 
    local r = RelativeHumidity

    local c1 = -42.38
    local c2 = 2.049
    local c3 = 10.14
    local c4 = -0.2248
    local c5 = -0.006838
    local c6 = -0.05482
    local c7 = 0.001228
    local c8 = 0.0008528
    local c9 = -0.00000199

    -- c1 + c2T + c3R + c4TR + c5T^2 + c6R^2 + c7T^2R + c8TR^2 + c9T^2R^2

    local hI = c1 + (c2 * t) + (c3 * r) + (c4 * t * r) + (c5 * t * t) + (c6 * r * r) + (c7 * t * t * r) + (c8 * t * r *r) + (c9 * t * t * r * r)
    
    return hI
end

-- *****
-- DISPLAY FUNCTIONS
-- *****

function lightOn()
    local pin = 1
    gpio.mode(pin, gpio.OUTPUT)
    gpio.write(pin, gpio.HIGH)
end

function lightOff()
    local pin = 1
    gpio.mode(pin, gpio.OUTPUT)
    gpio.write(pin, gpio.LOW)
end

function displayTemp(Inside, Outside)
    local cs  = 8 -- GPIO15, pull-down 10k to GND
    local dc  = 4 -- GPIO2
    local res = 0 -- GPIO16, RES is optional YMMV
    
    spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8)
    gpio.mode(8, gpio.INPUT, gpio.PULLUP)
    
    local disp = ucg.st7735_18x128x160_hw_spi(cs, dc, res)
    
    disp:begin(ucg.FONT_MODE_TRANSPARENT)
    disp:clearScreen()
    disp:setRotate90()
    
    disp:setFont(ucg.font_ncenR12_tr);
    disp:setColor(255, 255, 255);
    --disp:setColor(1, 255, 0,0);
    
    disp:setPrintPos(0, 45)
    --disp:print(Inside .. " / " .. Outside)

    disp:print("Inside: " .. Inside)

    disp:setPrintPos(0, 70)
    disp:print("Outside: " .. Outside)
    
    --print(disp:getWidth())
    --print(disp:getHeight())
    
    --disp:setColor(255, 153, 0)
    --disp:drawBox(0,50,45,45)
end

-- *****
-- FILE FUNCTIONS
-- *****

function updateWeatherFile()
    http.get("http://api.wunderground.com/api/97d9712197f73c53/conditions/q/CA/San_Francisco.json", nil, function(code, data)
        if (code < 0) then
          print("HTTP request failed")
        else
          print(code, data)
          fd = file.open("weather.json", "w")
          if fd then
            fd:write(data)
            fd:close()
          end
        end
    end)
end

function updateEpochTimeFile()
    http.get("http://www.convert-unix-time.com/api?timestamp=now", nil, function(code, data)
        if (code < 0) then
            print("HTTP request failed")
        else
            print(code, data)
            fd = file.open("epoch.json", "w")
            if fd then
                fd:write(data)
                fd:close()
            end
        end
    end)
end

function getWeatherFileData()
    local fd = file.open("weather.json", "r")
    local js = sjson.decode(fd:read(4096))
    fd:close()

    local w = {}
    w["epoch"] = js.observation_epoch
    w["f"] = js.current_observation.temp_f
    w["c"] = js.current_observation.temp_c

    return w
end

-- *****
-- MAIN LOOP
-- *****

-- while true do 

    -- open file and read
    outside = getWeatherFileData()
    inside = getTemp()

    -- future: check file data point obvservation_epoch to 
    -- determine if a new file needs to be downloaded

    -- assign variables
    outsideTemp = outside.f
    insideTemp = inside.f

    print("insideTemp: ", insideTemp)
    print("outsideTemp: ", outsideTemp)
    --print("inside.heatIndex_f: ", inside.heatIndex_f)

    -- display data
    displayTemp(insideTemp, outsideTemp)

    -- compare data
    if outsideTemp < insideTemp then
        lightOn()
    else 
        lightOff()
    end

-- end
