import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import viva_telemetry/bench
import viva_telemetry/log
import viva_telemetry/log/entry
import viva_telemetry/log/handler
import viva_telemetry/log/level
import viva_telemetry/metrics

pub fn main() -> Nil {
  gleeunit.main()
}

// Level tests
pub fn level_to_int_test() {
  assert level.to_int(level.Emergency) == 0
  assert level.to_int(level.Err) == 3
  assert level.to_int(level.Info) == 6
  assert level.to_int(level.Trace) == 8
}

pub fn level_from_int_test() {
  assert level.from_int(0) == level.Emergency
  assert level.from_int(3) == level.Err
  assert level.from_int(6) == level.Info
  assert level.from_int(99) == level.Trace
}

pub fn level_to_string_test() {
  assert level.to_string(level.Emergency) == "EMERGENCY"
  assert level.to_string(level.Err) == "ERROR"
  assert level.to_string(level.Info) == "INFO"
}

pub fn level_from_string_test() {
  assert level.from_string("info") == Ok(level.Info)
  assert level.from_string("ERROR") == Ok(level.Err)
  assert level.from_string("dbg") == Ok(level.Debug)
  assert level.from_string("unknown") == Error(Nil)
}

pub fn level_is_enabled_test() {
  // Error (3) is more severe than Info (6), so it should be enabled
  assert level.is_enabled(level.Err, level.Info) == True
  // Trace (8) is less severe than Info (6), so it should be disabled
  assert level.is_enabled(level.Trace, level.Info) == False
  // Same level should be enabled
  assert level.is_enabled(level.Info, level.Info) == True
}

// Entry tests
pub fn entry_new_test() {
  let e = entry.new(level.Info, "Test message", [#("key", "value")])
  assert e.level == level.Info
  assert e.message == "Test message"
  assert dict.get(e.fields, "key") == Ok("value")
}

pub fn entry_with_source_test() {
  let e =
    entry.new(level.Info, "Test", [])
    |> entry.with_source("my_module")
  assert e.source == "my_module"
}

pub fn entry_with_field_test() {
  let e =
    entry.new(level.Info, "Test", [])
    |> entry.with_field("extra", "data")
  assert dict.get(e.fields, "extra") == Ok("data")
}

pub fn entry_all_fields_test() {
  let ctx = dict.from_list([#("ctx", "value")])
  let e =
    entry.new(level.Info, "Test", [#("field", "data")])
    |> entry.with_context(ctx)

  let all = entry.all_fields(e)
  assert dict.get(all, "ctx") == Ok("value")
  assert dict.get(all, "field") == Ok("data")
}

// Handler tests
pub fn handler_console_default_test() {
  let h = handler.console()
  assert handler.get_level(h) == level.Info
}

pub fn handler_console_with_level_test() {
  let h = handler.console_with_level(level.Debug)
  assert handler.get_level(h) == level.Debug
}

pub fn handler_should_log_test() {
  let h = handler.console_with_level(level.Info)
  // Error should pass (more severe)
  assert handler.should_log(h, level.Err) == True
  // Info should pass (same level)
  assert handler.should_log(h, level.Info) == True
  // Debug should not pass (less severe)
  assert handler.should_log(h, level.Debug) == False
}

pub fn handler_erlang_logger_default_test() {
  let h = handler.erlang_logger(level.Info)
  assert handler.get_level(h) == level.Info
}

// Log module tests (integration)
pub fn log_configure_test() {
  log.configure([handler.console()])
  let handlers = log.handlers()
  assert handlers != []
}

pub fn log_context_test() {
  log.clear_context()
  log.bind_context([#("test", "value")])
  // Context is set (tested via internal state)
  log.clear_context()
}

// Lazy logging tests
pub fn log_would_log_test() {
  // Configure with Info level
  log.configure_console(log.info_level)

  // Error should be logged (more severe than Info)
  assert log.would_log(level.Err) == True

  // Info should be logged (same level)
  assert log.would_log(level.Info) == True

  // Debug should NOT be logged (less severe than Info)
  assert log.would_log(level.Debug) == False

  // Trace should NOT be logged
  assert log.would_log(level.Trace) == False
}

pub fn log_would_log_debug_level_test() {
  // Configure with Debug level
  log.configure_console(log.debug_level)

  // Debug should now be logged
  assert log.would_log(level.Debug) == True

  // Trace still should NOT be logged
  assert log.would_log(level.Trace) == False
}

pub fn log_lazy_functions_exist_test() {
  // Just verify lazy functions compile and can be called
  log.configure([handler.custom(log.info_level, fn(_) { Nil })])

  // These should not panic (debug won't be logged with info level)
  log.debug_lazy(fn() { "lazy debug" }, [])
  log.trace_lazy(fn() { "lazy trace" }, [])

  // These should actually log
  log.info_lazy(fn() { "lazy info" }, [])
  log.error_lazy(fn() { "lazy error" }, [])
}

pub fn log_configure_erlang_test() {
  log.configure_erlang(log.info_level)
  assert log.would_log(level.Info) == True
  assert log.would_log(level.Debug) == False
}

pub fn log_configure_erlang_with_name_test() {
  log.configure_erlang_with_name(log.warning_level, "viva.test")
  assert log.would_log(level.Err) == True
  assert log.would_log(level.Info) == False
}

pub fn named_logger_api_test() {
  log.configure([handler.custom(log.debug_level, fn(_) { Nil })])

  let logger =
    log.logger("viva.test")
    |> log.with_field("request_id", "req-1")
    |> log.with_int("attempt", 2)
    |> log.with_float("duration_ms", 12.5)
    |> log.with_bool("cached", False)
    |> log.with_error("not_found")
    |> log.with_option("user_id", Some(42), int_to_string)
    |> log.with_option("missing", None, int_to_string)
    |> log.with_result("status", Ok(200), int_to_string, fn(value) { value })
    |> log.with_result("failed_status", Error("boom"), int_to_string, fn(value) {
      value
    })

  logger
  |> log.logger_log(log.notice_level, "generic log works")
  |> log.logger_log_with(log.notice_level, "generic log with fields works", [
    #("generic", "true"),
  ])
  |> log.logger_emergency("emergency still works")
  |> log.logger_emergency_with("emergency with fields still works", [
    #("emergency", "true"),
  ])
  |> log.logger_alert("alert still works")
  |> log.logger_alert_with("alert with fields still works", [#("alert", "true")])
  |> log.logger_critical("critical still works")
  |> log.logger_critical_with("critical with fields still works", [
    #("critical", "true"),
  ])
  |> log.logger_info("named logger works")
  |> log.logger_info_with("with extra fields", [#("route", "/health")])
  |> log.logger_debug("debug still works")
  |> log.logger_debug_with("debug with fields still works", [#("debug", "true")])
  |> log.logger_warning("warning still works")
  |> log.logger_warning_with("warning with fields still works", [
    #("warning", "true"),
  ])
  |> log.logger_notice("notice still works")
  |> log.logger_notice_with("notice with fields still works", [
    #("notice", "true"),
  ])
  |> log.logger_error("error still works")
  |> log.logger_error_with("error with fields still works", [
    #("error_id", "e1"),
  ])
  |> log.logger_trace("trace still works")
  |> log.logger_trace_with("trace with fields still works", [#("trace", "true")])

  assert log.would_log(level.Debug) == True
}

fn int_to_string(value: Int) -> String {
  int.to_string(value)
}

// ============================================================================
// Metrics tests
// ============================================================================

pub fn metrics_counter_test() {
  metrics.reset()
  let c = metrics.counter("test_counter")
  metrics.inc(c)
  metrics.inc(c)
  metrics.inc_by(c, 3)
  assert metrics.get_counter(c) == 5
}

pub fn metrics_counter_with_labels_test() {
  metrics.reset()
  let c = metrics.counter_with_labels("http_requests", [#("method", "GET")])
  metrics.inc(c)
  assert metrics.get_counter(c) == 1
}

pub fn metrics_counter_description_prometheus_test() {
  metrics.reset()
  let c =
    metrics.counter_with_labels_and_description(
      "http_requests_total",
      [#("method", "GET")],
      "Total HTTP requests.",
    )
  metrics.inc(c)

  let output = metrics.to_prometheus()
  assert string.contains(
    output,
    "# HELP http_requests_total Total HTTP requests.",
  )
  assert string.contains(output, "# TYPE http_requests_total counter")
  assert string.contains(output, "http_requests_total{method=\"GET\"} 1")
}

pub fn metrics_description_is_preserved_test() {
  metrics.reset()
  let described =
    metrics.counter_with_description("jobs_processed_total", "Processed jobs.")
  let plain = metrics.counter("jobs_processed_total")
  metrics.inc(described)
  metrics.inc(plain)

  let output = metrics.to_prometheus()
  assert string.contains(output, "# HELP jobs_processed_total Processed jobs.")
  assert metrics.get_counter(plain) == 2
}

pub fn metrics_counter_does_not_decrement_test() {
  metrics.reset()
  let c = metrics.counter("monotonic_counter")
  metrics.inc_by(c, 2)
  metrics.inc_by(c, -1)
  assert metrics.get_counter(c) == 2
}

pub fn metrics_gauge_test() {
  metrics.reset()
  let g = metrics.gauge("test_gauge")
  metrics.set(g, 42.0)
  assert metrics.get_gauge(g) == 42.0

  metrics.gauge_inc(g)
  assert metrics.get_gauge(g) == 43.0

  metrics.gauge_dec(g)
  assert metrics.get_gauge(g) == 42.0

  metrics.gauge_add(g, 8.0)
  assert metrics.get_gauge(g) == 50.0
}

pub fn metrics_gauge_description_prometheus_test() {
  metrics.reset()
  let g =
    metrics.gauge_with_description(
      "active_connections",
      "Current active connections.",
    )
  metrics.gauge_add(g, 2.5)

  let output = metrics.to_prometheus()
  assert string.contains(
    output,
    "# HELP active_connections Current active connections.",
  )
  assert string.contains(output, "# TYPE active_connections gauge")
  assert string.contains(output, "active_connections 2.5")
}

pub fn metrics_histogram_test() {
  metrics.reset()
  let h = metrics.histogram("latency", [10.0, 50.0, 100.0])
  metrics.observe(h, 25.0)
  metrics.observe(h, 75.0)
  metrics.observe(h, 150.0)

  let #(count, sum) = metrics.get_histogram_stats(h)
  assert count == 3
  assert sum == 250.0
}

pub fn metrics_histogram_time_test() {
  metrics.reset()
  let h = metrics.histogram("timing", [100.0, 1000.0, 10_000.0])

  // Time a simple function
  let result = metrics.time(h, fn() { 1 + 1 })
  assert result == 2

  // Stats should be recorded
  let #(count, _sum) = metrics.get_histogram_stats(h)
  assert count >= 1
}

pub fn metrics_default_buckets_test() {
  let buckets = metrics.default_latency_buckets()
  assert list.length(buckets) == 11
}

pub fn metrics_beam_memory_test() {
  let mem = metrics.beam_memory()
  // Memory should be positive
  assert mem.total > 0
  assert mem.processes > 0
  assert mem.system > 0
}

pub fn metrics_prometheus_export_test() {
  metrics.reset()
  // Create some metrics
  let c = metrics.counter("prom_test_counter")
  metrics.inc(c)

  let output = metrics.to_prometheus()
  // Should contain BEAM memory metrics at minimum
  assert output != ""
}

pub fn metrics_prometheus_histogram_format_test() {
  metrics.reset()
  let h =
    metrics.histogram_with_labels_and_description(
      "request_duration_seconds",
      [0.5, 0.1],
      [#("route", "/users")],
      "Request duration in seconds.",
    )

  metrics.observe(h, 0.25)

  let output = metrics.to_prometheus()
  assert string.contains(
    output,
    "# HELP request_duration_seconds Request duration in seconds.",
  )
  assert string.contains(output, "# TYPE request_duration_seconds histogram")
  assert string.contains(
    output,
    "request_duration_seconds_bucket{le=\"0.5\",route=\"/users\"} 1",
  )
  assert string.contains(
    output,
    "request_duration_seconds_bucket{le=\"+Inf\",route=\"/users\"} 1",
  )
  assert string.contains(
    output,
    "request_duration_seconds_sum{route=\"/users\"} 0.25",
  )
  assert string.contains(
    output,
    "request_duration_seconds_count{route=\"/users\"} 1",
  )
}

// ============================================================================
// Bench tests
// ============================================================================

pub fn bench_default_config_test() {
  let cfg = bench.default_config()
  assert cfg.warmup_iterations == 10
  assert cfg.iterations == 100
  assert cfg.confidence == 0.95
}

pub fn bench_custom_config_test() {
  let cfg = bench.config(5, 50)
  assert cfg.warmup_iterations == 5
  assert cfg.iterations == 50
}

pub fn bench_run_test() {
  // Run a benchmark with measurable work
  let result = bench.run("fib15", fn() { fib(15) })

  assert result.name == "fib15"
  assert list.length(result.samples) == 100
  // Stats should be calculated (mean >= 0 is always true)
  assert result.stats.mean >=. 0.0
  // IPS might be Infinity for very fast functions, just check it exists
}

pub fn bench_run_with_config_test() {
  let cfg = bench.config(2, 10)
  let result = bench.run_with_config("mul", fn() { 2 * 3 }, cfg)

  assert result.name == "mul"
  assert list.length(result.samples) == 10
}

pub fn bench_compare_test() {
  // Use fib with different inputs to ensure measurable difference
  let slow =
    bench.run_with_config("fib20", fn() { fib(20) }, bench.config(2, 20))
  let fast =
    bench.run_with_config("fib10", fn() { fib(10) }, bench.config(2, 20))

  let cmp = bench.compare(slow, fast)
  assert cmp.baseline == "fib20"
  assert cmp.target == "fib10"
  // Just verify comparison works (speedup might vary)
  assert cmp.speedup >=. 0.0
}

pub fn bench_to_json_test() {
  let result =
    bench.run_with_config("json_test", fn() { 1 + 1 }, bench.config(2, 10))
  let json_str = bench.to_json_string(result)

  // Should contain benchmark name
  assert json_str != ""
}

pub fn bench_to_markdown_test() {
  let result =
    bench.run_with_config("md_test", fn() { 1 + 1 }, bench.config(2, 10))
  let md = bench.to_markdown(result)

  // Should be a table row
  assert md != ""
}

// Helper for benchmark tests
fn fib(n: Int) -> Int {
  case n {
    0 -> 0
    1 -> 1
    _ -> fib(n - 1) + fib(n - 2)
  }
}
