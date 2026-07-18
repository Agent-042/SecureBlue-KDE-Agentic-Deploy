Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 mkdir -p /usr/bin /usr/share/applications /usr/share/doc/research-browser /usr/lib/firefox/distribution

run0 tee /usr/bin/research-browser << 'EOF'
#!/bin/bash
# Launch Firefox in research profile with hardened defaults
exec firefox --profile /tmp/research-profile --no-remote --private-window "$@"
EOF

run0 chmod +x /usr/bin/research-browser

run0 tee /usr/share/applications/research-browser.desktop << 'EOF'
[Desktop Entry]
Name=Research Browser
Comment=Isolated privacy-hardened Firefox for research
Exec=research-browser %u
Type=Application
Terminal=false
Icon=firefox
Categories=Network;WebBrowser;
EOF

## Script Logic ##
# File: modules/privacy-browser-config/module.yml
type: files
files:
  - source: privacy-browser-config/usr
    destination: /usr

# File: config/files/usr/bin/research-browser
#!/bin/bash
exec firefox --profile /tmp/research-profile --no-remote --private-window "$@"

# File: config/files/usr/share/applications/research-browser.desktop
[Desktop Entry]
Name=Research Browser
Comment=Isolated privacy-hardened Firefox for research
Exec=research-browser %u
Type=Application
Terminal=false
Icon=firefox
Categories=Network;WebBrowser;

# File: config/files/usr/lib/firefox/distribution/policies.json
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFirefoxAccounts": true,
    "DisableMasterPasswordCreation": false,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "DNSOverHTTPS": {
      "Enabled": true,
      "ProviderURL": "https://doh.mullvad.net/dns-query"
    }
  }
}

# File: config/files/usr/share/doc/research-browser/firefox-fallback-user.js
// Hardened user.js for research profile
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.newtabpage.enabled", false);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.resistFingerprinting", true);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.sessionstore.resume_from_crash", false);
