# Migration CLI packaging and maintenance

## Distribution contract

`Formula/lambdadb-migration.rb` manually pins the published stable GitHub Release
`v0.1.6`, selecting the macOS/Linux amd64/arm64 archive with the formula DSL's
`on_macos`, `on_linux`, `on_intel` and `on_arm` blocks. Every URL contains the exact
version and every archive has a SHA-256. Installation copies the released Go
executable into Homebrew's managed prefix; it does not compile source, require Go
or Node, run the standalone installer, overwrite an existing prefix executable,
or change shell startup files. Homebrew's normal link conflict handling applies.

This is a deliberately hand-maintained **third-party tap formula**, not a
`homebrew/core` submission or a GoReleaser-generated formula. It retains the tap's
formula installation/test interface and Homebrew's `test do` checks on
both operating systems. Current [Homebrew guidance](https://docs.brew.sh/Adding-Software-to-Homebrew)
recommends casks for platform-specific prebuilt binaries, and the current
[cask contract](https://docs.brew.sh/Cask-Cookbook) supports the `binary` artifact
on Linux as well as macOS. Linux incompatibility is **not** the reason for this
choice. The formula DSL remains usable in a
[custom tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap); core's
[source-build acceptance policy](https://docs.brew.sh/Acceptable-Formulae) is a
different contract. Reassess this choice if upstream removes the required DSL
support or when adopting automated signed cask distribution.

[GoReleaser's `brews` integration is deprecated](https://goreleaser.com/resources/deprecations/)
(soft since 2.10, fully since 2.16); its recommended integration is
[`homebrew_casks`](https://goreleaser.com/customization/publish/homebrew_casks/).
Neither is configured here. The existing migration GoReleaser configuration and
release workflow remain unchanged, and this initial packaging needs no new
migration release. Tap updates start as reviewed manual PRs, without cross-repo
tokens, automatic publication or a development channel.

The existing macOS arm64 binary has an ad-hoc linker signature and no Developer
ID team identifier. A successful formula installation is not proof of Apple
notarization or Gatekeeper acceptance of a browser-downloaded archive. No
quarantine-removal hook, `--no-quarantine`, trust-disable flag or security-setting
change is part of this package. If execution is blocked, preserve the failure
and report the OS, Homebrew version and message; do not bypass the check.

## Update after a stable migration release

1. Complete the normal migration GitHub Release process first. Confirm that the
   release is published, not a draft/prerelease, and inspect its immutable tag,
   build commit, four `.tar.gz` files and `checksums.txt`. Never replace release
   artifacts or rewrite a release tag to repair packaging.
2. In a feature branch from current tap `main`, update the explicit version and
   all four versioned URLs/SHA-256 values in the formula. Preserve the existing
   `lambdadb-cli` formula. Review the released command contract before adapting
   tests; the executable version must match the formula version.
3. Run `python3 scripts/verify-migration-release.py`. It checks the release's stable
   metadata, downloads **all four** archives, compares each hash with both the
   formula and `checksums.txt` (and GitHub's asset digest when present), inspects
   Mach-O/ELF architecture headers and checks for the executable/LICENSE/NOTICE.
   A checksum/header check does not establish executability on that platform.
4. Run `bash scripts/test-install.sh local lambdadb-migration` and the unchanged
   CLI contract via `bash scripts/test-install.sh local`. Review the actual
   platform printed by each run. These tests make no service requests or data
   migrations. In particular, a migration `--migration.dry-run` is not used:
   that command still reads a source service's inventory.
5. Open a PR to `main`, record the release and checksums, and require the existing
   `Homebrew macos-15` and `Homebrew ubuntu-24.04` checks plus review. Those job
   names remain unchanged for branch protection; both now test both tools.
   PR jobs use temporary local taps, not the public tap. Keep the organization
   ruleset and repository protection unchanged.
6. After an authorized maintainer merges, verify the main workflow's **remote**
   runs and run `bash scripts/test-install.sh remote lambdadb-migration` on a
   clean consumer whose checkout matches public `main`. Remote mode uses the
   fully qualified installation command, lets Homebrew add the public tap and
   compares its formula byte-for-byte with the checkout. Follow any scoped
   Homebrew trust prompt; do not disable trust or trust unrelated taps.
7. For subsequent versions, separately verify `brew update` and
   `brew upgrade lambdadb/tap/lambdadb-migration` from the previously installed
   version in a disposable consumer. Fresh installation alone is not an upgrade
   test. Record old/new versions; use a reviewed formula `revision` for
   packaging-only corrections without modifying released binaries.

## Test ownership and cleanup

The harness defaults to the existing CLI test and accepts `lambdadb-migration`
as its second argument. It refuses an existing selected package's Cellar entry
or prefix executable (including dangling symlinks), and refuses an existing
selected test tap. Remote mode refuses an existing `lambdadb/tap`. Existing
executables elsewhere on PATH are untouched; the tests use explicit Homebrew
paths and change PATH only in child processes. Formula tests use Homebrew's
temporary test home, clear relevant credential variables and write only there.

Cleanup uninstalls only the selected test package and removes only the tap it
created, on success, failure, SIGINT or SIGTERM. SIGKILL or shutdown can leave
resources; inspect them manually before removal. No broad cleanup, dependency
autoremove or user-config deletion is performed. Homebrew downloads/caches and
CLI Node dependencies remain; a fresh runner gives the strongest isolation.
Homebrew uses a temporary XDG configuration directory for this test, keeping
any formula trust records out of the user's configuration.

## Initial publication gate and evidence

Status: **pending tap PR merge and public remote installation verification**.
Do not promote the consumer installation instructions as available yet.

Merge order: review and merge the tap PR first; then verify public remote
installation on macOS/Linux. Update the pending availability text in both
repositories with that evidence before merging the migration documentation PR.
The migration documentation PR may be reviewed in parallel but should remain a
draft until the public installation gate passes. No tag or new release is needed.

Local evidence, 2026-09-19:

- Published stable `v0.1.6` resolves to source commit
  `7256838f000e7058a5264e83723f83fd4e575f88`; installed `--version` agrees.
- All four downloaded archives match the release manifest and pinned formula;
  the archive checker also validates the GitHub digests and binary headers.
- macOS arm64, Homebrew 6.0.17: local-tap installation, style, `brew test`, exact
  version, root/help for all source and inventory commands, offline URL rejection,
  and execution with unusable Go/Node passed. Test installation/tap were removed.
- Existing CLI formula installation, style, configuration/permission checks and
  Node runtime selection passed unchanged. An injected `brew test` failure still
  cleaned up only the test install/tap; a dangling prefix executable was refused
  and preserved, and a separate PATH executable was left unchanged.
- Shell syntax, Ruby syntax and actionlint 1.7.12 passed. Homebrew package/tap
  inventories before and after the tests agree.
- Hosted CI and public remote installation results must be recorded separately
  in the PR. Local success does not imply either one passed.
- macOS amd64 and Linux arm64: archive integrity/header checks only; no execution
  evidence yet. Linux amd64 execution is delegated to the existing Ubuntu CI job.
- No migration data/service writes, public tap installation, cross-version upgrade,
  security-policy changes, tag creation or release publication were performed.
