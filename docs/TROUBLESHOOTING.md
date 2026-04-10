# Troubleshooting

## `rtk` command not found

Ensure your install path is on `PATH`.

```bash
rtk --version
rtk --help
```

## Hook rewrite not happening

Re-run setup:

```bash
rtk init -g
```

Then restart your agent tool.
