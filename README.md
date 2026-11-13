# OBS Studio Replay Buffer Automator

A lightweight Lua script for OBS Studio to manage replay buffer startup and post-save cooldown.

Read this in other languages: [Русский](README_RU.md)

## Features
- **Auto-start on launch**: Starts the replay buffer when OBS Studio opens.
- **Post-save cooldown**: Stops the buffer for 30 seconds after saving a replay, then restarts it automatically.
- **Safe manual stop**: Manually stopping the buffer will not trigger an automatic restart.
- **Language support**: Automatically detects OBS interface language (English and Russian).
- **Disabled by default**: All features are disabled initially.

## Installation
1. Enable the replay buffer in OBS: **Settings** → **Output** → **Replay Buffer** → check **Enable Replay Buffer**.
2. In OBS Studio, open **Tools** → **Scripts**.
3. Click **+** and select `auto_replay_buffer.lua`.
4. Enable the desired features in the script settings panel.

## Settings

| Setting | Default | Description |
| :--- | :---: | :--- |
| **Auto-start replay buffer on OBS launch** | Disabled | Starts the buffer when OBS opens |
| **Startup delay on OBS launch (ms)** | 1500 | Delay in milliseconds before starting |
| **Stop buffer after saving replay** | Disabled | Pauses the buffer after saving a clip |
| **Stop duration before restart (ms)** | 30000 | Pause duration in milliseconds before restarting |

## License

MIT
