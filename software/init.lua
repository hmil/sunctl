
-- TODO: 
-- - Initialize ADC
-- - Wait for wifi before running the main function
-- - main function:
--   - Initialize ntp and mqtt
--   - Then, when we have a time, make an adc reading
--   - Print the reading to the console and send it via MQTT
--   - Put the module in deepsleep

dofile('env.lua')

ONE_SECOND_MS = 1000
SLEEP_TIME= 2 * 60 * ONE_SECOND_MS -- Two minutes
RELAY_GPIO=1 -- GPIO5
CONNECT_TMR=0
PROCESS_TMR=1
CONFIG_FILE="config.json"

config = {}
config["manual"] = false
config["auto"] = true
config["light_max"] = 800
config["light_min"] = 200

last_light_intensity=1024
current_pin_state=gpio.LOW

if file.open(CONFIG_FILE, "r") then
    local data = file.read()
    file.close()
    local decoded = sjson.decode(data)
end

write_config = function() 
    if file.open(CONFIG_FILE, "w+") then
        file.write(sjson.encode(config))
        file.close()
    end
end

-- Initialize GPIO
gpio.mode(RELAY_GPIO, gpio.OUTPUT)

-- Initialize the ADC input
if adc.force_init_mode(adc.INIT_ADC)
then
    node.restart()
    return
end

-- Initialize the wifi with enduser setup
enduser_setup.start()

-- Listen for connect event
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
    T.netmask.."\n\tGateway IP: "..T.gateway)
    do_task()
end)

started = false
do_task = function()
    local has_sync = false
    local client = nil

    if started == true then
        return
    end
    started = true

    send_status = function()
        local payload = {}
        payload.config = config
        payload.state = current_pin_state
        payload.light = last_light_intensity
        client:publish("/sunctl/status", sjson.encode(payload), 2, 1, function(client)
            print("Status sent")
        end)
    end

    refresh_light = function()
        if config.auto == true then
            if last_light_intensity < config.light_max and last_light_intensity > config.light_min then
                current_pin_state = gpio.HIGH
            else
                current_pin_state = gpio.LOW
            end
        else
            if config.manual == true then
                current_pin_state = gpio.HIGH
            else
                current_pin_state = gpio.LOW
            end
        end
        gpio.write(RELAY_GPIO, current_pin_state)
        send_status()
    end

    process = function()
        if has_sync == true and client ~= nil then
            local time = rtctime.get()
            local light = 1024 - adc.read(0)
            last_light_intensity = light
            refresh_light()
            local payload = {}
            payload.epoch = time
            payload.intensity = light
            tmr.alarm(PROCESS_TMR, SLEEP_TIME, tmr.ALARM_SINGLE, process)
            client:publish("/sunctl/data", sjson.encode(payload), 2, 0)
        end
    end

    -- Initialize mqtt
    m = mqtt.Client("sunctl", 60, MQTT_USER, MQTT_PASSWORD)
    local connect = function()
        m:connect(MQTT_HOST, MQTT_PORT, MQTT_SECURE, function(cl)
            print('Success connecting to MQTT server')
            cl:subscribe("/sunctl/commands", 2, function(c2)
                print("Subscribed to MQTT channel")
                client = cl
                process()
            end)
        end,
        function(c2, reason)
            print('Mqtt failed, reason: ' .. reason)
            tmr.alarm(CONNECT_TMR, 10 * 1000, tmr.ALARM_SINGLE, connect)
        end)
    end
    connect()

    -- Sync the time once
    local sync_time = function()
        sntp.sync(nil, function()
            print('Success getting time')
            has_sync = true
            process()
        end, true)
    end
    sync_time()

    m:on("message", function(client, topic, data) 
        print(topic .. ":") 
        if data ~= nil then
            print(data)
        end
    
        decoded = sjson.decode(data)
    
        local config_changed = false
        if decoded.auto ~= nil then
            config.auto = decoded.auto
            config_changed = true
        end
        if decoded.manual ~= nil then
            config.manual = decoded.manual
            config_changed = true
        end
        if decoded.light_min ~= nil then
            config.light_min = decoded.light_min
            config_changed = true
        end
        if decoded.light_max ~= nil then
            config.light_max = decoded.light_max
            config_changed = true
        end
    
        if config_changed == true then
            write_config()
            refresh_light()
        end
    end)

    m:on("offline", function(client)
        client = nil
        print ("offline")
        tmr.alarm(CONNECT_TMR, 10 * 1000, tmr.ALARM_SINGLE, connect)
    end)
end

