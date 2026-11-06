import Foundation

public struct SyncSettings: Equatable {
    public var musicPath: String
    /// The folder that contains `_Serato_`: ~/Music, or the root of an external drive.
    public var seratoParentPath: String

    public init(musicPath: String, seratoParentPath: String) {
        self.musicPath = musicPath
        self.seratoParentPath = seratoParentPath
    }

    var seratoPath: String { seratoParentPath + "/_Serato_" }
    var subcratesPath: String { seratoPath + "/Subcrates" }

    /// Serato stores paths relative to the drive holding `_Serato_`: from the filesystem
    /// root on the startup disk, from the drive's own root on an external drive.
    func cratePath(forTrackAt path: String) -> String {
        let parts = seratoParentPath.split(separator: "/", omittingEmptySubsequences: true)
        if parts.count >= 2, parts[0] == "Volumes" {
            let driveRoot = "/Volumes/\(parts[1])/"
            if path.hasPrefix(driveRoot) {
                return String(path.dropFirst(driveRoot.count))
            }
        }
        return String(path.drop(while: { $0 == "/" }))
    }
}

public enum SyncError: LocalizedError {
    case musicFolderMissing(String)
    case seratoFolderMissing(String)
    case unreadableFolder(String)
    case noSubfolders(String)
    case backupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .musicFolderMissing(let path):
            return "Dossier de musique introuvable : \(path). Vérifie les réglages, et que le disque est branché."
        case .seratoFolderMissing(let path):
            return "Aucun dossier _Serato_ dans \(path). Vérifie les réglages, ou lance Serato une première fois."
        case .unreadableFolder(let path):
            return "Impossible de lire \(path). Rien n'a été modifié."
        case .noSubfolders(let path):
            return "Aucun sous-dossier dans \(path), donc aucune crate à créer. Rien n'a été modifié."
        case .backupFailed(let reason):
            return "La sauvegarde a échoué, rien n'a été modifié. \(reason)"
        }
    }
}

public struct CrateChange: Identifiable {
    public enum Kind { case create, update }

    public let fileName: String
    public let kind: Kind
    public let trackCount: Int
    let data: Data

    public var id: String { fileName }
}

public struct SyncPlan {
    public let changes: [CrateChange]
    public let unchangedCount: Int
    /// Crate files with no matching folder. Some may be crates made by hand in Serato.
    public let orphanFileNames: [String]
}

public struct Failure: Identifiable {
    public let fileName: String
    public let reason: String

    public var id: String { fileName }
}

public enum SyncEngine {
    /// Compares the music folder with the existing crates. Writes nothing.
    public static func plan(_ settings: SyncSettings) throws -> SyncPlan {
        let fileManager = FileManager.default
        var isFolder: ObjCBool = false
        guard fileManager.fileExists(atPath: settings.musicPath, isDirectory: &isFolder), isFolder.boolValue else {
            throw SyncError.musicFolderMissing(settings.musicPath)
        }
        guard fileManager.fileExists(atPath: settings.seratoPath, isDirectory: &isFolder), isFolder.boolValue else {
            throw SyncError.seratoFolderMissing(settings.seratoParentPath)
        }

        let crates = try LibraryScanner.scan(musicPath: settings.musicPath)
            .sorted { $0.stem.utf8.lexicographicallyPrecedes($1.stem.utf8) }
        // Without this guard, an empty scan would offer every crate for deletion.
        guard !crates.isEmpty else {
            throw SyncError.noSubfolders(settings.musicPath)
        }

        var changes: [CrateChange] = []
        var unchangedCount = 0
        for crate in crates {
            let fileName = crate.stem + CrateName.fileExtension
            let path = settings.subcratesPath + "/" + fileName
            let data = CrateFormat.build(trackPaths: crate.audioPaths.map(settings.cratePath(forTrackAt:)))

            if fileManager.fileExists(atPath: path) {
                if fileManager.contents(atPath: path) == data {
                    unchangedCount += 1
                } else {
                    changes.append(CrateChange(
                        fileName: fileName, kind: .update, trackCount: crate.audioPaths.count, data: data))
                }
            } else {
                changes.append(CrateChange(
                    fileName: fileName, kind: .create, trackCount: crate.audioPaths.count, data: data))
            }
        }

        let expected = Set(crates.map { $0.stem + CrateName.fileExtension })
        let existing = (try? fileManager.contentsOfDirectory(atPath: settings.subcratesPath)) ?? []
        let orphans = existing
            .filter { $0.hasSuffix(CrateName.fileExtension) && !expected.contains($0) }
            .sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }

        return SyncPlan(changes: changes, unchangedCount: unchangedCount, orphanFileNames: orphans)
    }

    /// Writes the planned crates, after a backup. One failing crate doesn't stop the others.
    public static func apply(
        _ plan: SyncPlan, settings: SyncSettings, backups: BackupStore
    ) throws -> [Failure] {
        guard !plan.changes.isEmpty else { return [] }
        try backups.backUp(subcratesPath: settings.subcratesPath)
        try FileManager.default.createDirectory(
            atPath: settings.subcratesPath, withIntermediateDirectories: true)

        var failures: [Failure] = []
        for change in plan.changes {
            let url = URL(fileURLWithPath: settings.subcratesPath + "/" + change.fileName)
            do {
                try change.data.write(to: url, options: .atomic)
            } catch {
                failures.append(Failure(fileName: change.fileName, reason: error.localizedDescription))
            }
        }
        return failures
    }

    /// Moves crates to the Trash, after a backup, so they can be put back.
    public static func trash(
        fileNames: [String], settings: SyncSettings, backups: BackupStore
    ) throws -> [Failure] {
        guard !fileNames.isEmpty else { return [] }
        try backups.backUp(subcratesPath: settings.subcratesPath)

        var failures: [Failure] = []
        for fileName in fileNames {
            let url = URL(fileURLWithPath: settings.subcratesPath + "/" + fileName)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                failures.append(Failure(fileName: fileName, reason: error.localizedDescription))
            }
        }
        return failures
    }
}
