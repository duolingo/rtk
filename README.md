# rtk

`rtk` is a Rust CLI proxy that filters noisy command output before it reaches an LLM.

## Scope of this fork

This fork keeps output filtering and hook integrations, and removes:

- OpenClaw integration
- outbound telemetry
- outbound telemetry/call-home behavior; local `rtk gain` stats remain local-only

## Install

### Cargo

```bash
cargo install --git https://github.com/duolingo/rtk
```

### Homebrew

```bash
brew install rtk
```

## Quick start

```bash
# Install hooks
rtk init -g

# Use filtered commands
rtk git status
rtk cargo test
rtk grep "error" .
```

## Core commands

- Files: `rtk ls`, `rtk tree`, `rtk read`, `rtk find`, `rtk grep`, `rtk diff`
- Dev tools: `rtk cargo`, `rtk npm`, `rtk pnpm`, `rtk vitest`, `rtk pytest`, `rtk go test`
- Git/GitHub: `rtk git`, `rtk gh`, `rtk gt`
- Infra: `rtk aws`, `rtk docker`, `rtk kubectl`
- Passthrough: `rtk proxy <cmd...>`

## Privacy

`rtk` in this fork does not send telemetry. Local `rtk gain` stats are stored only on disk and are never uploaded by RTK.

## Documentation

- Installation: `INSTALL.md`
- Troubleshooting: `docs/TROUBLESHOOTING.md`
- Architecture: `docs/contributing/ARCHITECTURE.md`
