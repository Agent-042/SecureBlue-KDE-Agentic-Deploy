// Fallback hardened preferences for Firefox when Mullvad Browser is unavailable.
// To use: copy this file into the target Firefox profile directory as user.js
// before first launch.

// Isolate certificate store from the host / enterprise CA bundle.
user_pref("security.enterprise_roots.enabled", false);
user_pref("security.osclientcerts.autoload", false);

// Disable telemetry and studies.
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("app.shield.optoutstudies.enabled", false);

// Hardened DNS: use Mullvad DNS-over-HTTPS.
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://dns.mullvad.net/dns-query");

// Disable password manager in favor of KeePassXC.
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);

// Disable geolocation and WebRTC leak vectors.
user_pref("geo.enabled", false);
user_pref("media.peerconnection.enabled", false);
