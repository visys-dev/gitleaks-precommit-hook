#!/usr/bin/env sh

set -eu

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: installer must be executed inside a Git repository." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BASE_URL="${GITLEAKS_HOOK_BASE_URL:-https://raw.githubusercontent.com/visys-dev/gitleaks-precommit-hook/main}"

echo "[installer] Configuring Git hooks..."

git config --local core.hooksPath hooks
git config --local gitleaks.enabled true
git config --local gitleaks.installerUrl \
    "${BASE_URL}/scripts/install-gitleaks.sh"

if [ ! -x "hooks/pre-commit" ]; then
    echo "[installer] ERROR: hooks/pre-commit not found or not executable." >&2
    exit 1
fi

echo "[installer] Installing/verifying Gitleaks..."

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "${BASE_URL}/scripts/install-gitleaks.sh" |
    sh

echo "[installer] Installation complete."
echo "[installer] core.hooksPath=$(git config --local --get core.hooksPath)"
echo "[installer] gitleaks.enabled=$(git config --local --get gitleaks.enabled)"
