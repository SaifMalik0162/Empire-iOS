import Foundation
import OSLog

final class AppTelemetry {
    static let shared = AppTelemetry()

    private let analyticsLogger = Logger(subsystem: "com.empire.app", category: "analytics")
    private let errorLogger = Logger(subsystem: "com.empire.app", category: "errors")
    private let performanceLogger = Logger(subsystem: "com.empire.app", category: "performance")

    private init() {}

    func configure() {
        NSSetUncaughtExceptionHandler { exception in
            let logger = Logger(subsystem: "com.empire.app", category: "crash")
            logger.critical("Uncaught exception: \(exception.name.rawValue, privacy: .public) reason=\(exception.reason ?? "unknown", privacy: .public)")
        }
    }

    func track(event: String, metadata: [String: String] = [:]) {
        if metadata.isEmpty {
            analyticsLogger.info("event=\(event, privacy: .public)")
            return
        }
        let payload = metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        analyticsLogger.info("event=\(event, privacy: .public) metadata=\(payload, privacy: .public)")
    }

    func record(error: Error, context: String) {
        errorLogger.error("context=\(context, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }

    func measure<T>(operation: String, _ block: () async throws -> T) async rethrows -> T {
        let start = ContinuousClock.now
        do {
            let value = try await block()
            let duration = start.duration(to: ContinuousClock.now)
            performanceLogger.info("operation=\(operation, privacy: .public) status=success duration=\(String(describing: duration), privacy: .public)")
            return value
        } catch {
            let duration = start.duration(to: ContinuousClock.now)
            performanceLogger.error("operation=\(operation, privacy: .public) status=failed duration=\(String(describing: duration), privacy: .public)")
            throw error
        }
    }
}
