#!/bin/sh
# Installs the rFabric @PRODUCT@ (`@BINARY@`).
#
#   curl -fsSL @GET_URL@/@SCRIPT@ | sh
#
# Linux with apt-get or dnf: adds the rFabric package repository (@LINUX_URL@) and
# installs the `@BINARY@` package, so `apt-get upgrade` / `dnf upgrade` keep it current.
# Any other system, or when RFABRIC_VERSION or RFABRIC_INSTALL_DIR is set: downloads the
# `@BINARY@` binary from https://github.com/@RELEASES@/releases into RFABRIC_INSTALL_DIR.
#
# Environment:
#   RFABRIC_CHANNEL      stable (default) or rc (release candidates).
#   RFABRIC_VERSION      Exact release to install as a binary, e.g. v1.4.0.
#   RFABRIC_INSTALL_DIR  Directory for the binary. Default: /usr/local/bin.
#
# Generated from install.sh in https://github.com/rfabric/get; edit it there.

set -eu

PRODUCT="@PRODUCT@"
BINARY="@BINARY@"
RELEASES="@RELEASES@"
LINUX_URL="@LINUX_URL@"
NEXT_STEP="@NEXT_STEP@"

CHANNEL="${RFABRIC_CHANNEL:-stable}"
INSTALL_DIR="${RFABRIC_INSTALL_DIR:-/usr/local/bin}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require() {
    command -v "$1" > /dev/null 2>&1 || err "missing required tool: $1"
}

# as_root <command...>: runs the command as root, through sudo when needed.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo > /dev/null 2>&1; then
        sudo "$@"
    else
        err "root is required: rerun as root or install sudo"
    fi
}

package_manager() {
    if command -v apt-get > /dev/null 2>&1; then
        echo apt-get
    elif command -v dnf > /dev/null 2>&1; then
        echo dnf
    elif command -v yum > /dev/null 2>&1; then
        echo yum
    fi
}

install_package() {
    manager="$1"
    log "adding the rFabric ${CHANNEL} package repository (${LINUX_URL})"
    if [ "${manager}" = apt-get ]; then
        as_root install -d -m 0755 /etc/apt/keyrings
        curl -fsSL "${LINUX_URL}/rfabric.asc" | as_root tee /etc/apt/keyrings/rfabric.asc > /dev/null
        as_root chmod 0644 /etc/apt/keyrings/rfabric.asc
        echo "deb [signed-by=/etc/apt/keyrings/rfabric.asc] ${LINUX_URL}/deb ${CHANNEL} main" \
            | as_root tee /etc/apt/sources.list.d/rfabric.list > /dev/null
        as_root apt-get update < /dev/null
        log "installing package ${BINARY}"
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${BINARY}" < /dev/null
    else
        as_root rpm --import "${LINUX_URL}/rfabric.asc"
        curl -fsSL "${LINUX_URL}/rpm/rfabric-${CHANNEL}.repo" | as_root tee /etc/yum.repos.d/rfabric.repo > /dev/null
        log "installing package ${BINARY}"
        as_root "${manager}" install -y "${BINARY}" < /dev/null
    fi
}

detect_os() {
    case "$(uname -s)" in
        Linux) echo linux ;;
        Darwin) echo darwin ;;
        *) err "unsupported OS: $(uname -s); see https://github.com/${RELEASES}/releases" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo amd64 ;;
        arm64 | aarch64) echo arm64 ;;
        *) err "unsupported architecture: $(uname -m)" ;;
    esac
}

resolve_version() {
    if [ -n "${RFABRIC_VERSION:-}" ]; then
        echo "${RFABRIC_VERSION}"
        return
    fi
    api="https://api.github.com/repos/${RELEASES}/releases"
    if [ "${CHANNEL}" = rc ]; then
        response=$(curl -fsSL "${api}?per_page=20") || err "could not query GitHub releases"
        tag=$(printf '%s' "${response}" | grep -E '"tag_name":' | grep -E -- '-rc\.' | head -n1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    else
        response=$(curl -fsSL "${api}/latest") || err "could not query GitHub releases"
        tag=$(printf '%s' "${response}" | grep -E '"tag_name":' | head -n1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    fi
    [ -n "${tag}" ] || err "no ${CHANNEL} release found"
    echo "${tag}"
}

install_binary() {
    require tar
    os=$(detect_os)
    arch=$(detect_arch)
    tag=$(resolve_version)
    archive="${BINARY}_${tag#v}_${os}_${arch}.tar.gz"
    base_url="https://github.com/${RELEASES}/releases/download/${tag}"
    log "installing ${BINARY} ${tag} (${os}/${arch}) into ${INSTALL_DIR}"

    tmp=$(mktemp -d)
    trap 'rm -rf "${tmp}"' EXIT
    curl -fsSL -o "${tmp}/${archive}" "${base_url}/${archive}" || err "failed to download ${base_url}/${archive}"
    curl -fsSL -o "${tmp}/checksums.txt" "${base_url}/checksums.txt" || err "failed to download checksums.txt"

    expected=$(grep -E " ${archive}\$" "${tmp}/checksums.txt" | awk '{print $1}')
    [ -n "${expected}" ] || err "no checksum entry for ${archive}"
    if command -v sha256sum > /dev/null 2>&1; then
        actual=$(sha256sum "${tmp}/${archive}" | awk '{print $1}')
    else
        actual=$(shasum -a 256 "${tmp}/${archive}" | awk '{print $1}')
    fi
    [ "${actual}" = "${expected}" ] || err "checksum mismatch (expected ${expected}, got ${actual})"

    tar -xzf "${tmp}/${archive}" -C "${tmp}"
    if [ -w "${INSTALL_DIR}" ] || { [ ! -e "${INSTALL_DIR}" ] && [ -w "$(dirname "${INSTALL_DIR}")" ]; }; then
        mkdir -p "${INSTALL_DIR}"
        install -m 0755 "${tmp}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    else
        as_root mkdir -p "${INSTALL_DIR}"
        as_root install -m 0755 "${tmp}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    fi
}

# Everything runs from main, after sh has read the whole script from the pipe.
main() {
    case "${CHANNEL}" in
        stable | rc) ;;
        *) err "unknown RFABRIC_CHANNEL '${CHANNEL}': use stable or rc" ;;
    esac
    require curl
    log "rFabric ${PRODUCT} installer (${CHANNEL})"

    manager=""
    if [ "$(uname -s)" = Linux ] && [ -z "${RFABRIC_VERSION:-}" ] && [ -z "${RFABRIC_INSTALL_DIR:-}" ]; then
        manager=$(package_manager)
    fi
    if [ -n "${manager}" ]; then
        install_package "${manager}"
        installed=$(command -v "${BINARY}") || err "${BINARY} is not on PATH after the package install"
    else
        install_binary
        installed="${INSTALL_DIR}/${BINARY}"
    fi

    "${installed}" version > /dev/null || err "${installed} failed to run"
    log "installed ${installed}"
    log "next: ${NEXT_STEP}"
}

main "$@"
