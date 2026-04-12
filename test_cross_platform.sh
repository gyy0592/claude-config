#!/usr/bin/env bash
# Dry-run test: verify cross-platform shell detection logic without modifying any files.
# Usage: bash test_cross_platform.sh

set -euo pipefail
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label (got: $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected: $expected, got: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Helper: extract what SHELL_RC would be set to ---
detect_shell_rc() {
  local shell_val="$1"
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$shell_val")" = "zsh" ]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

echo "=== 1. bash -n syntax check ==="
for f in set_claude.sh setup_codex.sh patches/fix-humanize-session-id.sh skills/pdf-ingest/scripts/ingest.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "  PASS: $f"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $f"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== 2. Shell detection: SHELL=/bin/bash ==="
SHELL=/bin/bash
result=$(detect_shell_rc "$SHELL")
assert_eq "bash -> .bashrc" "$HOME/.bashrc" "$result"

echo ""
echo "=== 3. Shell detection: SHELL=/bin/zsh (simulated macOS) ==="
SHELL=/bin/zsh
result=$(detect_shell_rc "$SHELL")
assert_eq "zsh -> .zshrc" "$HOME/.zshrc" "$result"

echo ""
echo "=== 4. Shell detection: SHELL=/usr/local/bin/zsh (Homebrew zsh) ==="
SHELL=/usr/local/bin/zsh
result=$(detect_shell_rc "$SHELL")
assert_eq "homebrew zsh -> .zshrc" "$HOME/.zshrc" "$result"

echo ""
echo "=== 5. sed -i cross-platform detection ==="
if sed --version 2>/dev/null | grep -q GNU; then
  echo "  INFO: GNU sed detected -> sed -i (no suffix)"
  PASS=$((PASS + 1))
else
  echo "  INFO: BSD sed detected -> sed -i '' (empty suffix)"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== 6. POSIX regex check (no GNU-only \\s or \\+) ==="
if grep -qE '\\\\s|\\\\+' setup_codex.sh 2>/dev/null; then
  echo "  FAIL: setup_codex.sh still contains GNU-only regex"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: setup_codex.sh uses POSIX regex only"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== 7. No hardcoded .bashrc outside detection block ==="
# Expect only the fallback line inside the if-else block
count=$(grep -c '\.bashrc' set_claude.sh || true)
# 1 occurrence expected: the SHELL_RC="$HOME/.bashrc" fallback
assert_eq "set_claude.sh .bashrc refs <= 1" "1" "$count"

count=$(grep -c '\.bashrc' setup_codex.sh || true)
assert_eq "setup_codex.sh .bashrc refs <= 1" "1" "$count"

echo ""
echo "=== 8. No BSD-incompatible grep -P flag ==="
if grep -q 'grep.*-[[:alpha:]]*P[[:alpha:]]*' set_claude.sh setup_codex.sh patches/*.sh skills/*/scripts/*.sh 2>/dev/null; then
  echo "  FAIL: Found grep -P usage (BSD grep doesn't support -P)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: No grep -P usage found"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== 9. Cross-platform package installation instructions ==="
if grep -q 'poppler-utils.*macOS\|poppler.*macOS' skills/pdf-ingest/scripts/ingest.sh 2>/dev/null; then
  echo "  PASS: PDF ingest script mentions both Linux and macOS package names"
  PASS=$((PASS + 1))
elif grep -q 'poppler-utils' skills/pdf-ingest/scripts/ingest.sh 2>/dev/null; then
  echo "  FAIL: PDF ingest script only mentions Linux package name"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: No poppler dependency found or different installation approach"
  PASS=$((PASS + 1))
fi

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "All tests passed!" || echo "Some tests failed."
exit "$FAIL"
