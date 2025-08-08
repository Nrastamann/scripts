-- Скрипт для ручного сброса груза и записи параметров в момент сброса, с возможностью записать параметры в момент сброса в txt файл на sd карте
-- Также есть возможность снять показания о положении в месте падения груза в этот же txt файл, с другой пометкой
-- После отладки и получения нужных данных, планируетя создание автоматического сброса
require("Libs/cargoDrop_helpers")

local INFO = 6 -- Info: Normal operational messages. Useful for logging. No action is required for these messages.

GCS_Wrapper(INFO, "Script - cargoDrop is enabled")

-- Input consts
local RC_FUNCTIONS = 300
local RC_FUNCTIONS_DROP = 302
local RC_FUNCTIONS_LAND = 301
local COMMAND_ID_SCRIPT = 228 --need to set it in waypoint

--DROP CONSTS
local GRAVITY_CONST = 9.81
local DISTANCE_OFFSET = 0
local TARGET_ALT = 35
local TARGET_SPD = 22

-- Фазы для контроля сброса
local currentPhase = 0
local CARGO_HOLD = 0
local CARGO_STARTING = 1
local CARGO_DROP = 2
local CARGO_DROPPED = 3
local CARGO_END = 4
local LAND_CHECK = 0
-- Каналы для сервомоторов и радиоканал для начала сброса
local RC_INPUT, RC_CARGO_DROP = Setup(RC_FUNCTIONS, RC_FUNCTIONS_DROP)
local RC_INPUT_LAND = Setup_LAND(RC_FUNCTIONS_LAND)

--Таймеры для контроля сброса
local timer = 0
local systimer = 0

-- Время для логов
local timerGPS1 = GPStime_wrapper(0)
local timerGPS2 = millis()

function Drop_function()
    while (currentPhase ~= CARGO_END) do
        if ((currentPhase == CARGO_HOLD)) then
            currentPhase = CARGO_STARTING
            GCS_Wrapper(INFO, "cargo started")
        elseif (currentPhase == CARGO_STARTING) then
            timer = get_time()

            currentPhase = CARGO_DROP

            -- Раскрываем отсек под сброс
            RC_INPUT:set_override(2000)

            GCS_Wrapper(INFO, "Cargo started (2nd phase)")
        elseif ((currentPhase == CARGO_DROP) and (systimer - timer >= 1.5)) then
            timer = get_time()

            RC_CARGO_DROP:set_override(2000)
            -- Записываем все нужные параметры для логов
            local GPS_Millis = timerGPS2 - millis()
            timerGPS2 = millis()
            -- Вызываем функцию для записи логов
            logging_wrapper(timerGPS1, GPS_Millis, 0)
            GCS_Wrapper(INFO, "Cargo dropped")

            currentPhase = CARGO_DROPPED;
        elseif ((currentPhase == CARGO_DROPPED) and ((systimer - timer) >= 5.0)) then
            -- Закрываем отсек под сброс
            RC_INPUT:set_override(1100)
            
            currentPhase = CARGO_END;
            GCS_Wrapper(INFO, "Servo's are done")
        end
    end
end

function update()
    systimer = get_time()
    -- Проверка нажатия кнопки
    local switch_state = RC_INPUT:get_aux_switch_pos()
    local switch_state_LAND = RC_INPUT_LAND:get_aux_switch_pos()

    --getting mission
    local next_mission = mission:get_current_nav_id() --maybe need to use smth else, like next mission?

    if (next_mission == COMMAND_ID_SCRIPT and currentPhase == CARGO_HOLD) then
        local speed = ahrs:airspeed_estimate()

        if (not (speed)) then
            speed = TARGET_SPD
            GCS_Wrapper(INFO, "NO SPEED ESTIMATIONS")
        end

        local height = terrain:height_above_tarrain(true)
        if (not (height)) then
            height = TARGET_ALT
            GCS_Wrapper(INFO, "NO HEIGHT ESTIMATIONS")
        end
        local distance = speed * sqrt(2 * height / GRAVITY_CONST) + DISTANCE_OFFSET

        local distance_to_wp = vehicle:get_wp_distance_m()


        if (not (distance_to_wp)) then
            GCS_Wrapper(INFO, "NO DISTANCE, FIX")
            return update, 50
        end

        if (distance_to_wp <= distance) then
            Drop_function()
        end
        --need to add some math
    end

    --Cargo setup, need to add smth to calculate and control position of the vehicle to target point
    if (switch_state > 0 and currentPhase ~= CARGO_END) then
        Drop_function()
    end
    -- запись логов на "земле"
    if (switch_state_LAND > 0 and LAND_CHECK == 0) then
        LAND_CHECK = 1
        -- Вызываем функцию для записи логов
        logging_wrapper(GPStime_wrapper(0), uint32_t(0), 1)
        GCS_Wrapper(INFO, "Cargo position is written")
    end
    return update, 20 -- 50 Hz
end

return update()
