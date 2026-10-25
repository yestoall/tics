//· PanelWindow ·
// Lo que SwiftUI no deja tocar de la ventana del panel, que crea macOS para MenuBarExtra:
//  - Las esquinas: se recorta con otro radio la vista que lleva el contenido (y el fondo
//    translúcido), el de la ventana se deja transparente y se rehace la sombra con esa forma.
//  - Cómo sale: con la animación de las alertas del sistema, que crece un poco al aparecer.
//  - Cuándo se abre y se cierra: MenuBarExtra no desmonta la vista al cerrar el panel, así que
//    onAppear solo salta la primera vez. La ventana sí avisa cuando pasa a verse o deja de verse.
//    No vale con que sea la activa: abrir otra ventana de Tics se la quita sin cerrar el panel.
// Se apoya en cómo monta Apple esa ventana por dentro: si cambia, el panel vuelve a lo de serie.

import AppKit
import SwiftUI

extension View {
    /// `onVisibility` recibe true cada vez que se abre el panel y false al cerrarlo
    func panelWindow(cornerRadius: CGFloat, onVisibility: @escaping (Bool) -> Void) -> some View {
        background(PanelWindow(radius: cornerRadius, onVisibility: onVisibility))
    }
}

private struct PanelWindow: NSViewRepresentable {
    let radius: CGFloat
    let onVisibility: (Bool) -> Void

    func makeNSView(context: Context) -> WindowView {
        WindowView(radius: radius)
    }

    func updateNSView(_ view: WindowView, context: Context) {
        view.onVisibility = onVisibility
    }
}

private final class WindowView: NSView {
    let radius: CGFloat
    var onVisibility: ((Bool) -> Void)?
    private var observers: [any NSObjectProtocol] = []
    /// Lo último que se avisó, para no repetirlo
    private var isVisible: Bool?

    init(radius: CGFloat) {
        self.radius = radius
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportVisibility() }
        })
        // La ventana termina de montarse después: se espera a la siguiente vuelta
        DispatchQueue.main.async { [weak self] in
            self?.apply()
            // La primera vez puede que ya se vea antes de empezar a escuchar
            self?.reportVisibility()
        }
    }

    private func reportVisibility() {
        guard let window else { return }
        let visible = window.isVisible && window.occlusionState.contains(.visible)
        guard visible != isVisible else { return }
        isVisible = visible
        onVisibility?(visible)
    }

    private func apply() {
        guard let window, let content = window.contentView else { return }
        window.animationBehavior = .alertPanel
        window.isOpaque = false
        window.backgroundColor = .clear
        content.wantsLayer = true
        content.layer?.cornerRadius = radius
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true
        window.invalidateShadow()
    }
}
