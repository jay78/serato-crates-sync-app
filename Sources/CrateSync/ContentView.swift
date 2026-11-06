import CrateSyncCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.isSeratoRunning {
                seratoBanner
                Divider()
            }
            results
            Divider()
            footer
        }
        .sheet(isPresented: $model.isShowingSettings, onDismiss: model.sheetDidClose) {
            SettingsView(model: model)
        }
        .sheet(isPresented: isShowingClean, onDismiss: model.sheetDidClose) {
            CleanView(model: model, fileNames: model.cleanCandidates ?? [])
        }
        .alert("Une erreur est survenue", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var isShowingClean: Binding<Bool> {
        Binding(
            get: { model.cleanCandidates != nil },
            set: { if !$0 { model.cleanCandidates = nil } })
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                model.preview()
            } label: {
                Label("Aperçu", systemImage: "eye")
            }
            .disabled(!model.isConfigured || model.isBusy)
            .help("Montre ce qui changerait, sans rien écrire")

            Button {
                model.synchronize()
            } label: {
                Label("Synchroniser", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canWrite)
            .help("Crée et met à jour les crates, après une sauvegarde")

            Button {
                model.prepareClean()
            } label: {
                Label("Nettoyer…", systemImage: "trash")
            }
            .disabled(!model.canWrite)
            .help("Choisit les crates sans dossier à mettre à la corbeille")

            Spacer()

            if model.isBusy {
                ProgressView().controlSize(.small)
            }

            Button {
                model.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Réglages")
            .accessibilityLabel("Réglages")
        }
        .controlSize(.large)
        .padding(14)
    }

    private var seratoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Serato est ouvert. Ferme-le pour synchroniser : l'aperçu reste possible.")
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
    }

    @ViewBuilder
    private var results: some View {
        if let report = model.report {
            ReportView(report: report)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("Tes dossiers, en crates Serato")
                    .font(.headline)
                Text("Lance un aperçu pour voir ce qui changerait, sans rien écrire.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack {
            Text(model.musicPath.isEmpty ? "Aucun dossier de musique choisi" : model.musicPath)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Afficher les sauvegardes") {
                model.showBackups()
            }
            .buttonStyle(.link)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private struct ReportView: View {
    let report: Report

    private var createdCount: Int { report.changes.filter { $0.kind == .create }.count }
    private var updatedCount: Int { report.changes.count - createdCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.headline)
                Text(summary)
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            if report.changes.isEmpty && report.failures.isEmpty {
                Divider()
                Text("Tout est déjà à jour.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(report.failures) { failure in
                        FailureRow(failure: failure)
                    }
                    ForEach(report.changes) { change in
                        ChangeRow(change: change)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summary: String {
        var parts: [String] = []
        if report.changes.isEmpty {
            parts.append(counted(report.unchangedCount, "crate à jour", "crates à jour"))
        } else if report.isPreview {
            parts.append("\(createdCount) à créer")
            parts.append("\(updatedCount) à mettre à jour")
            parts.append(counted(report.unchangedCount, "inchangée", "inchangées"))
        } else {
            parts.append(counted(createdCount, "créée", "créées"))
            parts.append(counted(updatedCount, "mise à jour", "mises à jour"))
            parts.append(counted(report.unchangedCount, "inchangée", "inchangées"))
        }
        if report.orphanCount > 0 {
            parts.append("\(report.orphanCount) sans dossier")
        }
        return parts.joined(separator: " · ")
    }
}

private struct ChangeRow: View {
    let change: CrateChange

    var body: some View {
        HStack(spacing: 10) {
            Text(change.kind == .create ? "Nouvelle" : "Mise à jour")
                .font(.caption.weight(.medium))
                .foregroundStyle(change.kind == .create ? Color.green : Color.accentColor)
                .frame(width: 72, alignment: .leading)
            Text(CrateName.displayName(fileName: change.fileName))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(counted(change.trackCount, "morceau", "morceaux"))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

private struct FailureRow: View {
    let failure: Failure

    var body: some View {
        HStack(spacing: 10) {
            Text("Échec")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading) {
                Text(CrateName.displayName(fileName: failure.fileName))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(failure.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
