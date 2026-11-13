--[[
    Auto Replay Buffer for OBS Studio
    - Automates replay buffer startup on application launch.
    - Temporarily halts the buffer for 30000 ms following a replay save.
    Supports runtime localization (English and Russian) matching the OBS interface language.
]]

local obs = obslua

-- Localization dictionary for UI properties, descriptions, and console logs
local translations = {
    ru = {
        description = [[
<h3>Управление буфером повтора</h3>
<p>Скрипт содержит независимые функции:</p>
<ul>
    <li><b>Автозапуск:</b> автоматический запуск буфера повтора при старте OBS Studio.</li>
    <li><b>Остановка после сохранения:</b> полная остановка буфера на <b>30 000 мс</b> после сохранения клипа с последующим автоматическим перезапуском.</li>
</ul>
<p><i>Включите нужные функции с помощью галочек в настройках ниже.</i></p>
]],
        autostart_label = "Автозапуск буфера при старте OBS",
        startup_delay_label = "Задержка автозапуска при старте OBS (мс)",
        stop_after_save_label = "Останавливать буфер после сохранения повтора",
        stop_duration_label = "Время остановки перед перезапуском (мс)",

        log_loaded = "[Auto Replay Buffer] Скрипт загружен. Запуск буфера через %d мс...",
        log_loaded_disabled = "[Auto Replay Buffer] Скрипт загружен (автозапуск отключен в настройках).",
        log_unloaded = "[Auto Replay Buffer] Скрипт выгружен.",
        log_started = "[Auto Replay Buffer] Буфер обратного повтора успешно запущен.",
        log_already_active = "[Auto Replay Buffer] Буфер обратного повтора уже активен.",
        log_autostart_skipped = "[Auto Replay Buffer] Автозапуск пропущен (функция отключена).",
        log_autostart_on = "[Auto Replay Buffer] Автозапуск включен пользователем.",
        log_autostart_off = "[Auto Replay Buffer] Автозапуск выключен пользователем.",
        log_saved = "[Auto Replay Buffer] Событие: повтор сохранен на диск.",
        log_stopping = "[Auto Replay Buffer] Остановка буфера на %d мс...",
        log_stopped_wait = "[Auto Replay Buffer] Буфер полностью остановлен. Ожидание времени перезапуска...",
        log_stopped_generic = "[Auto Replay Buffer] Буфер повтора остановлен.",
        log_started_manual = "[Auto Replay Buffer] Буфер запущен вручную до истечения таймера остановки.",
        log_ready = "[Auto Replay Buffer] Буфер повтора запущен и готов к работе.",
        log_restarted = "[Auto Replay Buffer] Время остановки истекло (%d сек). Буфер повтора успешно перезапущен.",
        log_stop_disabled = "[Auto Replay Buffer] Остановка после сохранения отключена. Таймер сброшен.",
    },
    en = {
        description = [[
<h3>Replay Buffer Management</h3>
<p>The script contains independent features:</p>
<ul>
    <li><b>Auto-start:</b> automatically starts the replay buffer when OBS Studio launches.</li>
    <li><b>Stop after save:</b> completely stops the buffer for <b>30 000 ms</b> after saving a clip, then automatically restarts it.</li>
</ul>
<p><i>Enable the desired features using the checkboxes below.</i></p>
]],
        autostart_label = "Auto-start replay buffer on OBS launch",
        startup_delay_label = "Startup delay on OBS launch (ms)",
        stop_after_save_label = "Stop buffer after saving replay",
        stop_duration_label = "Stop duration before restart (ms)",

        log_loaded = "[Auto Replay Buffer] Script loaded. Starting buffer in %d ms...",
        log_loaded_disabled = "[Auto Replay Buffer] Script loaded (auto-start is disabled in settings).",
        log_unloaded = "[Auto Replay Buffer] Script unloaded.",
        log_started = "[Auto Replay Buffer] Replay buffer successfully started.",
        log_already_active = "[Auto Replay Buffer] Replay buffer is already active.",
        log_autostart_skipped = "[Auto Replay Buffer] Auto-start skipped (feature disabled).",
        log_autostart_on = "[Auto Replay Buffer] Auto-start enabled by user.",
        log_autostart_off = "[Auto Replay Buffer] Auto-start disabled by user.",
        log_saved = "[Auto Replay Buffer] Event: replay clip saved to disk.",
        log_stopping = "[Auto Replay Buffer] Stopping buffer for %d ms...",
        log_stopped_wait = "[Auto Replay Buffer] Buffer completely stopped. Waiting for restart time...",
        log_stopped_generic = "[Auto Replay Buffer] Replay buffer stopped.",
        log_started_manual = "[Auto Replay Buffer] Buffer started manually before cooldown expired.",
        log_ready = "[Auto Replay Buffer] Replay buffer running and ready.",
        log_restarted = "[Auto Replay Buffer] Stop duration expired (%d sec). Replay buffer successfully restarted.",
        log_stop_disabled = "[Auto Replay Buffer] Stop after save disabled. Cooldown timer cancelled.",
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
local stop_duration_ms = 30000

-- Internal script state variables
local is_loaded = false
local is_cooling_down = false

-- Returns HTML script description for the OBS Scripts interface
function script_description()
    return tr("description")
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

-- Cooldown timer callback that restarts the replay buffer after the pause interval
local function on_cooldown_finished()
    obs.remove_current_callback()
    is_cooling_down = false

    if stop_after_save then
        if not obs.obs_frontend_replay_buffer_active() then
            obs.obs_frontend_replay_buffer_start()
            print(string.format(tr("log_restarted"), math.floor(stop_duration_ms / 1000)))
        else
            print(tr("log_already_active"))
        end
    end
end

-- OBS Studio frontend event listener
local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        print(tr("log_saved"))

        if stop_after_save then
            is_cooling_down = true
            print(string.format(tr("log_stopping"), stop_duration_ms))

            -- Stop the replay buffer immediately
            obs.obs_frontend_replay_buffer_stop()

            -- Schedule the automatic reactivation timer
            obs.timer_remove(on_cooldown_finished)
            obs.timer_add(on_cooldown_finished, stop_duration_ms)
        end

    elseif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STOPPED then
        if is_cooling_down then
            print(tr("log_stopped_wait"))
        else
            print(tr("log_stopped_generic"))
        end

    elseif event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STARTED then
        if is_cooling_down then
            -- Reset cooldown if user manually initiates the replay buffer early
            is_cooling_down = false
            obs.timer_remove(on_cooldown_finished)
            print(tr("log_started_manual"))
        else
            print(tr("log_ready"))
        end
    end
end

-- Defines custom properties and interactive UI controls in OBS Studio
function script_properties()
    local props = obs.obs_properties_create()

    -- Section: Auto-start on application launch
    obs.obs_properties_add_bool(props, "autostart_enabled", tr("autostart_label"))
    obs.obs_properties_add_int(props, "startup_delay_ms", tr("startup_delay_label"), 500, 10000, 250)

    -- Section: Post-save buffer pause and cooldown
    obs.obs_properties_add_bool(props, "stop_after_save", tr("stop_after_save_label"))
    obs.obs_properties_add_int(props, "stop_duration_ms", tr("stop_duration_label"), 1000, 300000, 1000)

    return props
end

-- Sets default configuration values in OBS data storage
function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "autostart_enabled", false)
    obs.obs_data_set_default_int(settings, "startup_delay_ms", 1500)
    obs.obs_data_set_default_bool(settings, "stop_after_save", false)
    obs.obs_data_set_default_int(settings, "stop_duration_ms", 30000)
end

-- Triggered when script settings are updated by user or OBS configuration load
function script_update(settings)
    local prev_autostart = autostart_enabled
    local prev_stop_after_save = stop_after_save

    autostart_enabled = obs.obs_data_get_bool(settings, "autostart_enabled")
    stop_after_save = obs.obs_data_get_bool(settings, "stop_after_save")

    local custom_startup_delay = obs.obs_data_get_int(settings, "startup_delay_ms")
    if custom_startup_delay and custom_startup_delay > 0 then
        startup_delay_ms = custom_startup_delay
    end

    local custom_stop_duration = obs.obs_data_get_int(settings, "stop_duration_ms")
    if custom_stop_duration and custom_stop_duration > 0 then
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

        -- Handle runtime deactivation of cooldown feature
        if prev_stop_after_save and not stop_after_save and is_cooling_down then
            is_cooling_down = false
            obs.timer_remove(on_cooldown_finished)
            print(tr("log_stop_disabled"))
        end
    end
end

-- Triggered by OBS Studio when the script is loaded or reloaded
function script_load(settings)
    autostart_enabled = obs.obs_data_get_bool(settings, "autostart_enabled")
    stop_after_save = obs.obs_data_get_bool(settings, "stop_after_save")

    local custom_startup_delay = obs.obs_data_get_int(settings, "startup_delay_ms")
    if custom_startup_delay and custom_startup_delay > 0 then
        startup_delay_ms = custom_startup_delay
    end

    local custom_stop_duration = obs.obs_data_get_int(settings, "stop_duration_ms")
    if custom_stop_duration and custom_stop_duration > 0 then
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
    print(tr("log_unloaded"))
end
