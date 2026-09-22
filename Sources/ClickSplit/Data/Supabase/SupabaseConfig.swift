import Foundation

/// Supabase configuration constants shared across Click platforms.
public enum SupabaseConfig {
    /// Shared Supabase project URL
    public static let defaultURL = URL(string: "https://lrgcwnmcscimkmslihxp.supabase.co")!

    /// Publishable anon key safe for client-side inclusion
    public static let defaultAnonKey = "sb_publishable_jJ7PIx7o_wIZcs8GNho4Kw_1TFn6Zcs"

    /// Server API base URL for receipt scanning and protected operations
    public static let defaultServerBaseURL = URL(string: "https://split.joinclick.co")!
}
