//· About ·
// «Acerca de Tics»: el icono, el nombre y la versión, y debajo los créditos: quién la hace, a quién
// se le agradece, de dónde salen los sonidos y dónde está el código. Es una ventana propia y no la de macOS
// (orderFrontStandardAboutPanel), porque esa no deja agrandar ni el icono ni el texto.

import AppKit
import SwiftUI

@MainActor
enum About {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
            window.title = String(localized: "Acerca de TICS")
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Tics vive en la barra de menús: sin activarla, la ventana se queda detrás de la app de delante
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct AboutView: View {
    private static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    private static let copyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
    /// El rojo del corazón de la firma, el de todas las apps de yestoall (#F22)
    private static let heart = Color(red: 1, green: 0.13, blue: 0.13)

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 160, height: 160)

            VStack(spacing: 2) {
                Text(verbatim: "TICS").font(.system(size: 40, weight: .bold))
                if let version = Self.version {
                    Text("Versión \(version)").font(.title3).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                Text("diseñado con ") + Text(Image(systemName: "heart.fill")).foregroundColor(Self.heart)
                    + Text(" por ") + Text(markdown("[@yestoall](https://yestoall.com)"))
                Text(markdown(String(localized: "Gracias a [JoyTap](https://setapp.com/apps/joytap) por la inspiración\ny a [Claude](https://claude.ai) por la ayuda.")))
                Text(markdown(String(localized: "Sonidos de [Mechvibes](https://github.com/hainguyents13/mechvibes) y [kbsim](https://github.com/tplai/kbsim), con licencia MIT.")))
                Text(markdown(String(localized: "Es open source: [el código está en GitHub](https://github.com/yestoall/tics).")))
            }
            .font(.title3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if let copyright = Self.copyright {
                Text(copyright).font(.callout).foregroundStyle(.secondary)
            }
        }
        .fontDesign(.rounded)
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(width: 440)
    }

    private func markdown(_ text: String) -> AttributedString {
        // Respetando los saltos de línea: en markdown normal, uno solo se queda en espacio
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
