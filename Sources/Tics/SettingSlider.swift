//· SettingSlider ·
// Un ajuste de los de las ventanas de ajustes, con su nombre, su valor y una CapsuleSlider, que
// avisa al soltar. El tono y el volumen son iguales en el ratón y en el teclado.

import SwiftUI

/// Un ajuste: el nombre y el valor arriba; debajo, la barra con lo que significa cada extremo
struct SettingSlider: View {
    let title: LocalizedStringKey
    let low: Text
    let high: Text
    @Binding var value: Double
    let range: ClosedRange<Double>
    let shown: Text
    let released: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                shown.monospacedDigit()
            }
            .font(.callout)
            HStack(spacing: 8) {
                low.font(.caption).foregroundStyle(.secondary)
                CapsuleSlider(value: $value, range: range, released: released)
                    .accessibilityLabel(Text(title))
                high.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension SettingSlider {
    /// El tono, en octavas: el centro es el de serie y cada lado dobla o parte por dos
    static func pitch(_ pitch: Double, set: @escaping (Double) -> Void, released: @escaping () -> Void) -> SettingSlider {
        SettingSlider(
            title: "Tono", low: Text("grave"), high: Text("agudo"),
            value: Binding(get: { log2(pitch) }, set: { set(pow(2, $0)) }),
            range: log2(SoundSettings.pitchRange.lowerBound)...log2(SoundSettings.pitchRange.upperBound),
            shown: times(pitch),
            released: released
        )
    }

    static func volume(_ volume: Double, set: @escaping (Double) -> Void, released: @escaping () -> Void) -> SettingSlider {
        SettingSlider(
            title: "Volumen", low: Text("flojo"), high: Text("fuerte"),
            value: Binding(get: { volume }, set: { set($0) }),
            range: SoundSettings.volumeRange,
            shown: times(volume),
            released: released
        )
    }

    /// «1,50×»
    private static func times(_ value: Double) -> Text {
        Text(verbatim: value.formatted(.number.precision(.fractionLength(2))) + "×")
    }
}
