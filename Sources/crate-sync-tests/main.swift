import Foundation

@testable import CrateSyncCore

// Plain executable: XCTest and Swift Testing both need Xcode, and this project builds without it.
// Run with: swift run crate-sync-tests

var failureCount = 0

func expect(_ condition: Bool, _ label: String, line: Int = #line) {
    if !condition {
        failureCount += 1
        print("  FAILED (line \(line)): \(label)")
    }
}

func expectThrows(_ label: String, line: Int = #line, _ work: () throws -> Void) {
    do {
        try work()
        expect(false, label + " should throw", line: line)
    } catch {}
}

/// A throwaway library: `<root>/_Serato_/Subcrates` and `<root>/Sons`.
struct Library {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    var settings: SyncSettings { SyncSettings(musicPath: root.path + "/Sons", seratoParentPath: root.path) }
    var backups: BackupStore { BackupStore(folder: root.appendingPathComponent("backups")) }
    var subcrates: String { root.path + "/_Serato_/Subcrates" }

    init() throws {
        try FileManager.default.createDirectory(atPath: subcrates, withIntermediateDirectories: true)
    }

    func addTrack(_ relativePath: String) throws {
        let url = root.appendingPathComponent("Sons/" + relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
    }

    func sync() throws {
        _ = try SyncEngine.apply(try SyncEngine.plan(settings), settings: settings, backups: backups)
    }
}

func test(_ name: String, _ body: (Library) throws -> Void) {
    print(name)
    do {
        let library = try Library()
        defer { try? FileManager.default.removeItem(at: library.root) }
        try body(library)
    } catch {
        failureCount += 1
        print("  FAILED: \(error)")
    }
}

test("Colons are encoded like Serato") { _ in
    expect(CrateName.stem(folders: ["Riddim: A", "b"]) == "Riddim␛␛3a A%%b", "stem")
    expect(CrateName.displayName(fileName: "Riddim␛␛3a A%%b.crate") == "Riddim: A › b", "display name")
}

test("Audio detection follows extensions and skips companion files") { _ in
    expect(LibraryScanner.isAudio("track.FLAC"), "uppercase extension")
    expect(!LibraryScanner.isAudio("cover.jpg"), "image")
    expect(!LibraryScanner.isAudio("track.wma"), "format Serato for Mac refuses")
    expect(!LibraryScanner.isAudio("._track.mp3"), "exFAT companion file")
    expect(!LibraryScanner.isAudio(".mp3"), "dot file")
}

test("Track paths depend on the drive holding _Serato_") { _ in
    let startup = SyncSettings(musicPath: "/Users/me/Sons", seratoParentPath: "/Users/me/Music")
    expect(startup.cratePath(forTrackAt: "/Users/me/Sons/a.mp3") == "Users/me/Sons/a.mp3", "startup disk")

    let external = SyncSettings(musicPath: "/Volumes/DJ/Sons", seratoParentPath: "/Volumes/DJ")
    expect(external.cratePath(forTrackAt: "/Volumes/DJ/Sons/a.mp3") == "Sons/a.mp3", "external drive")

    let mixed = SyncSettings(musicPath: "/Volumes/DJ/Sons", seratoParentPath: "/Users/me/Music")
    expect(mixed.cratePath(forTrackAt: "/Volumes/DJ/Sons/a.mp3") == "Volumes/DJ/Sons/a.mp3", "mixed")
}

test("A parent crate includes its subfolders") { library in
    try library.addTrack("Afro/one.mp3")
    try library.addTrack("Afro/amapiano/two.flac")

    let plan = try SyncEngine.plan(library.settings)

    let counts = Dictionary(uniqueKeysWithValues: plan.changes.map { ($0.fileName, $0.trackCount) })
    expect(counts == ["Afro.crate": 2, "Afro%%amapiano.crate": 1], "counts: \(counts)")
}

test("A second run finds nothing to do") { library in
    try library.addTrack("Afro/one.mp3")
    try library.sync()

    let plan = try SyncEngine.plan(library.settings)

    expect(plan.changes.isEmpty, "no changes")
    expect(plan.unchangedCount == 1, "one unchanged crate")
}

test("A folder with a colon is written under Serato's name") { library in
    try library.addTrack("Riddim: A/one.mp3")
    try library.sync()

    let names = try FileManager.default.contentsOfDirectory(atPath: library.subcrates)

    expect(names == ["Riddim␛␛3a A.crate"], "names: \(names)")
    expect(try SyncEngine.plan(library.settings).changes.isEmpty, "stable on the next run")
}

test("A crate without a folder is reported and left in place") { library in
    try library.addTrack("Afro/one.mp3")
    let orphan = library.subcrates + "/Made by hand.crate"
    try Data([1]).write(to: URL(fileURLWithPath: orphan))

    let plan = try SyncEngine.plan(library.settings)
    try library.sync()

    expect(plan.orphanFileNames == ["Made by hand.crate"], "reported")
    expect(FileManager.default.fileExists(atPath: orphan), "kept")
}

test("A backup is made before overwriting") { library in
    try library.addTrack("Afro/one.mp3")
    try Data([1]).write(to: URL(fileURLWithPath: library.subcrates + "/Afro.crate"))

    try library.sync()

    let folder = library.backups.folder
    let backup = try FileManager.default.contentsOfDirectory(atPath: folder.path)[0]
    let saved = folder.appendingPathComponent(backup + "/Afro.crate")
    expect(try Data(contentsOf: saved) == Data([1]), "previous content saved")
}

test("Nothing is backed up when nothing changes") { library in
    try library.addTrack("Afro/one.mp3")
    try library.sync()
    try FileManager.default.removeItem(at: library.backups.folder)

    try library.sync()

    expect(!FileManager.default.fileExists(atPath: library.backups.folder.path), "no backup")
}

test("Only the most recent backups are kept") { library in
    let store = library.backups
    let fileManager = FileManager.default
    for day in 10...24 {
        try fileManager.createDirectory(
            at: store.folder.appendingPathComponent("2026-01-\(day)_00-00-00"),
            withIntermediateDirectories: true)
    }

    try store.backUp(subcratesPath: library.subcrates)

    let names = try fileManager.contentsOfDirectory(atPath: store.folder.path).sorted()
    expect(names.count == 10, "count: \(names.count)")
    expect(!names.contains("2026-01-10_00-00-00"), "oldest removed")
}

test("A missing music folder is an error") { library in
    expectThrows("plan") { _ = try SyncEngine.plan(library.settings) }
}

test("A music folder without subfolders is an error") { library in
    try FileManager.default.createDirectory(atPath: library.settings.musicPath, withIntermediateDirectories: true)
    expectThrows("plan") { _ = try SyncEngine.plan(library.settings) }
}

print(failureCount == 0 ? "All tests passed" : "\(failureCount) failure(s)")
exit(failureCount == 0 ? 0 : 1)
