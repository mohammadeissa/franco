import Foundation

/// Locates the Resources directory in dev (`swift run`) and in the packaged app.
enum ResourceLocator {
    static let root: URL = {
        if let env = ProcessInfo.processInfo.environment["FRANCO_RESOURCES"] {
            return URL(fileURLWithPath: env)
        }
        // Packaged app: Franco.app/Contents/Resources/{profiles,dict}
        if let r = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: r.appendingPathComponent("profiles").path) {
            return r
        }
        // Dev: derive from source file path -> <root>/Sources/Franco/Engine/Resources.swift
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return root.appendingPathComponent("Resources")
    }()

    static func profile(_ id: String) -> URL { root.appendingPathComponent("profiles/\(id).json") }
    static func dict(_ name: String) -> URL { root.appendingPathComponent("dict/\(name)") }

    static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Franco", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
}
