# VSCodium Integration in SecureBlue

This document explains how VSCodium is integrated into the SecureBlue immutable OS image. The management of VSCodium is fully automated and codified within this repository. **There are no separate local installation scripts to manage or deprecate.**

## Overview

VSCodium is treated as a core component of the operating system. It is installed as a Flatpak and configured during the OS image build process managed by BlueBuild. This ensures that every installation is identical, secure, and reproducible.

## Installation

The VSCodium Flatpak (`com.vscodium.codium`) is installed automatically. This is defined in the BlueBuild recipe files:

-   `.backend/recipes/recipe.yml`
-   `.backend/recipes/recipe-amd-workstation.yml`
-   `.backend/recipes/recipe-intel-g16.yml`

These files include `com.vscodium.codium` in the list of `default-flatpaks` to be installed in the system-wide Flatpak installation.

## Security and Configuration

Strict security overrides are applied to the VSCodium Flatpak to enhance isolation and follow the principle of least privilege.

-   **Source of Truth:** The configuration is documented and sourced from `.assets/docs/vscodium.md`.
-   **Implementation:** During the build process, this configuration is used to create a system-wide override file at `/usr/share/flatpak/overrides/com.vscodium.codium`.

This override file restricts filesystem access, device access, and inter-process communication (IPC) to limit the potential impact of any vulnerability in the editor or its extensions.

## Desktop Integration

VSCodium is integrated into the KDE Plasma desktop environment for a seamless user experience. This includes:

-   **Application Launcher:** A `.desktop` file for VSCodium is included.
-   **Default Panel:** The VSCodium icon is added to the default KDE taskbar/panel.

These settings are managed by the `tahoe-theming` files located in `.backend/files/tahoe-theming/`.

## Summary

The entire lifecycle of VSCodium in this project—from installation to configuration and integration—is managed by files within this GitHub repository. This centralized, declarative approach means there is no "local" VSCodium software to manage separately. The setup is already "online on GitHub" and the documentation here serves to inform the RAG system.
