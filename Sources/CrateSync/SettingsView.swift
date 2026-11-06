import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Réglages")
                .font(.title2.weight(.semibold))

            FolderRow(
                title: "Dossier de musique",
                detail: "Chaque sous-dossier devient une crate.",
                path: model.musicPath,
                choose: { chooseFolder { model.setMusicPath($0) } })

            FolderRow(
                title: "Emplacement de Serato",
                detail: "Le dossier qui contient _Serato_ : Musique, ou la racine du disque externe.",
                path: model.seratoParentPath,
                choose: { chooseFolder { model.seratoParentPath = $0 } })

            HStack {
                // Until both folders are chosen, this sheet can't be dismissed and blocks the window's close button.
                if !model.isConfigured {
                    Button("Quitter") { model.quit() }
                }
                Spacer()
                Button("Terminé") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.isConfigured)
            }

            Text(versionLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .frame(width: 520)
        .interactiveDismissDisabled(!model.isConfigured)
    }

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let copyright = info?["NSHumanReadableCopyright"] as? String ?? ""
        return "Version \(version) · \(copyright)"
    }

    private func chooseFolder(_ onChoice: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir"
        if panel.runModal() == .OK, let url = panel.url {
            onChoice(url.path)
        }
    }
}

private struct FolderRow: View {
    let title: String
    let detail: String
    let path: String
    let choose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Text(path.isEmpty ? "Aucun dossier choisi" : path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choisir…", action: choose)
            }
        }
    }
}
