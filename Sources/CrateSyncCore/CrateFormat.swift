import Foundation

/// Serato's binary .crate format. Output must stay byte-identical to
/// sync_serato_crates.py, otherwise unchanged crates would be rewritten.
enum CrateFormat {
    private static let columns = [
        ("song", "250"),
        ("artist", "250"),
        ("bpm", "30"),
        ("key", "30"),
        ("album", "250"),
        ("length", "250"),
        ("comment", "250"),
    ]

    /// `trackPaths` are stored as given, so they must already be relative to the drive root.
    static func build(trackPaths: [String]) -> Data {
        var data = tag("vrsn", utf16be("1.0/Serato ScratchLive Crate"))
        for (name, width) in columns {
            data.append(tag("ovct", tag("tvcn", utf16be(name)) + tag("tvcw", utf16be(width))))
        }
        // UTF-8 order is code point order, which is what Python's sorted() uses.
        // Swift's own String ordering would differ on accented names.
        for path in trackPaths.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            data.append(tag("otrk", tag("ptrk", utf16be(path))))
        }
        return data
    }

    private static func utf16be(_ text: String) -> Data {
        var data = Data(capacity: text.utf16.count * 2)
        for unit in text.utf16 {
            data.append(UInt8(unit >> 8))
            data.append(UInt8(unit & 0xff))
        }
        return data
    }

    private static func tag(_ name: String, _ payload: Data) -> Data {
        var data = Data(name.utf8)
        withUnsafeBytes(of: UInt32(payload.count).bigEndian) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }
}
