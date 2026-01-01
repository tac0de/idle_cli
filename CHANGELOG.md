## 0.1.0

- Initial public release.
- JSON-only CLI commands: `create`, `tick`, `analyze`, `save`, `load`, `help`.
- Composable stdin/stdout workflow: commands accept snapshot JSON or `{snapshot: ...}` output.
- Deterministic save/load via `idle_save` envelope with canonical JSON encoding.
- Improved UX for automation: tolerant stdin parsing (handles leading `dart run` logs) and `--debug` for stack traces.
