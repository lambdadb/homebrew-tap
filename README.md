# LambdaDB Homebrew tap

Homebrew formulae for LambdaDB tools on macOS and Linux.

## Install

With [Homebrew](https://brew.sh/) installed:

```sh
brew install lambdadb/tap/lambdadb-cli
lambdadb --version
lambdadb --help
```

Homebrew adds this tap automatically and installs the required Node 24 runtime.
The CLI wrapper selects that runtime even if another Node is active. Follow any
formula trust prompt from Homebrew; whole-tap trust is not required.

| Formula | Executable | Source and usage |
| --- | --- | --- |
| `lambdadb-cli` | `lambdadb` | [LambdaDB CLI](https://github.com/lambdadb/lambdadb-cli) |

This tap tracks stable versions. npm `dev` and `rc` builds remain available from
the CLI package's npm channels. Additional LambdaDB tools can be added as separate
formulae after their distribution artifacts and installation checks are ready.

If another installation already provides `lambdadb`, check `command -v lambdadb`
before switching package managers. Do not force-overwrite an existing executable.
Homebrew may install or upgrade dependencies needed by Node.

## Update and remove

```sh
brew update
brew upgrade lambdadb/tap/lambdadb-cli
brew uninstall lambdadb/tap/lambdadb-cli
```

After removing all tools from this tap, optionally run `brew untap lambdadb/tap`.

## Maintainers

Use feature branches and pull requests targeting `main`. Both macOS and Linux
installation checks and one review are required for normal merges. The tap has
no separate development release channel and does not publish npm packages.

The CLI formula installs the published JavaScript tarball and separately fetches
the matching lockfile from the immutable release commit. Both downloads have
SHA-256 checksums. Production dependencies use `npm ci --omit=dev --ignore-scripts`
inside `libexec`; installation does not rebuild the CLI or run npm lifecycle scripts.

For stable CLI updates:

1. Finish and verify the npm stable release, including provenance and a clean
   consumer install.
2. Prepare and review the formula in the
   [CLI maintainer guide](https://github.com/lambdadb/lambdadb-cli/tree/develop/packaging/homebrew#readme).
   Update the npm tarball URL/checksum and release lockfile commit/checksum together.
3. Copy the exact reviewed formula into a PR here. Run local checks and pass both
   hosted installation jobs before merging. No cross-repository token is needed.
4. After merging, verify the remote-install jobs and an existing consumer's
   `brew update` / `brew upgrade`. Initial installation does not establish upgrade
   behavior between two distinct versions.

Use a formula `revision` for packaging-only corrections where appropriate. Never
rewrite a published npm version or release tag. Future formulae must include their
own installation tests and be added to CI before publication.

## Installation checks

```sh
bash scripts/test-install.sh local
# After publication, from a checkout matching the public formula:
bash scripts/test-install.sh remote
```

PRs test the checked-out formula through a disposable local tap. Pushes to `main`
and manual workflow runs install from the actual public tap and compare the
installed formula with the checkout. A concurrent formula update can make that
comparison fail; verify the latest main run rather than bypassing the check.

Checks cover formula style, installation, CLI version, JSON configuration, file
permissions, and runtime selection with an unusable ambient Node. They require
no LambdaDB credentials and make no LambdaDB API calls. The CLI repository also
tests the stable release's full CLI contracts against its Homebrew installation.

The script refuses an existing Homebrew CLI or prefix executable; remote mode
also refuses an existing `lambdadb/tap`. It removes only its test installation and
tap on completion or ordinary failure. Dependencies and caches remain; automatic
cleanup and autoremove are disabled. Use a fresh runner for complete isolation.
An interrupted process can leave resources requiring manual inspection.

## License

[Apache-2.0](LICENSE).
