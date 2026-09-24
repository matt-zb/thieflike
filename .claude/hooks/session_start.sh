#!/bin/bash
# SessionStart hook: installs the pinned Godot 4.7.2 headless build in cloud
# sessions so the implementer can run GUT tests and import the project.
# Local sessions (with the developer's own Godot editor) are left untouched.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_INSTALL_DIR="/opt/godot"
GODOT_BIN="${GODOT_INSTALL_DIR}/godot"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"

# Only cloud sessions need this; local dev machines bring their own editor.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Idempotent: skip the install if the pinned version is already in place.
# `godot --version` prints e.g. "4.7.2.stable.official.<hash>", so compare
# against the dotted form rather than the release tag's hyphenated form.
GODOT_VERSION_DOTTED="${GODOT_VERSION/-/.}"
if command -v godot >/dev/null 2>&1 && godot --version 2>/dev/null | grep -q "^${GODOT_VERSION_DOTTED}"; then
  echo "godot ${GODOT_VERSION} already installed, skipping download."
else
  echo "Installing Godot ${GODOT_VERSION} headless build..."
  mkdir -p "${GODOT_INSTALL_DIR}"
  tmp_zip="$(mktemp -d)/godot.zip"
  curl -fsSL "${GODOT_URL}" -o "${tmp_zip}"
  unzip -o -q "${tmp_zip}" -d "${GODOT_INSTALL_DIR}"
  rm -rf "$(dirname "${tmp_zip}")"

  # The archive extracts as Godot_v4.7.2-stable_linux.x86_64; normalize the
  # binary name so GODOT_BIN and the PATH symlink stay stable across
  # point releases.
  extracted_bin="$(find "${GODOT_INSTALL_DIR}" -maxdepth 1 -type f -name "Godot_v*" | head -n1)"
  if [ -n "${extracted_bin}" ]; then
    mv -f "${extracted_bin}" "${GODOT_BIN}"
  fi
  chmod +x "${GODOT_BIN}"
  ln -sf "${GODOT_BIN}" /usr/local/bin/godot
fi

# Make sure the symlink exists even if the binary was already present from a
# previous run (e.g. container image rebuilt without /usr/local/bin state).
if [ ! -e /usr/local/bin/godot ]; then
  ln -sf "${GODOT_BIN}" /usr/local/bin/godot
fi

# Warm the class/script cache so the first test run isn't paying import cost.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  godot --headless --import --path "${CLAUDE_PROJECT_DIR}" || true
fi
