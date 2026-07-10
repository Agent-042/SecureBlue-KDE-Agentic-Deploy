#!/usr/bin/env bash
# Post-commit hook: push live status after a successful commit.
exec "$(git rev-parse --show-toplevel)/scripts/push-live-status.sh"
