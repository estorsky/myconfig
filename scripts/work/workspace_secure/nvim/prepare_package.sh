#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
PACKAGE_DIR="${OUTPUT_DIR}/package"
MANIFEST_FILE="${OUTPUT_DIR}/manifest.env"
DEFAULT_COMPAT_VERSION="0.10.4"
DEFAULT_COMPAT_URL_X86_64="https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-x86_64.tar.gz"

source "${DIR}/../lib.sh"

workspace_secure_reset_dir "${OUTPUT_DIR}"
mkdir -p "${PACKAGE_DIR}"

SOURCE_KIND=""
SOURCE_VALUE=""

is_valid_nvim_root() {
    local candidate="$1"

    [ -x "${candidate}/bin/nvim" ] && [ -d "${candidate}/share/nvim/runtime" ]
}

extract_archive_into_package() {
    local archive_path="$1"
    local temp_dir
    local extracted_root=""

    temp_dir="$(mktemp -d)"
    trap 'rm -rf "${temp_dir}"' RETURN

    tar -xf "${archive_path}" -C "${temp_dir}"

    for candidate in "${temp_dir}"/* ; do
        if [ -d "${candidate}" ]; then
            extracted_root="${candidate}"
            break
        fi
    done

    if [ -z "${extracted_root}" ]; then
        echo "Could not detect extracted neovim directory"
        exit 1
    fi

    workspace_secure_copy_tree "${extracted_root}" "${PACKAGE_DIR}"
}

copy_portable_root() {
    local source_dir="$1"

    workspace_secure_copy_tree "${source_dir}" "${PACKAGE_DIR}"
}

host_nvim_version() {
    nvim --version | sed -n '1s/^NVIM v//p'
}

nvim_arch_suffix() {
    case "$(uname -m)" in
        x86_64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)
            echo "Unsupported architecture for nvim bundle: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

default_nvim_url() {
    local version
    local arch

    version="$(host_nvim_version)"
    arch="$(nvim_arch_suffix)"

    echo "https://github.com/neovim/neovim/releases/download/v${version}/nvim-linux-${arch}.tar.gz"
}

compat_nvim_url() {
    case "$(uname -m)" in
        x86_64)
            echo "${DEFAULT_COMPAT_URL_X86_64}"
            ;;
        *)
            echo "Unsupported architecture for compatible nvim bundle: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

selected_nvim_url() {
    local strategy="${WORKSPACE_SECURE_NVIM_STRATEGY:-compat}"

    if [ -n "${WORKSPACE_SECURE_NVIM_URL:-}" ]; then
        echo "${WORKSPACE_SECURE_NVIM_URL}"
        return
    fi

    case "${strategy}" in
        compat)
            echo "$(compat_nvim_url)"
            ;;
        host)
            echo "$(default_nvim_url)"
            ;;
        *)
            echo "Unknown WORKSPACE_SECURE_NVIM_STRATEGY: ${strategy}" >&2
            exit 1
            ;;
    esac
}

detect_nvim_root_from_path() {
    local nvim_path
    local candidate_root

    if ! command -v nvim >/dev/null 2>&1; then
        return 1
    fi

    nvim_path="$(readlink -f "$(command -v nvim)")"
    candidate_root="$(cd "$(dirname "${nvim_path}")/.." && pwd)"

    if [ "${candidate_root}" = "/usr" ] || [ "${candidate_root}" = "/usr/local" ]; then
        return 1
    fi

    if is_valid_nvim_root "${candidate_root}"; then
        echo "${candidate_root}"
        return 0
    fi

    return 1
}

if [ -n "${WORKSPACE_SECURE_NVIM_SOURCE_DIR:-}" ] && \
    is_valid_nvim_root "${WORKSPACE_SECURE_NVIM_SOURCE_DIR}"; then
    SOURCE_KIND="local-dir"
    SOURCE_VALUE="${WORKSPACE_SECURE_NVIM_SOURCE_DIR}"
    copy_portable_root "${WORKSPACE_SECURE_NVIM_SOURCE_DIR}"
elif [ -n "${WORKSPACE_SECURE_NVIM_ARCHIVE:-}" ] && [ -f "${WORKSPACE_SECURE_NVIM_ARCHIVE}" ]; then
    SOURCE_KIND="archive"
    SOURCE_VALUE="${WORKSPACE_SECURE_NVIM_ARCHIVE}"
    extract_archive_into_package "${WORKSPACE_SECURE_NVIM_ARCHIVE}"
elif [ "${WORKSPACE_SECURE_NVIM_STRATEGY:-compat}" = "host" ] && detected_root="$(detect_nvim_root_from_path)"; then
    SOURCE_KIND="detected-local-dir"
    SOURCE_VALUE="${detected_root}"
    copy_portable_root "${detected_root}"
else
    temp_archive="$(mktemp)"
    trap 'rm -f "${temp_archive}"' EXIT
    SOURCE_KIND="download"
    SOURCE_VALUE="$(selected_nvim_url)"
    wget -q --show-progress "${SOURCE_VALUE}" -O "${temp_archive}"
    extract_archive_into_package "${temp_archive}"
fi

{
    echo "package_name=nvim"
    echo "source_kind=${SOURCE_KIND}"
    echo "source_value=${SOURCE_VALUE}"
    echo "host_nvim_version=$(host_nvim_version)"
    echo "strategy=${WORKSPACE_SECURE_NVIM_STRATEGY:-compat}"
    echo "compat_version=${DEFAULT_COMPAT_VERSION}"
    echo "nvim_version=$("${PACKAGE_DIR}/bin/nvim" --version | sed -n '1p')"
} > "${MANIFEST_FILE}"
