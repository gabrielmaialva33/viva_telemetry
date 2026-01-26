//// Example: Using viva_telemetry/log
////
//// Run: gleam run -m viva_telemetry/examples/log_example

import gleam/int
import gleam/list
import viva_telemetry/log
import viva_telemetry/log/handler
import viva_telemetry/log/level

pub fn main() {
  // Configure handlers
  log.configure([
    handler.console_with_level(level.Debug),
    handler.json("app.jsonl"),
  ])

  // Basic logging
  log.info("Server starting", [#("port", "8080"), #("env", "dev")])
  log.debug("Config loaded", [#("file", "config.toml")])
  log.warning("Deprecated API used", [#("endpoint", "/v1/users")])
  log.error("Connection failed", [#("host", "db.local"), #("retries", "3")])

  // With context
  log.with_context([#("request_id", "abc123"), #("user_id", "42")], fn() {
    log.info("Processing request", [])
    log.debug("Fetching user data", [#("table", "users")])
    log.info("Request completed", [#("status", "200")])
  })

  // Sampling (only 10% of calls will log)
  list.range(1, 100)
  |> list.each(fn(i) {
    log.sampled(level.Debug, 0.1, "High frequency event", [
      #("i", int.to_string(i)),
    ])
  })

  // Different log levels
  log.trace("Very detailed trace", [])
  log.notice("Something noteworthy", [])
  log.critical("System critical!", [])
  log.alert("Immediate action needed!", [])
  log.emergency("System down!", [])

  log.info("Demo completed!", [])
}
