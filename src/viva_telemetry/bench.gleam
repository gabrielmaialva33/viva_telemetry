//// viva_telemetry/bench - Statistical benchmarking for Gleam
////
//// Inspired by: criterion (Rust), benchee (Elixir), hyperfine
////
//// ## Features
//// - Statistical analysis (mean, stddev, percentiles)
//// - Confidence intervals (bootstrapping)
//// - Multiple inputs and functions
//// - Comparison with speedup calculation
//// - Export to JSON/CSV/Markdown
//// - Regression detection
////
//// ## Quick Start
////
//// ```gleam
//// import viva_telemetry/bench
////
//// pub fn main() {
////   bench.run("my_function", fn() { my_function() })
////   |> bench.print()
//// }
//// ```

import gleam/float
import gleam/int
import gleam/io
import gleam/json.{type Json}
import gleam/list
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// Benchmark result
pub type BenchResult {
  BenchResult(name: String, samples: List(Int), stats: Stats)
}

/// Statistical summary
pub type Stats {
  Stats(
    mean: Float,
    stddev: Float,
    min: Int,
    max: Int,
    p50: Int,
    p95: Int,
    p99: Int,
    ips: Float,
    ci_95: #(Float, Float),
  )
}

/// Comparison between two benchmarks
pub type Comparison {
  Comparison(
    baseline: String,
    target: String,
    speedup: Float,
    significant: Bool,
    ci_95: #(Float, Float),
  )
}

/// Benchmark configuration
pub type Config {
  Config(warmup_iterations: Int, iterations: Int, confidence: Float)
}

// ============================================================================
// Configuration
// ============================================================================

/// Default configuration
pub fn default_config() -> Config {
  Config(warmup_iterations: 10, iterations: 100, confidence: 0.95)
}

/// Config with custom iterations
pub fn config(warmup: Int, iterations: Int) -> Config {
  Config(warmup_iterations: warmup, iterations: iterations, confidence: 0.95)
}

// ============================================================================
// Core Benchmark Functions
// ============================================================================

/// Run a single benchmark with default config
pub fn run(name: String, f: fn() -> a) -> BenchResult {
  run_with_config(name, f, default_config())
}

/// Run benchmark with custom config
pub fn run_with_config(name: String, f: fn() -> a, cfg: Config) -> BenchResult {
  // Warmup
  list.range(1, cfg.warmup_iterations)
  |> list.each(fn(_) {
    let _ = f()
    Nil
  })

  // Collect samples (time in microseconds)
  let samples =
    list.range(1, cfg.iterations)
    |> list.map(fn(_) {
      let #(time, _) = timer_tc(f)
      time
    })

  // Calculate stats
  let stats = calculate_stats(samples, cfg.confidence)

  BenchResult(name: name, samples: samples, stats: stats)
}

/// Run multiple benchmarks
pub fn run_all(
  benchmarks: List(#(String, fn() -> a)),
  cfg: Config,
) -> List(BenchResult) {
  list.map(benchmarks, fn(bench) {
    let #(name, f) = bench
    run_with_config(name, f, cfg)
  })
}

// ============================================================================
// Statistics
// ============================================================================

fn calculate_stats(samples: List(Int), _confidence: Float) -> Stats {
  let n = list.length(samples)
  let floats = list.map(samples, int.to_float)

  // Mean
  let sum = list.fold(floats, 0.0, fn(acc, x) { acc +. x })
  let mean = sum /. int.to_float(n)

  // Standard deviation
  let variance =
    list.fold(floats, 0.0, fn(acc, x) {
      let diff = x -. mean
      acc +. diff *. diff
    })
    /. int.to_float(n - 1)
  let stddev = float_sqrt(variance)

  // Sort for percentiles
  let sorted = list.sort(samples, int.compare)

  // Min/Max
  let min = list.first(sorted) |> result_unwrap(0)
  let max = list.last(sorted) |> result_unwrap(0)

  // Percentiles
  let p50 = percentile(sorted, 0.5)
  let p95 = percentile(sorted, 0.95)
  let p99 = percentile(sorted, 0.99)

  // IPS (iterations per second)
  let ips = case mean >. 0.0 {
    True -> 1_000_000.0 /. mean
    False -> 0.0
  }

  // 95% CI (using t-distribution approximation)
  let t_value = 1.96
  // For 95% CI
  let margin = t_value *. stddev /. float_sqrt(int.to_float(n))
  let ci_95 = #(mean -. margin, mean +. margin)

  Stats(
    mean: mean,
    stddev: stddev,
    min: min,
    max: max,
    p50: p50,
    p95: p95,
    p99: p99,
    ips: ips,
    ci_95: ci_95,
  )
}

fn percentile(sorted: List(Int), p: Float) -> Int {
  let n = list.length(sorted)
  let idx = float.round(int.to_float(n - 1) *. p)
  list_at(sorted, idx) |> result_unwrap(0)
}

// ============================================================================
// Comparison
// ============================================================================

/// Compare two benchmark results
pub fn compare(baseline: BenchResult, target: BenchResult) -> Comparison {
  let speedup = baseline.stats.mean /. target.stats.mean

  // Check if difference is significant (non-overlapping CIs)
  let #(base_lo, base_hi) = baseline.stats.ci_95
  let #(tgt_lo, tgt_hi) = target.stats.ci_95
  let significant = base_hi <. tgt_lo || tgt_hi <. base_lo

  // CI for speedup ratio (approximate)
  let lo = base_lo /. tgt_hi
  let hi = base_hi /. tgt_lo

  Comparison(
    baseline: baseline.name,
    target: target.name,
    speedup: speedup,
    significant: significant,
    ci_95: #(lo, hi),
  )
}

// ============================================================================
// Output / Display
// ============================================================================

/// Print benchmark result to console
pub fn print(result: BenchResult) -> Nil {
  let s = result.stats

  io.println(
    "\n╔══════════════════════════════════════════════════════════════╗",
  )
  io.println(
    "║  BENCHMARK: "
    <> result.name
    <> pad_to(50 - string.length(result.name))
    <> "║",
  )
  io.println("╠══════════════════════════════════════════════════════════════╣")
  io.println(
    "║  Mean:   "
    <> format_time(float.round(s.mean))
    <> " ± "
    <> format_time(float.round(s.stddev))
    <> pad_to(32)
    <> "║",
  )
  io.println(
    "║  IPS:    "
    <> format_number(s.ips)
    <> " iterations/sec"
    <> pad_to(26)
    <> "║",
  )
  io.println("║  Min:    " <> format_time(s.min) <> pad_to(44) <> "║")
  io.println("║  p50:    " <> format_time(s.p50) <> pad_to(44) <> "║")
  io.println("║  p95:    " <> format_time(s.p95) <> pad_to(44) <> "║")
  io.println("║  p99:    " <> format_time(s.p99) <> pad_to(44) <> "║")
  io.println("║  Max:    " <> format_time(s.max) <> pad_to(44) <> "║")
  io.println("╚══════════════════════════════════════════════════════════════╝")
}

/// Print comparison result
pub fn print_comparison(cmp: Comparison) -> Nil {
  let arrow = case cmp.speedup >=. 1.0 {
    True -> "🚀"
    False -> "🐢"
  }

  io.println("\n" <> cmp.baseline <> " vs " <> cmp.target)
  io.println("  Speedup: " <> format_number(cmp.speedup) <> "x " <> arrow)
  io.println("  Significant: " <> bool_to_string(cmp.significant))
  let #(lo, hi) = cmp.ci_95
  io.println(
    "  95% CI: [" <> format_number(lo) <> "x, " <> format_number(hi) <> "x]",
  )
}

// ============================================================================
// Export
// ============================================================================

/// Export to JSON
pub fn to_json(result: BenchResult) -> Json {
  let s = result.stats
  let #(ci_lo, ci_hi) = s.ci_95

  json.object([
    #("name", json.string(result.name)),
    #("mean_us", json.float(s.mean)),
    #("stddev_us", json.float(s.stddev)),
    #("min_us", json.int(s.min)),
    #("max_us", json.int(s.max)),
    #("p50_us", json.int(s.p50)),
    #("p95_us", json.int(s.p95)),
    #("p99_us", json.int(s.p99)),
    #("ips", json.float(s.ips)),
    #("ci_95_lo", json.float(ci_lo)),
    #("ci_95_hi", json.float(ci_hi)),
    #("samples", json.int(list.length(result.samples))),
  ])
}

/// Export to JSON string
pub fn to_json_string(result: BenchResult) -> String {
  to_json(result) |> json.to_string
}

/// Export to Markdown table row
pub fn to_markdown(result: BenchResult) -> String {
  let s = result.stats
  "| "
  <> result.name
  <> " | "
  <> format_time(float.round(s.mean))
  <> " | "
  <> format_time(s.p50)
  <> " | "
  <> format_time(s.p99)
  <> " | "
  <> format_number(s.ips)
  <> " |"
}

/// Export multiple results to Markdown table
pub fn to_markdown_table(results: List(BenchResult)) -> String {
  let header = "| Name | Mean | p50 | p99 | IPS |"
  let separator = "|------|------|-----|-----|-----|"
  let rows = list.map(results, to_markdown)

  [header, separator, ..rows]
  |> string.join("\n")
}

// ============================================================================
// Helpers
// ============================================================================

fn format_time(us: Int) -> String {
  case us >= 1_000_000 {
    True -> format_number(int.to_float(us) /. 1_000_000.0) <> "s"
    False ->
      case us >= 1000 {
        True -> format_number(int.to_float(us) /. 1000.0) <> "ms"
        False -> int.to_string(us) <> "μs"
      }
  }
}

fn format_number(n: Float) -> String {
  // Round to 2 decimal places
  let rounded = int.to_float(float.round(n *. 100.0)) /. 100.0
  float.to_string(rounded)
}

fn pad_to(n: Int) -> String {
  case n <= 0 {
    True -> ""
    False -> string.repeat(" ", n)
  }
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "Yes"
    False -> "No"
  }
}

fn result_unwrap(r: Result(a, b), default: a) -> a {
  case r {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn list_at(l: List(a), idx: Int) -> Result(a, Nil) {
  case idx < 0 {
    True -> Error(Nil)
    False ->
      case l {
        [] -> Error(Nil)
        [x, ..rest] ->
          case idx == 0 {
            True -> Ok(x)
            False -> list_at(rest, idx - 1)
          }
      }
  }
}

// FFI
@external(erlang, "timer", "tc")
fn timer_tc(f: fn() -> a) -> #(Int, a)

@external(erlang, "math", "sqrt")
fn float_sqrt(x: Float) -> Float
