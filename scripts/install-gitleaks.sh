#!/usr/bin/env sh

set -eu

GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.30.1}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: must be executed inside a Git repository." >&2
    exit 1
fi

GIT_DIR="$(git rev-parse --git-dir)"
INSTALL_DIR="${GITLEAKS_INSTALL_DIR:-${GIT_DIR}/tools}"

mkdir -p "$INSTALL_DIR"

OS_RAW="$(uname -s)"
ARCH_RAW="$(uname -m)"

case "$OS_RAW" in
    Linux*)
        OS="linux"
        ARCHIVE_TYPE="tar.gz"
        ;;
    Darwin*)
        OS="darwin"
        ARCHIVE_TYPE="tar.gz"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        OS="windows"
        ARCHIVE_TYPE="zip"
        ;;
    *)
        echo "ERROR: unsupported OS: $OS_RAW" >&2
        exit 1
        ;;
esac

case "$ARCH_RAW" in
    x86_64|amd64)
        ARCH="x64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    i386|i686)
        ARCH="x32"
        ;;
    *)
        echo "ERROR: unsupported architecture: $ARCH_RAW" >&2
        exit 1
        ;;
esac

if [ "$OS" = "windows" ]; then
    BINARY_NAME="gitleaks.exe"
else
    BINARY_NAME="gitleaks"
fi

TARGET="${INSTALL_DIR}/${BINARY_NAME}"

if [ -f "$TARGET" ]; then
    INSTALLED_VERSION="$("$TARGET" version 2>/dev/null || true)"

    case "$INSTALLED_VERSION" in
        *"$GITLEAKS_VERSION"*)
            echo "Gitleaks v${GITLEAKS_VERSION} already installed."
            exit 0
            ;;
    esac
fi

BASE_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"
ASSET="gitleaks_${GITLEAKS_VERSION}_${OS}_${ARCH}.${ARCHIVE_TYPE}"
CHECKSUM_FILE="gitleaks_${GITLEAKS_VERSION}_checksums.txt"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

echo "Installing Gitleaks v${GITLEAKS_VERSION}"
echo "Platform: ${OS}/${ARCH}"

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "${BASE_URL}/${ASSET}" \
    --output "${TMP_DIR}/${ASSET}"

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "${BASE_URL}/${CHECKSUM_FILE}" \
    --output "${TMP_DIR}/${CHECKSUM_FILE}"

EXPECTED_HASH="$(
    grep " ${ASSET}$" "${TMP_DIR}/${CHECKSUM_FILE}" |
    awk '{print $1}'
)"

if [ -z "$EXPECTED_HASH" ]; then
    echo "ERROR: checksum for ${ASSET} not found." >&2
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_HASH="$(
        sha256sum "${TMP_DIR}/${ASSET}" |
        awk '{print $1}'
    )"
elif command -v shasum >/dev/null 2>&1; then
    ACTUAL_HASH="$(
        shasum -a 256 "${TMP_DIR}/${ASSET}" |
        awk '{print $1}'
    )"
else
    echo "ERROR: SHA256 utility not found." >&2
    exit 1
fi

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "ERROR: SHA256 verification failed." >&2
    exit 1
fi

echo "SHA256 verification: OK"

if [ "$OS" = "windows" ]; then
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "${TMP_DIR}/${ASSET}" \
            "$BINARY_NAME" \
            -d "$INSTALL_DIR"
    else
        echo "ERROR: unzip is required on Windows Git Bash." >&2
        exit 1
    fi
else
    tar \
        -xzf "${TMP_DIR}/${ASSET}" \
        -C "$INSTALL_DIR" \
        "$BINARY_NAME"

    chmod 0755 "$TARGET"
fi

if [ ! -f "$TARGET" ]; then
    echo "ERROR: gitleaks installation failed." >&2
    exit 1
fi

echo "Installed:"
"$TARGET" version
