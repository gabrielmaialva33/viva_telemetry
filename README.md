<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12,14,30&height=200&section=header&text=viva_telemetry&fontSize=60&fontColor=fff&animation=fadeIn&fontAlignY=35&desc=Observability%20for%20Gleam&descSize=18&descAlignY=55" width="100%"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Gleam-FFAFF3?logo=gleam&logoColor=000" alt="Gleam"/>
  <a href="https://github.com/gabrielmaialva33/viva_telemetry/actions"><img src="https://github.com/gabrielmaialva33/viva_telemetry/workflows/CI/badge.svg" alt="CI"/></a>
  <a href="https://hex.pm/packages/viva_telemetry"><img src="https://img.shields.io/hexpm/v/viva_telemetry" alt="Hex"/></a>
  <a href="https://hexdocs.pm/viva_telemetry"><img src="https://img.shields.io/badge/hex-docs-ffaff3" alt="Docs"/></a>
  <img src="https://img.shields.io/github/license/gabrielmaialva33/viva_telemetry" alt="License"/>
</p>

<p align="center">
  <b>Professional observability suite for Gleam</b><br/>
  <sub>Structured logging, metrics collection, and statistical benchmarking</sub>
</p>

---

## Install

```sh
gleam add viva_telemetry@1
```

## Use

```gleam
import viva_telemetry/log
import viva_telemetry/metrics
import viva_telemetry/bench

pub fn main() {
  // Logging - one import setup!
  log.configure_console(log.debug_level)
  log.info("Server started", [#("port", "8080")])

  // Metrics
  let requests = metrics.counter("http_requests")
  metrics.inc(requests)

  // Benchmarking
  bench.run("my_function", fn() { heavy_work() })
  |> bench.print()
}
```

## Features

```
┌─────────────────────────────────────────────────────────────────┐
│                      viva_telemetry                             │
├─────────────────┬─────────────────┬─────────────────────────────┤
│      LOG        │     METRICS     │           BENCH             │
├─────────────────┼─────────────────┼─────────────────────────────┤
│ RFC 5424 Levels │ Counter         │ Statistical Analysis        │
│ Multiple Handlers│ Gauge          │ Confidence Intervals        │
│ Context Propagation│ Histogram    │ Comparison (speedup)        │
│ Lazy Evaluation │ BEAM Memory     │ Export JSON/CSV/Markdown    │
│ Sampling        │ Prometheus      │ Regression Detection        │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

## Logging

```gleam
// Quick setup (one import!)
log.configure_console(log.debug_level)

// Structured logging
log.info("User logged in", [#("user_id", "42"), #("ip", "192.168.1.1")])

// Context propagation
log.with_context([#("request_id", "abc123")], fn() {
  log.debug("Processing...")  // inherits request_id
})

// Lazy evaluation - avoid string construction when disabled
log.debug_lazy(fn() { "Heavy: " <> expensive_to_string(data) }, [])

// Sampling for high-volume logs (1% of messages)
log.sampled(log.trace_level, 0.01, "Hot path", [])
```

### Handlers

```gleam
log.configure_console(log.info_level)           // Console only
log.configure_json("app.jsonl", log.debug_level) // JSON file
log.configure_full(log.debug_level, "app.jsonl", log.info_level) // Both
```

## Metrics

```gleam
// Counter (monotonically increasing)
let requests = metrics.counter("http_requests_total")
metrics.inc(requests)
metrics.inc_by(requests, 5)

// Gauge (can go up or down)
let connections = metrics.gauge("active_connections")
metrics.set(connections, 42.0)
metrics.gauge_inc(connections)

// Histogram (distribution)
let latency = metrics.histogram("latency_ms", [10.0, 50.0, 100.0, 500.0])
metrics.observe(latency, 75.5)

// Time a function automatically
let result = metrics.time_ms(latency, fn() { do_work() })

// BEAM memory tracking
let mem = metrics.beam_memory()

// Export Prometheus format
io.println(metrics.to_prometheus())
```

## Benchmarking

```gleam
// Simple benchmark
bench.run("fib_recursive", fn() { fib(30) })
|> bench.print()

// Compare implementations
let slow = bench.run("v1", fn() { algo_v1() })
let fast = bench.run("v2", fn() { algo_v2() })
bench.compare(slow, fast)
|> bench.print_comparison()
// → v1 vs v2: 2.3x faster 🚀

// Export results
bench.to_json(result)
bench.to_markdown(result)
```

### Statistics

Each benchmark includes: **mean**, **stddev**, **min/max**, **p50/p95/p99**, **IPS**, **95% CI**

## Build

```sh
make test   # Run 32 tests
make bench  # Run benchmarks
make docs   # Generate documentation
```

Or directly:

```sh
gleam test
gleam docs build
```

## Part of VIVA

```
VIVA - Sentient Digital Life
├── viva_math      → Mathematical foundations
├── viva_emotion   → PAD emotional dynamics
├── viva_tensor    → Tensor compression (INT8/NF4/AWQ)
├── viva_aion      → Time perception
├── viva_glyph     → Symbolic language
└── viva_telemetry → Observability (this package)
```

## Inspired By

- **Logging**: [structlog](https://structlog.org/) (Python), [zap](https://github.com/uber-go/zap) (Go), [tracing](https://tracing.rs/) (Rust)
- **Metrics**: Prometheus, BEAM telemetry
- **Benchmarking**: criterion (Rust), benchee (Elixir)

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12,14,30&height=100&section=footer" width="100%"/>
</p>

<p align="center">
  <sub>Built with pure Gleam for the BEAM</sub>
</p>
