//· TicsApp ·
// Punto de entrada: una app que solo vive en la barra de menús

import SwiftUI

@main
struct TicsApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView(state: state)
        } label: {
            Image(nsImage: state.menuBarIcon.image(isSounding: state.isSounding))
        }
        .menuBarExtraStyle(.window)
    }
}
