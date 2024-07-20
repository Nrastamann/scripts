--Файл с функциями для создания логов и дебагга, используемыми при выполнении скрипта cargoDrop

-- INPUT_CONSTS
local FILE_NAME = "position.txt"
local FILE_NAME_CSV = "position.csv"
-- MATH_CONSTS
local RAD_TO_DEG = 180 / math.pi
local MULTIPLIER_LAT_LNG = 10 ^ 7
local CM_TO_M = 0.01
-- GCS_Wrapper channels
local ERROR = 3 -- Error: Indicates an error in secondary/redundant systems.
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
    logging_csv(DATE, mil, crnt_location, home_location, yaw, pitch, AS, GPS_GS, Land_or_sky)
end

-- Запись логов в position.txt на sd карте
function logging(DATE, TIME_MS, POS, POS_HOME, YAW, PITCH, AIR_SPEED, GROUND_SPEED, SKY_OR_LAND)
    -- открываем файл и проверяем, нет ли ошибок
    local file = io.open(FILE_NAME, "a")
    if not (file) then
        while (not (io.open(FILE_NAME, "a"))) do
            GCS_Wrapper(ERROR, "file does not open")
        end
    end

    -- 2 Варианта: аппарат сбросил груз в воздухе или мы проверяем позицию груза в месте падения 
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

-- Запись логов в position.csv на sd карте
function logging_csv(DATE, TIME_MS, POS, POS_HOME, YAW, PITCH, AIR_SPEED, GROUND_SPEED, SKY_OR_LAND)
    -- открываем файл и проверяем, нет ли ошибок
    local file = io.open(FILE_NAME_CSV, "a")
    if not (file) then
        while (not (io.open(FILE_NAME_CSV, "a"))) do
            GCS_Wrapper(ERROR, "file does not open")
        end
    end
    
    -- обновить время с GPS для записи в логи
    updateDate(DATE, TIME_MS)
    local time = DATE.Day .. ":" .. DATE.Month .. ":" .. DATE.Year .. " " .. DATE.Hour .. ":" .. DATE.Minute .. ":" .. DATE.Second .. ":" .. DATE.MS .. ";"
    infoCheck(file, DATE, time)

    -- 2 Варианта: аппарат сбросил груз в воздухе или мы проверяем позицию груза в месте падения 
    if (SKY_OR_LAND == 0) then
        file:write("SKY;")
    else
        file:write("LAND;")
    end

    infoCheck(file, POS, POS:lat() / MULTIPLIER_LAT_LNG .. ";")

    infoCheck(file, POS, POS:lng() / MULTIPLIER_LAT_LNG .. ";")

    if (POS_HOME) then
        infoCheck(file, POS, (POS:alt() - POS_HOME:alt()) * CM_TO_M .. ";")
    end

    infoCheck(file, YAW, YAW * RAD_TO_DEG .. ";")

    infoCheck(file, PITCH, PITCH * RAD_TO_DEG .. ";")

    infoCheck(file, AIR_SPEED, AIR_SPEED .. ";")

    infoCheck(file, GROUND_SPEED, GROUND_SPEED .. "\n")
end
