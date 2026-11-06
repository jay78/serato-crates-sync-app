/// Conversions between folder paths and Serato crate file names.
///
/// Serato separates subcrates with `%%` and stores `:` as `␛␛3a` (U+241B twice, then the
/// hex code). A crate written with a literal `:` is dropped by Serato's next export.
public enum CrateName {
    public static let fileExtension = ".crate"
    private static let separator = "%%"
    private static let encodedColon = "␛␛3a"

    /// ["Afro", "amapiano"] → "Afro%%amapiano"
    static func stem(folders: [String]) -> String {
        folders.joined(separator: separator)
            .split(separator: ":", omittingEmptySubsequences: false)
            .joined(separator: encodedColon)
    }

    /// "Afro%%amapiano.crate" → "Afro › amapiano"
    public static func displayName(fileName: String) -> String {
        var stem = fileName
        if stem.hasSuffix(fileExtension) {
            stem.removeLast(fileExtension.count)
        }
        return stem
            .components(separatedBy: separator)
            .joined(separator: " › ")
            .components(separatedBy: encodedColon)
            .joined(separator: ":")
    }
}
