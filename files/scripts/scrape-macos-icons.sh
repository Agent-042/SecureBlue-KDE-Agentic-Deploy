#!/usr/bin/env bash
# scrape-macos-icons.sh
# Build-time script to fetch authentic macOS icons from macosicons.com API
# and patch .desktop files to use them. Runs during BlueBuild image creation.
set -euo pipefail

# API endpoint (requires API key for production use)
API_URL="https://api.macosicons.com/api/v1/search"
ICON_DIR="/usr/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="/usr/local/share/applications"

# Target apps to fetch macOS icons for
# Format: "desktop-file-name:search-query"
declare -a TARGET_APPS=(
    "org.kde.dolphin:Dolphin"
    "org.kde.konsole:Terminal"
    "org.kde.kwrite:TextEdit"
    "systemsettings:System Settings"
    "trivalent:Safari"
    "org.kde.spectacle:Screenshot"
    "org.keepassxc.KeePassXC:KeePassXC"
    "com.yubico.yubioath:Yubico Authenticator"
)

# Note: This scraper requires a macosicons.com API key.
# Without a key, the API returns 403. For now, this script documents
# the intended approach and falls back to WhiteSur icons.
#
# To enable: set API_KEY environment variable in the BlueBuild pipeline.
# Accept the user's requested secret name, but keep backward compatibility
# with the old no-underscore variable name.
API_KEY="${MACOS_ICONS_API_KEY:-${MACOSICONS_API_KEY:-}}"

if [[ -z "$API_KEY" ]]; then
    echo "[scraper] No API key set (MACOS_ICONS_API_KEY or MACOSICONS_API_KEY). Skipping live scrape."
    echo "[scraper] WhiteSur icons will be used as fallback."
    exit 0
fi

mkdir -p "$ICON_DIR" "$DESKTOP_DIR"

fetch_icon() {
    local query="$1"
    local output="$2"
    local attempt=1
    local max_attempts=3
    local delay=2

    while [[ $attempt -le $max_attempts ]]; do
        local response
        response=$(curl -s -X POST "$API_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $API_KEY" \
            -d "{\"query\":\"$query\"}" 2>/dev/null) || true

        if [[ -n "$response" ]]; then
            # Extract the first PNG URL from the response
            local png_url
            png_url=$(echo "$response" | jq -r '.[0].lowResPngUrl // .[0].pngUrl // empty' 2>/dev/null) || true

            if [[ -n "$png_url" && "$png_url" != "null" ]]; then
                if curl -fs -L --retry 3 "$png_url" -o "$output" 2>/dev/null; then
                    echo "[scraper] Downloaded: $output"
                    return 0
                fi
            fi
        fi

        echo "[scraper] Attempt $attempt/$max_attempts failed for: $query"
        if [[ $attempt -lt $max_attempts ]]; then
            sleep "$delay"
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done

    echo "[scraper] Giving up on: $query"
    return 1
}

for app_spec in "${TARGET_APPS[@]}"; do
    IFS=':' read -r desktop_name search_query <<< "$app_spec"
    
    icon_file="${ICON_DIR}/${desktop_name}.png"
    
    if fetch_icon "$search_query" "$icon_file"; then
        # Find the original .desktop file
        src_desktop=""
        for d in /usr/share/applications /var/lib/flatpak/exports/share/applications; do
            if [[ -f "${d}/${desktop_name}.desktop" ]]; then
                src_desktop="${d}/${desktop_name}.desktop"
                break
            fi
        done
        
        if [[ -n "$src_desktop" ]]; then
            # Copy to /usr/local/share/applications/ (higher priority, survives updates)
            cp "$src_desktop" "${DESKTOP_DIR}/${desktop_name}.desktop"
            # Patch the Icon= line
            sed -i "s|^Icon=.*|Icon=${desktop_name}|" "${DESKTOP_DIR}/${desktop_name}.desktop"
            echo "[scraper] Patched: ${desktop_name}.desktop"
        fi
    fi
done

# Rebuild icon cache
gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true

echo "[scraper] Icon scraping complete."
