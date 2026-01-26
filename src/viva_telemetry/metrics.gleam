//// viva_telemetry/metrics - Metrics collection for Gleam
////
//// Inspired by: Prometheus, statsd, BEAM telemetry
////
//// ## Features
//// - Counters (monotonically increasing)
//// - Gauges (point-in-time values)
//// - Histograms (distribution of values)
//// - BEAM memory tracking
//// - Prometheus export format
////
//// ## Quick Start
////
//// ```gleam
//// import viva_telemetry/metrics
////
//// pub fn main() {
////   // Counter
////   let requests = metrics.counter("http_requests_total")
////   metrics.inc(requests)
////
////   // Gauge
////   let connections = metrics.gauge("active_connections")
////   metrics.set(connections, 42.0)
////
////   // Histogram
////   let latency = metrics.histogram("request_latency_ms", [10.0, 50.0, 100.0, 500.0])
////   metrics.observe(latency, 75.5)
////
////   // Export
////   let output = metrics.to_prometheus()
//// }
//// ```

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// A counter metric (monotonically increasing)
pub type Counter {
  Counter(name: String, labels: Dict(String, String))
}

/// A gauge metric (can go up or down)
pub type Gauge {
  Gauge(name: String, labels: Dict(String, String))
}

/// A histogram metric (distribution of values)
pub type Histogram {
  Histogram(name: String, buckets: List(Float), labels: Dict(String, String))
}

/// BEAM memory info
pub type BeamMemory {
  BeamMemory(
    total: Int,
    processes: Int,
    processes_used: Int,
    system: Int,
    atom: Int,
    atom_used: Int,
    binary: Int,
    code: Int,
    ets: Int,
  )
}

// ============================================================================
// Counter
// ============================================================================

/// Create a new counter
pub fn counter(name: String) -> Counter {
  Counter(name: name, labels: dict.new())
}

/// Create a counter with labels
pub fn counter_with_labels(
  name: String,
  labels: List(#(String, String)),
) -> Counter {
  Counter(name: name, labels: dict.from_list(labels))
}

/// Increment counter by 1
pub fn inc(counter: Counter) -> Nil {
  inc_by(counter, 1)
}

/// Increment counter by value
pub fn inc_by(counter: Counter, value: Int) -> Nil {
  let key = counter_key(counter)
  let current = get_counter_value(key)
  set_counter_value(key, current + value)
}

/// Get counter value
pub fn get_counter(counter: Counter) -> Int {
  get_counter_value(counter_key(counter))
}

fn counter_key(counter: Counter) -> String {
  counter.name <> labels_to_string(counter.labels)
}

// ============================================================================
// Gauge
// ============================================================================

/// Create a new gauge
pub fn gauge(name: String) -> Gauge {
  Gauge(name: name, labels: dict.new())
}

/// Create a gauge with labels
pub fn gauge_with_labels(name: String, labels: List(#(String, String))) -> Gauge {
  Gauge(name: name, labels: dict.from_list(labels))
}

/// Set gauge value
pub fn set(gauge: Gauge, value: Float) -> Nil {
  set_gauge_value(gauge_key(gauge), value)
}

/// Increment gauge by 1
pub fn gauge_inc(gauge: Gauge) -> Nil {
  gauge_add(gauge, 1.0)
}

/// Decrement gauge by 1
pub fn gauge_dec(gauge: Gauge) -> Nil {
  gauge_add(gauge, -1.0)
}

/// Add to gauge
pub fn gauge_add(gauge: Gauge, value: Float) -> Nil {
  let key = gauge_key(gauge)
  let current = get_gauge_value(key)
  set_gauge_value(key, current +. value)
}

/// Get gauge value
pub fn get_gauge(gauge: Gauge) -> Float {
  get_gauge_value(gauge_key(gauge))
}

fn gauge_key(gauge: Gauge) -> String {
  gauge.name <> labels_to_string(gauge.labels)
}

// ============================================================================
// Histogram
// ============================================================================

/// Create a new histogram with buckets
pub fn histogram(name: String, buckets: List(Float)) -> Histogram {
  Histogram(name: name, buckets: buckets, labels: dict.new())
}

/// Create a histogram with labels
pub fn histogram_with_labels(
  name: String,
  buckets: List(Float),
  labels: List(#(String, String)),
) -> Histogram {
  Histogram(name: name, buckets: buckets, labels: dict.from_list(labels))
}

/// Default buckets for latency (ms)
pub fn default_latency_buckets() -> List(Float) {
  [5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10_000.0]
}

/// Observe a value in the histogram
pub fn observe(histogram: Histogram, value: Float) -> Nil {
  let key = histogram_key(histogram)

  // Update sum
  let sum_key = key <> "_sum"
  let current_sum = get_gauge_value(sum_key)
  set_gauge_value(sum_key, current_sum +. value)

  // Update count
  let count_key = key <> "_count"
  let current_count = get_counter_value(count_key)
  set_counter_value(count_key, current_count + 1)

  // Update buckets
  list.each(histogram.buckets, fn(bucket) {
    case value <=. bucket {
      True -> {
        let bucket_key = key <> "_bucket_" <> float.to_string(bucket)
        let current = get_counter_value(bucket_key)
        set_counter_value(bucket_key, current + 1)
      }
      False -> Nil
    }
  })

  // Update +Inf bucket
  let inf_key = key <> "_bucket_inf"
  let inf_count = get_counter_value(inf_key)
  set_counter_value(inf_key, inf_count + 1)
}

/// Get histogram stats
pub fn get_histogram_stats(histogram: Histogram) -> #(Int, Float) {
  let key = histogram_key(histogram)
  let count = get_counter_value(key <> "_count")
  let sum = get_gauge_value(key <> "_sum")
  #(count, sum)
}

/// Time a function and record duration in histogram (microseconds)
///
/// Example:
/// ```gleam
/// let latency = metrics.histogram("request_latency_us", metrics.default_latency_buckets())
/// let result = metrics.time(latency, fn() { do_work() })
/// ```
pub fn time(histogram: Histogram, f: fn() -> a) -> a {
  let #(duration_us, result) = timer_tc(f)
  observe(histogram, int.to_float(duration_us))
  result
}

/// Time a function and record duration in histogram (milliseconds)
pub fn time_ms(histogram: Histogram, f: fn() -> a) -> a {
  let #(duration_us, result) = timer_tc(f)
  observe(histogram, int.to_float(duration_us) /. 1000.0)
  result
}

// FFI for timing
@external(erlang, "timer", "tc")
fn timer_tc(f: fn() -> a) -> #(Int, a)

fn histogram_key(histogram: Histogram) -> String {
  histogram.name <> labels_to_string(histogram.labels)
}

// ============================================================================
// BEAM Memory
// ============================================================================

/// Get current BEAM memory usage
pub fn beam_memory() -> BeamMemory {
  let mem = get_beam_memory()
  BeamMemory(
    total: dict_get_int(mem, "total"),
    processes: dict_get_int(mem, "processes"),
    processes_used: dict_get_int(mem, "processes_used"),
    system: dict_get_int(mem, "system"),
    atom: dict_get_int(mem, "atom"),
    atom_used: dict_get_int(mem, "atom_used"),
    binary: dict_get_int(mem, "binary"),
    code: dict_get_int(mem, "code"),
    ets: dict_get_int(mem, "ets"),
  )
}

fn dict_get_int(d: Dict(String, Int), key: String) -> Int {
  case dict.get(d, key) {
    Ok(v) -> v
    Error(_) -> 0
  }
}

// ============================================================================
// Export (Prometheus format)
// ============================================================================

/// Export all metrics in Prometheus text format
pub fn to_prometheus() -> String {
  let counters = get_all_counters()
  let gauges = get_all_gauges()
  let mem = beam_memory()

  let counter_lines =
    dict.to_list(counters)
    |> list.map(fn(kv) { kv.0 <> " " <> int.to_string(kv.1) })

  let gauge_lines =
    dict.to_list(gauges)
    |> list.map(fn(kv) { kv.0 <> " " <> float.to_string(kv.1) })

  let memory_lines = [
    "beam_memory_total_bytes " <> int.to_string(mem.total),
    "beam_memory_processes_bytes " <> int.to_string(mem.processes),
    "beam_memory_system_bytes " <> int.to_string(mem.system),
    "beam_memory_atom_bytes " <> int.to_string(mem.atom),
    "beam_memory_binary_bytes " <> int.to_string(mem.binary),
    "beam_memory_ets_bytes " <> int.to_string(mem.ets),
  ]

  [counter_lines, gauge_lines, memory_lines]
  |> list.flatten
  |> string.join("\n")
}

// ============================================================================
// Helpers
// ============================================================================

fn labels_to_string(labels: Dict(String, String)) -> String {
  case dict.size(labels) {
    0 -> ""
    _ -> {
      let pairs =
        dict.to_list(labels)
        |> list.map(fn(kv) { kv.0 <> "=\"" <> kv.1 <> "\"" })
        |> string.join(",")
      "{" <> pairs <> "}"
    }
  }
}

// ============================================================================
// FFI (Process Dictionary Storage)
// ============================================================================

@external(erlang, "viva_telemetry_metrics_ffi", "get_counter_value")
fn get_counter_value(key: String) -> Int

@external(erlang, "viva_telemetry_metrics_ffi", "set_counter_value")
fn set_counter_value(key: String, value: Int) -> Nil

@external(erlang, "viva_telemetry_metrics_ffi", "get_gauge_value")
fn get_gauge_value(key: String) -> Float

@external(erlang, "viva_telemetry_metrics_ffi", "set_gauge_value")
fn set_gauge_value(key: String, value: Float) -> Nil

@external(erlang, "viva_telemetry_metrics_ffi", "get_all_counters")
fn get_all_counters() -> Dict(String, Int)

@external(erlang, "viva_telemetry_metrics_ffi", "get_all_gauges")
fn get_all_gauges() -> Dict(String, Float)

@external(erlang, "viva_telemetry_metrics_ffi", "get_beam_memory")
fn get_beam_memory() -> Dict(String, Int)
