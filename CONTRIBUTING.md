# Contributing

Thanks for helping improve `viva_telemetry`.

This project is a Gleam observability library for structured logging, metrics,
Prometheus export, and small local benchmarks.

## Development Setup

Install Gleam and Erlang/OTP, then fetch dependencies:

```sh
gleam deps download
```

Common commands:

```sh
gleam format src test
gleam format --check src test
gleam test
gleam build
gleam docs build
```

The `Makefile` provides shortcuts:

```sh
make test
make check
make docs
make examples
```

## Project Structure

| Path | Purpose |
| ---- | ------- |
| `src/viva_telemetry/log.gleam` | Public structured logging API |
| `src/viva_telemetry/log/` | Log entries, handlers, and levels |
| `src/viva_telemetry/metrics.gleam` | Counters, gauges, histograms, Prometheus export |
| `src/viva_telemetry/bench.gleam` | Local statistical benchmarking |
| `src/*_ffi.erl` | Erlang FFI for time, logger, ETS, and BEAM runtime data |
| `src/viva_telemetry/examples/` | Runnable examples |
| `test/` | Gleeunit tests |

## Style

- Keep public APIs small and explicit.
- Prefer pure Gleam code unless Erlang FFI is needed for BEAM runtime features.
- Keep code, comments, documentation, and user-facing developer strings in English.
- Run `gleam format src test` before opening a pull request.
- Document public functions with `///` when they are part of the package API.
- Avoid adding dependencies unless they clearly simplify the library.

## Testing

Add or update tests for behavior changes.

At minimum, run:

```sh
gleam format --check src test
gleam test
gleam docs build
```

For changes to metrics, include tests for Prometheus output and reset behavior.
For logging changes, include tests for filtering, handler selection, and public
API ergonomics.

## Pull Requests

Before opening a pull request:

- explain the problem and the chosen approach;
- keep changes focused;
- include tests for behavior changes;
- update README or module docs when public APIs change;
- confirm formatting, tests, and docs generation pass.

## Releases

Releases are published to Hex from versioned tags. Before publishing, bump the
version in `gleam.toml`, update docs if needed, and run the full verification
commands.
