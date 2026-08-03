# Tailscale Container-to-Host Root Bridging Architecture

## Overview
On SecureBlue (Fedora Atomic / OSTree), `tailscaled` is containerized inside Podman using the official `docker.io/tailscale/tailscale:stable` image running with `--net=host --privileged`.

Because the official Tailscale container image is built on **Alpine Linux**, incoming Tailscale SSH sessions (`tailscale set --ssh`) drop into the container's `/bin/sh` shell environment.

## Namespace Traversal (`nsenter`)
Since the container runs with `--privileged` on the host kernel, PID 1 inside the container maps directly to host `systemd` (`/usr/lib/systemd/systemd`).

To traverse from the Alpine container into the **bare-metal SecureBlue host root shell**:

```bash
nsenter -t 1 -m -u -i -n -p /bin/bash -l
```

## Mirrored Endpoint Shortcuts
Bidirectional SSH shortcuts are pre-configured on both workstation (`100.126.24.10`) and laptop (`100.120.222.114`):

- **From Workstation to Laptop Host Root**: `ssh-laptop`
- **From Laptop to Workstation Host Root**: `ssh-workstation`

## SSH Config Hardening
To prevent host-key regeneration warnings when ephemeral containers restart, `~/.ssh/config` on both endpoints specifies:

```ssh
Host 100.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```
