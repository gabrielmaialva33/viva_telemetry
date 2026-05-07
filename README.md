# viva_telemetry

[![Package Version](https://img.shields.io/hexpm/v/viva_telemetry)](https://hex.pm/packages/viva_telemetry)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/viva_telemetry/)
[![CI](https://github.com/gabrielmaialva33/viva_telemetry/workflows/CI/badge.svg)](https://github.com/gabrielmaialva33/viva_telemetry/actions)

Observability for Gleam applications running on the BEAM.

`viva_telemetry` gives you structured logging, in-memory metrics, Prometheus
export, BEAM memory visibility, and small statistical benchmarks without
forcing a large framework into your application.

## Installation

```sh
gleam add viva_telemetry@1
```

## Quick Start

```gleam
import viva_telemetry/bench
import viva_telemetry/log
import viva_telemetry/metrics

pub fn main() {
  // Production on the BEAM: forward structured reports to Erlang's :logger.
  // Use log.configure_console(log.debug_level) for local console output.
  log.configure_erlang(log.info_level)
  log.info("Server started", [#("port", "8080")])

  let requests = metrics.counter("http_requests_total")
  metrics.inc(requests)

  bench.run("my_function", fn() { heavy_work() })
  |> bench.print()
}
```

## What It Provides

| Module | Purpose | Highlights |
| ------ | ------- | ---------- |
| `viva_telemetry/log` | Structured application logs | RFC 5424-style levels, context, lazy logs, sampling, console, JSON file, custom handlers, Erlang `:logger` forwarding |
| `viva_telemetry/metrics` | Runtime metrics | Counters, gauges, histograms, BEAM memory, Prometheus text export |
| `viva_telemetry/bench` | Local statistical benchmarks | Warmup, samples, mean, standard deviation, percentiles, IPS, JSON and Markdown output |

## Architecture

The package is intentionally split into three independent surfaces:

| Area | Data Flow | Storage |
| ---- | --------- | ------- |
| Logging | log call -> entry -> handlers | process-local configuration and context |
| Metrics | metric handle -> update -> export | ETS tables |
| Benchmarks | function -> timed samples -> statistics | in-memory result values |

For production logging on the BEAM, prefer `log.configure_erlang/1`. It keeps
the Gleam API small while letting Erlang's built-in logger handle the runtime
concerns it already owns.

## Logging

### Configure Handlers

```gleam
import viva_telemetry/log

// Recommended on the BEAM
log.configure_erlang(log.info_level)

// Useful during local development
log.configure_console(log.debug_level)

// JSON lines file
log.configure_json("app.jsonl", log.info_level)

// Console + JSON file
log.configure_full(log.debug_level, "app.jsonl", log.info_level)
```

### Structured Logs

```gleam
log.info("User logged in", [
  #("user_id", "42"),
  #("ip", "192.168.1.1"),
])
```

### Named Loggers

Named loggers are immutable values with persistent fields. They are useful for
passing request, actor, or subsystem context through your own code.

```gleam
let logger =
  log.logger("app.http")
  |> log.with_field("request_id", "abc123")
  |> log.with_int("attempt", 1)

logger
|> log.logger_info_with("Request completed", [#("status", "200")])
```

### Context, Lazy Logs, And Sampling

```gleam
log.with_context([#("request_id", "abc123")], fn() {
  log.debug("Processing request", [])
})

log.debug_lazy(fn() { "expensive value: " <> expensive_to_string(data) }, [])

log.sampled(log.trace_level, 0.01, "Hot path", [])
```

## Metrics

### Counters

Counters are monotonically increasing. Negative or zero increments are ignored;
use a gauge for values that can go down.

```gleam
let requests = metrics.counter("http_requests_total")
metrics.inc(requests)
metrics.inc_by(requests, 5)
```

### Gauges

```gleam
let connections = metrics.gauge("active_connections")
metrics.set(connections, 42.0)
metrics.gauge_inc(connections)
metrics.gauge_dec(connections)
metrics.gauge_add(connections, 8.0)
```

### Histograms

Histogram buckets are sorted when the histogram is created. Prometheus export
uses the standard `_bucket{le="..."}`, `_sum`, and `_count` series.

```gleam
let latency =
  metrics.histogram_with_labels("request_duration_seconds", [0.1, 0.5, 1.0], [
    #("route", "/users"),
  ])

metrics.observe(latency, 0.25)
```

### Timing Functions

```gleam
let result = metrics.time_ms(latency, fn() { do_work() })
```

### Prometheus Export

```gleam
io.println(metrics.to_prometheus())
```

Example output:

```text
request_duration_seconds_bucket{le="0.5",route="/users"} 1
request_duration_seconds_bucket{le="+Inf",route="/users"} 1
request_duration_seconds_sum{route="/users"} 0.25
request_duration_seconds_count{route="/users"} 1
# TYPE beam_memory_total_bytes gauge
beam_memory_total_bytes 12345678
```

## Benchmarks

```gleam
import viva_telemetry/bench

bench.run("fib_recursive", fn() { fib(30) })
|> bench.print()
```

Compare two implementations:

```gleam
let slow = bench.run("v1", fn() { algo_v1() })
let fast = bench.run("v2", fn() { algo_v2() })

bench.compare(slow, fast)
|> bench.print_comparison()
```

Export benchmark results:

```gleam
bench.to_json(result)
bench.to_json_string(result)
bench.to_markdown(result)
bench.to_markdown_table([result])
```

## Development

```sh
make test     # Run tests
make bench    # Run benchmark example
make log      # Run logging example
make metrics  # Run metrics example
make docs     # Generate HexDocs locally
```

Local verification:

```sh
gleam format --check src test
gleam test
gleam docs build
```

## Design Notes

- Logging integrates with Erlang `:logger` for production use on the BEAM.
- Metrics use ETS-backed storage and atomic counter updates.
- Prometheus output avoids custom diagram or JavaScript rendering, so it is
  readable on HexDocs, Hex preview, GitHub, and terminals.
- Benchmarks are intended for quick local comparisons, not replacement for a
  full profiler.

## VIVA Ecosystem

| Package | Purpose |
| ------- | ------- |
| `viva_math` | Mathematical foundations |
| `viva_emotion` | PAD emotional dynamics |
| `viva_tensor` | Tensor compression |
| `viva_aion` | Time perception |
| `viva_glyph` | Symbolic language |
| `viva_telemetry` | Observability |

## Inspiration

- Logging: Erlang `:logger`, glimt, glog, structlog, zap, tracing
- Metrics: Prometheus and BEAM telemetry conventions
- Benchmarking: criterion, benchee, hyperfine
