import Foundation
import OSLog

/// Logging categories aligned with Family Foqos device sync code.
enum LogCategory: String {
  case app = "App"
  case cloudKit = "CloudKit"
  case sync = "Sync"
  case strategy = "Strategy"
  case ui = "UI"
}

enum Log {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.ambitionsoftware.tymeboxed"

  static func debug(
    _ message: String,
    category: LogCategory = .app,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    Logger(subsystem: subsystem, category: category.rawValue).debug(
      "\((file as NSString).lastPathComponent):\(line) \(message)")
  }

  static func info(
    _ message: String,
    category: LogCategory = .app,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    Logger(subsystem: subsystem, category: category.rawValue).info(
      "\((file as NSString).lastPathComponent):\(line) \(message)")
  }

  static func warning(
    _ message: String,
    category: LogCategory = .app,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    Logger(subsystem: subsystem, category: category.rawValue).warning(
      "\((file as NSString).lastPathComponent):\(line) \(message)")
  }

  static func error(
    _ message: String,
    category: LogCategory = .app,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    Logger(subsystem: subsystem, category: category.rawValue).error(
      "\((file as NSString).lastPathComponent):\(line) \(message)")
  }
}
