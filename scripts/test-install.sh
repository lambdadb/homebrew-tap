#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
mode=${1:-local}
if [[ $# -gt 1 || ( "$mode" != local && "$mode" != remote ) ]]; then
  echo "Usage: bash scripts/test-install.sh [local|remote]" >&2
  exit 2
fi
if ! command -v brew >/dev/null; then
  echo "Homebrew is required." >&2
  exit 1
fi
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTOREMOVE=1
export HOMEBREW_DEVELOPER=1

brew_prefix=$(brew --prefix)
if brew list --versions lambdadb-cli >/dev/null 2>&1 || [[ -e "$brew_prefix/bin/lambdadb" || -L "$brew_prefix/bin/lambdadb" ]]; then
  echo "Preserve the existing Homebrew CLI or prefix executable; use a clean runner." >&2
  exit 1
fi
tap="lambdadb/tap-test-$$"
if [[ "$mode" == remote ]]; then
  tap="lambdadb/tap"
  if brew tap | grep -Fxq "$tap"; then
    echo "Preserve the existing $tap; use a clean runner for remote tests." >&2
    exit 1
  fi
fi
formula="$tap/lambdadb-cli"
test_dir=$(mktemp -d)
test_dir=$(cd "$test_dir" && pwd -P)
tap_attempted=0
install_attempted=0
cleanup() {
  status=$?
  trap - EXIT
  if [[ "$install_attempted" == 1 ]] && brew list --versions "$formula" >/dev/null 2>&1; then
    brew uninstall --formula "$formula" || status=1
  fi
  if [[ "$tap_attempted" == 1 ]] && brew tap | grep -Fxq "$tap"; then
    brew untap "$tap" || status=1
  fi
  rm -rf "$test_dir"
  exit "$status"
}
trap cleanup EXIT

if [[ "$mode" == local ]]; then
  mkdir -p "$test_dir/tap/Formula"
  cp "$repo_dir/Formula/lambdadb-cli.rb" "$test_dir/tap/Formula/"
  git -C "$test_dir/tap" init -q
  git -C "$test_dir/tap" add Formula
  git -C "$test_dir/tap" -c user.name='Tap installation test' -c user.email='tap-test@example.invalid' \
    -c commit.gpgsign=false commit -qm 'Local formula fixture'
  tap_attempted=1
  brew tap "$tap" "$test_dir/tap"
fi

# Remote mode exercises the documented one-command installation and automatic tap.
tap_attempted=1
install_attempted=1
brew install --formula "$formula"
cmp "$repo_dir/Formula/lambdadb-cli.rb" "$(brew --repository "$tap")/Formula/lambdadb-cli.rb"
brew style --formula "$formula"
brew test "$formula"

cli_prefix=$(brew --prefix "$formula")
mkdir -p "$test_dir/fake-bin"
printf '#!/bin/sh\necho "Unexpected ambient Node executable" >&2\nexit 97\n' > "$test_dir/fake-bin/node"
chmod +x "$test_dir/fake-bin/node"
env PATH="$test_dir/fake-bin:/usr/bin:/bin" "$cli_prefix/bin/lambdadb" --version
echo "Verified $formula ($mode): installation, formula equality, style, smoke and runtime selection."
