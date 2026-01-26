//// Log levels following syslog severity levels (RFC 5424)
////
//// From most severe to least:
//// Emergency > Alert > Critical > Err > Warning > Notice > Info > Debug > Trace

import gleam/int
import gleam/order.{type Order}
import gleam/string

/// Log severity levels (RFC 5424 + Trace)
/// Note: "Error" renamed to "Err" to avoid conflict with Result.Error
pub type Level {
  /// System is unusable
  Emergency
  /// Action must be taken immediately
  Alert
  /// Critical conditions
  Critical
  /// Error conditions
  Err
  /// Warning conditions
  Warning
  /// Normal but significant condition
  Notice
  /// Informational messages
  Info
  /// Debug-level messages
  Debug
  /// Fine-grained tracing
  Trace
}

/// Convert level to numeric severity (lower = more severe)
pub fn to_int(level: Level) -> Int {
  case level {
    Emergency -> 0
    Alert -> 1
    Critical -> 2
    Err -> 3
    Warning -> 4
    Notice -> 5
    Info -> 6
    Debug -> 7
    Trace -> 8
  }
}

/// Parse level from integer
pub fn from_int(n: Int) -> Level {
  case n {
    0 -> Emergency
    1 -> Alert
    2 -> Critical
    3 -> Err
    4 -> Warning
    5 -> Notice
    6 -> Info
    7 -> Debug
    _ -> Trace
  }
}

/// Convert level to string
pub fn to_string(level: Level) -> String {
  case level {
    Emergency -> "EMERGENCY"
    Alert -> "ALERT"
    Critical -> "CRITICAL"
    Err -> "ERROR"
    Warning -> "WARNING"
    Notice -> "NOTICE"
    Info -> "INFO"
    Debug -> "DEBUG"
    Trace -> "TRACE"
  }
}

/// Convert level to short string (3 chars)
pub fn to_short_string(level: Level) -> String {
  case level {
    Emergency -> "EMG"
    Alert -> "ALT"
    Critical -> "CRT"
    Err -> "ERR"
    Warning -> "WRN"
    Notice -> "NTC"
    Info -> "INF"
    Debug -> "DBG"
    Trace -> "TRC"
  }
}

/// Parse level from string (case insensitive)
pub fn from_string(s: String) -> Result(Level, Nil) {
  case string.lowercase(s) {
    "emergency" | "emg" -> Ok(Emergency)
    "alert" | "alt" -> Ok(Alert)
    "critical" | "crt" -> Ok(Critical)
    "error" | "err" -> Ok(Err)
    "warning" | "warn" | "wrn" -> Ok(Warning)
    "notice" | "ntc" -> Ok(Notice)
    "info" | "inf" -> Ok(Info)
    "debug" | "dbg" -> Ok(Debug)
    "trace" | "trc" -> Ok(Trace)
    _ -> Error(Nil)
  }
}

/// Compare two levels (for filtering)
pub fn compare(a: Level, b: Level) -> Order {
  int.compare(to_int(a), to_int(b))
}

/// Check if level a is at least as severe as level b
pub fn is_enabled(log_level: Level, min_level: Level) -> Bool {
  to_int(log_level) <= to_int(min_level)
}

/// ANSI color code for level
pub fn to_color(level: Level) -> String {
  case level {
    Emergency -> "\u{001b}[1;41;37m"
    // Bold white on red bg
    Alert -> "\u{001b}[1;31m"
    // Bold red
    Critical -> "\u{001b}[31m"
    // Red
    Err -> "\u{001b}[91m"
    // Light red
    Warning -> "\u{001b}[93m"
    // Yellow
    Notice -> "\u{001b}[96m"
    // Cyan
    Info -> "\u{001b}[92m"
    // Green
    Debug -> "\u{001b}[90m"
    // Gray
    Trace -> "\u{001b}[90m"
    // Gray
  }
}

/// ANSI reset code
pub fn color_reset() -> String {
  "\u{001b}[0m"
}
