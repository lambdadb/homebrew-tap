#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
mode=${1:-local}
package=${2:-lambdadb-cli}
if [[ $# -gt 2 || ( "$mode" != local && "$mode" != remote ) ||
      ( "$package" != lambdadb-cli && "$package" != lambdadb-migration ) ]]; then
  echo "Usage: bash scripts/test-install.sh [local|remote] [lambdadb-cli|lambdadb-migration]" >&2
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
executable=lambdadb
if [[ "$package" == lambdadb-migration ]]; then
  executable=lambdadb-migration
fi
if brew list --versions "$package" >/dev/null 2>&1 ||
   [[ -e "$(brew --cellar)/$package" || -L "$(brew --cellar)/$package" ||
      -e "$brew_prefix/bin/$executable" || -L "$brew_prefix/bin/$executable" ]]; then
  echo "Preserve the existing $package installation or prefix executable; use a clean runner." >&2
  exit 1
fi
tap="lambdadb/tap-test-$$"
if [[ "$mode" == remote ]]; then
  tap="lambdadb/tap"
fi
if brew tap | grep -Fxq "$tap"; then
  echo "Preserve the existing $tap; use a clean runner." >&2
  exit 1
fi
formula="$tap/$package"
test_dir=$(mktemp -d)
test_dir=$(cd "$test_dir" && pwd -P)
# Scoped trust decisions belong to this run, never the user's Homebrew settings.
export XDG_CONFIG_HOME="$test_dir/config"
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
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$mode" == local ]]; then
  mkdir -p "$test_dir/tap/Formula"
  cp "$repo_dir/Formula/$package.rb" "$test_dir/tap/Formula/"
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
cmp "$repo_dir/Formula/$package.rb" "$(brew --repository "$tap")/Formula/$package.rb"
brew style --formula "$formula"
brew test "$formula"

cli_prefix=$(brew --prefix "$formula")
mkdir -p "$test_dir/fake-bin"
printf '#!/bin/sh\necho "Unexpected ambient Node executable" >&2\nexit 97\n' > "$test_dir/fake-bin/node"
chmod +x "$test_dir/fake-bin/node"
if [[ "$package" == lambdadb-migration ]]; then
  cp "$test_dir/fake-bin/node" "$test_dir/fake-bin/go"
  mkdir -p "$test_dir/home"
  # No inherited credentials or user config; a Go/Node invocation would fail.
  env -i HOME="$test_dir/home" PATH="$test_dir/fake-bin:/usr/bin:/bin" \
    "$cli_prefix/bin/$executable" --version
  env -i HOME="$test_dir/home" PATH="$test_dir/fake-bin:/usr/bin:/bin" \
    "$brew_prefix/bin/$executable" --help >/dev/null
else
  env PATH="$test_dir/fake-bin:/usr/bin:/bin" "$cli_prefix/bin/$executable" --version
fi
echo "Verified $formula ($mode) on $(uname -sm): installation, formula equality, style, smoke and runtime selection."
