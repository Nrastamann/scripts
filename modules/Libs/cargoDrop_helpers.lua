--Файл со всеми вспомогательными функциями(кроме функций для создания логов и дебагга), используемыми при выполнении скрипта cargoDrop
require("Libs/cargoDrop_logs")

-- MATH_CONSTS
local TIME_IN_ONE_DAY = 86400
local GREENWICH_TO_MSK = 3
-- GCS_Wrapper channels
local ALERT = 1 -- Alert: Action should be taken immediately. Indicates error in non-critical systems.
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