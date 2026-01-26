//// viva_telemetry - Professional Observability Suite for Gleam
////
//// Part of the VIVA ecosystem - for the Gleam community
////
//// ## Modules
//// - `viva_telemetry/log` - Structured logging with handlers
//// - `viva_telemetry/metrics` - Counters, gauges, histograms
//// - `viva_telemetry/bench` - Statistical benchmarking
////
//// ## Quick Start
////
//// ```gleam
//// import viva_telemetry/log
////
//// pub fn main() {
////   log.info("Hello from VIVA!", [])
//// }
//// ```

import viva_telemetry/log
import viva_telemetry/log/level

/// Quick logging functions (re-exports)
pub fn info(msg: String, fields: List(#(String, String))) {
  log.info(msg, fields)
}

pub fn error(msg: String, fields: List(#(String, String))) {
  log.error(msg, fields)
}

pub fn debug(msg: String, fields: List(#(String, String))) {
  log.debug(msg, fields)
}

pub fn warning(msg: String, fields: List(#(String, String))) {
  log.warning(msg, fields)
}

pub fn trace(msg: String, fields: List(#(String, String))) {
  log.trace(msg, fields)
}

/// Log levels
pub const emergency = level.Emergency

pub const alert = level.Alert

pub const critical = level.Critical

pub const error_level = level.Err

pub const warning_level = level.Warning

pub const notice = level.Notice

pub const info_level = level.Info

pub const debug_level = level.Debug

pub const trace_level = level.Trace

/// Get library version
pub fn version() -> String {
  "1.0.1"
}
