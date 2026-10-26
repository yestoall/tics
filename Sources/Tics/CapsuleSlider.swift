//· CapsuleSlider ·
// Un slider como los del Centro de control: la barra tan gruesa como el tirador, rellena de color
// hasta él, y el tirador ovalado y blanco, que desde macOS 26 reacciona al tocarlo (Liquid Glass). El de serie de macOS
// no deja cambiar su forma.
// Arrastrar el tirador lo mueve desde donde está; pulsar en la barra lo lleva ahí. `released`
// avisa al soltar, se haya movido o no: el de serie, sin moverlo, no avisa.

import SwiftUI

struct CapsuleSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    /// Hasta dónde suena de verdad, si es menos que el valor (TICS más bajo): el relleno llega ahí
    /// y el tramo hasta el tirador sale tenue. El tirador sigue en el valor elegido
    var sounding: Double? = nil
    var released: () -> Void = {}

    static let height: CGFloat = 22
    static let knobWidth: CGFloat = 36

    @Environment(\.isEnabled) private var isEnabled
    /// Al empezar a arrastrar: el valor de partida, si se cogió el tirador
    @State private var grabbed: Double?
    @State private var isDragging = false

    private var span: Double { range.upperBound - range.lowerBound }

    var body: some View {
        GeometryReader { geometry in
            let usable = max(geometry.size.width - Self.knobWidth, 1)
            let knobX = usable * (value - range.lowerBound) / span
            let soundingX = usable * (min(sounding ?? value, value) - range.lowerBound) / span
            let fill = isEnabled ? Color.accentColor : Color.primary.opacity(0.25)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(fill.opacity(0.35))
                    .frame(width: knobX + Self.knobWidth)
                Capsule()
                    .fill(fill)
                    .frame(width: soundingX + Self.knobWidth)
                Knob()
                    .frame(width: Self.knobWidth - 4, height: Self.height - 4)
                    .offset(x: knobX + 2)
            }
            .contentShape(.rect)
            .gesture(drag(usable: usable, knobX: knobX))
        }
        .frame(height: Self.height)
        .opacity(isEnabled ? 1 : 0.5)
        // Para VoiceOver y el teclado es un slider de los de siempre
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }

    private func drag(usable: Double, knobX: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if !isDragging {
                    isDragging = true
                    let onKnob = (knobX...(knobX + Self.knobWidth)).contains(drag.startLocation.x)
                    grabbed = onKnob ? value : nil
                }
                let new = if let grabbed {
                    grabbed + drag.translation.width / usable * span
                } else {
                    range.lowerBound + (drag.location.x - Self.knobWidth / 2) / usable * span
                }
                value = min(max(new, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                isDragging = false
                grabbed = nil
                released()
            }
    }
}

/// El tirador: blanco puro, sobre cristal para que reaccione al tocarlo (macOS 26); antes, blanco
/// con sombra sin más
private struct Knob: View {
    var body: some View {
        if #available(macOS 26, *) {
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
        }
    }
}
