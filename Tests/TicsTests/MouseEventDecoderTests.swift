//· MouseEventDecoderTests ·
// De lo que trae el tap del ratón a lo que suena: clics, arrastres (también los que empiezan sin su
// clic, porque yabai se lo ha quedado) y la rueda. Con eventos inventados

import CoreGraphics
import Testing
@testable import Tics

private let ms: UInt64 = 1_000_000

private func raw(_ type: CGEventType, x: Double = 0, at time: UInt64 = 0, lines: Int64 = 0, phase: Int64 = 0) -> RawMouseEvent {
    RawMouseEvent(
        type: type, location: CGPoint(x: x, y: 0), timestamp: time, sourcePID: 0,
        scrollLines: lines, scrollPhase: phase, momentumPhase: 0
    )
}

@Test func unClicSinMoverseEsUnClic() {
    var decoder = MouseEventDecoder()
    #expect(decoder.decode(raw(.leftMouseDown)) == .button(.left, isDown: true))
    #expect(decoder.decode(raw(.leftMouseDragged, x: 1, at: 10 * ms)) == nil)
    #expect(decoder.decode(raw(.leftMouseUp, x: 1, at: 20 * ms)) == .button(.left, isDown: false))
}

@Test func moverseConElBotonPulsadoEsUnArrastre() {
    var decoder = MouseEventDecoder()
    _ = decoder.decode(raw(.leftMouseDown))
    guard case .dragTick = decoder.decode(raw(.leftMouseDragged, x: 10, at: 50 * ms)) else {
        Issue.record("Debía sonar el primer clic del arrastre")
        return
    }
}

@Test func otroBotonDuranteUnArrastreSoloHaceClic() {
    var decoder = MouseEventDecoder()
    _ = decoder.decode(raw(.leftMouseDown))
    _ = decoder.decode(raw(.leftMouseDragged, x: 10, at: 50 * ms))
    #expect(decoder.decode(raw(.rightMouseDown, x: 10, at: 60 * ms)) == .button(.right, isDown: true))
    #expect(decoder.decode(raw(.rightMouseUp, x: 10, at: 70 * ms)) == .button(.right, isDown: false))
    // El arrastre sigue: 40 puntos más, deprisa, suenan
    #expect(decoder.decode(raw(.leftMouseDragged, x: 60, at: 110 * ms)) != nil)
}

//- Arrastres sin su clic (yabai) -

@Test func unArrastreSinSuClicSuenaAlMomento() {
    var decoder = MouseEventDecoder()
    #expect(decoder.decode(raw(.leftMouseDragged, x: 0, at: 0)) == .dragTick(volume: 1))
    // Y sigue como un arrastre: un movimiento pequeño no suena
    #expect(decoder.decode(raw(.leftMouseDragged, x: 1, at: 10 * ms)) == nil)
}

@Test func unArrastreSinSuClicSeAcabaTrasUnRatoQuieto() {
    var decoder = MouseEventDecoder()
    _ = decoder.decode(raw(.leftMouseDragged, x: 0, at: 0))
    _ = decoder.decode(raw(.leftMouseDragged, x: 1, at: 10 * ms))
    // Más de 300 ms sin moverse: el siguiente movimiento empieza otro, y suena
    #expect(decoder.decode(raw(.leftMouseDragged, x: 2, at: 400 * ms)) == .dragTick(volume: 1))
}

@Test func unArrastreSinSuClicSeAcabaConElSiguienteClic() {
    var decoder = MouseEventDecoder()
    _ = decoder.decode(raw(.leftMouseDragged, x: 0, at: 0))
    _ = decoder.decode(raw(.leftMouseDown, x: 0, at: 50 * ms))
    _ = decoder.decode(raw(.leftMouseUp, x: 0, at: 60 * ms))
    // Ya no hay arrastre: el siguiente movimiento sin clic empieza otro
    #expect(decoder.decode(raw(.leftMouseDragged, x: 1, at: 70 * ms)) == .dragTick(volume: 1))
}

@Test func alPararElTapSeOlvidaElBotonPulsado() {
    var decoder = MouseEventDecoder()
    _ = decoder.decode(raw(.leftMouseDown))
    decoder.reset()
    #expect(decoder.decode(raw(.leftMouseDragged, x: 1, at: 10 * ms)) == .dragTick(volume: 1))
}

//- Rueda -

@Test func laRuedaSuenaYElTrackpadNo() {
    var decoder = MouseEventDecoder()
    #expect(decoder.decode(raw(.scrollWheel, lines: 1)) == .scrollTick)
    #expect(decoder.decode(raw(.scrollWheel, at: 100 * ms, lines: 1, phase: 1)) == nil)
    #expect(decoder.decode(raw(.mouseMoved)) == nil)
}
