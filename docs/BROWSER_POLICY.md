# Browser Policy

This image ships two browser profiles that are intentionally isolated from each other.

## Enterprise Browser: Trivalent

Trivalent (enterprise Chromium) is the default browser for Google Workspace, corporate SSO, and daily productivity.

Profile path managed by the `trivalent-config` module:

```text
/usr/etc/chromium/policies/managed/trivalent-policies.json
```

On the booted image this is available at `/etc/chromium/policies/managed/trivalent-policies.json`.

### Policy highlights

| Policy | Setting | Purpose |
|--------|---------|---------|
| `DefaultCookiesSetting` | Allow | Permit cookies for enterprise web apps |
| `CookiesAllowedForUrls` | `[*.]google.com`, SSO IdP domains | Allow persistent Google/SSO session cookies |
| `AuthServerAllowlist` | `[*.]google.com`, `[*.]okta.com`, `[*.]auth0.com` | Whitelist authentication servers for integrated SSO |
| `ForceDarkMode` | Enabled | Force dark mode across all sites |
| `PreferredColorScheme` | Dark | Report `prefers-color-scheme: dark` to sites |
| `CloudReportingEnabled` | Enabled | Enterprise telemetry/reporting (if managed) |
| Managed bookmarks | Company apps, documentation | Curated bookmarks bar |

### Certificate handling

Trivalent uses the system NSS certificate store plus any enterprise CAs installed by the `trivalent-config` module. Do **not** import research or personal certificates into this profile.

## Privacy / Research Browser: Mullvad Browser

Mullvad Browser is the isolated browser for sensitive research, privacy-sensitive browsing, and untrusted sites.

Profile path managed by the `privacy-browser-config` module:

```text
~/.var/app/net.mullvad.MullvadBrowser/config/mullvad-browser/profile.default
```

(or the equivalent Flatpak profile directory if the application ID differs).

### Isolation requirements

- A **dedicated profile directory** separate from Trivalent/Firefox.
- A **dedicated certificate store**; no enterprise CA is imported automatically.
- Hardened DNS (DoH / Mullvad DNS) and, when required, proxy/Socks5 routing.
- No access to Trivalent cookies, history, or extensions.

### Policy highlights

| Setting | Value | Purpose |
|--------|-------|---------|
| DNS over HTTPS | Enabled via Mullvad DNS | Encrypted, no-log DNS |
| Proxy/Socks5 | Configurable per profile | Route research traffic separately |
| Certificate store | Isolated | Prevent enterprise CA leakage |
| State separation | Flatpak sandbox + per-profile paths | Block cross-contamination |

## Certificate Isolation

The two browsers must never share a certificate store:

1. **Trivalent** reads system CAs and any enterprise CAs declared in the recipe/module.
2. **Mullvad Browser** starts with an empty, profile-local certificate store.
3. If an enterprise CA must be trusted for the privacy browser, it is imported manually in that profile only and documented in the deployment runbook.

## Operational notes

- Use Trivalent for corporate identity, Google Workspace, and trusted SaaS.
- Use Mullvad Browser for research, sensitive searches, and untrusted sites.
- Never copy `cert9.db`, `key4.db`, or cookies between the two profiles.
