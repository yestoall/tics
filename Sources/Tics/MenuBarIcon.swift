//· MenuBarIcon ·
// El icono de TICS en la barra de menús, a elegir en el panel. Cuando no suena nada sale más
// tenue, como los controles desactivados de macOS.

import AppKit

enum MenuBarIcon: String, CaseIterable {
    case keyboardFill = "keyboard.fill"
    case keyboard = "keyboard"
    case waveformFill = "waveform.circle.fill"
    case waveform = "waveform.circle"

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
    func image(isSounding: Bool) -> NSImage {
        let size = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "TICS")?
            .withSymbolConfiguration(size) else { return NSImage() }
        // Se redibuja siempre en una imagen nueva: la de un símbolo tal cual, la barra la recorta
        // (de waveform.circle solo quedaban dos arcos). Callada, más transparente. Sigue siendo de
        // plantilla, así que la barra la pinta en su color y respeta la transparencia
        let drawn = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: isSounding ? 1 : 0.4)
            return true
        }
        drawn.isTemplate = true
        return drawn
    }
}
