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
  <sub>Structured logging • Metrics collection • Statistical benchmarking</sub>
</p>

---

## Install

```sh
gleam add viva_telemetry@1
```

## Architecture

```mermaid
graph TB
    subgraph viva_telemetry
        direction TB
        LOG[📝 Log]
        METRICS[📊 Metrics]
        BENCH[⚡ Bench]
    end

    subgraph Handlers
        CONSOLE[🖥️ Console]
        JSON[📄 JSON File]
        FILE[📁 Plain File]
        CUSTOM[🔧 Custom]
    end

    subgraph Storage
        PROCDICT[(Process Dict)]
        ETS[(ETS Tables)]
    end

    subgraph Export
        PROM[Prometheus]
        MD[Markdown]
        CSV[JSON/CSV]
    end

    LOG --> CONSOLE
    LOG --> JSON
    LOG --> FILE
    LOG --> CUSTOM
    LOG --> PROCDICT

    METRICS --> ETS
    METRICS --> PROM

    BENCH --> MD
    BENCH --> CSV

    style LOG fill:#2E8B57,stroke:#1a5235,color:#fff
    style METRICS fill:#4169E1,stroke:#2d4a9e,color:#fff
    style BENCH fill:#CD5C5C,stroke:#8b3d3d,color:#fff
```

## Quick Start

```gleam
import viva_telemetry/log
import viva_telemetry/metrics
import viva_telemetry/bench

pub fn main() {
  // 📝 Logging - one import setup!
  log.configure_console(log.debug_level)
  log.info("Server started", [#("port", "8080")])

  // 📊 Metrics
  let requests = metrics.counter("http_requests")
  metrics.inc(requests)

  // ⚡ Benchmarking
  bench.run("my_function", fn() { heavy_work() })
  |> bench.print()
}
```

---

## 📝 Logging

```mermaid
flowchart LR
    A[Log Call] --> B{Level Check}
    B -->|Enabled| C[Build Entry]
    B -->|Disabled| X[Skip]
    C --> D[Add Context]
    D --> E[Dispatch]
    E --> F[Console]
    E --> G[JSON File]
    E --> H[Custom Handler]

    style A fill:#2E8B57,stroke:#1a5235,color:#fff
    style X fill:#CD5C5C,stroke:#8b3d3d,color:#fff
```

### Features

| Feature | Description |
|---------|-------------|
| **RFC 5424 Levels** | Emergency → Trace (9 levels) |
| **Structured Fields** | Key-value pairs with every log |
| **Context Propagation** | Inherit fields in nested calls |
| **Lazy Evaluation** | Avoid string construction when disabled |
| **Sampling** | Log only N% of high-volume messages |
| **Multiple Handlers** | Console, JSON, File, Custom |

### Usage

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

---

## 📊 Metrics

```mermaid
flowchart TB
    subgraph Types
        C[Counter]
        G[Gauge]
        H[Histogram]
    end

    subgraph Operations
        C --> INC[inc / inc_by]
        G --> SET[set / add]
        H --> OBS[observe / time]
    end

    subgraph Storage
        INC --> ETS[(ETS)]
        SET --> ETS
        OBS --> ETS
    end

    subgraph Export
        ETS --> PROM[to_prometheus]
        ETS --> BEAM[beam_memory]
    end

    style C fill:#4169E1,stroke:#2d4a9e,color:#fff
    style G fill:#4169E1,stroke:#2d4a9e,color:#fff
    style H fill:#4169E1,stroke:#2d4a9e,color:#fff
```

### Metric Types

| Type | Use Case | Operations |
|------|----------|------------|
| **Counter** | Requests, errors, events | `inc()`, `inc_by(n)` |
| **Gauge** | Connections, queue size | `set(v)`, `add(v)`, `inc()`, `dec()` |
| **Histogram** | Latency, response sizes | `observe(v)`, `time(fn)` |

### Usage

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
// → BeamMemory(total, processes, system, atom, binary, ets)

// Export Prometheus format
io.println(metrics.to_prometheus())
```

---

## ⚡ Benchmarking

```mermaid
flowchart LR
    A[Function] --> B[Warmup]
    B --> C[Collect Samples]
    C --> D[Calculate Stats]
    D --> E[Results]

    E --> F[Print]
    E --> G[to_json]
    E --> H[to_markdown]
    E --> I[Compare]

    style A fill:#CD5C5C,stroke:#8b3d3d,color:#fff
    style E fill:#2E8B57,stroke:#1a5235,color:#fff
```

### Statistics

Each benchmark calculates:

| Stat | Description |
|------|-------------|
| **mean** | Average duration |
| **stddev** | Standard deviation |
| **min/max** | Range |
| **p50** | Median (50th percentile) |
| **p95** | 95th percentile |
| **p99** | 99th percentile |
| **ips** | Iterations per second |
| **ci_95** | 95% confidence interval |

### Usage

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
bench.to_json(result)      // JSON object
bench.to_json_string(result) // JSON string
bench.to_markdown(result)  // | Name | Mean | p50 | p99 | IPS |
```

---

## Build

```sh
make test    # Run 32 tests
make bench   # Run benchmarks
make log     # Run log example
make metrics # Run metrics example
make docs    # Generate documentation
```

## Part of VIVA Ecosystem

```mermaid
graph LR
    VIVA[🧠 VIVA] --> MATH[viva_math]
    VIVA --> EMOTION[viva_emotion]
    VIVA --> TENSOR[viva_tensor]
    VIVA --> AION[viva_aion]
    VIVA --> GLYPH[viva_glyph]
    VIVA --> TELEMETRY[viva_telemetry]

    style TELEMETRY fill:#FFAFF3,stroke:#333,stroke-width:2px
```

| Package | Purpose |
|---------|---------|
| **viva_math** | Mathematical foundations |
| **viva_emotion** | PAD emotional dynamics |
| **viva_tensor** | Tensor compression (INT8/NF4/AWQ) |
| **viva_aion** | Time perception |
| **viva_glyph** | Symbolic language |
| **viva_telemetry** | Observability ← *this package* |

## Inspired By

- **Logging**: [structlog](https://structlog.org/) (Python), [zap](https://github.com/uber-go/zap) (Go), [tracing](https://tracing.rs/) (Rust)
- **Metrics**: Prometheus, BEAM telemetry
- **Benchmarking**: criterion (Rust), benchee (Elixir)

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=12,14,30&height=100&section=footer" width="100%"/>
</p>

<p align="center">
  <sub>Built with pure Gleam for the BEAM ⚗️</sub>
</p>
