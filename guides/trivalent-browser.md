Go to script logic:
# See ## Script Logic ## section at the bottom for BlueBuild build integration.

## Human Logic ##
run0 rpm-ostree install -y trivalent trivalent-qt6-ui

run0 systemctl reboot

## Script Logic ##
# File: modules/trivalent-rpm/module.yml
# Adds the SecureBlue hardened Chromium repository and installs Trivalent
type: rpm-ostree
repos:
  - https://repo.secureblue.dev/secureblue.repo
keys:
  - https://repo.secureblue.dev/secureblue.gpg
install:
  - trivalent
  - trivalent-qt6-ui

# File: modules/trivalent-config/module.yml
# Enterprise policy configuration for Trivalent
type: files
files:
  - source: trivalent-config/usr
    destination: /usr

# File: config/files/usr/etc/chromium/policies/managed/trivalent-policies.json
{
  "DefaultCookiesSetting": 4,
  "DefaultJavaScriptSetting": 1,
  "DefaultNotificationsSetting": 2,
  "DefaultGeolocationSetting": 2,
  "DefaultMediaStreamingSetting": 2,
  "ExtensionInstallBlocklist": ["*"],
  "HomepageLocation": "about:blank",
  "RestoreOnStartup": 5,
  "SafeBrowsingEnabled": true,
  "SitePerProcess": true,
  "SSLVersionMin": "tls1.2"
}
