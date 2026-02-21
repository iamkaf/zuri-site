#!/usr/bin/env bash
set -euo pipefail

REPO="iamkaf/zuri"
API_BASE="https://api.github.com/repos/${REPO}/releases"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Install Zuri on Linux from GitHub Releases.

Usage:
  curl -fsSL https://zuri.kaf.sh/install.sh | bash

Optional environment variables:
  ZURI_VERSION=v0.1.0   Install a specific tag (default: latest)
  ZURI_REPO=owner/name  Override GitHub repo (default: iamkaf/zuri)
EOF
  exit 0
fi

if [[ -n "${ZURI_REPO:-}" ]]; then
  REPO="$ZURI_REPO"
  API_BASE="https://api.github.com/repos/${REPO}/releases"
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: this installer currently supports Linux only." >&2
  exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  echo "Error: only x86_64/amd64 is currently supported. Detected: ${ARCH}" >&2
  exit 1
fi

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

release_json() {
  if [[ -n "${ZURI_VERSION:-}" ]]; then
    local tag="$ZURI_VERSION"
    [[ "$tag" == v* ]] || tag="v${tag}"
    curl -fsSL "${API_BASE}/tags/${tag}"
  else
    curl -fsSL "${API_BASE}/latest"
  fi
}

extract_asset_url() {
  local json="$1"
  local ext="$2"
  printf '%s\n' "$json" |
    grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+\.'"${ext}"'"' |
    sed -E 's/^"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)"$/\1/' |
    head -n 1
}

echo "Fetching release metadata from ${REPO}..."
JSON="$(release_json)"

PKG_TYPE=""
ASSET_URL=""

if have_cmd dpkg; then
  PKG_TYPE="deb"
  ASSET_URL="$(extract_asset_url "$JSON" "deb")"
fi

if [[ -z "$ASSET_URL" ]] && have_cmd rpm; then
  PKG_TYPE="rpm"
  ASSET_URL="$(extract_asset_url "$JSON" "rpm")"
fi

if [[ -z "$ASSET_URL" || -z "$PKG_TYPE" ]]; then
  echo "Error: could not find a matching .deb or .rpm release asset for this system." >&2
  exit 1
fi

if ! have_cmd sudo; then
  echo "Error: sudo is required to install packages system-wide." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_PATH="${TMP_DIR}/zuri.${PKG_TYPE}"

echo "Downloading ${ASSET_URL}..."
curl -fL "$ASSET_URL" -o "$PKG_PATH"

echo "Installing Zuri (${PKG_TYPE})..."
if [[ "$PKG_TYPE" == "deb" ]]; then
  sudo dpkg -i "$PKG_PATH" || true
  if have_cmd apt-get; then
    sudo apt-get install -f -y
  fi
else
  if have_cmd dnf; then
    sudo dnf install -y "$PKG_PATH"
  elif have_cmd yum; then
    sudo yum install -y "$PKG_PATH"
  elif have_cmd zypper; then
    sudo zypper --non-interactive install "$PKG_PATH"
  else
    sudo rpm -Uvh --replacepkgs "$PKG_PATH"
  fi
fi

echo "Zuri installed successfully."
