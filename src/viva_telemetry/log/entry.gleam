//// Log entry type - the core data structure for log messages

import gleam/dict.{type Dict}
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/string
import viva_telemetry/log/level.{type Level}

/// A structured log entry
pub type Entry {
  Entry(
    /// Log level
    level: Level,
    /// Log message
    message: String,
    /// Structured fields (key-value pairs)
    fields: Dict(String, String),
    /// Unix timestamp in microseconds
    timestamp: Int,
    /// Inherited context fields
    context: Dict(String, String),
    /// Optional module/source name
    source: String,
  )
}

/// Create a new log entry
pub fn new(
  level: Level,
  message: String,
  fields: List(#(String, String)),
) -> Entry {
  Entry(
    level: level,
    message: message,
    fields: dict.from_list(fields),
    timestamp: now_microseconds(),
    context: dict.new(),
    source: "",
  )
}

/// Create entry with source module
pub fn with_source(entry: Entry, source: String) -> Entry {
  Entry(..entry, source: source)
}

/// Add context to entry
pub fn with_context(entry: Entry, context: Dict(String, String)) -> Entry {
  Entry(..entry, context: dict.merge(entry.context, context))
}

/// Add a field to entry
pub fn with_field(entry: Entry, key: String, value: String) -> Entry {
  Entry(..entry, fields: dict.insert(entry.fields, key, value))
}

/// Get all fields (context + entry fields)
pub fn all_fields(entry: Entry) -> Dict(String, String) {
  dict.merge(entry.context, entry.fields)
}

/// Convert entry to JSON
pub fn to_json(entry: Entry) -> Json {
  let fields =
    all_fields(entry)
    |> dict.to_list()
    |> list.map(fn(kv) { #(kv.0, json.string(kv.1)) })

  let base = [
    #("level", json.string(level.to_string(entry.level))),
    #("message", json.string(entry.message)),
    #("timestamp", json.int(entry.timestamp)),
  ]

  let with_source = case entry.source {
    "" -> base
    s -> [#("source", json.string(s)), ..base]
  }

  json.object(list.append(with_source, fields))
}

/// Convert entry to JSON string
pub fn to_json_string(entry: Entry) -> String {
  to_json(entry)
  |> json.to_string()
}

/// Format entry for console output
pub fn to_console_string(entry: Entry, colored: Bool) -> String {
  let level_str = level.to_short_string(entry.level)
  let time_str = format_timestamp(entry.timestamp)

  let level_formatted = case colored {
    True -> level.to_color(entry.level) <> level_str <> level.color_reset()
    False -> level_str
  }

  let source_str = case entry.source {
    "" -> ""
    s -> " [" <> s <> "]"
  }

  let fields_str = case dict.size(all_fields(entry)) {
    0 -> ""
    _ -> " " <> format_fields(all_fields(entry))
  }

  time_str
  <> " "
  <> level_formatted
  <> source_str
  <> " "
  <> entry.message
  <> fields_str
}

/// Format fields as key=value pairs
fn format_fields(fields: Dict(String, String)) -> String {
  fields
  |> dict.to_list()
  |> list.map(fn(kv) { kv.0 <> "=" <> quote_if_needed(kv.1) })
  |> string.join(" ")
}

/// Quote string if it contains spaces
fn quote_if_needed(s: String) -> String {
  case string.contains(s, " ") {
    True -> "\"" <> s <> "\""
    False -> s
  }
}

/// Format timestamp as ISO-like string (HH:MM:SS.mmm)
fn format_timestamp(ts: Int) -> String {
  // Convert microseconds to components
  let ms = ts / 1000 % 1000
  let secs = ts / 1_000_000
  let s = secs % 60
  let m = secs / 60 % 60
  let h = secs / 3600 % 24

  pad2(h) <> ":" <> pad2(m) <> ":" <> pad2(s) <> "." <> pad3(ms)
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

fn pad3(n: Int) -> String {
  case n < 10 {
    True -> "00" <> int.to_string(n)
    False ->
      case n < 100 {
        True -> "0" <> int.to_string(n)
        False -> int.to_string(n)
      }
  }
}

/// Get current time in microseconds (via Erlang)
@external(erlang, "viva_telemetry_ffi", "now_microseconds")
fn now_microseconds() -> Int
