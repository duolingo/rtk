# Installation

## Cargo

```bash
cargo install --git https://github.com/duolingo/rtk
```

## From a local checkout

```bash
cargo install --path . --force
```

## Installer script

The installer targets this fork (`duolingo/rtk`). It first tries to download a release asset, then falls back to `cargo install --git` if no matching release asset is available.

```bash
curl -fsSL https://raw.githubusercontent.com/duolingo/rtk/refs/heads/master/install.sh | sh
```

## Homebrew

This fork does not currently publish a Homebrew tap/formula. Avoid `brew install rtk`: it may install an unrelated or upstream package.

## Verify

```bash
rtk --version
rtk --help
```

## Initialize hooks

```bash
rtk init -g
```

## Smoke test

```bash
rtk git status
rtk ls
```
