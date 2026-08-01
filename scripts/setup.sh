#!/usr/bin/env bash
# scripts/setup.sh — Install Linux system dependencies and verify the Rust
# toolchain for jcode development. Prints a doctor-style pass/fail summary.
#
# Usage:
#   scripts/setup.sh          # install deps + verify
#   scripts/setup.sh --check  # verify only, do not install
set -euo pipefail

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

PASS=0
FAIL=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# System packages (Debian/Ubuntu). Matches CI: libfontconfig1-dev (desktop2),
# clang + mold (fast linking via scripts/dev_cargo.sh), lld (fallback linker).
# ---------------------------------------------------------------------------
REQUIRED_PKGS=(libfontconfig1-dev clang mold lld)

echo "==> System dependencies"

if [[ "$CHECK_ONLY" == false ]]; then
    missing=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "    Installing: ${missing[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${missing[@]}"
    else
        echo "    All packages already installed."
    fi
fi

for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        ok "$pkg"
    else
        fail "$pkg (not installed)"
    fi
done

# ---------------------------------------------------------------------------
# Rust toolchain
# ---------------------------------------------------------------------------
echo "==> Rust toolchain"

if command -v rustup &>/dev/null; then
    ok "rustup"
else
    fail "rustup (install: https://rustup.rs)"
fi

if command -v rustc &>/dev/null; then
    toolchain="$(rustup show active-toolchain 2>/dev/null || true)"
    if [[ "$toolchain" == stable* ]]; then
        ok "stable toolchain ($toolchain)"
    else
        fail "stable toolchain (active: ${toolchain:-none})"
    fi
else
    fail "rustc (not found)"
fi

for component in clippy rustfmt rust-src; do
    if rustup component list --installed 2>/dev/null | grep -q "^${component}"; then
        ok "component: $component"
    else
        if [[ "$CHECK_ONLY" == false ]] && command -v rustup &>/dev/null; then
            rustup component add "$component" 2>/dev/null && ok "component: $component (added)" || fail "component: $component"
        else
            fail "component: $component (missing)"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Summary: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
