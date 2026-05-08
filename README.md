# viva_telemetry

Observability for Gleam applications running on the BEAM.

`viva_telemetry` gives you structured logging, in-memory metrics, Prometheus
export, BEAM memory visibility, and small statistical benchmarks without
forcing a large framework into your application.

- Package: [hex.pm/packages/viva_telemetry](https://hex.pm/packages/viva_telemetry)
- Documentation: [hexdocs.pm/viva_telemetry](https://hexdocs.pm/viva_telemetry/)
- Repository: [github.com/gabrielmaialva33/viva_telemetry](https://github.com/gabrielmaialva33/viva_telemetry)

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
  // Production on the BEAM.
  log.configure_erlang(log.info_level)
  log.info("Server started", [#("port", "8080")])

  let requests = metrics.counter("http_requests_total")
  metrics.inc(requests)

  bench.run("my_function", fn() { heavy_work() })
  |> bench.print()
}
```

## Modules

- `viva_telemetry/log` provides structured application logs, named loggers,
  context, lazy logs, sampling, console output, JSON files, custom handlers, and
  Erlang `:logger` forwarding.
- `viva_telemetry/metrics` provides counters, gauges, histograms, BEAM memory
  metrics, and Prometheus text export.
- `viva_telemetry/bench` provides small local benchmarks with warmup, samples,
  percentiles, IPS, JSON output, and Markdown output.

## Architecture

The package is intentionally split into three independent surfaces.

- Logging turns log calls into entries and dispatches them through handlers.
  Handler configuration and context are process-local.
- Metrics store counter, gauge, and histogram samples in ETS tables before
  exporting them as Prometheus text.
- Benchmarks run functions, collect timed samples, and return in-memory result
  values for printing or export.

For production logging on the BEAM, prefer `log.configure_erlang/1`. It keeps
the Gleam API small while letting Erlang's built-in logger handle the runtime
concerns it already owns.

## Logging

### Configure Handlers

```gleam
import viva_telemetry/log

// Recommended on the BEAM
log.configure_erlang(log.info_level)

// Recommended when many applications share the same runtime logger
log.configure_erlang_with_name(log.info_level, "my_app")

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
import gleam/int
import gleam/option.{Some}

let logger =
  log.logger("app.http")
  |> log.with_field("request_id", "abc123")
  |> log.with_int("attempt", 1)
  |> log.with_option("user_id", Some(42), int.to_string)

logger
|> log.logger_info_with("Request completed", [#("status", "200")])
```

Named loggers also have level-specific helpers with one-off fields:

```gleam
logger
|> log.logger_debug_with("Cache lookup", [#("cache", "user_profile")])
|> log.logger_warning_with("Retrying request", [#("retry", "2")])
|> log.logger_error_with("Request failed", [#("reason", "timeout")])
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

Use the description constructors when you want Prometheus `HELP` metadata:

```gleam
let requests =
  metrics.counter_with_labels_and_description(
    "http_requests_total",
    [#("method", "GET")],
    "Total HTTP requests.",
  )
```

### Gauges

```gleam
let connections = metrics.gauge("active_connections")
metrics.set(connections, 42.0)
metrics.gauge_inc(connections)
metrics.gauge_dec(connections)
metrics.gauge_add(connections, 8.0)
```

Gauge add, increment, and decrement operations are serialized in the FFI so
concurrent updates do not overwrite each other.

### Histograms

Histogram buckets are sorted when the histogram is created. Prometheus export
uses the standard `_bucket{le="..."}`, `_sum`, and `_count` series.

```gleam
let latency =
  metrics.histogram_with_labels_and_description(
    "request_duration_seconds",
    [0.1, 0.5, 1.0],
    [#("route", "/users")],
    "Request duration in seconds.",
  )

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
# HELP request_duration_seconds Request duration in seconds.
# TYPE request_duration_seconds histogram
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
- Logging handler configuration and `with_context` data are process-local.
  Configure each process explicitly, pass named loggers through your own call
  graph, or forward to Erlang `:logger` for runtime-wide handling.
- Metrics use ETS-backed storage, atomic counter updates, serialized gauge
  updates, and Prometheus `HELP`/`TYPE` metadata when descriptions are provided.
- Prometheus output avoids custom diagram or JavaScript rendering, so it is
  readable on HexDocs, Hex preview, GitHub, and terminals.
- Benchmarks are intended for quick local comparisons, not replacement for a
  full profiler.

## VIVA Ecosystem

- `viva_math`: mathematical foundations.
- `viva_emotion`: PAD emotional dynamics.
- `viva_tensor`: tensor compression.
- `viva_aion`: time perception.
- `viva_glyph`: symbolic language.
- `viva_telemetry`: observability.

## Inspiration

- Logging: Erlang `:logger`, glimt, glog, structlog, zap, tracing
- Metrics: Prometheus and BEAM telemetry conventions
- Benchmarking: criterion, benchee, hyperfine
