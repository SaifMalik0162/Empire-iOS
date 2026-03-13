import OSLog

enum AppLogger {
    private static let subsystem = "com.empire.app"

    static let supabaseAuth = Logger(subsystem: subsystem, category: "supabase-auth")
    static let supabaseCars = Logger(subsystem: subsystem, category: "supabase-cars")
    static let supabaseMeets = Logger(subsystem: subsystem, category: "supabase-meets")
}
