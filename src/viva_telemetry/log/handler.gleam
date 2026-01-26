//// Handler interface for log outputs
////
//// Handlers receive log entries and output them somewhere:
//// - Console (stdout/stderr)
//// - File (with rotation)
//// - JSON file (structured)
//// - Custom (network, database, etc.)

import viva_telemetry/log/entry.{type Entry}
import viva_telemetry/log/level.{type Level}

/// Handler configuration
pub type Handler {
  /// Console handler - outputs to stdout/stderr
  ConsoleHandler(config: ConsoleConfig)
  /// JSON handler - outputs structured JSON to file
  JsonHandler(config: JsonConfig)
  /// File handler - outputs plain text to file
  FileHandler(config: FileConfig)
  /// Custom handler - user-provided function
  CustomHandler(config: CustomConfig)
}

/// Console handler configuration
pub type ConsoleConfig {
  ConsoleConfig(
    /// Minimum level to log
    level: Level,
    /// Use ANSI colors
    colored: Bool,
    /// Output to stderr for errors (else stdout)
    stderr_for_errors: Bool,
  )
}

/// JSON handler configuration
pub type JsonConfig {
  JsonConfig(
    /// Minimum level to log
    level: Level,
    /// File path
    path: String,
    /// Pretty print JSON
    pretty: Bool,
  )
}

/// File handler configuration
pub type FileConfig {
  FileConfig(
    /// Minimum level to log
    level: Level,
    /// File path
    path: String,
    /// Rotation strategy
    rotation: Rotation,
  )
}

/// Custom handler configuration
pub type CustomConfig {
  CustomConfig(
    /// Minimum level to log
    level: Level,
    /// Custom handler function
    handler_fn: fn(Entry) -> Nil,
  )
}

/// File rotation strategies
pub type Rotation {
  /// No rotation
  NoRotation
  /// Rotate daily
  Daily
  /// Rotate when file exceeds size (bytes)
  Size(max_bytes: Int)
  /// Keep N rotated files
  KeepN(n: Int, strategy: Rotation)
}

/// Default console handler (Info level, colored)
pub fn console() -> Handler {
  ConsoleHandler(ConsoleConfig(
    level: level.Info,
    colored: True,
    stderr_for_errors: True,
  ))
}

/// Console handler with custom level
pub fn console_with_level(lvl: Level) -> Handler {
  ConsoleHandler(ConsoleConfig(
    level: lvl,
    colored: True,
    stderr_for_errors: True,
  ))
}

/// JSON handler
pub fn json(path: String) -> Handler {
  JsonHandler(JsonConfig(level: level.Info, path: path, pretty: False))
}

/// JSON handler with level
pub fn json_with_level(path: String, lvl: Level) -> Handler {
  JsonHandler(JsonConfig(level: lvl, path: path, pretty: False))
}

/// File handler
pub fn file(path: String) -> Handler {
  FileHandler(FileConfig(level: level.Info, path: path, rotation: NoRotation))
}

/// File handler with rotation
pub fn file_with_rotation(path: String, rotation: Rotation) -> Handler {
  FileHandler(FileConfig(level: level.Info, path: path, rotation: rotation))
}

/// Custom handler
pub fn custom(lvl: Level, handler_fn: fn(Entry) -> Nil) -> Handler {
  CustomHandler(CustomConfig(level: lvl, handler_fn: handler_fn))
}

/// Get handler's minimum level
pub fn get_level(handler: Handler) -> Level {
  case handler {
    ConsoleHandler(c) -> c.level
    JsonHandler(c) -> c.level
    FileHandler(c) -> c.level
    CustomHandler(c) -> c.level
  }
}

/// Check if handler should process this level
pub fn should_log(handler: Handler, log_level: Level) -> Bool {
  level.is_enabled(log_level, get_level(handler))
}
