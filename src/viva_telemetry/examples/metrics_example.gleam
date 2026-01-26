//// Example: Using viva_telemetry/metrics
////
//// Run: gleam run -m viva_telemetry/examples/metrics_example

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import viva_telemetry/metrics

pub fn main() {
  io.println("=== viva_telemetry/metrics Demo ===\n")

  // Counter example
  io.println("--- Counter ---")
  let requests = metrics.counter("http_requests_total")
  metrics.inc(requests)
  metrics.inc(requests)
  metrics.inc_by(requests, 10)
  io.println(
    "http_requests_total: " <> int.to_string(metrics.get_counter(requests)),
  )

  // Counter with labels
  let errors =
    metrics.counter_with_labels("http_errors_total", [
      #("method", "GET"),
      #("status", "500"),
    ])
  metrics.inc(errors)
  metrics.inc(errors)
  io.println(
    "http_errors_total: " <> int.to_string(metrics.get_counter(errors)),
  )

  // Gauge example
  io.println("\n--- Gauge ---")
  let connections = metrics.gauge("active_connections")
  metrics.set(connections, 10.0)
  metrics.gauge_inc(connections)
  metrics.gauge_inc(connections)
  metrics.gauge_dec(connections)
  io.println(
    "active_connections: " <> float.to_string(metrics.get_gauge(connections)),
  )

  let temperature = metrics.gauge("cpu_temperature")
  metrics.set(temperature, 65.5)
  io.println(
    "cpu_temperature: " <> float.to_string(metrics.get_gauge(temperature)),
  )

  // Histogram example
  io.println("\n--- Histogram ---")
  let latency =
    metrics.histogram("request_latency_ms", metrics.default_latency_buckets())

  // Simulate some latencies
  list.each([5.2, 12.5, 48.0, 150.0, 520.0, 23.0, 8.0, 95.0], fn(v) {
    metrics.observe(latency, v)
  })

  let #(count, sum) = metrics.get_histogram_stats(latency)
  io.println("request_latency_ms count: " <> int.to_string(count))
  io.println("request_latency_ms sum: " <> float.to_string(sum))
  io.println(
    "request_latency_ms avg: " <> float.to_string(sum /. int.to_float(count)),
  )

  // BEAM Memory
  io.println("\n--- BEAM Memory ---")
  let mem = metrics.beam_memory()
  io.println("Total: " <> format_bytes(mem.total))
  io.println("Processes: " <> format_bytes(mem.processes))
  io.println("System: " <> format_bytes(mem.system))
  io.println("Binary: " <> format_bytes(mem.binary))
  io.println("ETS: " <> format_bytes(mem.ets))

  // Prometheus export
  io.println("\n--- Prometheus Export ---")
  let prom = metrics.to_prometheus()
  io.println(prom)

  io.println("\n=== Demo completed! ===")
}

fn format_bytes(bytes: Int) -> String {
  case bytes >= 1_048_576 {
    True -> float.to_string(int.to_float(bytes) /. 1_048_576.0) <> " MB"
    False ->
      case bytes >= 1024 {
        True -> float.to_string(int.to_float(bytes) /. 1024.0) <> " KB"
        False -> int.to_string(bytes) <> " B"
      }
  }
}
