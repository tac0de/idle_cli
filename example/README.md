# idle_cli example

This folder contains a minimal example that forwards arguments to the CLI
entrypoint exposed by `package:idle_cli`.

## Run

```sh
dart run example/main.dart help
dart run example/main.dart create
dart run example/main.dart create | dart run example/main.dart tick --count 10
```

For automation-friendly JSON-only stdout (no `dart run` build logs), prefer
compiling the CLI binary as shown in the package `README.md`.
