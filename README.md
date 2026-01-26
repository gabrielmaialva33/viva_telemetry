<p align="center">
  <img src="https://raw.githubusercontent.com/gabrielmaialva33/viva_gleam/master/.github/assets/viva_telemetry_banner.svg" alt="viva_telemetry" width="800"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Gleam-FFAFF3?logo=gleam&logoColor=000" alt="Gleam"/>
  <a href="https://github.com/gabrielmaialva33/viva_telemetry/actions"><img src="https://github.com/gabrielmaialva33/viva_telemetry/workflows/CI/badge.svg" alt="CI"/></a>
  <a href="https://hex.pm/packages/viva_telemetry"><img src="https://img.shields.io/hexpm/v/viva_telemetry" alt="Hex"/></a>
  <a href="https://hexdocs.pm/viva_telemetry"><img src="https://img.shields.io/badge/hex-docs-ffaff3" alt="Docs"/></a>
  <img src="https://img.shields.io/github/license/gabrielmaialva33/viva_telemetry" alt="License"/>
</p>

---

# viva_telemetry

Professional observability suite for Gleam: **structured logging**, **metrics**, and **statistical benchmarking**.

Inspired by: [structlog](https://www.structlog.org/) (Python), [zap](https://github.com/uber-go/zap) (Go), [tracing](https://tracing.rs/) (Rust)

## Install

```sh
gleam add viva_telemetry@1
```

## Features

```
┌─────────────────────────────────────────────────────────────────┐
│  viva_telemetry                                                 │
├─────────────────────────────────────────────────────────────────┤
│  LOG         │  METRICS      │  BENCH                          │
│  ├─ Levels   │  ├─ Counter   │  ├─ Statistical analysis        │
│  ├─ Handlers │  ├─ Gauge     │  ├─ Confidence intervals        │
│  ├─ Context  │  ├─ Histogram │  ├─ Comparison (speedup)        │
│  ├─ Sampling │  ├─ BEAM mem  │  └─ Export (JSON/CSV/MD)        │
│  └─ Lazy     │  └─ Prometheus│                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Logging

```gleam
import viva_telemetry/log

pub fn main() {
  // Quick setup (one import!)
  log.configure_console(log.debug_level)

  // Structured logging
  log.info("Server started", [#("port", "8080")])

  // Context propagation
  log.with_context([#("request_id", "abc123")], fn() {
    log.debug("Processing request", [])
  })

  // Lazy evaluation (avoid string construction when disabled)
  log.debug_lazy(fn() { "Item: " <> expensive_to_string(data) }, [])

  // Sampling for high-volume logs
  log.sampled(log.trace_level, 0.01, "Hot path", [])
}
```

### Log Levels (RFC 5424)

| Level | Constant | Severity |
|-------|----------|----------|
| Emergency | `log.emergency_level` | 0 |
| Alert | `log.alert_level` | 1 |
| Critical | `log.critical_level` | 2 |
| Error | `log.error_level` | 3 |
| Warning | `log.warning_level` | 4 |
| Notice | `log.notice_level` | 5 |
| Info | `log.info_level` | 6 |
| Debug | `log.debug_level` | 7 |
| Trace | `log.trace_level` | 8 |

### Handlers

```gleam
import viva_telemetry/log
import viva_telemetry/log/handler

// Console only
log.configure_console(log.info_level)

// JSON file only
log.configure_json("app.jsonl", log.debug_level)

// Console + JSON
log.configure_full(log.debug_level, "app.jsonl", log.info_level)

// Custom handler
log.configure([
  handler.console_with_level(log.info_level),
  handler.json_with_level("app.jsonl", log.debug_level),
  handler.custom(log.error_level, fn(entry) { send_to_slack(entry) }),
])
```

## Metrics

```gleam
import viva_telemetry/metrics

pub fn main() {
  // Counter
  let requests = metrics.counter("http_requests_total")
  metrics.inc(requests)
  metrics.inc_by(requests, 5)

  // Gauge
  let active = metrics.gauge("active_connections")
  metrics.set(active, 42)
  metrics.inc_gauge(active)
  metrics.dec_gauge(active)

  // Histogram with custom buckets
  let latency = metrics.histogram("request_latency_ms", [10.0, 50.0, 100.0, 500.0])
  metrics.observe(latency, 75.5)

  // Time a function automatically
  let result = metrics.time_ms(latency, fn() { do_work() })

  // With labels
  let labeled = metrics.counter_with_labels("http_requests", [#("method", "GET")])

  // BEAM memory tracking
  let mem = metrics.beam_memory()
  // → Dict with total, processes, atom, binary, code, ets

  // Export Prometheus format
  io.println(metrics.to_prometheus())
}
```

## Benchmarking

```gleam
import viva_telemetry/bench

pub fn main() {
  // Simple benchmark
  let result = bench.run("fib_recursive", fn() { fib(20) })

  // With configuration
  let result = bench.run_with_config(
    "fib",
    fn() { fib(30) },
    bench.Config(warmup_ms: 500, duration_ms: 2000, confidence: 0.95),
  )

  // Compare two implementations
  let comparison = bench.compare(
    bench.Fn("recursive", fn() { fib_recursive(20) }),
    bench.Fn("iterative", fn() { fib_iterative(20) }),
  )
  // → Comparison(speedup: 2.3x, significant: True)

  // Export results
  bench.to_json(result)
  bench.to_markdown(result)
}
```

### Statistics

Each benchmark returns:

```gleam
Stats(
  mean: Float,      // Average duration
  stddev: Float,    // Standard deviation
  min: Float,       // Minimum
  max: Float,       // Maximum
  p50: Float,       // Median
  p95: Float,       // 95th percentile
  p99: Float,       // 99th percentile
  ips: Float,       // Iterations per second
  ci_95: #(Float, Float),  // 95% confidence interval
)
```

## Build

```sh
gleam build      # Build
gleam test       # Run tests (17 passing)
gleam docs build # Generate documentation
```

## Part of VIVA Ecosystem

```
VIVA - Sentient Digital Life
├── viva_math      → Mathematical foundations
├── viva_emotion   → PAD emotional dynamics
├── viva_tensor    → Tensor compression (INT8/NF4/AWQ)
├── viva_aion      → Time perception
├── viva_glyph     → Symbolic language
└── viva_telemetry → Observability (this package)
```

---

<p align="center">
  <sub>Built with pure Gleam for the BEAM</sub>
</p>
