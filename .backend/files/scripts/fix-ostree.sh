#!/usr/bin/env bash
set -euxo pipefail

echo "=== OSTREE BUILD ENVIRONMENT DIAGNOSTICS ==="
ls -la /run || true
ls -la /var/run || true

if [ -f /run/ostree-booted ] || [ -d /run/ostree-booted ]; then
    echo "Found /run/ostree-booted! Removing it to force container mode..."
    rm -rf /run/ostree-booted
fi

if [ -f /var/run/ostree-booted ] || [ -d /var/run/ostree-booted ]; then
    echo "Found /var/run/ostree-booted! Removing it to force container mode..."
    rm -rf /var/run/ostree-booted
fi
