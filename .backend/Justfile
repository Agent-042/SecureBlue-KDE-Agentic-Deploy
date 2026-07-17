# Justfile for SecureBlue KDE Agentic Deploy
# https://github.com/casey/just

_default:
    @just --list

# Validate the BlueBuild recipe
validate:
    bluebuild validate recipes/recipe.yml

# Regenerate deployment documentation from the recipe
generate-docs:
    python3 scripts/generate-docs.py

# Generate (but do not build) the Containerfile to inspect build steps
# Note: a functional rootless container runtime (podman >=4) is required.
generate-containerfile:
    bluebuild generate recipes/recipe.yml -o Containerfile

# Commit and push the current tree to the default GitHub remote, then trigger Actions
# Requires GITHUB_PAT to be exported (source scripts/env-init.sh) and a configured remote.
push-and-trigger remote="origin" branch="main":
    git push {{remote}} {{branch}}
    gh workflow run build.yml --ref {{branch}}

# Open the GitHub Actions build page (CLI only, no browser required)
watch-build:
    gh run list --workflow=build.yml --limit 5
