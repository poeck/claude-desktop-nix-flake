#!/usr/bin/env bash
set -euo pipefail

repo="https://downloads.claude.ai/claude-desktop/apt/stable"
pkg_file="pkgs/claude-desktop/default.nix"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch_packages() {
  local deb_arch="$1"
  curl -fsSL "$repo/dists/stable/main/binary-$deb_arch/Packages" > "$tmp/Packages.$deb_arch"
}

latest_field() {
  local deb_arch="$1"
  local field="$2"
  awk -v field="$field" '
    BEGIN { RS=""; FS="\n" }
    /^Package: claude-desktop$/ {
      version = ""
      value = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ "^Version: ") version = substr($i, 10)
        if ($i ~ "^" field ": ") value = substr($i, length(field) + 3)
      }
      if (version != "" && value != "") print version "\t" value
    }
  ' "$tmp/Packages.$deb_arch" | sort -V | tail -n1 | cut -f2-
}

to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

fetch_packages amd64
fetch_packages arm64

version_amd64="$(latest_field amd64 Version)"
version_arm64="$(latest_field arm64 Version)"

if [[ "$version_amd64" != "$version_arm64" ]]; then
  echo "Version mismatch: amd64=$version_amd64 arm64=$version_arm64" >&2
  exit 1
fi

hash_amd64="$(to_sri "$(latest_field amd64 SHA256)")"
hash_arm64="$(to_sri "$(latest_field arm64 SHA256)")"

perl -0pi \
  -e "s{version = \"[^\"]+\";}{version = \"$version_amd64\";}" \
  -e "s{debArch = \"amd64\";\n      hash = \"[^\"]+\";}{debArch = \"amd64\";\n      hash = \"$hash_amd64\";}" \
  -e "s{debArch = \"arm64\";\n      hash = \"[^\"]+\";}{debArch = \"arm64\";\n      hash = \"$hash_arm64\";}" \
  "$pkg_file"

echo "Updated claude-desktop to $version_amd64"
