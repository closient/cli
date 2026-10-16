# closient CLI

`closient` is the command-line client for the [Closient API](https://docs.closient.com):
resolve GTINs through the GS1 Digital Link resolver, export label sheets, and
call every public API operation from a terminal or a script.

This repository holds the release binaries and the install scripts. Full
documentation is at [docs.closient.com/cli](https://docs.closient.com/cli).

## Install

macOS or Linux, with Homebrew:

```sh
brew install closient/tap/closient
```

macOS or Linux, without Homebrew (installs to `~/.local/bin`, no sudo):

```sh
curl -fsSL https://www.closient.com/cli/install.sh | sh
```

Windows (PowerShell, installs to `%LOCALAPPDATA%\Programs\closient`):

```powershell
irm https://www.closient.com/cli/install.ps1 | iex
```

Both scripts verify the download against the release's `SHA256SUMS` and
install nothing if it does not match. Set `CLOSIENT_INSTALL_DIR` to install
somewhere else, or `CLOSIENT_VERSION` to install a specific version.

Each [release](https://github.com/closient/cli/releases) also carries the
archives for manual download:

| Platform | Archive |
|----------|---------|
| macOS, Apple silicon | `closient-<version>-aarch64-apple-darwin.tar.gz` |
| macOS, Intel | `closient-<version>-x86_64-apple-darwin.tar.gz` |
| Linux x86_64 (static) | `closient-<version>-x86_64-unknown-linux-musl.tar.gz` |
| Linux arm64 (static) | `closient-<version>-aarch64-unknown-linux-musl.tar.gz` |
| Windows x86_64 | `closient-<version>-x86_64-pc-windows-msvc.zip` |

## Update

```sh
closient update           # download, verify and install the latest release
closient update --check   # only report whether a newer release exists
brew upgrade closient     # if you installed with Homebrew
```

`closient update` defers to Homebrew when Homebrew installed it. The CLI
also prints a one-line notice, at most once a day, when a newer release is
out. It is shown only on an interactive terminal, never when `CI` is set,
and `CLOSIENT_NO_UPDATE_NOTIFIER=1` turns it off.

## Uninstall

```sh
brew uninstall closient                  # Homebrew
rm ~/.local/bin/closient                 # install script (or your CLOSIENT_INSTALL_DIR)
rm -r ~/.config/closient                 # optional: stored logins and settings
```

On Windows, delete `%LOCALAPPDATA%\Programs\closient` and, optionally,
`%APPDATA%\closient`. Run `closient auth logout` first to revoke a stored
login on the server.

## Support

Questions and bug reports: [support@closient.com](mailto:support@closient.com).
