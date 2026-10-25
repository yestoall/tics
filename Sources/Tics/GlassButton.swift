//· GlassButton ·
// Los botones de las ventanas de ajustes, de cristal como los de macOS 26.

import SwiftUI

extension View {
    /// De cristal desde macOS 26; antes, el botón de siempre
    @ViewBuilder func glassButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}
