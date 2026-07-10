#!/usr/bin/env bash
# scripts/rebase.sh
# Detect the host fleet and rebase to the matching SecureBlue KDE Agentic image.
#
# Usage:
#   scripts/rebase.sh [--dry-run] [--verify]
#
# Detection order:
#   1. DMI product name (ASUS ROG Zephyrus G16 -> intel-g16).
#   2. CPU vendor + NVIDIA GPU count (AuthenticAMD with multiple NVIDIA GPUs ->
#      amd-workstation; GenuineIntel -> intel-g16).
#   3. Fallback to the default image.
#
# With --dry-run the rpm-ostree (and optional cosign) command is printed but not
# executed. With --verify, cosign verify is run against the public key in the
# repo root before rebasing.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT

readonly COSIGN_PUB="${PROJECT_ROOT}/cosign.pub"

# Image registry and tag configuration.
readonly REGISTRY="ghcr.io/Agent-042"
readonly TAG="latest"
readonly DEFAULT_IMAGE="${REGISTRY}/secureblue-kde-agentic-deploy:${TAG}"
readonly AMD_WORKSTATION_IMAGE="${REGISTRY}/secureblue-kde-agentic-deploy-amd-workstation:${TAG}"
readonly INTEL_G16_IMAGE="${REGISTRY}/secureblue-kde-agentic-deploy-intel-g16:${TAG}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Detect the local hardware fleet and rebase to the corresponding image.

Options:
  --dry-run   Print the rpm-ostree rebase command instead of running it.
  --verify    Run cosign verify before rebasing (requires cosign.pub).
  -h, --help  Show this help message.

Detected fleets:
  amd-workstation -> ${AMD_WORKSTATION_IMAGE}
  intel-g16       -> ${INTEL_G16_IMAGE}
  default         -> ${DEFAULT_IMAGE}
EOF
}

detect_cpu_vendor() {
    awk '/^vendor_id/{print $3; exit}' /proc/cpuinfo 2>/dev/null || echo "unknown"
}

detect_product_name() {
    cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown"
}

count_nvidia_gpus() {
    if command -v lspci >/dev/null 2>&1; then
        lspci -nn 2>/dev/null | grep -ic 'nvidia' || true
    else
        echo 0
    fi
}

detect_fleet() {
    local cpu_vendor product_name nvidia_count
    cpu_vendor="$(detect_cpu_vendor)"
    product_name="$(detect_product_name)"
    nvidia_count="$(count_nvidia_gpus)"

    echo "Detected CPU vendor: ${cpu_vendor}" >&2
    echo "Detected product name: ${product_name}" >&2
    echo "Detected NVIDIA GPUs: ${nvidia_count}" >&2

    if [[ "${product_name}" =~ (Zephyrus|GU605|G16) ]]; then
        echo "intel-g16"
    elif [[ "${cpu_vendor}" == "AuthenticAMD" && "${nvidia_count}" -ge 2 ]]; then
        echo "amd-workstation"
    elif [[ "${cpu_vendor}" == "AuthenticAMD" ]]; then
        # AMD CPU without multiple NVIDIA GPUs still maps to the AMD workstation
        # recipe as the closest supported target.
        echo "amd-workstation"
    elif [[ "${cpu_vendor}" == "GenuineIntel" ]]; then
        echo "intel-g16"
    else
        echo "default"
    fi
}

image_for_fleet() {
    local fleet="${1}"
    case "${fleet}" in
        amd-workstation)
            echo "${AMD_WORKSTATION_IMAGE}"
            ;;
        intel-g16)
            echo "${INTEL_G16_IMAGE}"
            ;;
        default|*)
            echo "${DEFAULT_IMAGE}"
            ;;
    esac
}

main() {
    local dry_run=false
    local verify=false

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --verify)
                verify=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: ${1}" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "warning: rebasing usually requires root privileges. Continuing detection..." >&2
    fi

    local fleet image_ref
    fleet="$(detect_fleet)"
    image_ref="$(image_for_fleet "${fleet}")"

    echo ""
    echo "Detected fleet: ${fleet}"
    echo "Target image:   ${image_ref}"

    if [[ "${verify}" == true ]]; then
        if ! command -v cosign >/dev/null 2>&1; then
            echo "error: cosign is not installed. Install cosign to use --verify." >&2
            exit 1
        fi
        if [[ ! -f "${COSIGN_PUB}" ]]; then
            echo "error: cosign public key not found at ${COSIGN_PUB}" >&2
            exit 1
        fi
        if [[ "${dry_run}" == true ]]; then
            echo "[dry-run] cosign verify --key ${COSIGN_PUB} ${image_ref}"
        else
            echo "Verifying image signature..."
            cosign verify --key "${COSIGN_PUB}" "${image_ref}"
        fi
    fi

    if [[ "${dry_run}" == true ]]; then
        echo "[dry-run] rpm-ostree rebase ostree-image-signed:docker://${image_ref}"
        echo "[dry-run] systemctl reboot"
    else
        echo "Rebasing..."
        rpm-ostree rebase "ostree-image-signed:docker://${image_ref}"
        echo "Rebase complete. Run 'systemctl reboot' to boot into the new image."
    fi
}

main "$@"
