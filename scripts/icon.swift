// El icono de Tics, dibujado con código: cuatro teclas con T, I, C y S sobre el rojo de la firma
// (#F22). Genera Resources/AppIcon.icns con todos los tamaños que pide macOS, y build-app.sh lo
// copia en la app. Se dibuja una vez a 1024 px y se reduce para el resto, como haría macOS:
// las sombras de AppKit no encogen al dibujar en pequeño.
// Uso: swift scripts/icon.swift

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("Resources/AppIcon.icns")

//- Colores y formas -

/// El rojo del fondo: arriba y abajo del degradado
let backgroundTop = rgb(0xFF5A4E)
let backgroundBottom = rgb(0xD81E2A)

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ path: NSBezierPath, top: NSColor, bottom: NSColor) {
    NSGradient(starting: bottom, ending: top)!.draw(in: path, angle: 90)
}

func withShadow(_ color: NSColor, blur: CGFloat, y: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// Una letra centrada, en SF Pro Rounded como el panel
func letter(_ string: String, size: CGFloat, center: NSPoint) {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
    let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: rgb(0x1C1D22)])
    let bounds = text.size()
    text.draw(at: NSPoint(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2 + size * 0.04))
}

//- El dibujo, a 1024 px -

/// El cuadrado de los iconos de macOS: 824 de 1024, con las esquinas de la plantilla
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = rounded(body, 185)

let icon = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
    withShadow(NSColor.black.withAlphaComponent(0.35), blur: 28, y: -12) {
        NSColor.black.setFill()
        bodyPath.fill()
    }
    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()
    fill(bodyPath, top: backgroundTop, bottom: backgroundBottom)

    // Cuatro teclas en cuadrícula: el faldón y, encima, la cara con su letra
    let keySize: CGFloat = 300, gap: CGFloat = 36
    let origin = NSPoint(x: 512 - keySize - gap / 2, y: 512 - keySize - gap / 2)
    for (i, character) in ["T", "I", "C", "S"].enumerated() {
        let column = CGFloat(i % 2), row = CGFloat(1 - i / 2)
        let key = NSRect(x: origin.x + column * (keySize + gap), y: origin.y + row * (keySize + gap),
                         width: keySize, height: keySize)
        withShadow(NSColor.black.withAlphaComponent(0.4), blur: 20, y: -14) {
            fill(rounded(key, 62), top: rgb(0xF2F2F5), bottom: rgb(0xC9CAD3))
        }
        fill(rounded(key.insetBy(dx: 34, dy: 34).offsetBy(dx: 0, dy: 14), 44), top: rgb(0xFFFFFF), bottom: rgb(0xECEDF2))
        letter(character, size: 150, center: NSPoint(x: key.midX, y: key.midY + 14))
    }
    NSGraphicsContext.restoreGraphicsState()

    // Un brillo fino en el borde
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let rim = rounded(body.insetBy(dx: 2, dy: 2), 183)
    rim.lineWidth = 4
    rim.stroke()
    return true
}

//- El .icns -

func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let full = NSImage(data: png(icon, pixels: 1024))!
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try png(full, pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil no pudo crear el .icns") }
print("→ \(output.path)")
