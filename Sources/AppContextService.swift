import Foundation
#if os(macOS)
import AppKit

struct RunningApplicationChoice: Identifiable, Hashable {
    let bundleIdentifier: String
    let name: String
    var id: String { bundleIdentifier }
}

final class AppContextService {
    static let shared = AppContextService()

    var currentBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func runningApplications() -> [RunningApplicationChoice] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .compactMap { app -> RunningApplicationChoice? in
                guard app.activationPolicy == .regular,
                      let bundleIdentifier = app.bundleIdentifier,
                      !bundleIdentifier.isEmpty,
                      seen.insert(bundleIdentifier).inserted else {
                    return nil
                }
                let name = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
                return RunningApplicationChoice(
                    bundleIdentifier: bundleIdentifier,
                    name: (name?.isEmpty == false ? name! : bundleIdentifier)
                )
            }
            .sorted { lhs, rhs in lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
    }
}
#endif
