import CrateSyncCore
import Foundation

// Developer tool: runs the engine without the interface, to compare its output
// with sync_serato_crates.py. Point it at a scratch folder, not a real library.
//
//   crate-sync-check <serato_parent> <music_dir> [--write]

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("Usage: crate-sync-check <serato_parent> <music_dir> [--write]")
    exit(2)
}

let settings = SyncSettings(musicPath: arguments[2], seratoParentPath: arguments[1])
let backups = BackupStore(
    folder: URL(fileURLWithPath: arguments[1]).appendingPathComponent("crate-sync-check-backups"))

do {
    let plan = try SyncEngine.plan(settings)
    for change in plan.changes {
        print("[\(change.kind == .create ? "CREATE" : "UPDATE")] \(change.fileName) (\(change.trackCount) tracks)")
    }
    print("\(plan.changes.count) to write, \(plan.unchangedCount) unchanged, \(plan.orphanFileNames.count) orphans")

    if arguments.contains("--write") {
        let failures = try SyncEngine.apply(plan, settings: settings, backups: backups)
        failures.forEach { print("[FAILED] \($0.fileName): \($0.reason)") }
        exit(failures.isEmpty ? 0 : 1)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
