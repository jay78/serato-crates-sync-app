import Foundation

struct ScannedCrate {
    let stem: String
    let audioPaths: [String]
}

/// Walks the music folder. Each subfolder becomes a crate holding its own audio files
/// and those of all its subfolders. Uses readdir because names must reach the crate
/// exactly as stored on disk, without Unicode normalization.
enum LibraryScanner {
    // No "wma": Serato for Mac drops those tracks on every export ("Unknown file format"),
    // so listing them would report the same crates as changed on every run.
    private static let audioExtensions: Set<String> = [
        "mp3", "flac", "wav", "m4a", "aif", "aiff", "ogg", "alac", "mp4", "aac",
    ]

    static func scan(musicPath: String) throws -> [ScannedCrate] {
        var crates: [ScannedCrate] = []
        _ = try collect(path: musicPath, folders: [], into: &crates)
        return crates
    }

    private static func collect(
        path: String, folders: [String], into crates: inout [ScannedCrate]
    ) throws -> [String] {
        var audioPaths: [String] = []
        for entry in try entries(of: path) {
            let child = path + "/" + entry.name
            if entry.isFolder {
                audioPaths += try collect(path: child, folders: folders + [entry.name], into: &crates)
            } else if isAudio(entry.name) {
                audioPaths.append(child)
            }
        }
        if !folders.isEmpty {
            crates.append(ScannedCrate(stem: CrateName.stem(folders: folders), audioPaths: audioPaths))
        }
        return audioPaths
    }

    /// Skips the `._` companion files macOS leaves on exFAT drives: they look like audio but aren't.
    static func isAudio(_ name: String) -> Bool {
        guard !name.hasPrefix("._"), let dot = name.lastIndex(of: ".") else { return false }
        // Same as Python's splitext: leading dots don't start an extension.
        guard name[..<dot].contains(where: { $0 != "." }) else { return false }
        return audioExtensions.contains(name[name.index(after: dot)...].lowercased())
    }

    private struct Entry {
        let name: String
        let isFolder: Bool
    }

    private static func entries(of path: String) throws -> [Entry] {
        guard let directory = opendir(path) else {
            throw SyncError.unreadableFolder(path)
        }
        defer { closedir(directory) }

        var entries: [Entry] = []
        while let pointer = readdir(directory) {
            let name = withUnsafePointer(to: &pointer.pointee.d_name) {
                String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            if name == "." || name == ".." { continue }

            switch Int32(pointer.pointee.d_type) {
            case DT_DIR:
                entries.append(Entry(name: name, isFolder: true))
            case DT_LNK:
                // Links to folders aren't followed, to avoid loops.
                if !pointsToFolder(path + "/" + name) {
                    entries.append(Entry(name: name, isFolder: false))
                }
            case DT_UNKNOWN:
                // Some exFAT and network drives don't report the entry type.
                var info = stat()
                let isFolder = lstat(path + "/" + name, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
                entries.append(Entry(name: name, isFolder: isFolder))
            default:
                entries.append(Entry(name: name, isFolder: false))
            }
        }
        return entries
    }

    private static func pointsToFolder(_ path: String) -> Bool {
        var info = stat()
        return stat(path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
    }
}
