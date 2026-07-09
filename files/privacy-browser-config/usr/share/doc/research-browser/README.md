# Privacy / Research Browser Configuration

This module provides an isolated browser profile for untrusted research,
separate from the enterprise Trivalent profile and host certificates.

## Primary: Mullvad Browser (flatpak)

- Flatpak ID: `net.mullvad.MullvadBrowser`
- Launch entry: **Research Browser** desktop file, or run `research-browser`
  from a terminal.
- Profile directory: `~/.var/app/net.mullvad.MullvadBrowser/data/research-browser`
- Certificate store: isolated inside the flatpak sandbox / profile directory.
- The wrapper unsets enterprise proxy and host CA-bundle environment variables
  so the research browser does not inherit Trivalent/enterprise trust anchors.

## Fallback: Firefox + Arkenfox-style hardening

If Mullvad Browser is unavailable:

1. Replace the flatpak ID in `/usr/bin/research-browser` with the
   Firefox flatpak ID (e.g. `org.mozilla.firefox`).
2. Copy `/usr/share/doc/research-browser/firefox-fallback-user.js` into the
   Firefox profile directory as `user.js` before first launch.
3. The system-wide `/usr/lib/firefox/distribution/policies.json` applies
   baseline hardening policies to any native Firefox install.

## DNS / proxy

Mullvad Browser ships with anti-fingerprinting defaults and respects the
system DNS-over-TLS configuration managed by the Infrastructure stream.
Do not add persistent proxy settings here unless the VPN/Whonix stream
explicitly provides them.
