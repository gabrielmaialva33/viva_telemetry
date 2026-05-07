//// viva_telemetry/log - Structured logging for Gleam
////
//// Inspired by: structlog (Python), zap (Go), tracing (Rust)
////
//// ## Features
//// - Structured logging with key-value fields
//// - Multiple handlers (console, file, JSON)
//// - Log levels (RFC 5424)
//// - Context propagation
//// - Sampling for high-volume logs
////
//// ## Quick Start
////
//// ```gleam
//// import viva_telemetry/log
////
//// pub fn main() {
////   // Simple logging
////   log.info("Server started", [#("port", "8080")])
////
////   // With context
////   log.with_context([#("request_id", "abc123")], fn() {
////     log.debug("Processing request", [])
////   })
//// }
//// ```

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import simplifile
import viva_telemetry/log/entry.{type Entry}
import viva_telemetry/log/handler.{
  type Handler, ConsoleHandler, CustomHandler, ErlangLoggerHandler, FileHandler,
  JsonHandler,
}
import viva_telemetry/log/level.{type Level}

// ============================================================================
// Re-exported Levels (convenience)
// ============================================================================

/// Emergency level (system is unusable)
pub const emergency_level = level.Emergency

/// Alert level (action must be taken immediately)
pub const alert_level = level.Alert

/// Critical level
pub const critical_level = level.Critical

/// Error level
pub const error_level = level.Err

/// Warning level
pub const warning_level = level.Warning

/// Notice level (normal but significant)
pub const notice_level = level.Notice

/// Info level
pub const info_level = level.Info

/// Debug level
pub const debug_level = level.Debug

/// Trace level (fine-grained)
pub const trace_level = level.Trace

// ============================================================================
// Named Logger
// ============================================================================

/// A named immutable logger with persistent structured fields.
///
/// This gives applications a small fluent API while keeping the low-level
/// logging functions available for one-off messages.
pub opaque type Logger {
  Logger(source: String, fields: List(#(String, String)))
}

/// Create a named logger.
pub fn logger(source: String) -> Logger {
  Logger(source: source, fields: [])
}

/// Add a string field to a named logger.
pub fn with_field(logger: Logger, key: String, value: String) -> Logger {
  Logger(..logger, fields: [#(key, value), ..logger.fields])
}

/// Add an integer field to a named logger.
pub fn with_int(logger: Logger, key: String, value: Int) -> Logger {
  with_field(logger, key, int.to_string(value))
}

/// Add a float field to a named logger.
pub fn with_float(logger: Logger, key: String, value: Float) -> Logger {
  with_field(logger, key, float.to_string(value))
}

/// Add a bool field to a named logger.
pub fn with_bool(logger: Logger, key: String, value: Bool) -> Logger {
  with_field(logger, key, bool_to_string(value))
}

/// Add many fields to a named logger.
pub fn with_fields(logger: Logger, fields: List(#(String, String))) -> Logger {
  Logger(..logger, fields: list.append(fields, logger.fields))
}

/// Log an info message with a named logger.
pub fn logger_info(logger: Logger, message: String) -> Logger {
  log_named(logger, level.Info, message, [])
}

/// Log a debug message with a named logger.
pub fn logger_debug(logger: Logger, message: String) -> Logger {
  log_named(logger, level.Debug, message, [])
}

/// Log a warning message with a named logger.
pub fn logger_warning(logger: Logger, message: String) -> Logger {
  log_named(logger, level.Warning, message, [])
}

/// Log an error message with a named logger.
pub fn logger_error(logger: Logger, message: String) -> Logger {
  log_named(logger, level.Err, message, [])
}

/// Log an info message with additional one-off fields.
pub fn logger_info_with(
  logger: Logger,
  message: String,
  fields: List(#(String, String)),
) -> Logger {
  log_named(logger, level.Info, message, fields)
}

fn log_named(
  logger: Logger,
  lvl: Level,
  message: String,
  fields: List(#(String, String)),
) -> Logger {
  log_from(logger.source, lvl, message, list.append(fields, logger.fields))
  logger
}

// ============================================================================
// Global State (via process dictionary)
// ============================================================================

/// Configure global handlers
pub fn configure(handlers: List(Handler)) -> Nil {
  set_handlers(handlers)
}

/// Quick setup: console handler with specified level
///
/// Example:
/// ```gleam
/// log.configure_console(log.debug_level)
/// ```
pub fn configure_console(lvl: Level) -> Nil {
  set_handlers([handler.console_with_level(lvl)])
}

/// Quick setup: JSON file handler with specified level
///
/// Example:
/// ```gleam
/// log.configure_json("app.jsonl", log.info_level)
/// ```
pub fn configure_json(path: String, lvl: Level) -> Nil {
  set_handlers([handler.json_with_level(path, lvl)])
}

/// Quick setup: console + JSON file
///
/// Example:
/// ```gleam
/// log.configure_full(log.debug_level, "app.jsonl", log.info_level)
/// ```
pub fn configure_full(
  console_level: Level,
  json_path: String,
  json_level: Level,
) -> Nil {
  set_handlers([
    handler.console_with_level(console_level),
    handler.json_with_level(json_path, json_level),
  ])
}

/// Quick setup: forward structured logs to Erlang's built-in `:logger`
///
/// This is the recommended production integration when running on the BEAM.
pub fn configure_erlang(lvl: Level) -> Nil {
  set_handlers([handler.erlang_logger(lvl)])
}

/// Add a handler to the existing configuration
pub fn add_handler(handler: Handler) -> Nil {
  let current = get_handlers()
  set_handlers([handler, ..current])
}

/// Get current handlers
pub fn handlers() -> List(Handler) {
  get_handlers()
}

// ============================================================================
// Core Logging Functions
// ============================================================================

/// Log at emergency level
pub fn emergency(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Emergency, message, fields)
}

/// Log at alert level
pub fn alert(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Alert, message, fields)
}

/// Log at critical level
pub fn critical(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Critical, message, fields)
}

/// Log at error level
pub fn error(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Err, message, fields)
}

/// Log at warning level
pub fn warning(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Warning, message, fields)
}

/// Log at notice level
pub fn notice(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Notice, message, fields)
}

/// Log at info level
pub fn info(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Info, message, fields)
}

/// Log at debug level
pub fn debug(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Debug, message, fields)
}

/// Log at trace level
pub fn trace(message: String, fields: List(#(String, String))) -> Nil {
  log(level.Trace, message, fields)
}

/// Log with explicit level
pub fn log(
  lvl: Level,
  message: String,
  fields: List(#(String, String)),
) -> Nil {
  let e = entry.new(lvl, message, fields)
  let e_with_ctx = entry.with_context(e, get_context())
  dispatch(e_with_ctx)
}

// ============================================================================
// Lazy Logging (avoid string construction when log won't be emitted)
// ============================================================================

/// Check if any handler would log at this level
/// Use this to avoid expensive computations when log won't be emitted
pub fn would_log(lvl: Level) -> Bool {
  let hs = get_handlers()
  case hs {
    [] -> level.is_enabled(lvl, level.Info)
    _ -> list.any(hs, fn(h) { handler.should_log(h, lvl) })
  }
}

/// Lazy log - only evaluates message function if log will be emitted
///
/// Example:
/// ```gleam
/// log.debug_lazy(fn() { "Processing " <> expensive_to_string(data) }, [])
/// ```
pub fn log_lazy(
  lvl: Level,
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  case would_log(lvl) {
    False -> Nil
    True -> log(lvl, message_fn(), fields)
  }
}

/// Lazy log with lazy fields - both message and fields evaluated only if needed
pub fn log_lazy_all(
  lvl: Level,
  message_fn: fn() -> String,
  fields_fn: fn() -> List(#(String, String)),
) -> Nil {
  case would_log(lvl) {
    False -> Nil
    True -> log(lvl, message_fn(), fields_fn())
  }
}

/// Lazy emergency
pub fn emergency_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Emergency, message_fn, fields)
}

/// Lazy alert
pub fn alert_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Alert, message_fn, fields)
}

/// Lazy critical
pub fn critical_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Critical, message_fn, fields)
}

/// Lazy error
pub fn error_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Err, message_fn, fields)
}

/// Lazy warning
pub fn warning_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Warning, message_fn, fields)
}

/// Lazy notice
pub fn notice_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Notice, message_fn, fields)
}

/// Lazy info
pub fn info_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Info, message_fn, fields)
}

/// Lazy debug - most common use case for lazy logging
///
/// Example:
/// ```gleam
/// // String only constructed if debug level is enabled
/// log.debug_lazy(fn() { "Item: " <> int.to_string(i) }, [])
/// ```
pub fn debug_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Debug, message_fn, fields)
}

/// Lazy trace - for high-frequency logs that should be cheap when disabled
pub fn trace_lazy(
  message_fn: fn() -> String,
  fields: List(#(String, String)),
) -> Nil {
  log_lazy(level.Trace, message_fn, fields)
}

/// Log with source module
pub fn log_from(
  source: String,
  lvl: Level,
  message: String,
  fields: List(#(String, String)),
) -> Nil {
  let e =
    entry.new(lvl, message, fields)
    |> entry.with_source(source)
    |> entry.with_context(get_context())
  dispatch(e)
}

// ============================================================================
// Context Propagation
// ============================================================================

/// Execute function with additional context
pub fn with_context(context: List(#(String, String)), f: fn() -> a) -> a {
  let old_context = get_context()
  let new_context = dict.merge(old_context, dict.from_list(context))
  set_context(new_context)
  let result = f()
  set_context(old_context)
  result
}

/// Add context fields that persist for this process
pub fn bind_context(context: List(#(String, String))) -> Nil {
  let old_context = get_context()
  let new_context = dict.merge(old_context, dict.from_list(context))
  set_context(new_context)
}

/// Clear all context
pub fn clear_context() -> Nil {
  set_context(dict.new())
}

// ============================================================================
// Sampling
// ============================================================================

/// Log with sampling (only log rate% of messages)
pub fn sampled(
  lvl: Level,
  rate: Float,
  message: String,
  fields: List(#(String, String)),
) -> Nil {
  case should_sample(rate) {
    True -> log(lvl, message, fields)
    False -> Nil
  }
}

// ============================================================================
// Dispatcher
// ============================================================================

fn dispatch(e: Entry) -> Nil {
  let hs = get_handlers()
  case hs {
    [] -> {
      // No handlers configured, use default console
      dispatch_to_handler(e, handler.console())
    }
    _ -> {
      list.each(hs, fn(h) { dispatch_to_handler(e, h) })
    }
  }
}

fn dispatch_to_handler(e: Entry, h: Handler) -> Nil {
  case handler.should_log(h, e.level) {
    False -> Nil
    True ->
      case h {
        ConsoleHandler(config) -> {
          let output = entry.to_console_string(e, config.colored)
          case config.stderr_for_errors && level.to_int(e.level) <= 3 {
            True -> print_stderr(output)
            False -> io.println(output)
          }
        }
        JsonHandler(config) -> {
          let json_str = entry.to_json_string(e)
          let _ = simplifile.append(config.path, json_str <> "\n")
          Nil
        }
        FileHandler(config) -> {
          let text = entry.to_console_string(e, False)
          let _ = simplifile.append(config.path, text <> "\n")
          Nil
        }
        CustomHandler(config) -> {
          config.handler_fn(e)
        }
        ErlangLoggerHandler(config) -> {
          erlang_log(
            level.to_string(e.level),
            config.logger_name,
            e.message,
            entry.all_fields(e),
          )
        }
      }
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

// ============================================================================
// Process Dictionary FFI
// ============================================================================

@external(erlang, "viva_telemetry_ffi", "get_handlers")
fn get_handlers() -> List(Handler)

@external(erlang, "viva_telemetry_ffi", "set_handlers")
fn set_handlers(handlers: List(Handler)) -> Nil

@external(erlang, "viva_telemetry_ffi", "get_context")
fn get_context() -> Dict(String, String)

@external(erlang, "viva_telemetry_ffi", "set_context")
fn set_context(context: Dict(String, String)) -> Nil

@external(erlang, "viva_telemetry_ffi", "erlang_log")
fn erlang_log(
  level: String,
  logger_name: String,
  message: String,
  fields: Dict(String, String),
) -> Nil

@external(erlang, "viva_telemetry_ffi", "should_sample")
fn should_sample(rate: Float) -> Bool

@external(erlang, "viva_telemetry_ffi", "print_stderr")
fn print_stderr(msg: String) -> Nil
