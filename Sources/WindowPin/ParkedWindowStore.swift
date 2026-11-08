import Foundation
import os

@MainActor
final class ParkedWindowStore {
    private let logger = Logger(subsystem: AppIdentity.subsystem, category: "recovery")
    private let fileURL: URL

    init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.name, isDirectory: true)
        fileURL = directory.appendingPathComponent("parked-windows.json")
    }

    func sync(_ records: [ParkedWindowRecord]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Could not save parked windows: \(error.localizedDescription, privacy: .public)")
        }
    }

    func restoreOrphans() {
        guard PermissionGate.hasAccessibility else { return }
        let records = load()
        guard !records.isEmpty else { return }
        var remaining: [ParkedWindowRecord] = []
        for record in records {
            if !SourceWindowParker.restoreIfStillParked(record) {
                remaining.append(record)
            }
        }
        sync(remaining)
    }

    private func load() -> [ParkedWindowRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([ParkedWindowRecord].self, from: data)) ?? []
    }
}
