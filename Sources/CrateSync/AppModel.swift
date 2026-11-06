import AppKit
import CrateSyncCore
import SwiftUI

struct Report {
    let title: String
    let isPreview: Bool
    let changes: [CrateChange]
    let unchangedCount: Int
    let orphanCount: Int
    var failures: [Failure] = []
}

func counted(_ count: Int, _ singular: String, _ plural: String) -> String {
    "\(count) \(count > 1 ? plural : singular)"
}

@MainActor
final class AppModel: ObservableObject {
    private static let seratoBundleID = "com.serato.seratodj"
    private static let musicPathKey = "musicPath"
    private static let seratoParentPathKey = "seratoParentPath"

    @Published var musicPath: String {
        didSet { UserDefaults.standard.set(musicPath, forKey: Self.musicPathKey) }
    }
    @Published var seratoParentPath: String {
        didSet { UserDefaults.standard.set(seratoParentPath, forKey: Self.seratoParentPathKey) }
    }
    @Published var isShowingSettings = false
    @Published var isBusy = false
    @Published var isSeratoRunning = false
    @Published var report: Report?
    @Published var errorMessage: String?
    @Published var cleanCandidates: [String]?

    private var isQuitting = false
    let backups = BackupStore.standard
    private var observers: [NSObjectProtocol] = []

    init() {
        let defaults = UserDefaults.standard
        musicPath = defaults.string(forKey: Self.musicPathKey) ?? ""
        seratoParentPath = defaults.string(forKey: Self.seratoParentPathKey) ?? Self.defaultSeratoParent()
        isShowingSettings = !isConfigured
        refreshSeratoState()

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshSeratoState() }
            })
        }
    }

    var isConfigured: Bool { !musicPath.isEmpty && !seratoParentPath.isEmpty }

    var canWrite: Bool { isConfigured && !isBusy && !isSeratoRunning }

    private var settings: SyncSettings {
        SyncSettings(musicPath: musicPath, seratoParentPath: seratoParentPath)
    }

    private static func defaultSeratoParent() -> String {
        let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)[0].path
        return FileManager.default.fileExists(atPath: music + "/_Serato_") ? music : ""
    }

    private func refreshSeratoState() {
        isSeratoRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.seratoBundleID).isEmpty
    }

    /// On an external drive, `_Serato_` sits at the drive root, so offer it straight away.
    func setMusicPath(_ path: String) {
        musicPath = path
        let parts = path.split(separator: "/")
        if parts.count >= 2, parts[0] == "Volumes" {
            let driveRoot = "/Volumes/\(parts[1])"
            if FileManager.default.fileExists(atPath: driveRoot + "/_Serato_") {
                seratoParentPath = driveRoot
            }
        }
    }

    func preview() {
        run { settings, _ in
            let plan = try SyncEngine.plan(settings)
            return Report(
                title: "Aperçu : rien n'a été modifié",
                isPreview: true,
                changes: plan.changes,
                unchangedCount: plan.unchangedCount,
                orphanCount: plan.orphanFileNames.count)
        }
    }

    func synchronize() {
        refreshSeratoState()
        guard canWrite else { return }
        run { settings, backups in
            let plan = try SyncEngine.plan(settings)
            let failures = try SyncEngine.apply(plan, settings: settings, backups: backups)
            let failedNames = Set(failures.map(\.fileName))
            return Report(
                title: failures.isEmpty ? "Synchronisation terminée" : "Synchronisation terminée, avec des erreurs",
                isPreview: false,
                changes: plan.changes.filter { !failedNames.contains($0.fileName) },
                unchangedCount: plan.unchangedCount,
                orphanCount: plan.orphanFileNames.count,
                failures: failures)
        }
    }

    func prepareClean() {
        guard canWrite else { return }
        let settings = settings
        perform {
            try await Task.detached { try SyncEngine.plan(settings).orphanFileNames }.value
        } onSuccess: { [weak self] orphans in
            self?.cleanCandidates = orphans
        }
    }

    func trash(_ fileNames: [String]) {
        cleanCandidates = nil
        refreshSeratoState()
        guard canWrite else { return }
        run { settings, backups in
            let failures = try SyncEngine.trash(fileNames: fileNames, settings: settings, backups: backups)
            let plan = try SyncEngine.plan(settings)
            return Report(
                title: counted(fileNames.count - failures.count, "crate mise", "crates mises") + " à la corbeille",
                isPreview: false,
                changes: [],
                unchangedCount: plan.unchangedCount,
                orphanCount: plan.orphanFileNames.count,
                failures: failures)
        }
    }

    /// AppKit refuses to terminate while a sheet is attached, so sheets close first.
    func quit() {
        guard isShowingSettings || cleanCandidates != nil else {
            NSApp.terminate(nil)
            return
        }
        isQuitting = true
        isShowingSettings = false
        cleanCandidates = nil
    }

    func sheetDidClose() {
        if isQuitting {
            NSApp.terminate(nil)
        }
    }

    func showBackups() {
        try? FileManager.default.createDirectory(at: backups.folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(backups.folder)
    }

    private func run(_ work: @escaping @Sendable (SyncSettings, BackupStore) throws -> Report) {
        let settings = settings
        let backups = backups
        perform {
            try await Task.detached { try work(settings, backups) }.value
        } onSuccess: { [weak self] report in
            self?.report = report
        }
    }

    private func perform<Value>(
        _ work: @escaping () async throws -> Value,
        onSuccess: @escaping (Value) -> Void
    ) {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                onSuccess(try await work())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
