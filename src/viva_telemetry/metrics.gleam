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
  register_metric(name, "counter", "")
  Counter(name: name, labels: dict.new())
}

/// Create a new counter with Prometheus HELP text.
pub fn counter_with_description(name: String, description: String) -> Counter {
  register_metric(name, "counter", description)
  Counter(name: name, labels: dict.new())
}

/// Create a counter with labels
pub fn counter_with_labels(
  name: String,
  labels: List(#(String, String)),
) -> Counter {
  register_metric(name, "counter", "")
  Counter(name: name, labels: dict.from_list(labels))
}

/// Create a labeled counter with Prometheus HELP text.
pub fn counter_with_labels_and_description(
  name: String,
  labels: List(#(String, String)),
  description: String,
) -> Counter {
  register_metric(name, "counter", description)
  Counter(name: name, labels: dict.from_list(labels))
}

/// Increment counter by 1
pub fn inc(counter: Counter) -> Nil {
  inc_by(counter, 1)
}

/// Increment counter by value
pub fn inc_by(counter: Counter, value: Int) -> Nil {
  case value <= 0 {
    True -> Nil
    False -> add_counter_value(counter_key(counter), value)
  }
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
  register_metric(name, "gauge", "")
  Gauge(name: name, labels: dict.new())
}

/// Create a new gauge with Prometheus HELP text.
pub fn gauge_with_description(name: String, description: String) -> Gauge {
  register_metric(name, "gauge", description)
  Gauge(name: name, labels: dict.new())
}

/// Create a gauge with labels
pub fn gauge_with_labels(
  name: String,
  labels: List(#(String, String)),
) -> Gauge {
  register_metric(name, "gauge", "")
  Gauge(name: name, labels: dict.from_list(labels))
}

/// Create a labeled gauge with Prometheus HELP text.
pub fn gauge_with_labels_and_description(
  name: String,
  labels: List(#(String, String)),
  description: String,
) -> Gauge {
  register_metric(name, "gauge", description)
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
  add_gauge_value(gauge_key(gauge), value)
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
  register_metric(name, "histogram", "")
  Histogram(name: name, buckets: sort_buckets(buckets), labels: dict.new())
}

/// Create a new histogram with Prometheus HELP text.
pub fn histogram_with_description(
  name: String,
  buckets: List(Float),
  description: String,
) -> Histogram {
  register_metric(name, "histogram", description)
  Histogram(name: name, buckets: sort_buckets(buckets), labels: dict.new())
}

/// Create a histogram with labels
pub fn histogram_with_labels(
  name: String,
  buckets: List(Float),
  labels: List(#(String, String)),
) -> Histogram {
  register_metric(name, "histogram", "")
  Histogram(
    name: name,
    buckets: sort_buckets(buckets),
    labels: dict.from_list(labels),
  )
}

/// Create a labeled histogram with Prometheus HELP text.
pub fn histogram_with_labels_and_description(
  name: String,
  buckets: List(Float),
  labels: List(#(String, String)),
  description: String,
) -> Histogram {
  register_metric(name, "histogram", description)
  Histogram(
    name: name,
    buckets: sort_buckets(buckets),
    labels: dict.from_list(labels),
  )
}

/// Default buckets for latency (ms)
pub fn default_latency_buckets() -> List(Float) {
  [5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10_000.0]
}

/// Observe a value in the histogram
pub fn observe(histogram: Histogram, value: Float) -> Nil {
  // Update sum
  let sum_key = histogram_sample_key(histogram, "_sum", [])
  add_gauge_value(sum_key, value)

  // Update count
  let count_key = histogram_sample_key(histogram, "_count", [])
  add_counter_value(count_key, 1)

  // Update buckets
  list.each(histogram.buckets, fn(bucket) {
    case value <=. bucket {
      True -> {
        let bucket_key =
          histogram_sample_key(histogram, "_bucket", [
            #("le", float.to_string(bucket)),
          ])
        add_counter_value(bucket_key, 1)
      }
      False -> Nil
    }
  })

  // Update +Inf bucket
  let inf_key = histogram_sample_key(histogram, "_bucket", [#("le", "+Inf")])
  add_counter_value(inf_key, 1)
}

/// Get histogram stats
pub fn get_histogram_stats(histogram: Histogram) -> #(Int, Float) {
  let count = get_counter_value(histogram_sample_key(histogram, "_count", []))
  let sum = get_gauge_value(histogram_sample_key(histogram, "_sum", []))
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
  let metric_types = get_metric_types()
  let metric_descriptions = get_metric_descriptions()
  let mem = beam_memory()

  let counter_samples =
    dict.to_list(counters)
    |> list.map(fn(kv) { #(kv.0, int.to_string(kv.1), "counter") })

  let gauge_samples =
    dict.to_list(gauges)
    |> list.map(fn(kv) { #(kv.0, float.to_string(kv.1), "gauge") })

  let memory_lines = [
    "# HELP beam_memory_total_bytes Total memory currently allocated by the BEAM.",
    "# TYPE beam_memory_total_bytes gauge",
    "beam_memory_total_bytes " <> int.to_string(mem.total),
    "# HELP beam_memory_processes_bytes Memory currently allocated by BEAM processes.",
    "# TYPE beam_memory_processes_bytes gauge",
    "beam_memory_processes_bytes " <> int.to_string(mem.processes),
    "# HELP beam_memory_system_bytes Memory currently allocated by the BEAM system.",
    "# TYPE beam_memory_system_bytes gauge",
    "beam_memory_system_bytes " <> int.to_string(mem.system),
    "# HELP beam_memory_atom_bytes Memory currently allocated for atoms.",
    "# TYPE beam_memory_atom_bytes gauge",
    "beam_memory_atom_bytes " <> int.to_string(mem.atom),
    "# HELP beam_memory_binary_bytes Memory currently allocated for binaries.",
    "# TYPE beam_memory_binary_bytes gauge",
    "beam_memory_binary_bytes " <> int.to_string(mem.binary),
    "# HELP beam_memory_ets_bytes Memory currently allocated for ETS tables.",
    "# TYPE beam_memory_ets_bytes gauge",
    "beam_memory_ets_bytes " <> int.to_string(mem.ets),
  ]

  let #(metric_lines, _) =
    render_samples(
      list.append(counter_samples, gauge_samples),
      metric_types,
      metric_descriptions,
      [],
    )

  list.append(metric_lines, memory_lines)
  |> string.join("\n")
  |> append_final_newline
}

/// Clear all in-memory metrics.
///
/// This is primarily useful for tests and short-lived scripts that want a clean
/// registry before running a scenario.
pub fn reset() -> Nil {
  clear_all()
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
        |> list.map(fn(kv) { kv.0 <> "=\"" <> escape_label_value(kv.1) <> "\"" })
        |> string.join(",")
      "{" <> pairs <> "}"
    }
  }
}

fn render_samples(
  samples: List(#(String, String, String)),
  metric_types: Dict(String, String),
  metric_descriptions: Dict(String, String),
  seen_metadata: List(String),
) -> #(List(String), List(String)) {
  case samples {
    [] -> #([], seen_metadata)
    [sample, ..rest] -> {
      let #(key, value, fallback_type) = sample
      let metadata_name = metadata_name_for_sample(key, metric_types)
      let sample_type =
        dict.get(metric_types, metadata_name)
        |> result_unwrap(fallback_type)
      let metadata_lines = case list.contains(seen_metadata, metadata_name) {
        True -> []
        False -> metadata_lines(metadata_name, sample_type, metric_descriptions)
      }
      let seen_metadata = case list.contains(seen_metadata, metadata_name) {
        True -> seen_metadata
        False -> [metadata_name, ..seen_metadata]
      }
      let #(rest_lines, seen_metadata) =
        render_samples(rest, metric_types, metric_descriptions, seen_metadata)
      #(
        list.append(metadata_lines, [key <> " " <> value, ..rest_lines]),
        seen_metadata,
      )
    }
  }
}

fn metadata_lines(
  name: String,
  metric_type: String,
  metric_descriptions: Dict(String, String),
) -> List(String) {
  let type_line = "# TYPE " <> name <> " " <> metric_type
  case dict.get(metric_descriptions, name) {
    Ok("") | Error(_) -> [type_line]
    Ok(description) -> [
      "# HELP " <> name <> " " <> escape_help_text(description),
      type_line,
    ]
  }
}

fn metadata_name_for_sample(
  key: String,
  metric_types: Dict(String, String),
) -> String {
  let sample_name = sample_name(key)
  let candidates = [
    sample_name,
    strip_suffix(sample_name, "_bucket"),
    strip_suffix(sample_name, "_sum"),
    strip_suffix(sample_name, "_count"),
  ]

  candidates
  |> list.find(fn(candidate) { dict.has_key(metric_types, candidate) })
  |> result_unwrap(sample_name)
}

fn sample_name(key: String) -> String {
  case string.split_once(key, "{") {
    Ok(#(name, _labels)) -> name
    Error(_) -> key
  }
}

fn strip_suffix(value: String, suffix: String) -> String {
  case string.ends_with(value, suffix) {
    True -> string.drop_end(value, string.length(suffix))
    False -> value
  }
}

fn sort_buckets(buckets: List(Float)) -> List(Float) {
  list.sort(buckets, fn(a, b) { float.compare(a, with: b) })
}

fn histogram_sample_key(
  histogram: Histogram,
  suffix: String,
  extra_labels: List(#(String, String)),
) -> String {
  histogram.name
  <> suffix
  <> labels_to_string(dict.merge(histogram.labels, dict.from_list(extra_labels)))
}

fn escape_label_value(value: String) -> String {
  value
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "\"", with: "\\\"")
  |> string.replace(each: "\n", with: "\\n")
}

fn escape_help_text(value: String) -> String {
  value
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "\n", with: "\\n")
}

fn append_final_newline(output: String) -> String {
  case output {
    "" -> ""
    _ -> output <> "\n"
  }
}

fn result_unwrap(result: Result(a, b), default: a) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> default
  }
}

// ============================================================================
// FFI (Process Dictionary Storage)
// ============================================================================

@external(erlang, "viva_telemetry_metrics_ffi", "get_counter_value")
fn get_counter_value(key: String) -> Int

@external(erlang, "viva_telemetry_metrics_ffi", "add_counter_value")
fn add_counter_value(key: String, value: Int) -> Nil

@external(erlang, "viva_telemetry_metrics_ffi", "get_gauge_value")
fn get_gauge_value(key: String) -> Float

@external(erlang, "viva_telemetry_metrics_ffi", "set_gauge_value")
fn set_gauge_value(key: String, value: Float) -> Nil

@external(erlang, "viva_telemetry_metrics_ffi", "add_gauge_value")
fn add_gauge_value(key: String, value: Float) -> Nil

@external(erlang, "viva_telemetry_metrics_ffi", "get_all_counters")
fn get_all_counters() -> Dict(String, Int)

@external(erlang, "viva_telemetry_metrics_ffi", "get_all_gauges")
fn get_all_gauges() -> Dict(String, Float)

@external(erlang, "viva_telemetry_metrics_ffi", "get_beam_memory")
fn get_beam_memory() -> Dict(String, Int)

@external(erlang, "viva_telemetry_metrics_ffi", "register_metric")
fn register_metric(
  name: String,
  metric_type: String,
  description: String,
) -> Nil

@external(erlang, "viva_telemetry_metrics_ffi", "get_metric_types")
fn get_metric_types() -> Dict(String, String)

@external(erlang, "viva_telemetry_metrics_ffi", "get_metric_descriptions")
fn get_metric_descriptions() -> Dict(String, String)

@external(erlang, "viva_telemetry_metrics_ffi", "clear_all")
fn clear_all() -> Nil
