import AppKit

// Draws the app icon at one size. Usage: swift make-icon.swift <size> <output.png>
// The base is read from the installed Serato app, so its artwork never enters this project.
//
// Serato's waveform fills its disc, leaving no room for arrows. So the waveform is lifted
// off the disc, the disc is repaired, and the waveform goes back smaller, inside the arrows.

let basePath = "/Applications/Serato DJ Pro.app/Contents/Resources/icon.icns"
guard let base = NSImage(contentsOfFile: basePath) else {
    print("Serato DJ Pro is needed to build the icon: \(basePath) not found")
    exit(1)
}

// Always composed at full size, because the waveform can't be isolated from a 16 px image.
let side = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)

func makeBitmap(_ pixels: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: pixels * 4, bitsPerPixel: 32)!
}

func draw(into bitmap: NSBitmapImageRep, _ body: () -> Void) {
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current!.imageInterpolation = .high
    body()
    NSGraphicsContext.current = nil
}

let disc = makeBitmap(side)
draw(into: disc) { base.draw(in: canvas) }
let pixels = disc.bitmapData!

let waveform = makeBitmap(side)
let waveformPixels = waveform.bitmapData!

func offset(_ x: Int, _ y: Int) -> Int { (y * side + x) * 4 }

/// The disc's blue has almost no red, so red tells how much of a pixel is waveform.
func isWaveform(_ x: Int, _ y: Int) -> Bool {
    let dx = Double(x - side / 2)
    let dy = Double(y - side / 2)
    return (dx * dx + dy * dy).squareRoot() < Double(side) * 0.43 && pixels[offset(x, y)] > 40
}

for y in 0..<side {
    for x in 0..<side where isWaveform(x, y) {
        let red = Double(pixels[offset(x, y)])
        let alpha = UInt8(min(255, max(0, (red - 40) / 200 * 255)))
        // bitmapData is premultiplied, so white at this opacity is `alpha` on every channel.
        for channel in 0..<4 {
            waveformPixels[offset(x, y) + channel] = alpha
        }
    }
}

// Repairs each row by blending between the blue on either side of the waveform. The disc's
// shading is mostly vertical, so the blue on a given row is nearly constant.
let margin = 8
for y in 0..<side {
    var x = 0
    while x < side {
        guard isWaveform(x, y) else {
            x += 1
            continue
        }
        var end = x
        while end + 1 < side, (end + 1..<min(side, end + 1 + margin)).contains(where: { isWaveform($0, y) }) {
            end += 1
        }
        let left = max(0, x - margin)
        let right = min(side - 1, end + margin)
        for fill in left...right {
            let ratio = Double(fill - left) / Double(max(1, right - left))
            for channel in 0..<4 {
                let start = Double(pixels[offset(left, y) + channel])
                let stop = Double(pixels[offset(right, y) + channel])
                pixels[offset(fill, y) + channel] = UInt8(start + (stop - start) * ratio)
            }
        }
        x = right + 1
    }
}

let arrowConfiguration = NSImage.SymbolConfiguration(pointSize: CGFloat(side) * 0.61, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let arrows = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)!
    .withSymbolConfiguration(arrowConfiguration)!

let composed = makeBitmap(side)
draw(into: composed) {
    disc.draw(in: canvas)
    let inset = CGFloat(side) * (1 - 0.42) / 2
    waveform.draw(
        in: canvas.insetBy(dx: inset, dy: inset), from: canvas, operation: .sourceOver,
        fraction: 1, respectFlipped: false, hints: nil)
    arrows.draw(
        at: NSPoint(x: (canvas.width - arrows.size.width) / 2, y: (canvas.height - arrows.size.height) / 2),
        from: .zero, operation: .sourceOver, fraction: 1)
}

let size = Int(CommandLine.arguments[1])!
let output = makeBitmap(size)
draw(into: output) {
    composed.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size), from: canvas, operation: .copy,
        fraction: 1, respectFlipped: false, hints: nil)
}
try! output.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
