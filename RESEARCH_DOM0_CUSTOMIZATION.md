# Research Phase 1: dom0 Customization (KDE & Immutability)

This document summarizes the findings for the feasibility of creating a Qubes OS `dom0` with the KDE Plasma desktop and an immutable filesystem based on `rpm-ostree`.

## 1. KDE Plasma in `dom0`

**Conclusion: Fully Feasible and Supported.**

The Qubes OS project officially supports and maintains packages for using KDE Plasma as the desktop environment in `dom0`.

### Installation Process

The recommended method is to install the pre-built and signed packages directly from the Qubes repositories. This ensures that all Qubes-specific integrations (colored window borders, secure application menus) are included.

The command to be run in a `dom0` terminal is:

```bash
sudo qubes-dom0-update @kde-desktop-qubes
```

or alternatively:

```bash
sudo qubes-dom0-update kde-settings-qubes
```

After installation, the user can select "Plasma (X11)" from the session menu at the login screen to start the KDE environment.

### Optional Configuration: SDDM

It is also possible to switch the default `lightdm` display manager to KDE's native `sddm`. This involves editing `/etc/sddm.conf` to add Qubes-specific X-server arguments and then enabling the `sddm` service via `systemctl`.

### Building from Source

While possible using `qubes-builder` by adding the `desktop-linux-kde` component, it is not necessary unless we plan to modify the KDE integration source code itself. For the goal of simply using KDE, the pre-built packages are sufficient and more reliable.

## 2. Immutable `dom0` with `rpm-ostree`

**Conclusion: Not Feasible with Current Qubes Architecture.**

While highly desirable for security and atomic rollbacks, creating an `rpm-ostree`-based `dom0` faces major, unresolved architectural challenges.

### Key Technical Hurdles

1.  **Networkless Update Model:** `dom0` is fundamentally offline. The `qubes-dom0-update` tool uses a proxy VM to download RPMs, which are then securely transferred and installed. `rpm-ostree` is designed for direct network access to pull entire OS commits, a model that directly conflicts with `dom0`'s isolation. Adapting this would require a significant rewrite of the Qubes update mechanism.
2.  **Xen Bootloader Integration:** Qubes boots the Xen hypervisor, which then loads the `dom0` kernel as a module. `rpm-ostree` is designed to manage the GRUB bootloader to handle atomic deployments. Integrating `rpm-ostree`'s bootloader management with Xen's boot process is a complex, unsolved task.
3.  **Increased Attack Surface:** The `rpm-ostree` stack is complex, pulling in many dependencies. Adding this entire stack to `dom0` would significantly increase its Trusted Computing Base (TCB), which runs contrary to the core Qubes principle of minimizing `dom0`.

### Alternatives & The Path Forward

A true immutable `dom0` is not a practical goal at this time. However, we can achieve the underlying goals of reproducibility and declarative system state through other means:

1.  **Infrastructure as Code via SaltStack:** The Qubes-native approach is to use **SaltStack** for `dom0` and VM management. We can create Salt states that define every package, configuration file, and setting in `dom0`. This allows us to treat the entire system configuration as code, making it version-controlled, auditable, and fully reproducible by an agent. This aligns perfectly with the "Agentic DevOps" goal.
2.  **Focus Immutability on AppVMs:** We will apply the `rpm-ostree` and Fedora Atomic concepts (like Bazzite) to the **Templates and StandaloneVMs**. This is a core strength of Qubes OS and provides immense security benefits by ensuring applications run in hardened, reproducible, and easily disposable environments.

**Decision:** We will proceed with a standard, mutable Fedora `dom0` and install KDE using the supported method. We will then leverage SaltStack as the primary mechanism for achieving a declarative, agent-driven, and reproducible system configuration, focusing our immutable image-building efforts on the templates that will host the Gaming and Agent VMs.
