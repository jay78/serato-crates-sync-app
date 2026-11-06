import CrateSyncCore
import SwiftUI

private final class CleanChoices: ObservableObject {
    @Published var selection: Set<String> = []
    @Published var isConfirming = false
}

/// Nothing is ticked by default: a crate without a folder may be one made by hand.
struct CleanView: View {
    @ObservedObject var model: AppModel
    let fileNames: [String]

    @Environment(\.dismiss) private var dismiss
    // @State needs a macro plugin that only ships with Xcode, and this project builds without it.
    @StateObject private var choices = CleanChoices()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crates sans dossier")
                .font(.title2.weight(.semibold))

            if fileNames.isEmpty {
                Text("Toutes les crates correspondent à un dossier. Rien à nettoyer.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Ces crates ne correspondent à aucun dossier, mais certaines ont peut-être été faites à la main dans Serato. Coche uniquement celles à retirer : elles iront à la corbeille. Si une crate revient après une session Serato, supprime-la dans Serato.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                List(fileNames, id: \.self) { fileName in
                    Toggle(isOn: binding(for: fileName)) {
                        Text(CrateName.displayName(fileName: fileName))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if !fileNames.isEmpty {
                    Button("Mettre à la corbeille (\(choices.selection.count))") {
                        choices.isConfirming = true
                    }
                    .disabled(choices.selection.isEmpty)
                }
            }
        }
        .padding(22)
        .frame(width: 580, height: 460)
        .confirmationDialog(
            "Mettre " + counted(choices.selection.count, "crate", "crates") + " à la corbeille ?",
            isPresented: $choices.isConfirming
        ) {
            Button("Mettre à la corbeille", role: .destructive) {
                model.trash(fileNames.filter(choices.selection.contains))
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Une sauvegarde est faite avant. Tes fichiers audio ne sont pas touchés.")
        }
    }

    private func binding(for fileName: String) -> Binding<Bool> {
        Binding(
            get: { choices.selection.contains(fileName) },
            set: { isOn in
                if isOn {
                    choices.selection.insert(fileName)
                } else {
                    choices.selection.remove(fileName)
                }
            })
    }
}
