import Foundation

/// Copies Subcrates aside before anything is written, keeping the most recent copies.
public struct BackupStore {
    public let folder: URL
    private let keptCount = 10

    public init(folder: URL) {
        self.folder = folder
    }

    public static var standard: BackupStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return BackupStore(folder: support.appendingPathComponent("Serato Crates Sync/Backups"))
    }

    func backUp(subcratesPath: String) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: subcratesPath) else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let destination = folder.appendingPathComponent(formatter.string(from: Date()))

        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            // Two runs within the same second already share an identical backup.
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: URL(fileURLWithPath: subcratesPath), to: destination)
            }
        } catch {
            throw SyncError.backupFailed(error.localizedDescription)
        }
        removeOldBackups()
    }

    private func removeOldBackups() {
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
        // Names are timestamps, so sorting them sorts by date.
        for name in names.filter({ !$0.hasPrefix(".") }).sorted().dropLast(keptCount) {
            try? fileManager.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}
