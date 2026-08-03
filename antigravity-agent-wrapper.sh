#!/bin/bash
export WAYLAND_DISPLAY=wayland-0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export XDG_RUNTIME_DIR=/run/user/1000
exec /var/home/agent-42/.local/bin/kwin-mcp "$@"
