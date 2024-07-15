--Файл со всеми функциями, используемыми при выполнении скрипта cargoDrop


-- INPUT_CONSTS
local FILE_NAME = "position.txt"
-- MATH_CONSTS
local TIME_IN_ONE_DAY = 86400
local RAD_TO_DEG = 180 / math.pi
local GREENWICH_TO_MSK = 3
local MULTIPLIER_LAT_LNG = 10 ^ 7
local CM_TO_M = 0.01
-- GCS_Wrapper channels
local ALERT = 1 -- Alert: Action should be taken immediately. Indicates error in non-critical systems.
local ERROR = 3 -- Error: Indicates an error in secondary/redundant systems.
local INFO = 6  -- Info: Normal operational messages. Useful for logging. No action is required for these messages.
-- other
local MONTH_DAYS
-- ФУНКЦИИ НАСТРОЙКИ ПРИ ПЕРВОМ ЗАПУСКЕ=======================================================================================================================
-- функция для подключения по RC для записи логов сброшенного груза на земле
function Setup_LAND(RC_FUNCTIONS)
    local RC_INPUT = rc:find_channel_for_option(RC_FUNCTIONS)

    if (not (RC_INPUT)) then
        GCS_Wrapper(ALERT, "no RC connection with servos")
        return Setup_LAND(RC_FUNCTIONS), 500
    end
    GCS_Wrapper(INFO, "RC CONNECTION ESTABLISHED (LAND ONE)")
    return RC_INPUT
end

-- функция для подключения по RC и определения сервомоторов для сброса в воздухе
function Setup(RC_FUNCTIONS, SERVO_FUNCTIONS_1, SERVO_FUNCTIONS_2)
    local RC_INPUT = rc:find_channel_for_option(RC_FUNCTIONS)

    local chan1 = SRV_Channels:find_channel(SERVO_FUNCTIONS_1)
    local chan2 = SRV_Channels:find_channel(SERVO_FUNCTIONS_2)

    if (not (RC_INPUT)) then
        GCS_Wrapper(ALERT, "no RC connection with servos")
        return Setup(RC_FUNCTIONS, SERVO_FUNCTIONS_1, SERVO_FUNCTIONS_2), 500
    end
    GCS_Wrapper(INFO, "RC connection established")

    if (not (chan1)) then
        GCS_Wrapper(ALERT, "Servo's channel1 is not found")
        return Setup(RC_FUNCTIONS, SERVO_FUNCTIONS_1, SERVO_FUNCTIONS_2), 500
    end
    GCS_Wrapper(INFO, "Servo's channel1 is found")

    if (not (chan2)) then
        GCS_Wrapper(ALERT, "Servo's channel2 is not found")
        return Setup(RC_FUNCTIONS, SERVO_FUNCTIONS_1, SERVO_FUNCTIONS_2), 500
    end
    GCS_Wrapper(INFO, "Servo's channel2 is found")

    return chan1, chan2, RC_INPUT
end

-- ФУНКЦИИ ДЛЯ ОПРЕДЕЛЕНИЯ ВРЕМЕНИ============================================================================================================================
-- определение времени по gps(wrapper)
function GPStime_wrapper(instance)
    return GPStime(gps:time_week(instance), gps:time_week_ms(instance))
end

-- определение времени по gps
function GPStime(time_week, time_week_ms)
    local seconds_per_week = uint32_t(TIME_IN_ONE_DAY * 7)
    -- Определеяем timestamp_s как кол-во секунд с января 2001 до текущего времени
    timestamp_s = uint32_t(time_week - 1095) * seconds_per_week
    -- Вычитаем чтобы получить точное время с 1 января 2001 г.
    timestamp_s = timestamp_s - uint32_t(TIME_IN_ONE_DAY + 18)
    -- Добавляем время прошедшее за текущую неделю
    timestamp_s = timestamp_s + (time_week_ms / uint32_t(1000))

    timestamp_s = timestamp_s:toint() -- кол-во секунд с 1 января 2001

    -- получаем текущий год
    local ts_year = 2001
    while true do
        local year_seconds = TIME_IN_ONE_DAY * ((ts_year % 4 == 0) and 366 or 365)
        if timestamp_s >= year_seconds then
            timestamp_s = timestamp_s - year_seconds
            ts_year = ts_year + 1
        else
            break
        end
    end

    -- получаем текущий месяц учитывая високосный ли текущий год
    local ts_month = 1
    MONTH_DAYS = { 31, (ts_year % 4 == 0) and 29 or 28,
        31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    for _, md in ipairs(MONTH_DAYS) do
        local month_seconds = TIME_IN_ONE_DAY * md
        if timestamp_s >= month_seconds then
            timestamp_s = timestamp_s - month_seconds
            ts_month = ts_month + 1
        else
            break
        end
    end

    -- переводим оставшиеся секунды в дни, часы, минуты, секунды и миллисекунды
    local ts_day = 1 + (timestamp_s // TIME_IN_ONE_DAY)
    timestamp_s = timestamp_s % TIME_IN_ONE_DAY

    local ts_hour = timestamp_s // 3600 + GREENWICH_TO_MSK
    timestamp_s = timestamp_s % 3600

    local ts_minute = timestamp_s // 60
    local ts_second = timestamp_s % 60
    -- сохраняем в структуру для будущего использования
    local date = {
        Year = ts_year,
        Month = ts_month,
        Day = ts_day,
        Hour = ts_hour,
        Minute = ts_minute,
        Second = ts_second,
        MS = (time_week_ms % 1000):toint()
    }
    return date
end

function get_time()
    return millis():tofloat() * 0.001
end

-- Обновление времени, полученного по GPS
function updateDate(DATE, TIME_MS)
    local Date_Previous = { DATE.Month, DATE.Year }

    DATE.MS = (DATE.MS + TIME_MS):toint()
    DATE.Second = DATE.Second + DATE.MS // 1000
    DATE.MS = DATE.MS % 1000

    DATE.Minute = DATE.Minute + DATE.Second // 60
    DATE.Second = DATE.Second % 60

    DATE.Hour = DATE.Hour + DATE.Minute // 60
    DATE.Minute = DATE.Minute % 60

    DATE.Day = DATE.Day + DATE.Hour // 24
    DATE.Hour = DATE.Hour % 24

    DATE.Month = DATE.Month + DATE.Day // MONTH_DAYS[Date_Previous[1]]
    if (Date_Previous[1] ~= DATE.Month) then
        DATE.Day = 1
    end
    DATE.Year = DATE.Year + DATE.Month // 12
    if (Date_Previous[2] ~= DATE.Year) then
        DATE.Month = 1
    end
    return DATE
end

-- ФУНКЦИИ ДЛЯ ЛОГОВ И ДЕБАГА=================================================================================================================================
-- Отправка сообщений в GCS (в нашем случае - mission planner) (Wrapper)
function GCS_Wrapper(chan, text)
    local msg = "LUA_CARGO: " .. text
    gcs:send_text(chan, msg)
end

-- Проверка на нулевое значение объекта и запись в файл
function infoCheck(file, obj, text)
    if (obj) then
        file:write(text)
    else
        file:write("NIL VALUE")
        GCS_Wrapper(ERROR, "TRYING TO LOG NIL VALUE")
    end
end

-- Запись логов в position.txt на sd карте(wrapper)
function logging_wrapper(DATE, mil, Land_or_sky)
    local crnt_location = ahrs:get_location()
    local home_location = ahrs:get_home()
    local yaw = ahrs:get_yaw()
    local pitch = ahrs:get_pitch()
    local AS = ahrs:airspeed_estimate()
    local GPS_GS = gps:ground_speed(0)
    logging(DATE, mil, crnt_location, home_location, yaw, pitch, AS, GPS_GS, Land_or_sky)
end

-- Запись логов в position.txt на sd карте
function logging(DATE, TIME_MS, POS, POS_HOME, YAW, PITCH, AIR_SPEED, GROUND_SPEED, SKY_OR_LAND)
    local file = io.open(FILE_NAME, "a")
    if not (file) then
        while (not (io.open(FILE_NAME, "a"))) do
            GCS_Wrapper(ERROR, "file does not open") -- STILL IN WORK, DO OTHER WAY TO LOG
        end
    end
    if (SKY_OR_LAND == 0) then
        file:write("DROPPING POSITION - SKY -----------------------------------------------------------------------\n")
    else
        file:write("DROPPING POSITION - LAND ----------------------------------------------------------------------\n")
    end
    file:write("Time: ")
    -- обновить время с GPS для записи в логи
    updateDate(DATE, TIME_MS)
    local time = DATE.Day .. ":" .. DATE.Month .. ":" .. DATE.Year .. " " .. DATE.Hour .. ":" .. DATE.Minute .. ":" .. DATE.Second .. ":" .. DATE.MS .. "\n"
    infoCheck(file, DATE, time)

    file:write("latitude: ")
    infoCheck(file, POS, POS:lat() / MULTIPLIER_LAT_LNG)

    file:write("\nLongtitude: ")
    infoCheck(file, POS, POS:lng() / MULTIPLIER_LAT_LNG)

    file:write("\nAltitude: ")
    if (POS_HOME) then
        infoCheck(file, POS, (POS:alt() - POS_HOME:alt()) * CM_TO_M)
    end
    file:write("\nYaw: ")
    infoCheck(file, YAW, YAW * RAD_TO_DEG)

    file:write("\nPitch: ")
    infoCheck(file, PITCH, PITCH * RAD_TO_DEG)

    file:write("\nAS: ")
    infoCheck(file, AIR_SPEED, AIR_SPEED)

    file:write("\nGS: ")
    infoCheck(file, GROUND_SPEED, GROUND_SPEED .. "\n")

    file:write("END OF DROPPING POSITION----------------------------------------------------------------\n")
end
