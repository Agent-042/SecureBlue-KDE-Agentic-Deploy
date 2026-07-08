# Browser Policy

This image ships two enterprise browser profiles plus an isolated privacy browser. Trivalent and Google Chrome are configured with the same enterprise SSO/dark-mode policy goals, but each uses its own managed policy path. Mullvad Browser remains strictly isolated from both.

## Enterprise Browser: Trivalent

Trivalent (hardened enterprise Chromium) is the primary browser for Google Workspace, corporate SSO, and daily productivity.

Policy path managed by the `trivalent-config` module:

```text
/usr/etc/chromium/policies/managed/trivalent-policies.json
```

On the booted image this is available at `/etc/chromium/policies/managed/trivalent-policies.json`.

### Policy highlights

| Policy | Setting | Purpose |
|--------|---------|---------|
| `DefaultCookiesSetting` | Allow | Permit cookies for enterprise web apps |
| `CookiesAllowedForUrls` | `[*.]google.com`, SSO IdP domains | Allow persistent Google/SSO session cookies |
| `AuthServerAllowlist` | `*.google.com`, `*.microsoftonline.com`, `*.okta.com`, `*.onelogin.com` | Whitelist authentication servers for integrated SSO |
| `ForceDarkMode` / `ForceDarkModeEnabled` | Enabled | Force dark mode across all sites |
| `PreferredColorScheme` | Dark (`2`) | Report `prefers-color-scheme: dark` to sites |
| `CloudReportingEnabled` | Enabled | Enterprise telemetry/reporting (if managed) |
| Managed bookmarks | Google Workspace apps | Curated bookmarks bar |

### Certificate handling

Trivalent uses the system NSS certificate store plus any enterprise CAs installed by the `trivalent-config` module. Do **not** import research or personal certificates into this profile.

## Enterprise Browser: Google Chrome

Google Chrome is provided as an additional enterprise browser. It shares the same SSO allowlists, dark-mode enforcement, managed bookmarks, and cloud-reporting goals as Trivalent, but it is managed independently via Chrome's own enterprise policy path.

Policy path managed by the `google-chrome-config` module:

```text
/usr/etc/opt/chrome/policies/managed/google-chrome-policies.json
```

On the booted image this is available at `/etc/opt/chrome/policies/managed/google-chrome-policies.json`.

### Policy highlights

| Policy | Setting | Purpose |
|--------|---------|---------|
| `DefaultCookiesSetting` | Allow | Permit cookies for enterprise web apps |
| `CookiesAllowedForUrls` | `[*.]google.com`, SSO IdP domains | Allow persistent Google/SSO session cookies |
| `AuthServerAllowlist` | `*.google.com`, `*.microsoftonline.com`, `*.okta.com`, `*.onelogin.com` | Whitelist authentication servers for integrated SSO |
| `ForceDarkMode` / `ForceDarkModeEnabled` | Enabled | Force dark mode across all sites |
| `PreferredColorScheme` | Dark (`2`) | Report `prefers-color-scheme: dark` to sites |
| `CloudReportingEnabled` | Enabled | Enterprise telemetry/reporting (if managed) |
| Managed bookmarks | Google Workspace apps | Curated bookmarks bar |

### Certificate handling

Google Chrome uses the same system NSS certificate store as Trivalent and trusts enterprise CAs installed at the system level. Do **not** import research or personal certificates into this profile.

## Privacy / Research Browser: Mullvad Browser

Mullvad Browser is the isolated browser for sensitive research, privacy-sensitive browsing, and untrusted sites.

Profile path managed by the `privacy-browser-config` module:

```text
~/.var/app/net.mullvad.MullvadBrowser/config/mullvad-browser/profile.default
```

(or the equivalent Flatpak profile directory if the application ID differs).

### Isolation requirements

- A **dedicated profile directory** separate from Trivalent/Chrome/Firefox.
- A **dedicated certificate store**; no enterprise CA is imported automatically.
- Hardened DNS (DoH / Mullvad DNS) and, when required, proxy/Socks5 routing.
- No access to Trivalent/Chrome cookies, history, or extensions.

### Policy highlights

| Setting | Value | Purpose |
|--------|-------|---------|
| DNS over HTTPS | Enabled via Mullvad DNS | Encrypted, no-log DNS |
| Proxy/Socks5 | Configurable per profile | Route research traffic separately |
| Certificate store | Isolated | Prevent enterprise CA leakage |
| State separation | Flatpak sandbox + per-profile paths | Block cross-contamination |

## Certificate Isolation

The three browsers must never share certificate state:

1. **Trivalent** and **Google Chrome** read system CAs and any enterprise CAs declared in the recipe/module.
2. **Mullvad Browser** starts with an empty, profile-local certificate store.
3. If an enterprise CA must be trusted for the privacy browser, it is imported manually in that profile only and documented in the deployment runbook.
4. Never copy `cert9.db`, `key4.db`, or cookies between the enterprise browsers and Mullvad Browser.

## Preinstalled Applications

In addition to the browser profiles, the image ships:

- **Yubico Authenticator** (`com.yubico.yubioath`) — Flatpak for hardware-token based 2FA/TOTP.
- **Mullvad VPN** (`mullvad-vpn`) — RPM client from the official Mullvad repository; the `mullvad-daemon.service` is enabled by default.

## Operational notes

- Use Trivalent or Google Chrome for corporate identity, Google Workspace, and trusted SaaS.
- Use Mullvad Browser for research, sensitive searches, and untrusted sites.
- Never copy `cert9.db`, `key4.db`, or cookies between the enterprise browsers and Mullvad Browser.
