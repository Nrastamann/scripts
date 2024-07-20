-- Скрипт для ручного сброса груза и записи параметров в момент сброса, с возможностью записать параметры в момент сброса в txt файл на sd карте
-- Также есть возможность снять показания о положении в месте падения груза в этот же txt файл, с другой пометкой
-- После отладки и получения нужных данных, планируетя создание автоматического сброса
require("Libs/cargoDrop_helpers")

local INFO = 6 -- Info: Normal operational messages. Useful for logging. No action is required for these messages.

GCS_Wrapper(INFO, "Script - cargoDrop is enabled")
-- Input consts
local SERVO_FUNCTIONS_1 = 94
local SERVO_FUNCTIONS_2 = 95
local RC_FUNCTIONS = 300
local RC_FUNCTIONS_LAND = 301

-- Фазы для контроля сброса
local currentPhase = 0
local CARGO_HOLD = 0
local CARGO_STARTING = 1
local CARGO_DROPPED = 2
local CARGO_END = 3
local LAND_CHECK = 0
-- Каналы для сервомоторов и радиоканал для начала сброса
local CHAN_1, CHAN_2, RC_INPUT = Setup(RC_FUNCTIONS, SERVO_FUNCTIONS_1, SERVO_FUNCTIONS_2)
local RC_INPUT_LAND = Setup_LAND(RC_FUNCTIONS_LAND)

--Таймеры для контроля сброса
local timer = 0
local systimer = 0

-- Время для логов
local timerGPS1 = GPStime_wrapper(0)
local timerGPS2 = millis()

function update()
    systimer = get_time()
    -- Проверка нажатия кнопки
    local swtch_pos = RC_INPUT:get_aux_switch_pos()
    local swtch_pos_LAND = RC_INPUT_LAND:get_aux_switch_pos()

    if (swtch_pos > 0 and currentPhase ~= CARGO_END) then
        if ((currentPhase == CARGO_HOLD)) then
            currentPhase = CARGO_STARTING
            GCS_Wrapper(INFO, "cargo started")
        elseif (currentPhase == CARGO_STARTING) then
            timer = get_time()
            currentPhase = CARGO_DROPPED

            -- Раскрываем отсек под сброс
            SRV_Channels:set_output_pwm_chan(CHAN_1, 2000)
            SRV_Channels:set_output_pwm_chan(CHAN_2, 2000)

            -- Записываем все нужные параметры для логов
            local GPS_Millis = timerGPS2 - millis()
            timerGPS2 = millis()
            -- Вызываем функцию для записи логов
            logging_wrapper(timerGPS1, GPS_Millis, 0)
            GCS_Wrapper(INFO, "Cargo dropped")
        elseif ((currentPhase == CARGO_DROPPED) and ((systimer - timer) >= 5.0)) then
            -- Закрываем отсек под сброс
            SRV_Channels:set_output_pwm_chan(CHAN_1, 1100)
            SRV_Channels:set_output_pwm_chan(CHAN_2, 1100)

            currentPhase = CARGO_END;
            GCS_Wrapper(INFO, "Servo's are done")
        end
    end
    -- запись логов на "земле"
    if (swtch_pos_LAND > 0 and LAND_CHECK == 0) then
        LAND_CHECK = 1
        -- Вызываем функцию для записи логов
        logging_wrapper(GPStime_wrapper(0), uint32_t(0), 1)
        GCS_Wrapper(INFO, "Cargo position is written")
    end
    return update, 20 -- 50 Hz
end

return update()