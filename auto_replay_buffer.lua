--[[
    Auto Replay Buffer for OBS Studio
    - Automates replay buffer startup on application launch.
    - Optional post-save restart delay and buffer reset.
    - Delayed stop feature keeps recording active during the restart delay window,
      extending the replay if repeated saves occur, and resets the buffer only after activity ends.
    All features disabled by default.
    Supports runtime localization (English and Russian) matching the OBS interface language.
]]

local obs = obslua

-- Localization dictionary for UI properties, descriptions, and console logs
local translations = {
    ru = {
        description = [[
<h3>Управление буфером повтора</h3>
<p>Скрипт содержит функции:</p>
<ul>
    <li><b>Автозапуск:</b> автоматический запуск буфера повтора при старте OBS Studio.</li>
    <li><b>Задержка перезапуска буфера:</b> опциональная функция перезапуска буфера после сохранения клипа.</li>
    <li><b>Отложенная остановка:</b> не выключает буфер сразу, а продлевает его работу на время задержки. При повторном сохранении старый откат заменяется новым, а таймер продлевается. Перезапуск буфера происходит только после окончания активности.</li>
</ul>
<p><i>Включите нужные функции с помощью галочек в настройках ниже.</i></p>
]],
        autostart_label = "Автозапуск буфера при старте OBS",
        startup_delay_label = "Задержка автозапуска при старте OBS",
        stop_after_save_label = "Задержка перезапуска буфера",
        stop_duration_label = "Время задержки перезапуска",
        delayed_stop_label = "Отложенная остановка",

        log_loaded = "[Auto Replay Buffer] Скрипт загружен. Запуск буфера через %d мс...",
        log_loaded_disabled = "[Auto Replay Buffer] Скрипт загружен. Автозапуск отключен в настройках.",
        log_unloaded = "[Auto Replay Buffer] Скрипт выгружен.",
        log_started = "[Auto Replay Buffer] Буфер обратного повтора успешно запущен.",
        log_already_active = "[Auto Replay Buffer] Буфер обратного повтора уже активен.",
        log_autostart_skipped = "[Auto Replay Buffer] Автозапуск пропущен. Функция отключена.",
        log_autostart_on = "[Auto Replay Buffer] Автозапуск включен пользователем.",
        log_autostart_off = "[Auto Replay Buffer] Автозапуск выключен пользователем.",
        log_saved = "[Auto Replay Buffer] Событие: повтор сохранен на диск: %s",
        log_stopping = "[Auto Replay Buffer] Остановка буфера на %d мс...",
        log_stopped_wait = "[Auto Replay Buffer] Буфер полностью остановлен. Ожидание времени перезапуска...",
        log_stopped_generic = "[Auto Replay Buffer] Буфер повтора остановлен.",
        log_started_manual = "[Auto Replay Buffer] Буфер запущен вручную до истечения таймера остановки.",
        log_ready = "[Auto Replay Buffer] Буфер повтора запущен и готов к работе.",
        log_restarted = "[Auto Replay Buffer] Время остановки истекло: %d сек. Буфер повтора успешно перезапущен.",
        log_stop_disabled = "[Auto Replay Buffer] Задержка перезапуска отключена. Таймер сброшен.",

        log_delayed_waiting = "[Auto Replay Buffer] Повтор сохранен. Буфер продолжает работу. Ожидание %d сек без новых сохранений...",
        log_delayed_extended = "[Auto Replay Buffer] Повторное сохранение! Откат продлен еще на %d сек.",
        log_delayed_timeout = "[Auto Replay Buffer] Окно активности закрыто: %d сек тишины. Сброс буфера...",
        log_delayed_stopped_restarting = "[Auto Replay Buffer] Буфер остановлен для сброса. Перезапуск через 1 сек...",
        log_delayed_restarted = "[Auto Replay Buffer] Буфер повтора успешно очищен и перезапущен.",
    },
    en = {
        description = [[
<h3>Replay Buffer Management</h3>
<p>The script contains features:</p>
<ul>
    <li><b>Auto-start:</b> automatically starts the replay buffer when OBS Studio launches.</li>
    <li><b>Buffer restart delay:</b> optional post-save buffer restart and cooldown feature.</li>
    <li><b>Delayed stop:</b> keeps the buffer running for the duration of the restart delay. When saving again within this window, the previous clip is replaced by the new one, and the timer extends. Buffer resets only after silence.</li>
</ul>
<p><i>Enable the desired features using the checkboxes below.</i></p>
]],
        autostart_label = "Auto-start replay buffer on OBS launch",
        startup_delay_label = "Startup delay on OBS launch",
        stop_after_save_label = "Buffer restart delay",
        stop_duration_label = "Restart delay duration",
        delayed_stop_label = "Delayed stop",

        log_loaded = "[Auto Replay Buffer] Script loaded. Starting buffer in %d ms...",
        log_loaded_disabled = "[Auto Replay Buffer] Script loaded. Auto-start is disabled in settings.",
        log_unloaded = "[Auto Replay Buffer] Script unloaded.",
        log_started = "[Auto Replay Buffer] Replay buffer successfully started.",
        log_already_active = "[Auto Replay Buffer] Replay buffer is already active.",
        log_autostart_skipped = "[Auto Replay Buffer] Auto-start skipped. Feature disabled.",
        log_autostart_on = "[Auto Replay Buffer] Auto-start enabled by user.",
        log_autostart_off = "[Auto Replay Buffer] Auto-start disabled by user.",
        log_saved = "[Auto Replay Buffer] Event: replay clip saved to disk: %s",
        log_stopping = "[Auto Replay Buffer] Stopping buffer for %d ms...",
        log_stopped_wait = "[Auto Replay Buffer] Buffer completely stopped. Waiting for restart time...",
        log_stopped_generic = "[Auto Replay Buffer] Replay buffer stopped.",
        log_started_manual = "[Auto Replay Buffer] Buffer started manually before cooldown expired.",
        log_ready = "[Auto Replay Buffer] Replay buffer running and ready.",
        log_restarted = "[Auto Replay Buffer] Stop duration expired: %d sec. Replay buffer successfully restarted.",
        log_stop_disabled = "[Auto Replay Buffer] Restart delay disabled. Cooldown timer cancelled.",

        log_delayed_waiting = "[Auto Replay Buffer] Replay saved. Buffer remains active. Waiting %d sec without new saves...",
        log_delayed_extended = "[Auto Replay Buffer] Repeated save! Replay extended for another %d sec.",
        log_delayed_timeout = "[Auto Replay Buffer] Activity window closed: %d sec of silence. Resetting buffer...",
        log_delayed_stopped_restarting = "[Auto Replay Buffer] Buffer stopped for reset. Restarting in 1 sec...",
        log_delayed_restarted = "[Auto Replay Buffer] Replay buffer successfully flushed and restarted.",
    }
}

-- Detect active OBS Studio interface language
local function get_lang()
    if obs and obs.obs_get_locale then
        local loc = obs.obs_get_locale()
        if loc and string.sub(string.lower(loc), 1, 2) == "ru" then
            return "ru"
        end
    end
    return "en"
end

-- Retrieve localized string by key with fallback to English
local function tr(key)
    local lang = get_lang()
    local dict = translations[lang] or translations["en"]
    return dict[key] or translations["en"][key] or key
end

-- Default configuration parameters (all actions disabled by default)
local autostart_enabled = false
local startup_delay_ms = 1500
local stop_after_save = false
local delayed_stop_enabled = false
local stop_duration_ms = 30000

-- Internal script state variables
local is_loaded = false
local is_cooling_down = false
local is_waiting_for_silence = false
local is_restarting_after_delayed = false
local last_saved_replay_path = nil

-- Returns HTML script description for the OBS Scripts interface
function script_description()
    return tr("description")
end

-- Silently deletes a file from disk
local function delete_file(filepath)
    if not filepath or filepath == "" then return false end
    local success = os.remove(filepath)
    if not success then
        local win_path = string.gsub(filepath, "/", "\\")
        os.remove(win_path)
    end
end

-- Starts the replay buffer if not currently active
local function start_replay_buffer()
    if not obs.obs_frontend_replay_buffer_active() then
        obs.obs_frontend_replay_buffer_start()
        print(tr("log_started"))
    else
        print(tr("log_already_active"))
    end
end

-- One-shot timer callback triggered on application startup
local function on_startup_timer()
    obs.remove_current_callback()
    if autostart_enabled then
        start_replay_buffer()
    else
        print(tr("log_autostart_skipped"))
    end
end

-- Timer callback for classic mode: restarts the buffer after cooldown
local function on_cooldown_finished()
    obs.remove_current_callback()
    is_cooling_down = false

    if not obs.obs_frontend_replay_buffer_active() then
        obs.obs_frontend_replay_buffer_start()
        print(string.format(tr("log_restarted"), math.floor(stop_duration_ms / 1000)))
    else
        print(tr("log_already_active"))
    end
end

-- Timer callback to quickly restart buffer after flushing in delayed stop mode
local function on_restart_after_delayed_stop()
    obs.remove_current_callback()
    is_restarting_after_delayed = false

    if not obs.obs_frontend_replay_buffer_active() then
        obs.obs_frontend_replay_buffer_start()
        print(tr("log_delayed_restarted"))
    else
        print(tr("log_already_active"))
    end
end

-- Inactivity timer callback: fires when no new saves occurred during the dynamic window
local function on_delayed_stop_timeout()
    obs.remove_current_callback()
    is_waiting_for_silence = false
    last_saved_replay_path = nil

    print(string.format(tr("log_delayed_timeout"), math.floor(stop_duration_ms / 1000)))
    if obs.obs_frontend_replay_buffer_active() then
        is_restarting_after_delayed = true
        obs.obs_frontend_replay_buffer_stop()
    else
        is_restarting_after_delayed = false
    end
end

-- OBS Studio frontend event listener
local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        local current_replay_path = ""
        if obs.obs_frontend_get_last_replay then
            current_replay_path = obs.obs_frontend_get_last_replay() or ""
        end
        print(string.format(tr("log_saved"), current_replay_path))

        -- Задержка после сохранения работает, только если включена опция
        if stop_after_save then
            if delayed_stop_enabled then
                -- Режим отложенной остановки: буфер не глушится, а продлевается
                local window_sec = math.floor(stop_duration_ms / 1000)

                if is_waiting_for_silence then
                    -- Повторное сохранение в пределах окна: продлеваем откат
                    print(string.format(tr("log_delayed_extended"), window_sec))

                    -- Автоматически оставляем только один актуальный файл
                    if last_saved_replay_path and last_saved_replay_path ~= "" then
                        if current_replay_path ~= "" and current_replay_path ~= last_saved_replay_path then
                            delete_file(last_saved_replay_path)
                        end
                    end
                else
                    -- Первое сохранение в серии
                    print(string.format(tr("log_delayed_waiting"), window_sec))
                end

                -- Запоминаем текущий сохранённый файл
                last_saved_replay_path = current_replay_path
                is_waiting_for_silence = true

                -- Сбрасываем и продлеваем таймер окна активности
                obs.timer_remove(on_delayed_stop_timeout)
                obs.timer_add(on_delayed_stop_timeout, stop_duration_ms)
            else
                -- Классический режим: немедленная остановка буфера на stop_duration_ms
                is_cooling_down = true
                print(string.format(tr("log_stopping"), stop_duration_ms))
                obs.obs_frontend_replay_buffer_stop()

                obs.timer_remove(on_cooldown_finished)
                obs.timer_add(on_cooldown_finished, stop_duration_ms)
            end
        end

    elseif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STOPPED then
        if is_restarting_after_delayed then
            -- Буфер был остановлен по истечении окна активности для сброса памяти
            print(tr("log_delayed_stopped_restarting"))
            obs.timer_remove(on_restart_after_delayed_stop)
            obs.timer_add(on_restart_after_delayed_stop, 1000)
        elseif is_cooling_down then
            print(tr("log_stopped_wait"))
        else
            -- Ручная остановка пользователем или внешним действием
            if is_waiting_for_silence then
                is_waiting_for_silence = false
                last_saved_replay_path = nil
                obs.timer_remove(on_delayed_stop_timeout)
            end
            print(tr("log_stopped_generic"))
        end

    elseif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STARTED then
        if is_cooling_down then
            is_cooling_down = false
            obs.timer_remove(on_cooldown_finished)
            print(tr("log_started_manual"))
        else
            print(tr("log_ready"))
        end
    end
end

-- Callback that enables/disables dependent properties in UI
local function on_property_modified(props, prop, settings)
    local is_enabled = obs.obs_data_get_bool(settings, "stop_after_save")
    local p_duration = obs.obs_properties_get(props, "stop_duration_ms")
    local p_delayed = obs.obs_properties_get(props, "delayed_stop_enabled")

    if p_duration then
        obs.obs_property_set_enabled(p_duration, is_enabled)
    end
    if p_delayed then
        obs.obs_property_set_enabled(p_delayed, is_enabled)
    end
    return true
end

-- Defines custom properties and interactive UI controls in OBS Studio
function script_properties()
    local props = obs.obs_properties_create()

    -- Section: Auto-start on application launch
    obs.obs_properties_add_bool(props, "autostart_enabled", tr("autostart_label"))
    obs.obs_properties_add_int(props, "startup_delay_ms", tr("startup_delay_label"), 0, 10000, 250)

    -- Section: Optional post-save delay, cooldown and extension
    local p_stop = obs.obs_properties_add_bool(props, "stop_after_save", tr("stop_after_save_label"))
    local p_duration = obs.obs_properties_add_int(props, "stop_duration_ms", tr("stop_duration_label"), 0, 300000, 1000)
    local p_delayed = obs.obs_properties_add_bool(props, "delayed_stop_enabled", tr("delayed_stop_label"))

    -- Bind UI modifier callback to stop_after_save
    obs.obs_property_set_modified_callback(p_stop, on_property_modified)

    -- Initialize enabled state depending on whether stop_after_save is active
    obs.obs_property_set_enabled(p_duration, stop_after_save)
    obs.obs_property_set_enabled(p_delayed, stop_after_save)

    return props
end

-- Sets default configuration values in OBS data storage (all false by default)
function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "autostart_enabled", false)
    obs.obs_data_set_default_int(settings, "startup_delay_ms", 1500)
    obs.obs_data_set_default_bool(settings, "stop_after_save", false)
    obs.obs_data_set_default_int(settings, "stop_duration_ms", 30000)
    obs.obs_data_set_default_bool(settings, "delayed_stop_enabled", false)
end

-- Triggered when script settings are updated by user or OBS configuration load
function script_update(settings)
    local prev_autostart = autostart_enabled
    local prev_stop_after_save = stop_after_save
    local prev_delayed_stop = delayed_stop_enabled

    autostart_enabled = obs.obs_data_get_bool(settings, "autostart_enabled")
    stop_after_save = obs.obs_data_get_bool(settings, "stop_after_save")
    delayed_stop_enabled = obs.obs_data_get_bool(settings, "delayed_stop_enabled")

    local custom_startup_delay = obs.obs_data_get_int(settings, "startup_delay_ms")
    if custom_startup_delay and custom_startup_delay >= 0 then
        startup_delay_ms = custom_startup_delay
    end

    local custom_stop_duration = obs.obs_data_get_int(settings, "stop_duration_ms")
    if custom_stop_duration and custom_stop_duration >= 0 then
        stop_duration_ms = custom_stop_duration
    end

    if is_loaded then
        -- Handle runtime toggling of startup state
        if prev_autostart ~= autostart_enabled then
            if autostart_enabled then
                print(tr("log_autostart_on"))
                start_replay_buffer()
            else
                print(tr("log_autostart_off"))
                obs.timer_remove(on_startup_timer)
            end
        end

        -- Handle runtime deactivation of stop/delay feature
        if prev_stop_after_save and not stop_after_save then
            if is_cooling_down then
                is_cooling_down = false
                obs.timer_remove(on_cooldown_finished)
            end
            if is_waiting_for_silence then
                is_waiting_for_silence = false
                last_saved_replay_path = nil
                obs.timer_remove(on_delayed_stop_timeout)
            end
            print(tr("log_stop_disabled"))
        end

        -- Handle runtime deactivation of delayed stop
        if prev_delayed_stop and not delayed_stop_enabled and is_waiting_for_silence then
            is_waiting_for_silence = false
            last_saved_replay_path = nil
            obs.timer_remove(on_delayed_stop_timeout)
        end
    end
end

-- Triggered by OBS Studio when the script is loaded or reloaded
function script_load(settings)
    autostart_enabled = obs.obs_data_get_bool(settings, "autostart_enabled")
    stop_after_save = obs.obs_data_get_bool(settings, "stop_after_save")
    delayed_stop_enabled = obs.obs_data_get_bool(settings, "delayed_stop_enabled")

    local custom_startup_delay = obs.obs_data_get_int(settings, "startup_delay_ms")
    if custom_startup_delay and custom_startup_delay >= 0 then
        startup_delay_ms = custom_startup_delay
    end

    local custom_stop_duration = obs.obs_data_get_int(settings, "stop_duration_ms")
    if custom_stop_duration and custom_stop_duration >= 0 then
        stop_duration_ms = custom_stop_duration
    end

    is_loaded = true

    -- Register frontend event listener
    obs.obs_frontend_add_event_callback(on_frontend_event)

    if autostart_enabled then
        print(string.format(tr("log_loaded"), startup_delay_ms))
        obs.timer_add(on_startup_timer, startup_delay_ms)
    else
        print(tr("log_loaded_disabled"))
    end
end

-- Triggered by OBS Studio when the script is unloaded
function script_unload()
    obs.obs_frontend_remove_event_callback(on_frontend_event)
    obs.timer_remove(on_startup_timer)
    obs.timer_remove(on_cooldown_finished)
    obs.timer_remove(on_delayed_stop_timeout)
    obs.timer_remove(on_restart_after_delayed_stop)
    last_saved_replay_path = nil
    print(tr("log_unloaded"))
end
