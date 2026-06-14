// Generates the WakeGuard app icon as PNGs into an .iconset directory.
// Drawn vectorially at every size with AppKit/CoreGraphics — no design tools.
//
// Concept: a heartbeat / ECG pulse line (keep-alive, "active") in white over a
// green→teal squircle, echoing the app's green "● Active" menu-bar indicator.
//
// Usage: swift scripts/make-icon.swift <output.iconset dir> [preview.png]
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <iconset-dir> [preview.png]\n".utf8))
    exit(2)
}
let iconsetDir = args[1]
let previewPath = args.count >= 3 ? args[2] : nil

try? FileManager.default.createDirectory(atPath: iconsetDir,
                                         withIntermediateDirectories: true)

/// Draws the icon at the given pixel size into a fresh bitmap.
func drawIcon(size s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded-square app shape with a transparent margin, Big Sur curvature.
    let inset = s * 0.085
    let shape = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = shape.width * 0.2237

    NSGraphicsContext.current!.saveGraphicsState()
    let clip = NSBezierPath(roundedRect: shape, xRadius: radius, yRadius: radius)
    clip.addClip()

    // Diagonal green→teal gradient background.
    let topColor = NSColor(srgbRed: 0.16, green: 0.82, blue: 0.55, alpha: 1)   // fresh green
    let botColor = NSColor(srgbRed: 0.03, green: 0.42, blue: 0.52, alpha: 1)   // deep teal
    NSGradient(starting: topColor, ending: botColor)!.draw(in: shape, angle: -65)

    // Soft top highlight for depth.
    let hi = NSGradient(colors: [NSColor(white: 1, alpha: 0.18), NSColor(white: 1, alpha: 0)])!
    hi.draw(in: shape, angle: -90)
    NSGraphicsContext.current!.restoreGraphicsState()

    // ECG / heartbeat polyline, normalized (x, y) with y up; 0.5 == vertical center.
    let pts: [(CGFloat, CGFloat)] = [
        (0.10, 0.50), (0.32, 0.50),
        (0.40, 0.60),   // small rise
        (0.47, 0.30),   // dip before the spike
        (0.535, 0.84),  // tall R spike
        (0.60, 0.50),
        (0.66, 0.50),
        (0.71, 0.57),   // gentle T bump
        (0.77, 0.50),
        (0.90, 0.50),
    ]
    func map(_ p: (CGFloat, CGFloat)) -> CGPoint {
        CGPoint(x: shape.minX + p.0 * shape.width,
                y: shape.minY + p.1 * shape.height)
    }

    let line = NSBezierPath()
    line.lineWidth = s * 0.05
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.move(to: map(pts[0]))
    for p in pts.dropFirst() { line.line(to: map(p)) }

    // Glow under the stroke.
    ctx.setShadow(offset: .zero, blur: s * 0.03,
                  color: NSColor(srgbRed: 0.6, green: 1.0, blue: 0.8, alpha: 0.9).cgColor)
    NSColor.white.setStroke()
    line.stroke()

    // A bright dot at the spike peak — a live "beat".
    ctx.setShadow(offset: .zero, blur: s * 0.02,
                  color: NSColor(srgbRed: 0.6, green: 1.0, blue: 0.8, alpha: 1).cgColor)
    let peak = map(pts[4])
    let r = s * 0.035
    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: peak.x - r, y: peak.y - r, width: 2 * r, height: 2 * r)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode \(path)\n".utf8)); exit(1)
    }
    try? data.write(to: URL(fileURLWithPath: path))
}

let targets: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

var cache: [CGFloat: NSBitmapImageRep] = [:]
for t in targets {
    let rep = cache[t.px] ?? drawIcon(size: t.px)
    cache[t.px] = rep
    writePNG(rep, to: "\(iconsetDir)/\(t.name).png")
}

if let previewPath {
    writePNG(cache[512] ?? drawIcon(size: 512), to: previewPath)
}

print("wrote \(targets.count) PNGs to \(iconsetDir)")
