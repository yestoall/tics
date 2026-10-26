//· MenuBarIcon ·
// El icono de TICS en la barra de menús, a elegir en el panel. Cuando no suena nada sale más
// tenue, como los controles desactivados de macOS, y con versión nueva lleva un punto.

import AppKit

enum MenuBarIcon: String, CaseIterable {
    case keyboardFill = "keyboard.fill"
    case keyboard = "keyboard"
    case waveformFill = "waveform.circle.fill"
    case waveform = "waveform.circle"

    /// El rojo de yestoall (#F22), el del corazón de la firma
    private static let updateDotColor = NSColor(red: 1, green: 0.13, blue: 0.13, alpha: 1)

    /// El símbolo de SF Symbols que pinta
    var symbol: String { rawValue }

    var name: String {
        switch self {
        case .keyboardFill: String(localized: "Teclado lleno")
        case .keyboard: String(localized: "Teclado vacío")
        case .waveformFill: String(localized: "Ondas llenas")
        case .waveform: String(localized: "Ondas")
        }
    }

    /// La imagen para la barra, algo más grande que la de serie. La etiqueta de MenuBarExtra no
    /// hace caso de .font ni de .imageScale: el tamaño va en la propia imagen
    func image(isSounding: Bool, hasUpdate: Bool = false) -> NSImage {
        let size = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "TICS")?
            .withSymbolConfiguration(size) else { return NSImage() }
        // Se redibuja siempre en una imagen nueva: la de un símbolo tal cual, la barra la recorta
        // (de waveform.circle solo quedaban dos arcos). Callada, más transparente. Sigue siendo de
        // plantilla, así que la barra la pinta en su color y respeta la transparencia
        let drawn = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: isSounding ? 1 : 0.4)
            // Con versión nueva, un punto rojo arriba a la derecha, siempre entero aunque esté
            // callada. Con el rojo la imagen deja de ser de plantilla y la barra ya no la pinta: el
            // icono se tiñe a mano, blanco o negro según lo que tenga la barra detrás al dibujarlo
            if hasUpdate, let context = NSGraphicsContext.current {
                let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                (isDark ? NSColor.white : NSColor.black).set()
                rect.fill(using: .sourceAtop)
                // Antes se vacía un anillo alrededor del punto, para que se despegue del icono
                let dot = NSRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 6, height: 6)
                context.compositingOperation = .clear
                NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
                context.compositingOperation = .sourceOver
                Self.updateDotColor.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        drawn.isTemplate = !hasUpdate
        return drawn
    }
}
