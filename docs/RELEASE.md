# Release & Build Runbook

This runbook covers how to trigger the first (and subsequent) BlueBuild GitHub Actions builds for the SecureBlue KDE Agentic Deploy image.

## 1. Prerequisites

- `gh` CLI installed and authenticated, or `GITHUB_PAT` exported via `scripts/env-init.sh`.
- A Cosign keypair for image signing (see section 2).
- The GitHub repository `Agent-042/SecureBlue-KDE-Agentic-Deploy` exists and this repo is pushed to it.
- You are working from the project root at `~/Agentic-OS/SecureBlue-KDE-Agentic-Deploy`.

## 2. Generate signing keys

From the repo root:

```bash
# On an immutable SecureBlue host, podman may not be usable for key generation.
# Use the bundled openssl-based helper instead:
scripts/generate-cosign-keys.sh
```

This produces:

- `cosign.pub` — public key; commit this file to the repository root.
- `cosign.key` — private key; keep it secret.

Add the private key as a GitHub Actions secret named `SIGNING_SECRET`:

```bash
source scripts/env-init.sh
scripts/set-signing-secret.sh
```

Then remove `cosign.key` from the local filesystem or store it in a password manager:

```bash
shred -u cosign.key
```

## 3. Push the repository

```bash
git remote add origin https://github.com/Agent-042/SecureBlue-KDE-Agentic-Deploy.git
git push -u origin main
```

## 4. Trigger a build

```bash
just push-and-trigger
```

Or manually:

```bash
git push origin main
gh workflow run build.yml --ref main
```

## 5. Verify the image

Once the workflow finishes:

```bash
gh run list --workflow=build.yml --limit 5
```

Download the public key and verify the image signature:

```bash
cosign verify --key cosign.pub \
  ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest
```

## 6. Rebase a test host

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/Agent-042/secureblue-kde-agentic-deploy:latest
systemctl reboot
```
