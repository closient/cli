#!/bin/sh
# Install the closient CLI on macOS or Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/closient/cli/main/install.sh | sh
#
# Downloads the latest release from https://github.com/closient/cli, verifies
# it against the release's SHA256SUMS, and installs the binary to
# ~/.local/bin. Never uses sudo; nothing is installed if any step fails.
#
# Environment:
#   CLOSIENT_INSTALL_DIR   install here instead of ~/.local/bin
#   CLOSIENT_VERSION       install this version (e.g. 0.1.0) instead of the latest
#   CLOSIENT_RELEASES_URL  release host (default https://github.com/closient/cli/releases)
#
# POSIX sh: no bashisms, so it runs under dash, ash and macOS /bin/sh alike.
# Everything runs inside main(), called on the last line, so a download cut
# short part-way through runs nothing at all.

set -eu

say() { printf 'closient-install: %s\n' "$*" >&2; }
fail() {
  say "error: $*"
  exit 1
}

detect_target() {
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
  Darwin)
    # A shell under Rosetta reports x86_64 on Apple silicon; take the
    # native build there.
    if [ "$arch" = x86_64 ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
      arch=arm64
    fi
    case "$arch" in
    arm64 | aarch64) echo aarch64-apple-darwin ;;
    x86_64) echo x86_64-apple-darwin ;;
    *) fail "unsupported macOS architecture: $arch" ;;
    esac
    ;;
  Linux)
    case "$arch" in
    x86_64 | amd64) echo x86_64-unknown-linux-musl ;;
    aarch64 | arm64) echo aarch64-unknown-linux-musl ;;
    *) fail "unsupported Linux architecture: $arch" ;;
    esac
    ;;
  MINGW* | MSYS* | CYGWIN*)
    fail "on Windows, run in PowerShell: irm https://raw.githubusercontent.com/closient/cli/main/install.ps1 | iex"
    ;;
  *) fail "unsupported operating system: $os" ;;
  esac
}

# HTTPS only, redirects included, unless CLOSIENT_RELEASES_URL is a plain
# http:// mirror (a local test server). A wget that cannot promise that
# (BusyBox's, for one) is refused rather than trusted.
download() { # url destination
  if command -v curl >/dev/null 2>&1; then
    curl --proto "$protocols" -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    if [ "$protocols" = '=https' ]; then
      wget --help 2>&1 | grep -q -- --https-only ||
        fail "this wget cannot be limited to HTTPS (no --https-only); install curl and re-run"
      wget --https-only -q -O "$2" "$1"
    else
      wget -q -O "$2" "$1"
    fi
  else
    fail "curl or wget is required"
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  else
    fail "sha256sum or shasum is required to verify the download"
  fi
}

main() {
  RELEASES_URL="${CLOSIENT_RELEASES_URL:-https://github.com/closient/cli/releases}"
  INSTALL_DIR="${CLOSIENT_INSTALL_DIR:-${HOME:?HOME is not set}/.local/bin}"
  VERSION="${CLOSIENT_VERSION:-}"
  VERSION="${VERSION#v}"
  case "$RELEASES_URL" in
  http://*) protocols='=http,https' ;;
  *) protocols='=https' ;;
  esac

  target=$(detect_target)
  work=$(mktemp -d 2>/dev/null || mktemp -d -t closient-install)
  staged=""
  trap 'rm -rf "$work" ${staged:+"$staged"}' EXIT INT TERM

  if [ -n "$VERSION" ]; then
    sums_url="$RELEASES_URL/download/v$VERSION/SHA256SUMS"
  else
    sums_url="$RELEASES_URL/latest/download/SHA256SUMS"
  fi
  download "$sums_url" "$work/SHA256SUMS" || fail "could not download $sums_url"

  # One line per archive: "<sha256>  closient-<version>-<target>.tar.gz".
  line=$(grep -E "^[0-9a-f]{64}  closient-[^ ]+-$target\.tar\.gz\$" "$work/SHA256SUMS" | head -n 1 || true)
  [ -n "$line" ] || fail "no $target build in $sums_url"
  expected=${line%% *}
  archive=${line##* }
  version=${archive#closient-}
  version=${version%-"$target".tar.gz}

  say "downloading closient $version for $target"
  download "$RELEASES_URL/download/v$version/$archive" "$work/$archive" ||
    fail "could not download $archive"

  actual=$(sha256_of "$work/$archive")
  if [ "$actual" != "$expected" ]; then
    fail "checksum mismatch for $archive (expected $expected, got $actual); nothing was installed"
  fi

  tar -xzf "$work/$archive" -C "$work"
  binary="$work/closient-$version-$target/closient"
  [ -f "$binary" ] || fail "$archive does not contain closient"

  mkdir -p "$INSTALL_DIR" || fail "cannot create $INSTALL_DIR; set CLOSIENT_INSTALL_DIR to a directory you can write"
  [ -w "$INSTALL_DIR" ] || fail "$INSTALL_DIR is not writable; set CLOSIENT_INSTALL_DIR to a directory you can write"

  # Copy next to the destination, then rename: a rename within one directory
  # is atomic, so a running closient is never left half-written.
  staged="$INSTALL_DIR/.closient.install.$$"
  cp "$binary" "$staged"
  chmod 755 "$staged"
  mv -f "$staged" "$INSTALL_DIR/closient"

  say "installed closient $version to $INSTALL_DIR/closient"

  case ":${PATH:-}:" in
  *":$INSTALL_DIR:"*)
    found=$(command -v closient 2>/dev/null || true)
    if [ -n "$found" ] && [ "$found" != "$INSTALL_DIR/closient" ]; then
      say "note: $found comes first on your PATH and will run instead"
    fi
    ;;
  *)
    say "$INSTALL_DIR is not on your PATH. Add it to your shell profile:"
    say "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
  esac
  say "run 'closient --help' to get started, and 'closient update' to upgrade later"
}

main "$@"
