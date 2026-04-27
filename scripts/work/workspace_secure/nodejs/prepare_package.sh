#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
PACKAGE_DIR="${OUTPUT_DIR}/package"
MANIFEST_FILE="${OUTPUT_DIR}/manifest.env"

source "${DIR}/../lib.sh"

workspace_secure_reset_dir "${OUTPUT_DIR}"
mkdir -p "${PACKAGE_DIR}"

SOURCE_KIND=""
SOURCE_VALUE=""

is_valid_node_root() {
    local candidate="$1"

    [ -x "${candidate}/bin/node" ] && [ -e "${candidate}/bin/npm" ]
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
        echo "Could not detect extracted nodejs directory"
        exit 1
    fi

    workspace_secure_copy_tree "${extracted_root}" "${PACKAGE_DIR}"
}

copy_portable_root() {
    local source_dir="$1"

    workspace_secure_copy_tree "${source_dir}" "${PACKAGE_DIR}"
}

host_node_version() {
    node --version | sed 's/^v//'
}

node_arch_suffix() {
    case "$(uname -m)" in
        x86_64) echo "x64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7l" ;;
        *)
            echo "Unsupported architecture for nodejs bundle: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

default_node_url() {
    local version
    local arch

    version="$(host_node_version)"
    arch="$(node_arch_suffix)"

    echo "https://nodejs.org/dist/v${version}/node-v${version}-linux-${arch}.tar.xz"
}

detect_node_root_from_path() {
    local node_path
    local candidate_root

    if ! command -v node >/dev/null 2>&1; then
        return 1
    fi

    node_path="$(readlink -f "$(command -v node)")"
    candidate_root="$(cd "$(dirname "${node_path}")/.." && pwd)"

    if [ "${candidate_root}" = "/usr" ] || [ "${candidate_root}" = "/usr/local" ]; then
        return 1
    fi

    if is_valid_node_root "${candidate_root}"; then
        echo "${candidate_root}"
        return 0
    fi

    return 1
}

if [ -n "${WORKSPACE_SECURE_NODEJS_SOURCE_DIR:-}" ] && \
    is_valid_node_root "${WORKSPACE_SECURE_NODEJS_SOURCE_DIR}"; then
    SOURCE_KIND="local-dir"
    SOURCE_VALUE="${WORKSPACE_SECURE_NODEJS_SOURCE_DIR}"
    copy_portable_root "${WORKSPACE_SECURE_NODEJS_SOURCE_DIR}"
elif [ -n "${WORKSPACE_SECURE_NODEJS_ARCHIVE:-}" ] && [ -f "${WORKSPACE_SECURE_NODEJS_ARCHIVE}" ]; then
    SOURCE_KIND="archive"
    SOURCE_VALUE="${WORKSPACE_SECURE_NODEJS_ARCHIVE}"
    extract_archive_into_package "${WORKSPACE_SECURE_NODEJS_ARCHIVE}"
elif detected_root="$(detect_node_root_from_path)"; then
    SOURCE_KIND="detected-local-dir"
    SOURCE_VALUE="${detected_root}"
    copy_portable_root "${detected_root}"
else
    temp_archive="$(mktemp)"
    trap 'rm -f "${temp_archive}"' EXIT
    SOURCE_KIND="download"
    SOURCE_VALUE="$(default_node_url)"
    wget -q --show-progress "${SOURCE_VALUE}" -O "${temp_archive}"
    extract_archive_into_package "${temp_archive}"
fi

{
    echo "package_name=nodejs"
    echo "source_kind=${SOURCE_KIND}"
    echo "source_value=${SOURCE_VALUE}"
    echo "node_version=$("${PACKAGE_DIR}/bin/node" --version)"
} > "${MANIFEST_FILE}"
