#!/usr/bin/env bash
set -euo pipefail

# Install the top-level README as on-image documentation.
# CONFIG_DIRECTORY points to the recipe root during a BlueBuild run;
# fall back to the relative path from modules/docs-readme/ to the repo root.
README_PATH="${CONFIG_DIRECTORY:-../..}/README.md"
install -Dm644 "$README_PATH" /usr/share/doc/secureblue-kde-agentic/README.md
