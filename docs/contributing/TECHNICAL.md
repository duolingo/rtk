# Technical Notes

`rtk` is a command proxy.

Flow:
1. Parse CLI args.
2. Route to command-specific filter module.
3. Execute underlying command.
4. Return filtered output.

This fork does not include telemetry or any call-home path. Local `rtk gain` stats remain local-only.
