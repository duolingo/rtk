# Architecture

Main components:

- `src/main.rs`: CLI and command routing
- `src/cmds/*`: command filters and formatters
- `src/core/*`: shared utilities (config, filtering, runner, tee)
- `src/hooks/*`: hook install and integrity checks
- `src/discover/*`: rewrite registry and parsing helpers used by hooks

Removed from this fork:

- OpenClaw integration
- telemetry sender (removed in this fork)
- analytics/tracking commands (removed in this fork)
