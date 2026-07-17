#!/usr/bin/env bash
# G16 EasyEffects speaker-clarity autostart helper
# Starts the EasyEffects Flatpak service and loads the system-wide
# "G16 Speaker Clarity" output preset at login.

set -euo pipefail

readonly APP_ID="com.github.wwmm.easyeffects"
readonly PRESET="G16 Speaker Clarity"

# Ensure the EasyEffects background service is running.  A single-instance
# GApplication will receive later --load-preset requests on the session bus.
if ! pgrep -af "flatpak run.*${APP_ID}.*--gapplication-service" >/dev/null 2>&1; then
    flatpak run --command=easyeffects "${APP_ID}" --gapplication-service &
    # Allow the service time to register before sending the preset load.
    sleep 3
fi

# Activate the running instance and ask it to load the preset.
flatpak run --command=easyeffects "${APP_ID}" --load-preset "${PRESET}"
