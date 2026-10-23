import Foundation

enum SupabaseConfig {
    /// `SUPABASE_PROJECT_URL` is a per-configuration build setting copied into Info.plist.
    /// Release uses prod storage; the Staging configuration uses the blnd_staging project.
    static let projectURL: String = {
        let raw = (Bundle.main.infoDictionary?["SUPABASE_PROJECT_URL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "https://wtnbecnjsougjjcplhqf.supabase.co" : raw
    }()
    static let bucket = "avatars"
}
